import Foundation
import GRDB
import Testing
@testable import TonariCore

struct SubtitleParserTests {
    @Test func parsesSRTWithHoursAndCleansTags() {
        let srt = "1\r\n00:00:01,500 --> 00:00:03,000\r\n<i>こんにちは</i>\r\n\r\n2\r\n01:00:00.25 --> 01:00:01.000\r\n{\\an8}二行目\r\n"
        #expect(SubtitleParser.parse(srt, format: "srt") == [
            .init(startMs: 1500, endMs: 3000, text: "こんにちは"),
            .init(startMs: 3_600_250, endMs: 3_601_000, text: "二行目"),
        ])
    }

    @Test func parsesLRCWithMultipleStampsAndCentiseconds() {
        let lrc = "[ti:title]\n[00:05.50][00:10.00]同じ行\n[00:01.123]最初\n"
        #expect(SubtitleParser.parse(lrc, format: "lrc") == [
            .init(startMs: 1123, endMs: 5500, text: "最初"),
            .init(startMs: 5500, endMs: 10000, text: "同じ行"),
            .init(startMs: 10000, endMs: 15000, text: "同じ行"),
        ])
    }
}

struct ScannerAndImportTests {
    let root = URL.temporaryDirectory.appending(path: UUID().uuidString)

    private func write(_ relative: String, _ content: String = "x") throws {
        let url = root.appending(path: relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(content.utf8).write(to: url)
    }

    private func buildLibrary() throws {
        try write("[社团] 作品A RJ01000001/本編/01_start.wav")
        try write("[社团] 作品A RJ01000001/本編/01_start.wav.vtt", "WEBVTT\n\n00:00.000 --> 00:02.000\nやあ\n")
        try write("[社团] 作品A RJ01000001/cover.jpg")
        try write("合集/rj1000002_b/track.mp3")
        try write("合集/rj1000002_b/readme.txt")
        try write("没有编号/a.mp3")
    }

    @Test func rjIdsAreFoundAtThreeDepths() throws {
        try buildLibrary()
        let scan = FolderScanner.scan(root)
        #expect(Set(scan.works.map(\.productId)) == ["RJ01000001", "RJ1000002"])
        #expect(scan.unrecognizedDirs.map { URL(filePath: $0).lastPathComponent } == ["没有编号"])
        let a = scan.works.first { $0.productId == "RJ01000001" }!
        #expect(a.files(.audio).map(\.relativePath) == ["本編/01_start.wav"])
        #expect(Set(a.files.map(\.kind)) == [.audio, .subtitle, .image])
        #expect(FolderScanner.scan(root, only: "RJ1000002").works.map(\.productId) == ["RJ1000002"])
    }

    @Test func importWritesSnapshotAndRescanKeepsProgress() throws {
        try buildLibrary()
        let db = try AppDatabase.inMemory()
        let first = try db.applyScanResult(FolderScanner.scan(root), sourceFolderId: "f1")
        #expect(first.worksInserted == 2)
        #expect(first.tracksTotal == 2)

        let trackId = "RJ01000001|本編/01_start.wav"
        let (subtitle, files, track) = try db.reader.read { db in
            (try Subtitle.fetchOne(db, key: trackId)!, try WorkFile.fetchCount(db), try Track.fetchOne(db, key: trackId)!)
        }
        #expect(subtitle.originalLinesJson == [.init(startMs: 0, endMs: 2000, text: "やあ")])
        #expect(files == 3)
        #expect(track.title == "01_start")
        #expect(track.categoryHint == "main")

        try db.writer.write { try $0.execute(sql: "UPDATE tracks SET last_position_ms = 4200 WHERE id = ?", arguments: [trackId]) }
        try FileManager.default.removeItem(at: root.appending(path: "[社团] 作品A RJ01000001/cover.jpg"))
        let second = try db.applyScanResult(FolderScanner.scan(root), sourceFolderId: "f1")
        #expect(second.worksUpdated == 2)
        let (position, fileCount) = try db.reader.read { db in
            (try Int.fetchOne(db, sql: "SELECT last_position_ms FROM tracks WHERE id = ?", arguments: [trackId])!, try WorkFile.fetchCount(db))
        }
        #expect(position == 4200)
        #expect(fileCount == 2)
    }

    @Test func skipExistingOnlyAddsNewWorks() throws {
        try buildLibrary()
        let db = try AppDatabase.inMemory()
        _ = try db.applyScanResult(FolderScanner.scan(root, only: "RJ01000001"), sourceFolderId: "f1")
        let summary = try db.applyScanResult(FolderScanner.scan(root), sourceFolderId: "f1", skipExisting: true)
        #expect(summary.worksInserted == 1)
        #expect(summary.worksSkipped == 1)
        #expect(summary.workIds == ["RJ1000002"])
    }

    @Test func removedWorksStayRemovedUntilRevived() throws {
        try buildLibrary()
        let db = try AppDatabase.inMemory()
        _ = try db.applyScanResult(FolderScanner.scan(root), sourceFolderId: "f1")
        try db.removeWork("RJ01000001")
        #expect(try db.reader.read { try Track.filter(Column("work_id") == "RJ01000001").fetchCount($0) } == 0)

        let rescan = try db.applyScanResult(FolderScanner.scan(root), sourceFolderId: "f1")
        #expect(!rescan.workIds.contains("RJ01000001"))
        #expect(try db.reader.read { try SourceQueries.removedWorks($0).map(\.productId) } == ["RJ01000001"])

        let revived = try db.applyScanResult(FolderScanner.scan(root, only: "RJ01000001"), sourceFolderId: "f1", reviveTombstoned: true)
        #expect(revived.workIds == ["RJ01000001"])
        #expect(try db.reader.read { try SourceQueries.removedWorks($0) }.isEmpty)
    }

    @Test func deletingSourceTakesItsWorks() throws {
        try buildLibrary()
        let db = try AppDatabase.inMemory()
        try db.writer.write { db in
            try ImportedFolder(id: "f1", displayName: "x", bookmarkBase64: "", type: "local", serverId: nil,
                               remotePath: "/x", createdAt: .now, updatedAt: .now).insert(db)
        }
        _ = try db.applyScanResult(FolderScanner.scan(root), sourceFolderId: "f1")
        #expect(try db.reader.read { try SourceQueries.all($0).map(\.workCount) } == [2])
        #expect(try db.deleteSource("f1") == 2)
        let counts = try db.reader.read { db in
            [try Work.fetchCount(db), try Track.fetchCount(db), try WorkFile.fetchCount(db), try Subtitle.fetchCount(db), try ImportedFolder.fetchCount(db)]
        }
        #expect(counts == [0, 0, 0, 0, 0])
    }

    @Test func localImportAddsFolderOnceAndImportsThroughBookmark() async throws {
        try buildLibrary()
        let db = try AppDatabase.inMemory()
        let flow = LocalImport(database: db)
        let folder = try flow.addFolder(root)
        #expect(try flow.addFolder(root).id == folder.id)
        let summary = try await flow.importFolder(folder)
        #expect(summary.worksInserted == 2)

        let work = try await db.reader.read { try Work.fetchOne($0, key: "RJ1000002")! }
        try db.removeWork(work.productId)
        let revived = try await flow.reimportWork(work, from: folder)
        #expect(revived.workIds == ["RJ1000002"])
    }
}

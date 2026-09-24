import Foundation
import GRDB
import Testing
@testable import TonariCore

struct P115CipherTests {
    /// Vector from the Flutter build's test, itself checked against p115cipher.
    @Test func encryptsDownurlPayloadLikeFlutter() {
        #expect(P115Cipher.encrypt(["pickcode": "abc123"])
            == "C/K77ytKjE5SY30/UtT17jMnyejh5T37Y+9d81OQjzpnjAOCFf4wcD8rdnb1libQRKTXYIemT2bL+larZoLw5pZeGo5VVhAJZ30kBza7gFvthr+fMoV5JdDakSH1ROiHtPjgzw58owP5qcr/mvbf1WOBGkfJwpiFIM9UFR/xlbo=")
    }
}

struct P115ImportTests {
    /// A fake 115 tree: cid → entries.
    static let tree: [String: [RemoteEntry]] = [
        "root": [
            RemoteEntry(id: "c1", path: "c1", name: "[社团] RJ01000001", kind: .folder, sourceId: "p115"),
            RemoteEntry(id: "c2", path: "c2", name: "合集", kind: .folder, sourceId: "p115"),
        ],
        "c1": [
            RemoteEntry(id: "c11", path: "c11", name: "特典", kind: .folder, sourceId: "p115"),
            RemoteEntry(id: "f1", path: "f1", name: "01.mp3", kind: .audio, size: 100, pickcode: "pc1", sourceId: "p115"),
            RemoteEntry(id: "f2", path: "f2", name: "01.mp3.vtt", kind: .subtitle, size: 10, pickcode: "pc2", sourceId: "p115"),
        ],
        "c11": [RemoteEntry(id: "f3", path: "f3", name: "おまけ.wav", kind: .audio, size: 50, pickcode: "pc3", sourceId: "p115")],
        "c2": [RemoteEntry(id: "c21", path: "c21", name: "RJ01000002", kind: .folder, sourceId: "p115")],
        "c21": [RemoteEntry(id: "f4", path: "f4", name: "a.flac", kind: .audio, size: 10, pickcode: "pc4", sourceId: "p115")],
    ]

    func importer(_ db: AppDatabase, failing: Set<String> = []) -> P115Import {
        P115Import(database: db, transport: .init(
            list: { cid in
                if failing.contains(cid) { throw P115Error.failed("限流") }
                return Self.tree[cid]!
            },
            download: { _ in Data("WEBVTT\n\n00:00.000 --> 00:01.000\nはい\n".utf8) }
        ))
    }

    let root = RemoteEntry(id: "root", path: "root", name: "ASMR", kind: .folder, sourceId: "p115")

    @Test func importsWorksWithPickcodesAndSubtitles() async throws {
        let db = try AppDatabase.inMemory()
        let summary = try await importer(db).importFolder(root)
        #expect(summary.worksInserted == 2)
        let (work, tracks, subtitle, source) = try await db.reader.read { db in
            (
                try Work.fetchOne(db, key: "RJ01000001")!,
                try Track.filter(Column("work_id") == "RJ01000001").order(Column("relative_path")).fetchAll(db),
                try Subtitle.fetchOne(db, key: "RJ01000001|01.mp3")!,
                try ImportedFolder.fetchOne(db)!
            )
        }
        #expect(work.localFolderPath == "c1")
        #expect(tracks.map(\.filePath) == ["pc1", "pc3"])
        #expect(tracks.map(\.categoryHint) == [nil, "bonus"])
        #expect(tracks.map(\.parentDirName) == ["[社团] RJ01000001", "特典"])
        #expect(subtitle.originalLinesJson.map(\.text) == ["はい"])
        #expect(source.displayName == "115 网盘 / ASMR")
        #expect(work.importedFolderId == source.id)
    }

    @Test func reimportSkipsExistingWorksWhileScanning() async throws {
        let db = try AppDatabase.inMemory()
        _ = try await importer(db).importFolder(root)
        let again = try await importer(db).importFolder(root)
        #expect(again.worksInserted == 0)
        #expect(again.worksSkipped == 2)
        #expect(try await db.reader.read { try ImportedFolder.fetchCount($0) } == 1)
    }

    @Test func failedSubfolderMarksWorkIncomplete() async throws {
        let db = try AppDatabase.inMemory()
        let summary = try await importer(db, failing: ["c11"]).importFolder(root)
        #expect(summary.incompleteWorks == ["RJ01000001"])
        #expect(try await db.reader.read { try Work.fetchOne($0, key: "RJ01000001") } == nil)
    }

    @Test func singleWorkRescanRevivesTombstone() async throws {
        let db = try AppDatabase.inMemory()
        _ = try await importer(db).importFolder(root)
        try db.removeWork("RJ01000002")
        let work = try await db.reader.read { try Work.fetchOne($0, key: "RJ01000002")! }
        let summary = try await importer(db).reimportWork(work)
        #expect(summary.workIds == ["RJ01000002"])
        #expect(try await db.reader.read { try Track.filter(Column("work_id") == "RJ01000002").fetchCount($0) } == 1)
    }

    @Test func cookieMergeKeepsSessionAndAddsRedirectCookies() {
        #expect(P115Client.mergeCookies("UID=u; CID=c", ["acw_tc=x; Path=/", "CID=c2"]) == "UID=u; CID=c2; acw_tc=x")
    }
}

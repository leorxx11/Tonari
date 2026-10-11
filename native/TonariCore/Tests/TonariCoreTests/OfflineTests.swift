import Foundation
import GRDB
import Testing
@testable import TonariCore

struct OfflineTests {
    let database = try! AppDatabase.inMemory()
    let files = OfflineFiles(root: URL.temporaryDirectory.appending(path: UUID().uuidString))

    private func track(_ workId: String, _ path: String) -> Track {
        Track(
            id: "\(workId)|\(path)", workId: workId, filePath: "pc-\(path)", relativePath: path,
            fileName: String(path.split(separator: "/").last!), fileFormat: "wav", fileSizeBytes: 10,
            durationMs: 1000, sampleRate: nil, bitRate: nil, categoryHint: nil, userCategory: nil,
            parentDirName: "", trackNumber: nil, title: path, alternateQualityPathsJson: [:],
            lastPositionMs: 0, playCount: 0, createdAt: Fixtures.date, updatedAt: Fixtures.date, titleZh: nil
        )
    }

    private func seed() throws -> [Track] {
        let tracks = [
            track("RJ1", "WAV/01.wav"), track("RJ1", "WAV/02.wav"), track("RJ1", "MP3/01.mp3"),
            track("RJ2", "01.wav"),
        ]
        try database.writer.write { db in
            try Fixtures.work("RJ1").insert(db)
            try Fixtures.work("RJ2").insert(db)
            for track in tracks { try track.insert(db) }
        }
        return tracks
    }

    private func download(_ track: Track) throws {
        let temp = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try Data("audio".utf8).write(to: temp)
        try files.store(temp, for: "\(track.workId)/\(track.relativePath)")
    }

    @Test func downloadsOnlyTheChosenFolderOldestWorkFirst() throws {
        let tracks = try seed()
        try database.keepOffline("RJ2", folder: [], at: Date(timeIntervalSince1970: 20))
        try database.keepOffline("RJ1", folder: ["WAV"], at: Date(timeIntervalSince1970: 10))

        #expect(try database.reader.read { try OfflineQueries.nextPending($0, files: files) }?.relativePath == "WAV/01.wav")
        #expect(try database.reader.read { try OfflineQueries.track(at: "RJ1/WAV/02.wav", $0) }?.id == tracks[1].id)
        try download(tracks[0])
        #expect(try database.reader.read { try OfflineQueries.nextPending($0, files: files) }?.relativePath == "WAV/02.wav")
        #expect(try database.reader.read { try OfflineQueries.status(of: "RJ1", $0, files: files) } == .init(downloaded: 1, total: 2))

        try download(tracks[1])
        #expect(try database.reader.read { try OfflineQueries.nextPending($0, files: files) }?.workId == "RJ2")
        #expect(try database.reader.read { try OfflineQueries.status(of: "RJ1", $0, files: files) }!.isComplete)
        #expect(files.localURL(for: tracks[2]) == nil)
        #expect(try Data(contentsOf: files.localURL(for: tracks[0])!) == Data("audio".utf8))
        #expect(files.bytes(of: "RJ1") == 10)

        try download(tracks[3])
        #expect(try database.reader.read { try OfflineQueries.nextPending($0, files: files) } == nil)
        #expect(try database.reader.read { try OfflineQueries.entries($0, files: files) }.map(\.id) == ["RJ1", "RJ2"])
    }

    @Test func removingAWorkForgetsItAndPruneDeletesItsCopies() throws {
        let tracks = try seed()
        try database.keepOffline("RJ1", folder: ["WAV"])
        try database.keepOffline("RJ2", folder: [])
        try download(tracks[0])
        try download(tracks[3])

        try database.removeWork("RJ1")
        let kept = try database.reader.read { try Set(OfflineQueries.all($0).map(\.workId)) }
        #expect(kept == ["RJ2"])
        try files.prune(keeping: kept)
        #expect(files.localURL(for: tracks[0]) == nil)
        #expect(files.localURL(for: tracks[3]) != nil)

        try database.removeOffline("RJ2")
        #expect(try database.reader.read { try OfflineQueries.status(of: "RJ2", $0, files: files) } == nil)
    }
}

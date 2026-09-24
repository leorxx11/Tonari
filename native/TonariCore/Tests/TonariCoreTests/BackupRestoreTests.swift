import Foundation
import GRDB
import Testing
@testable import TonariCore

struct BackupRestoreTests {
    let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
    var backup: URL { root.appending(path: "Tonari备份_2026-09-24_2046") }
    var documents: URL { root.appending(path: "Documents") }
    let defaults = UserDefaults(suiteName: "BackupRestoreTests.\(UUID().uuidString)")!

    init() throws {
        try FileManager.default.createDirectory(at: backup.appending(path: "images/RJ01000001"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    }

    private func writeBackup(schemaVersion: Int = 17) throws {
        try AppDatabase.open(in: backup).writer.write { try Fixtures.work("RJ01000001").insert($0) }
        try Data("jpg".utf8).write(to: backup.appending(path: "images/RJ01000001/main.jpg"))
        try Data(#"""
            {"theme.mode":{"t":"s","v":"system"},"privacy.blurOnBackground":{"t":"b","v":true},
             "player.seekStepSeconds":{"t":"i","v":5},"subtitle.overlay.dy":{"t":"d","v":186.5},
             "tags":{"t":"l","v":["a","b"]},"diagnostic.log.enabled":{"t":"b","v":false}}
            """#.utf8).write(to: backup.appending(path: "prefs.json"))
        try Data(#"{"p115_cookie":"UID=1","webdav_password:abc":"pw"}"#.utf8)
            .write(to: backup.appending(path: "secrets.json"))
        try Data("""
            {"formatVersion":2,"schemaVersion":\(schemaVersion),"createdAt":"2026-09-24T20:46:35.730600",
             "dirs":["images","videoCovers"],"includesSecrets":true}
            """.utf8).write(to: backup.appending(path: BackupRestore.manifestName))
    }

    @Test func rejectsFolderWithoutManifest() {
        #expect(throws: BackupRestore.Invalid.self) { try BackupRestore.inspect(backup) }
    }

    @Test func rejectsOtherSchemaVersions() throws {
        try writeBackup(schemaVersion: 16)
        let error = #expect(throws: BackupRestore.Invalid.self) { try BackupRestore.inspect(backup) }
        #expect(error?.errorDescription?.contains("16") == true)
    }

    @Test func nothingToApplyWithoutStagedRestore() throws {
        #expect(try BackupRestore.applyPending(in: documents, defaults: defaults) { _ in } == nil)
    }

    @Test func stagesThenAppliesOnNextLaunch() throws {
        try writeBackup()
        try FileManager.default.createDirectory(at: documents.appending(path: "images/old"), withIntermediateDirectories: true)
        try AppDatabase.open(in: documents).writer.write { try Fixtures.work("RJ09999999").insert($0) }

        var progress: [Int64] = []
        var total: Int64 = 0
        try BackupRestore.stage(backup, into: documents) { done, all in
            progress.append(done)
            total = all
        }
        #expect(progress.first == 0)
        #expect(progress.last == total)

        var secrets: [String: String] = [:]
        let summary = try #require(try BackupRestore.applyPending(in: documents, defaults: defaults) { secrets = $0 })

        #expect(summary.prefs == 5)
        #expect(summary.secrets == 2)
        #expect(summary.dirs == ["images"])
        #expect(secrets == ["p115_cookie": "UID=1", "webdav_password:abc": "pw"])
        #expect(defaults.string(forKey: "theme.mode") == "system")
        #expect(defaults.bool(forKey: "privacy.blurOnBackground"))
        #expect(defaults.integer(forKey: "player.seekStepSeconds") == 5)
        #expect(defaults.double(forKey: "subtitle.overlay.dy") == 186.5)
        #expect(defaults.stringArray(forKey: "tags") == ["a", "b"])
        #expect(defaults.object(forKey: "diagnostic.log.enabled") == nil)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: documents.appending(path: "images/RJ01000001/main.jpg").path))
        #expect(!fm.fileExists(atPath: documents.appending(path: "images/old").path))
        #expect(!fm.fileExists(atPath: documents.appending(path: "restore_pending").path))
        let ids = try AppDatabase.open(in: documents).reader.read { try String.fetchAll($0, sql: "SELECT product_id FROM works") }
        #expect(ids == ["RJ01000001"])
    }

    @Test func incompleteStagingIsNotApplied() throws {
        try writeBackup()
        try BackupRestore.stage(backup, into: documents) { _, _ in }
        try FileManager.default.removeItem(at: documents.appending(path: "restore_pending/\(BackupRestore.manifestName)"))
        #expect(try BackupRestore.applyPending(in: documents, defaults: defaults) { _ in } == nil)
    }
}

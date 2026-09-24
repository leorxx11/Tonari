import Foundation
import GRDB
import Testing
@testable import TonariCore

/// Checks against a real backup folder exported by the Flutter build.
/// Run with `TONARI_BACKUP=<unzipped backup folder> swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["TONARI_BACKUP"] != nil))
struct RealBackupTests {
    let backup = URL(filePath: ProcessInfo.processInfo.environment["TONARI_BACKUP"]!)
    let dbQueue: DatabaseQueue

    init() throws {
        var config = AppDatabase.configuration
        config.readonly = true
        dbQueue = try DatabaseQueue(path: backup.appending(path: AppDatabase.fileName).path, configuration: config)
    }

    @Test func manifestIsAccepted() throws {
        let manifest = try BackupRestore.inspect(backup)
        #expect(manifest.dirs.allSatisfy { BackupRestore.dirs[$0] != nil })
    }

    @Test func schemaMatchesNativeDefinition() throws {
        let native = try AppDatabase.inMemory()
        func columns(_ reader: any DatabaseReader) throws -> [String: [String]] {
            try reader.read { db in
                let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
                return try Dictionary(uniqueKeysWithValues: tables.map { table in
                    let info = try Row.fetchAll(db, sql: "PRAGMA table_info(\"\(table)\")").map { row in
                        "\(row["name"] as String) \(row["type"] as String) notnull=\(row["notnull"] as Int) default=\(row["dflt_value"] as String? ?? "-") pk=\(row["pk"] as Int)"
                    }
                    return (table, info.sorted())
                })
            }
        }
        #expect(try columns(dbQueue) == columns(native.reader))
        #expect(try dbQueue.read { try AppDatabase.userVersion($0) } == Schema.version)
    }

    @Test func everyRowOfEveryTableDecodes() throws {
        let types: [any DriftRecord.Type] = [
            Work.self, Track.self, WorkFile.self, Subtitle.self, ImportedFolder.self, WebdavServer.self,
            LlmProvider.self, AppEvent.self, PlayHistoryEntry.self, ListenLog.self, LibraryCollection.self,
            CollectionWork.self, CollectionVideo.self, VideoItem.self,
        ]
        try dbQueue.read { db in
            for type in types {
                let decoded = try type.fetchAll(db).count
                let raw = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(type.databaseTableName)")!
                #expect(decoded == raw, "\(type.databaseTableName)")
                print("\(type.databaseTableName): \(decoded)")
            }
        }
    }

    @Test func imagePathsResolveInsideBackup() throws {
        let works = try dbQueue.read { try Work.fetchAll($0) }
        let missing = works.compactMap(\.mainImageLocalPath).filter {
            !FileManager.default.fileExists(atPath: backup.appending(path: $0).path)
        }
        #expect(missing.isEmpty, "missing: \(missing.prefix(5))")
    }

    /// Hits DLsite. A refresh keeps a translation only when the re-parsed
    /// title and description content equal what the Flutter build stored.
    /// Run with `TONARI_LIVE=1` as well.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TONARI_LIVE"] != nil))
    func liveParseReproducesStoredText() async throws {
        let works = try await dbQueue.read { try Work.filter(Column("description_html_zh") != nil).fetchAll($0) }
        let client = DLsiteClient()
        for work in works {
            let parsed = try DLsiteParser.parseHTML(try await client.workPage(work.productId), productId: work.productId)
            #expect(parsed.title == work.title, "\(work.productId) title")
            #expect(MetadataEnrichment.content(parsed.descriptionHtml) == MetadataEnrichment.content(work.descriptionHtml), "\(work.productId) description")
        }
    }
}

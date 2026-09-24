import Foundation
import GRDB
import Testing
@testable import TonariCore

/// Reads a real database exported by the Flutter build's backup feature.
/// Run with `TONARI_DB=<backup>/tonari.sqlite swift test`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["TONARI_DB"] != nil))
struct FlutterDatabaseTests {
    let dbQueue: DatabaseQueue

    init() throws {
        var config = Configuration()
        config.readonly = true
        dbQueue = try DatabaseQueue(path: ProcessInfo.processInfo.environment["TONARI_DB"]!, configuration: config)
    }

    @Test func everyWorkRowDecodes() throws {
        let (works, count) = try dbQueue.read { db in
            (try Work.fetchAll(db), try Work.fetchCount(db))
        }
        #expect(works.count == count)
        #expect(count > 0)

        let sample = try #require(works.first { !$0.voiceActors.isEmpty && $0.releaseDate != nil })
        print("works=\(count) sample=\(sample.productId) \(sample.title) \(sample.voiceActors) \(sample.releaseDate!)")
    }

    @Test func tableRowCounts() throws {
        let (version, counts) = try dbQueue.read { db in
            (try Int.fetchOne(db, sql: "PRAGMA user_version")!, try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
                .map { ($0, try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \"\($0)\"")!) })
        }
        print("schema version \(version)")
        for (table, count) in counts { print("\(table): \(count)") }
    }
}

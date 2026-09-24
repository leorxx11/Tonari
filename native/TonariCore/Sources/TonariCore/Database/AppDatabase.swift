import Foundation
import GRDB

public final class AppDatabase: Sendable {
    public static let fileName = "tonari.sqlite"

    /// Stand-in for SwiftUI previews and environment defaults.
    public static let empty = try! inMemory()

    public let writer: any DatabaseWriter
    public var reader: any DatabaseReader { writer }

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try migrate()
    }

    public static func open(in directory: URL) throws -> AppDatabase {
        let path = directory.appending(path: fileName).path
        return try AppDatabase(DatabasePool(path: path, configuration: configuration))
    }

    public static func inMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue(configuration: configuration))
    }

    /// Drift never enabled foreign keys, and existing rows and delete orders
    /// rely on that.
    static var configuration: Configuration {
        var config = Configuration()
        config.foreignKeysEnabled = false
        return config
    }

    /// Continues Drift's `user_version` numbering: 0 is a fresh file, 17 is the
    /// Flutter schema; native schema changes bump it from 18 on.
    private func migrate() throws {
        try writer.write { db in
            if try Self.userVersion(db) == 0 {
                for sql in Schema.tables {
                    try db.execute(sql: sql)
                }
                try db.execute(sql: "PRAGMA user_version = \(Schema.version)")
            }
            let version = try Self.userVersion(db)
            precondition(version == Schema.version, "Unsupported database schema \(version)")
        }
    }

    static func userVersion(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "PRAGMA user_version")!
    }
}

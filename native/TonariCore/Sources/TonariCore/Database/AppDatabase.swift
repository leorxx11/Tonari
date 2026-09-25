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
    /// Flutter schema (a restored Flutter backup starts there); native schema
    /// changes count up from 18.
    private func migrate() throws {
        try writer.write { db in
            if try Self.userVersion(db) == 0 {
                for sql in Schema.tables {
                    try db.execute(sql: sql)
                }
                try db.execute(sql: "PRAGMA user_version = \(Schema.flutterVersion)")
            }
            var version = try Self.userVersion(db)
            precondition((Schema.flutterVersion...Schema.version).contains(version), "Unsupported database schema \(version)")
            while version < Schema.version {
                try db.execute(sql: Schema.migrations[version - Schema.flutterVersion])
                version += 1
                try db.execute(sql: "PRAGMA user_version = \(version)")
            }
        }
    }

    static func userVersion(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "PRAGMA user_version")!
    }
}

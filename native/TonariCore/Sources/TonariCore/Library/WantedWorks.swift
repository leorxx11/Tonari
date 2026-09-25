import Foundation
import GRDB

/// 待入库: works noted from DLsite to add to the library later. An entry
/// shows as imported once the library holds its RJ number.
public struct WantedWork: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "wanted_works"

    public var productId: String
    public var title: String
    public var circle: String?
    public var coverUrl: String
    public var addedAt: Date

    public var id: String { productId }

    public init(productId: String, title: String, circle: String?, coverUrl: String, addedAt: Date) {
        self.productId = productId
        self.title = title
        self.circle = circle
        self.coverUrl = coverUrl
        self.addedAt = addedAt
    }
}

public enum WantedWorks {
    public struct Entry: Sendable, Identifiable, Hashable {
        public let work: WantedWork
        public let imported: Bool
        public var id: String { work.productId }
    }

    /// Newest first, each marked when the library already has it.
    public static func all(_ db: Database) throws -> [Entry] {
        let owned = try Set(String.fetchAll(db, sql: "SELECT product_id FROM works WHERE is_removed = 0"))
        return try WantedWork.order(Column("added_at").desc).fetchAll(db)
            .map { Entry(work: $0, imported: owned.contains($0.productId)) }
    }

    public static func contains(_ productId: String, _ db: Database) throws -> Bool {
        try WantedWork.exists(db, key: productId)
    }
}

extension AppDatabase {
    public func addWanted(_ work: WantedWork) throws {
        try writer.write { try work.insert($0, onConflict: .replace) }
    }

    public func removeWanted(_ productId: String) throws {
        _ = try writer.write { try WantedWork.deleteOne($0, key: productId) }
    }

    /// Drops the entries the library now holds.
    public func clearImportedWanted() throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM wanted_works WHERE product_id IN (SELECT product_id FROM works WHERE is_removed = 0)")
        }
    }
}

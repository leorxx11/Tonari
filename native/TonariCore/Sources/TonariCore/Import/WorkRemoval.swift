import Foundation
import GRDB

extension AppDatabase {
    /// Drops a work's snapshot (tracks, files, subtitles) but keeps the row as
    /// a tombstone so folder re-imports don't bring it back.
    public func removeWork(_ productId: String) throws {
        try writer.write { db in
            try Self.deleteSnapshot(of: [productId], db)
            try db.execute(sql: "UPDATE works SET is_removed = 1, updated_at = ? WHERE product_id = ?",
                           arguments: [Date.now.unixSeconds, productId])
        }
    }

    /// Forgets a removed work entirely; a later import adds it as new.
    public func deleteWorkPermanently(_ productId: String) throws {
        try writer.write { db in
            try Self.deleteSnapshot(of: [productId], db)
            try Work.deleteOne(db, key: productId)
        }
    }

    /// Deletes a source and every work that came from it, tombstones
    /// included. Returns how many works went with it.
    @discardableResult
    public func deleteSource(_ folderId: String) throws -> Int {
        try writer.write { db in
            let ids = try String.fetchAll(db, Work.filter(Column("imported_folder_id") == folderId).select(Column("product_id")))
            try Self.deleteSnapshot(of: ids, db)
            try Work.filter(keys: ids).deleteAll(db)
            try ImportedFolder.deleteOne(db, key: folderId)
            return ids.count
        }
    }

    private static func deleteSnapshot(of productIds: [String], _ db: Database) throws {
        let trackIds = try String.fetchAll(db, Track.filter(productIds.contains(Column("work_id"))).select(Column("id")))
        try Subtitle.filter(trackIds.contains(Column("track_id"))).deleteAll(db)
        try Track.filter(productIds.contains(Column("work_id"))).deleteAll(db)
        try WorkFile.filter(productIds.contains(Column("work_id"))).deleteAll(db)
    }
}

public enum SourceQueries {
    public struct Source: Sendable, Identifiable {
        public let folder: ImportedFolder
        /// Works a delete would remove, tombstones included.
        public let workCount: Int
        public var id: String { folder.id }
    }

    public static func all(_ db: Database) throws -> [Source] {
        let counts = try Row.fetchAll(db, sql: "SELECT imported_folder_id AS id, COUNT(*) AS n FROM works GROUP BY imported_folder_id")
        let byId = Dictionary(uniqueKeysWithValues: counts.compactMap { row in (row["id"] as String?).map { ($0, row["n"] as Int) } })
        return try ImportedFolder.order(Column("created_at").desc).fetchAll(db).map { Source(folder: $0, workCount: byId[$0.id] ?? 0) }
    }

    public static func removedWorks(_ db: Database) throws -> [Work] {
        try Work.filter(Column("is_removed") == true).order(Column("updated_at").desc).fetchAll(db)
    }
}

import Foundation
import GRDB

extension AppDatabase {
    public func setFavorite(_ productId: String, _ favorite: Bool) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE works SET is_favorite = ?, updated_at = ? WHERE product_id = ?",
                arguments: [favorite, Date.now.unixSeconds, productId]
            )
        }
    }

    public func setVideoFavorite(_ videoId: String, _ favorite: Bool) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE video_items SET is_favorite = ? WHERE id = ?", arguments: [favorite, videoId])
        }
    }

    @discardableResult
    public func createCollection(named name: String) throws -> String {
        let now = Date.now
        let collection = LibraryCollection(id: UUID().uuidString.lowercased(), name: name, sortOrder: 0, createdAt: now, updatedAt: now)
        try writer.write { try collection.insert($0) }
        return collection.id
    }

    public func renameCollection(_ id: String, to name: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE collections SET name = ?, updated_at = ? WHERE id = ?",
                arguments: [name, Date.now.unixSeconds, id]
            )
        }
    }

    /// Deletes only the group; its works and videos stay in the library.
    public func deleteCollection(_ id: String) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM collection_works WHERE collection_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM collection_videos WHERE collection_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM collections WHERE id = ?", arguments: [id])
        }
    }

    public func setMembership(work productId: String, collection collectionId: String, member: Bool) throws {
        try writer.write { db in
            if member {
                try CollectionWork(collectionId: collectionId, workId: productId, addedAt: .now).insert(db, onConflict: .ignore)
            } else {
                try db.execute(
                    sql: "DELETE FROM collection_works WHERE collection_id = ? AND work_id = ?",
                    arguments: [collectionId, productId]
                )
            }
        }
    }
}

extension Date {
    /// Drift stores dates as whole Unix seconds.
    var unixSeconds: Int64 { Int64(timeIntervalSince1970) }
}

/// How the favorites page orders its groups.
public enum CollectionSort: String, CaseIterable, Sendable {
    case createdAt, name, recentlyAdded

    public static let preferenceKey = "favorites.collectionSort"

    public var label: String {
        switch self {
        case .createdAt: "创建时间"
        case .name: "名称"
        case .recentlyAdded: "最近加入"
        }
    }

    public func sorted(_ summaries: [CollectionQueries.Summary]) -> [CollectionQueries.Summary] {
        switch self {
        case .createdAt: summaries.sorted { $0.collection.createdAt < $1.collection.createdAt }
        case .name: summaries.sorted { $0.collection.name.localizedStandardCompare($1.collection.name) == .orderedAscending }
        case .recentlyAdded: summaries.sorted { ($0.lastAddedAt ?? .distantPast) > ($1.lastAddedAt ?? .distantPast) }
        }
    }
}

/// How a group (or all favorites) orders its works.
public enum CollectionWorkSort: String, CaseIterable, Sendable {
    case addedAt, releaseDate, title

    public static let preferenceKey = "favorites.workSort"

    public var label: String {
        switch self {
        case .addedAt: "加入时间"
        case .releaseDate: "发售日期"
        case .title: "标题"
        }
    }

    /// `added` is the membership or import time column in scope.
    func orderSQL(added: String) -> String {
        switch self {
        case .addedAt: "\(added) DESC"
        case .releaseDate: "w.release_date IS NULL, w.release_date DESC"
        case .title: "COALESCE(NULLIF(w.title_zh, ''), w.title) COLLATE NOCASE"
        }
    }
}

public enum CollectionQueries {
    public struct Summary: Sendable, Identifiable, Hashable {
        public let collection: LibraryCollection
        public let workCount: Int
        public let videoCount: Int
        /// Up to four covers of the works added last, for the collage.
        public let covers: [String]
        public let lastAddedAt: Date?
        public var id: String { collection.id }
    }

    public static func summaries(_ db: Database) throws -> [Summary] {
        let collections = try LibraryCollection.order(Column("sort_order"), Column("created_at")).fetchAll(db)
        let works = try countByCollection(db, table: "collection_works", join: "JOIN works w ON w.product_id = m.work_id AND w.is_removed = 0")
        let videos = try countByCollection(db, table: "collection_videos", join: "")
        let coverRows = try Row.fetchAll(db, sql: """
            SELECT m.collection_id, w.main_image_local_path AS cover FROM collection_works m
            JOIN works w ON w.product_id = m.work_id AND w.is_removed = 0
            WHERE w.main_image_local_path IS NOT NULL ORDER BY m.added_at DESC
            """)
        let covers = Dictionary(grouping: coverRows, by: { $0["collection_id"] as String }).mapValues { Array($0.prefix(4).map { $0["cover"] as String }) }
        let lastRows = try Row.fetchAll(db, sql: """
            SELECT collection_id, MAX(added_at) AS last FROM (
                SELECT collection_id, added_at FROM collection_works UNION ALL SELECT collection_id, added_at FROM collection_videos
            ) GROUP BY collection_id
            """)
        let lastAdded = Dictionary(uniqueKeysWithValues: lastRows.map { ($0["collection_id"] as String, Date(timeIntervalSince1970: $0["last"])) })
        return collections.map {
            Summary(
                collection: $0, workCount: works[$0.id] ?? 0, videoCount: videos[$0.id] ?? 0,
                covers: covers[$0.id] ?? [], lastAddedAt: lastAdded[$0.id]
            )
        }
    }

    private static func countByCollection(_ db: Database, table: String, join: String) throws -> [String: Int] {
        let rows = try Row.fetchAll(db, sql: "SELECT m.collection_id, COUNT(*) AS n FROM \(table) m \(join) GROUP BY m.collection_id")
        return Dictionary(uniqueKeysWithValues: rows.map { ($0["collection_id"], $0["n"]) })
    }

    /// Favorites have no favorited-at time; "added" means imported.
    public static func favoriteWorks(sort: CollectionWorkSort = .addedAt, _ db: Database) throws -> [Work] {
        try Work.fetchAll(db, sql: """
            SELECT w.* FROM works w WHERE w.is_favorite = 1 AND w.is_removed = 0
            ORDER BY \(sort.orderSQL(added: "w.local_imported_at")), w.product_id
            """)
    }

    public static func favoriteVideos(_ db: Database) throws -> [VideoItem] {
        try VideoItem.filter(Column("is_favorite") == true).order(Column("added_at").desc).fetchAll(db)
    }

    public static func works(in collectionId: String, sort: CollectionWorkSort = .addedAt, _ db: Database) throws -> [Work] {
        try Work.fetchAll(db, sql: """
            SELECT w.* FROM works w JOIN collection_works m ON m.work_id = w.product_id
            WHERE m.collection_id = ? AND w.is_removed = 0 ORDER BY \(sort.orderSQL(added: "m.added_at")), w.product_id
            """, arguments: [collectionId])
    }

    public static func videos(in collectionId: String, _ db: Database) throws -> [VideoItem] {
        try VideoItem.fetchAll(db, sql: """
            SELECT v.* FROM video_items v JOIN collection_videos m ON m.video_id = v.id
            WHERE m.collection_id = ? ORDER BY m.added_at DESC
            """, arguments: [collectionId])
    }

    public static func collectionIds(containing productId: String, _ db: Database) throws -> Set<String> {
        try Set(String.fetchAll(db, sql: "SELECT collection_id FROM collection_works WHERE work_id = ?", arguments: [productId]))
    }

    /// Latest play of each work or video, newest first.
    public static func recentlyPlayed(limit: Int, _ db: Database) throws -> [PlayHistoryEntry] {
        try PlayHistoryEntry.order(Column("played_at").desc).limit(limit).fetchAll(db)
    }
}

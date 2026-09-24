import Foundation
import GRDB

/// A user-defined favorites group (分组); named to avoid clashing with
/// Swift's `Collection` protocol.
public struct LibraryCollection: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "collections"

    public var id: String
    public var name: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
}

public struct CollectionWork: DriftRecord, Hashable {
    public static let databaseTableName = "collection_works"

    public var collectionId: String
    public var workId: String
    public var addedAt: Date
}

public struct CollectionVideo: DriftRecord, Hashable {
    public static let databaseTableName = "collection_videos"

    public var collectionId: String
    public var videoId: String
    public var addedAt: Date
}

public struct VideoItem: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "video_items"

    public var id: String
    /// local / webdav / p115
    public var sourceKind: String
    public var sourceId: String
    public var sourceName: String
    public var path: String
    public var fileName: String
    public var pickcode: String?
    public var size: Int?
    public var customTitle: String?
    /// Relative to Documents, e.g. `video_covers/<id>.png`.
    public var coverPath: String?
    public var isFavorite: Bool
    public var addedAt: Date
    public var lastPlayedAt: Date?
}

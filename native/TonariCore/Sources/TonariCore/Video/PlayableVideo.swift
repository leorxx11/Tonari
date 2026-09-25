import Foundation
import GRDB

/// A video the player can open, wherever it came from: a 115 file (browsed,
/// in the library or in the history) or one imported from Files. Ids match
/// the Flutter build, so history, library rows and covers line up.
public struct PlayableVideo: Sendable, Hashable, Identifiable {
    public static let localSourceId = "video_import"
    public static let localSourceName = "本地导入"

    public let id: String
    /// `p115` or `local`.
    public let sourceKind: String
    public let sourceId: String
    public let sourceName: String
    /// The 115 file id, or a path relative to Documents for imports.
    public let path: String
    public let fileName: String
    public let pickcode: String?
    public let size: Int?

    public var title: String { PlaybackStore.fileTitle(fileName) }
    public var isLocal: Bool { sourceKind == "local" }

    public init(p115 entry: RemoteEntry, sourceName: String) {
        id = PlaybackStore.historyId(entry)
        sourceKind = "p115"
        sourceId = entry.sourceId
        self.sourceName = sourceName
        path = entry.path
        fileName = entry.name
        pickcode = entry.pickcode
        size = entry.size
    }

    /// A file copied into Documents by the import.
    public init(localPath: String, fileName: String, size: Int?) {
        id = "local:\(Self.localSourceId):\(localPath)"
        sourceKind = "local"
        sourceId = Self.localSourceId
        sourceName = Self.localSourceName
        path = localPath
        self.fileName = fileName
        pickcode = nil
        self.size = size
    }

    public init(_ item: VideoItem) {
        id = item.id
        sourceKind = item.sourceKind
        sourceId = item.sourceId
        sourceName = item.sourceName
        path = item.path
        fileName = item.fileName
        pickcode = item.pickcode
        size = item.size
    }

    /// The video a history entry played, when it is one this build can open.
    public init?(history entry: PlayHistoryEntry) {
        guard entry.kind == "video", let sourceKind = entry.sourceKind, ["p115", "local"].contains(sourceKind),
              let sourceId = entry.sourceId, let path = entry.path, let fileName = entry.fileName
        else { return nil }
        id = entry.id
        self.sourceKind = sourceKind
        self.sourceId = sourceId
        sourceName = entry.sourceName ?? (sourceKind == "local" ? Self.localSourceName : P115Client.sourceName)
        self.path = path
        self.fileName = fileName
        pickcode = entry.pickcode
        size = entry.size
    }
}

/// A video partly watched, for 继续观看.
public struct VideoProgress: Sendable, Identifiable {
    public let video: PlayableVideo
    public let positionMs: Int
    public let durationMs: Int
    public var id: String { video.id }
}

extension AppDatabase {
    public func addVideo(_ video: PlayableVideo, at date: Date = .now) throws {
        try writer.write { db in
            try VideoItem(
                id: video.id, sourceKind: video.sourceKind, sourceId: video.sourceId, sourceName: video.sourceName,
                path: video.path, fileName: video.fileName, pickcode: video.pickcode, size: video.size,
                customTitle: nil, coverPath: nil, isFavorite: false, addedAt: date, lastPlayedAt: nil
            ).insert(db, onConflict: .ignore)
        }
    }

    /// Leaves groups too; history keeps its own entry.
    public func removeVideo(_ id: String) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM collection_videos WHERE video_id = ?", arguments: [id])
            _ = try VideoItem.deleteOne(db, key: id)
        }
    }

    /// Nil or blank goes back to the file name.
    public func renameVideo(_ id: String, to title: String?) throws {
        let title = title.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        try writer.write { db in
            try db.execute(sql: "UPDATE video_items SET custom_title = ? WHERE id = ?", arguments: [title, id])
        }
    }

    public func setVideoCover(_ id: String, path: String) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE video_items SET cover_path = ? WHERE id = ?", arguments: [path, id])
        }
    }

    public func setMembership(video videoId: String, collection collectionId: String, member: Bool) throws {
        try writer.write { db in
            if member {
                try CollectionVideo(collectionId: collectionId, videoId: videoId, addedAt: .now).insert(db, onConflict: .ignore)
            } else {
                try db.execute(
                    sql: "DELETE FROM collection_videos WHERE collection_id = ? AND video_id = ?",
                    arguments: [collectionId, videoId]
                )
            }
        }
    }
}

extension CollectionQueries {
    public static func collectionIds(containingVideo videoId: String, _ db: Database) throws -> Set<String> {
        try Set(String.fetchAll(db, sql: "SELECT collection_id FROM collection_videos WHERE video_id = ?", arguments: [videoId]))
    }
}

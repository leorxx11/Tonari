import Foundation
import GRDB

/// A 115 work kept on the device: the track folder picked when it was added
/// downloads into `OfflineFiles`, and playback prefers those copies.
public struct OfflineWork: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "offline_works"

    public var workId: String
    public var folder: [String]
    public var addedAt: Date

    public var id: String { workId }
}

/// Downloaded copies, laid out as `<work>/<relative path>`. A copy is only
/// moved there once complete, so a file that exists is a whole track.
public struct OfflineFiles: Sendable {
    public static let shared = OfflineFiles(root: URL.documentsDirectory.appending(path: "offline"))

    public let root: URL

    public func url(for track: Track) -> URL {
        root.appending(path: track.workId).appending(path: track.relativePath)
    }

    public func localURL(for track: Track) -> URL? {
        let url = url(for: track)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Moves a finished download into place, replacing an older copy.
    public func store(_ download: URL, for relativePath: String) throws {
        let target = root.appending(path: relativePath)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
        try FileManager.default.moveItem(at: download, to: target)
    }

    public func bytes(of workId: String) -> Int {
        let folder = root.appending(path: workId)
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey])?.compactMap { $0 as? URL } ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    /// Deletes the copies of works no longer kept offline.
    public func prune(keeping workIds: Set<String>) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        for folder in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        where !workIds.contains(folder.lastPathComponent) {
            try FileManager.default.removeItem(at: folder)
        }
    }
}

public enum OfflineQueries {
    public struct Status: Sendable, Hashable {
        public let downloaded: Int
        public let total: Int
        public let downloadedBytes: Int
        public let totalBytes: Int
        public var isComplete: Bool { downloaded == total }
    }

    public struct Entry: Sendable, Identifiable {
        public let work: Work
        public let status: Status
        public var id: String { work.productId }
    }

    public static func all(_ db: Database) throws -> [OfflineWork] {
        try OfflineWork.order(Column("added_at")).fetchAll(db)
    }

    /// The tracks an offline work keeps: those directly in its folder, in
    /// the track list's order (115 tracks are stored by pickcode).
    static func tracks(of offline: OfflineWork, _ db: Database) throws -> [Track] {
        try WorkQueries.tracks(of: offline.workId).fetchAll(db)
            .filter { $0.relativePath.split(separator: "/").dropLast().map(String.init) == offline.folder }
            .sorted { NaturalOrder.less($0.relativePath, $1.relativePath) }
    }

    /// Every track still to download, oldest offline work first.
    public static func pending(_ db: Database, files: OfflineFiles) throws -> [Track] {
        try all(db).flatMap { try tracks(of: $0, db).filter { files.localURL(for: $0) == nil } }
    }

    /// The tracks a work keeps, for per-track download marks.
    public static func tracks(of workId: String, _ db: Database) throws -> [Track] {
        try OfflineWork.fetchOne(db, key: workId).map { try tracks(of: $0, db) } ?? []
    }

    /// The track a download's `<work>/<relative path>` names.
    public static func track(at path: String, _ db: Database) throws -> Track? {
        let parts = path.split(separator: "/", maxSplits: 1).map(String.init)
        return try Track.filter(Column("work_id") == parts[0] && Column("relative_path") == parts[1]).fetchOne(db)
    }

    public static func status(of workId: String, _ db: Database, files: OfflineFiles) throws -> Status? {
        try OfflineWork.fetchOne(db, key: workId).map { try status(of: $0, db, files: files) }
    }

    public static func entries(_ db: Database, files: OfflineFiles) throws -> [Entry] {
        try all(db).map { offline in
            Entry(work: try Work.fetchOne(db, key: offline.workId)!, status: try status(of: offline, db, files: files))
        }
    }

    private static func status(of offline: OfflineWork, _ db: Database, files: OfflineFiles) throws -> Status {
        let tracks = try tracks(of: offline, db)
        let downloaded = tracks.filter { files.localURL(for: $0) != nil }
        return Status(
            downloaded: downloaded.count, total: tracks.count,
            downloadedBytes: downloaded.reduce(0) { $0 + $1.fileSizeBytes },
            totalBytes: tracks.reduce(0) { $0 + $1.fileSizeBytes }
        )
    }
}

extension AppDatabase {
    public func keepOffline(_ workId: String, folder: [String], at date: Date = .now) throws {
        try writer.write { try OfflineWork(workId: workId, folder: folder, addedAt: date).insert($0, onConflict: .replace) }
    }

    public func removeOffline(_ workId: String) throws {
        _ = try writer.write { try OfflineWork.deleteOne($0, key: workId) }
    }
}

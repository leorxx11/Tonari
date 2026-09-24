import AVFoundation
import Foundation
import GRDB

/// Imports RJ works from folders the user picked in the Files app, reaching
/// them again later through the security-scoped bookmark stored on the
/// source.
public struct LocalImport: Sendable {
    public struct Failure: LocalizedError {
        public let errorDescription: String?
        public init(_ message: String) { errorDescription = message }
    }

    let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// Records a picked folder as a source. Re-picking a folder already
    /// imported refreshes its bookmark instead of adding a duplicate, which
    /// is also how a restored source regains access.
    public func addFolder(_ url: URL) throws -> ImportedFolder {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData().base64EncodedString()
        let path = url.resolvingSymlinksInPath().path
        let now = Date.now
        return try database.writer.write { db in
            let existing = try ImportedFolder.filter(Column("type") == "local" && Column("remote_path") == path).fetchOne(db)
            var folder = existing ?? ImportedFolder(
                id: UUID().uuidString.lowercased(), displayName: url.lastPathComponent, bookmarkBase64: bookmark,
                type: "local", serverId: nil, remotePath: path, createdAt: now, updatedAt: now
            )
            folder.displayName = url.lastPathComponent
            folder.bookmarkBase64 = bookmark
            folder.updatedAt = now
            try folder.save(db)
            return folder
        }
    }

    /// Scans a whole source. New works only unless `skipExisting` is false.
    public func importFolder(_ folder: ImportedFolder, skipExisting: Bool = true) async throws -> ImportSummary {
        try await withAccess(folder) { root in
            let scan = FolderScanner.scan(root)
            // A listing that fails at the root means the folder isn't readable
            // (typically a bookmark restored from another app), not that it
            // holds no works.
            if scan.works.isEmpty, let error = scan.errors.first {
                throw Failure("「\(folder.displayName)」无法读取，请从媒体库重新导入这个文件夹以重新授权（\(error)）")
            }
            let summary = try database.applyScanResult(scan, sourceFolderId: folder.id, skipExisting: skipExisting)
            await probeDurations(of: summary.workIds)
            return summary
        }
    }

    /// Rescans one work in place, reviving it if it was removed.
    public func reimportWork(_ work: Work, from folder: ImportedFolder) async throws -> ImportSummary {
        try await withAccess(folder) { root in
            let scan = FolderScanner.scan(root, only: work.productId)
            let summary = try database.applyScanResult(scan, sourceFolderId: folder.id, reviveTombstoned: true)
            if summary.incompleteWorks.contains(work.productId) { throw Failure("扫描未完成：\(work.productId)") }
            guard summary.workIds.contains(work.productId) else { throw Failure("未在原始导入位置找到 \(work.productId)") }
            await probeDurations(of: summary.workIds)
            return summary
        }
    }

    /// Drops a source that yielded no works, e.g. a folder picked by mistake.
    public func removeIfEmpty(_ folder: ImportedFolder) throws {
        try database.writer.write { db in
            if try Work.filter(Column("imported_folder_id") == folder.id).fetchCount(db) == 0 {
                try ImportedFolder.deleteOne(db, key: folder.id)
            }
        }
    }

    private func withAccess<T>(_ folder: ImportedFolder, _ body: (URL) async throws -> T) async throws -> T {
        var stale = false
        let root: URL
        do {
            root = try URL(resolvingBookmarkData: Data(base64Encoded: folder.bookmarkBase64)!, bookmarkDataIsStale: &stale)
        } catch {
            throw Failure("「\(folder.displayName)」需要重新授权：请从媒体库重新导入这个文件夹")
        }
        // False for folders that need no scope, e.g. inside the app's container.
        let accessing = root.startAccessingSecurityScopedResource()
        defer { if accessing { root.stopAccessingSecurityScopedResource() } }
        if stale {
            let bookmark = try root.bookmarkData().base64EncodedString()
            try await database.writer.write { db in
                try db.execute(sql: "UPDATE imported_folders SET bookmark_base64 = ?, updated_at = ? WHERE id = ?",
                               arguments: [bookmark, Date.now.unixSeconds, folder.id])
            }
        }
        return try await body(root)
    }

    /// The scanner doesn't read audio headers; fill in lengths while the
    /// folder is accessible.
    private func probeDurations(of workIds: Set<String>) async {
        let tracks = try! await database.reader.read { db in
            try Track.filter(workIds.contains(Column("work_id")) && Column("duration_ms") == 0).fetchAll(db)
        }
        for track in tracks {
            do {
                let duration = try await AVURLAsset(url: URL(filePath: track.filePath)).load(.duration)
                let ms = Int(duration.seconds * 1000)
                guard ms > 0 else { continue }
                try await database.writer.write { db in
                    try db.execute(sql: "UPDATE tracks SET duration_ms = ?, updated_at = ? WHERE id = ?",
                                   arguments: [ms, Date.now.unixSeconds, track.id])
                }
            } catch {
                DiagnosticLog.shared.write("import", "duration_probe_failed", ["path": track.filePath, "error": "\(error)"])
            }
        }
    }

    /// Launch-time pass for local works flagged `needsRescan`. Remote sources
    /// are left to the user so a cold start never hammers 115.
    public func rescanFlaggedLocalWorks() async {
        let folders = try! await database.reader.read { db in
            try ImportedFolder.fetchAll(db, sql: """
                SELECT DISTINCT f.* FROM imported_folders f JOIN works w ON w.imported_folder_id = f.id
                WHERE w.needs_rescan = 1 AND f.type = 'local'
                """)
        }
        for folder in folders {
            do {
                _ = try await importFolder(folder, skipExisting: false)
            } catch {
                DiagnosticLog.shared.write("import", "flagged_rescan_failed", ["folder": folder.displayName, "error": "\(error)"])
            }
        }
    }
}

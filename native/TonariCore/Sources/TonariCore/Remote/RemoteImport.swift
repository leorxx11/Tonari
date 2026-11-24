import Foundation
import GRDB

/// Imports RJ works from a 115 or WebDAV folder. Tracks store the file's
/// handle as their path (115: the pickcode, WebDAV: the server path) and
/// works the path of their folder, which is all playback and rescans need.
public struct RemoteImport: Sendable {
    /// (works found so far, the work being scanned)
    public typealias Progress = @Sendable (Int, String) -> Void

    /// Works already in the library whose subtitles are still remote.
    public struct Imported: Sendable {
        public let summary: ImportSummary
        let scan: ScanResult
        let subtitles: [ScannedFile]

        public var subtitleCount: Int { subtitles.count }
    }

    /// A failure every later request would meet too. `auth` ends any scan;
    /// `unavailable` (115 blocking, a WebDAV server out of reach) ends it
    /// between works, while one met inside a work only marks that work
    /// incomplete.
    enum Failure {
        case auth, unavailable
    }

    /// How one kind of remote source is listed, read and recorded.
    struct Source: Sendable {
        /// `imported_folders.type`
        let type: String
        let serverId: String
        let name: String
        let rootPath: String
        let list: @Sendable (String) async throws -> [RemoteEntry]
        let download: @Sendable (String) async throws -> Data
        let failure: @Sendable (Error) -> Failure?
        let categoryHint: @Sendable (_ parent: String, _ file: String) -> String?
    }

    let database: AppDatabase
    let source: Source

    init(database: AppDatabase, source: Source) {
        self.database = database
        self.source = source
    }

    /// Scans a folder and imports what it finds, leaving subtitles to
    /// `importSubtitles` so the works show up, and a scan cut short is
    /// reported, without waiting a request per subtitle. Works already in
    /// the library are skipped while scanning, so re-importing a big folder
    /// only lists the new ones and doesn't trip 115's rate limit.
    public func importFolder(_ folder: RemoteEntry, progress: Progress? = nil) async throws -> Imported {
        let folderId = try await ensureSource(folder)
        let skip = try await database.reader.read { db in
            try Set(String.fetchAll(db, sql: "SELECT product_id FROM works WHERE is_removed = 0"))
        }
        let scan = try await scan(folder, skip: skip, progress: progress)
        if scan.works.isEmpty, let error = scan.errors.first, scan.skippedExisting == 0 {
            throw LocalImport.Failure("扫描失败：\(error)")
        }
        return imported(scan, try database.applyScanResult(scan, sourceFolderId: folderId, includesSubtitles: false))
    }

    /// Rescans one work's own folder, reviving it if removed.
    public func reimportWork(_ work: Work) async throws -> ImportSummary {
        let entry = RemoteEntry(id: work.localFolderPath, path: work.localFolderPath, name: work.productId, kind: .folder, sourceId: source.serverId)
        let scan = try await scan(entry, skip: [], progress: nil)
        let summary = try database.applyScanResult(scan, sourceFolderId: work.importedFolderId, reviveTombstoned: true, includesSubtitles: false)
        if summary.incompleteWorks.contains(work.productId) { throw LocalImport.Failure("扫描未完成：\(work.productId)") }
        try await importSubtitles(imported(scan, summary))
        return summary
    }

    // MARK: - Scanning

    /// Same layout rules as a local folder: the folder itself, its children or
    /// grandchildren carry the RJ id.
    func scan(_ root: RemoteEntry, skip: Set<String>, progress: Progress?) async throws -> ScanResult {
        var works: [ScannedWork] = []
        var unrecognized: [String] = []
        var errors: [String] = []
        var skipped = 0

        func add(_ dir: RemoteEntry, _ id: String) async throws {
            if skip.contains(id) {
                skipped += 1
                return
            }
            progress?(works.count, id)
            works.append(try await buildWork(dir, id, &errors))
        }

        if let id = RJID.extract(root.name) {
            try await add(root, id)
        } else {
            let top: [RemoteEntry]
            do {
                top = try await source.list(root.path)
            } catch where source.failure(error) != nil {
                throw error
            } catch {
                return ScanResult(rootPath: root.path, works: [], unrecognizedDirs: [], errors: ["\(root.path): \(error.localizedDescription)"])
            }
            for child in top where child.isFolder {
                if let id = RJID.extract(child.name) {
                    try await add(child, id)
                    continue
                }
                var found = false
                do {
                    for grandchild in try await source.list(child.path) where grandchild.isFolder {
                        if let id = RJID.extract(grandchild.name) {
                            found = true
                            try await add(grandchild, id)
                        }
                    }
                } catch where source.failure(error) != nil {
                    throw error
                } catch {
                    errors.append("\(child.path): \(error.localizedDescription)")
                }
                if !found { unrecognized.append(child.path) }
            }
        }
        return ScanResult(rootPath: root.path, works: works, unrecognizedDirs: unrecognized, errors: errors, skippedExisting: skipped)
    }

    /// A listing that fails midway (often 115 throttling a sub-folder) marks
    /// the work incomplete so its existing snapshot is left alone.
    private func buildWork(_ dir: RemoteEntry, _ productId: String, _ errors: inout [String]) async throws -> ScannedWork {
        var files: [ScannedFile] = []
        var incomplete = false
        var pending: [(entry: RemoteEntry, prefix: String)] = [(dir, "")]
        while !pending.isEmpty {
            let (folder, prefix) = pending.removeFirst()
            let entries: [RemoteEntry]
            do {
                entries = try await source.list(folder.path)
            } catch where source.failure(error) == .auth {
                throw error
            } catch {
                errors.append("\(folder.path): \(error.localizedDescription)")
                incomplete = true
                continue
            }
            for entry in entries {
                let relative = prefix.isEmpty ? entry.name : "\(prefix)/\(entry.name)"
                if entry.isFolder {
                    pending.append((entry, relative))
                    continue
                }
                let parent = prefix.isEmpty ? dir.name : String(prefix.split(separator: "/").last!)
                files.append(ScannedFile(
                    path: entry.pickcode ?? entry.path, relativePath: relative, fileName: entry.name, sizeBytes: entry.size ?? 0,
                    parentDirName: parent, categoryHint: source.categoryHint(parent, entry.name)
                ))
            }
        }
        return ScannedWork(productId: productId, rootPath: dir.path, files: files, incomplete: incomplete)
    }

    // MARK: - Subtitles and source

    private func imported(_ scan: ScanResult, _ summary: ImportSummary) -> Imported {
        let subtitles = scan.works.filter { summary.workIds.contains($0.productId) }.flatMap { $0.files(.subtitle) }
            .filter { SubtitleParser.supports(FileKind.ext($0.fileName)) }
        return Imported(summary: summary, scan: scan, subtitles: subtitles)
    }

    /// Downloads and writes the subtitles of imported works, returning how
    /// many came down; `progress` gets (done, total). A subtitle that fails
    /// to download is skipped; a failed login or a block aborts before
    /// anything is written, since every later request would fail the same
    /// way, and the works keep the subtitles they had.
    @discardableResult
    public func importSubtitles(_ imported: Imported, progress: (@Sendable (Int, Int) -> Void)? = nil) async throws -> Int {
        var downloaded: [String: Data] = [:]
        for (index, subtitle) in imported.subtitles.enumerated() {
            progress?(index, imported.subtitles.count)
            do {
                downloaded[subtitle.path] = try await source.download(subtitle.path)
            } catch where source.failure(error) != nil {
                throw error
            } catch {
                DiagnosticLog.shared.write(source.type, "subtitle_download_failed", ["file": subtitle.fileName, "error": "\(error)"])
            }
        }
        try database.applySubtitles(imported.scan, to: imported.summary.workIds, downloaded: downloaded)
        return downloaded.count
    }

    private func ensureSource(_ folder: RemoteEntry) async throws -> String {
        let name = folder.path == source.rootPath ? source.name : "\(source.name) / \(folder.name)"
        let now = Date.now
        return try await database.writer.write { [source] db in
            if var existing = try ImportedFolder.filter(
                Column("type") == source.type && Column("server_id") == source.serverId && Column("remote_path") == folder.path
            ).fetchOne(db) {
                existing.displayName = name
                existing.updatedAt = now
                try existing.update(db)
                return existing.id
            }
            let folder = ImportedFolder(
                id: UUID().uuidString.lowercased(), displayName: name, bookmarkBase64: "", type: source.type,
                serverId: source.serverId, remotePath: folder.path, createdAt: now, updatedAt: now
            )
            try folder.insert(db)
            return folder.id
        }
    }
}

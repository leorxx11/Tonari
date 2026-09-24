import Foundation
import GRDB

/// Imports RJ works from a 115 folder. Tracks store the pickcode as their
/// path and works the cid of their folder, which is all playback and
/// rescans need.
public struct P115Import: Sendable {
    /// (works found so far, what is being scanned or downloaded)
    public typealias Progress = @Sendable (Int, String) -> Void

    public struct Transport: Sendable {
        var list: @Sendable (String) async throws -> [RemoteEntry]
        var download: @Sendable (String) async throws -> Data
    }

    let database: AppDatabase
    let transport: Transport

    public init(database: AppDatabase, client: P115Client) {
        self.init(database: database, transport: Transport(
            list: { try await client.list($0) },
            download: { try await client.download(pickcode: $0) }
        ))
    }

    init(database: AppDatabase, transport: Transport) {
        self.database = database
        self.transport = transport
    }

    /// Scans a folder and imports what it finds. Works already in the library
    /// are skipped while scanning, so re-importing a big folder only lists
    /// the new ones and doesn't trip 115's rate limit.
    public func importFolder(_ folder: RemoteEntry, progress: Progress? = nil) async throws -> ImportSummary {
        let folderId = try await ensureSource(folder)
        let skip = try await database.reader.read { db in
            try Set(String.fetchAll(db, sql: "SELECT product_id FROM works WHERE is_removed = 0"))
        }
        let scan = try await scan(folder, skip: skip, progress: progress)
        if scan.works.isEmpty, let error = scan.errors.first, scan.skippedExisting == 0 {
            throw P115Error.failed("扫描失败：\(error)")
        }
        let subtitles = try await downloadSubtitles(scan, progress: progress)
        return try database.applyScanResult(scan, sourceFolderId: folderId, remoteSubtitles: subtitles)
    }

    /// Rescans one work's own folder, reviving it if removed.
    public func reimportWork(_ work: Work) async throws -> ImportSummary {
        let entry = RemoteEntry(id: work.localFolderPath, path: work.localFolderPath, name: work.productId, kind: .folder, sourceId: P115Client.sourceId)
        let scan = try await scan(entry, skip: [], progress: nil)
        let subtitles = try await downloadSubtitles(scan, progress: nil)
        let summary = try database.applyScanResult(scan, sourceFolderId: work.importedFolderId, reviveTombstoned: true, remoteSubtitles: subtitles)
        if summary.incompleteWorks.contains(work.productId) { throw P115Error.failed("扫描未完成：\(work.productId)") }
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
                top = try await transport.list(root.path)
            } catch let error as P115Error where error == .authExpired || error == .blocked {
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
                    for grandchild in try await transport.list(child.path) where grandchild.isFolder {
                        if let id = RJID.extract(grandchild.name) {
                            found = true
                            try await add(grandchild, id)
                        }
                    }
                } catch let error as P115Error where error == .authExpired || error == .blocked {
                    throw error
                } catch {
                    errors.append("\(child.path): \(error.localizedDescription)")
                }
                if !found { unrecognized.append(child.path) }
            }
        }
        return ScanResult(rootPath: root.path, works: works, unrecognizedDirs: unrecognized, errors: errors, skippedExisting: skipped)
    }

    /// A listing that fails midway (usually 115 throttling a sub-folder)
    /// marks the work incomplete so its existing snapshot is left alone.
    private func buildWork(_ dir: RemoteEntry, _ productId: String, _ errors: inout [String]) async throws -> ScannedWork {
        var files: [ScannedFile] = []
        var incomplete = false
        var pending: [(entry: RemoteEntry, prefix: String)] = [(dir, "")]
        while !pending.isEmpty {
            let (folder, prefix) = pending.removeFirst()
            let entries: [RemoteEntry]
            do {
                entries = try await transport.list(folder.path)
            } catch let error as P115Error where error == .authExpired {
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
                    path: entry.pickcode!, relativePath: relative, fileName: entry.name, sizeBytes: entry.size ?? 0,
                    parentDirName: parent, categoryHint: Self.categoryHint(parent: parent, file: entry.name)
                ))
            }
        }
        return ScannedWork(productId: productId, rootPath: dir.path, files: files, incomplete: incomplete)
    }

    /// The 115 build's own keyword rules, kept so rescans don't relabel tracks.
    static func categoryHint(parent: String, file: String) -> String? {
        let s = "\(parent)/\(file)".lowercased()
        if s.contains("free") || s.contains("フリートーク") { return "free" }
        if s.contains("bonus") || s.contains("おまけ") || s.contains("特典") { return "bonus" }
        if s.contains("main") || s.contains("本編") || s.contains("本篇") { return "main" }
        return nil
    }

    // MARK: - Subtitles and source

    /// A subtitle that fails to download is skipped; an expired login or a
    /// block aborts, since every later request would fail the same way.
    private func downloadSubtitles(_ scan: ScanResult, progress: Progress?) async throws -> [String: Data] {
        let subtitles = scan.works.filter { !$0.incomplete }.flatMap { $0.files(.subtitle) }
            .filter { SubtitleParser.supports(FileKind.ext($0.fileName)) }
        var out: [String: Data] = [:]
        for (index, subtitle) in subtitles.enumerated() {
            progress?(scan.works.count, "下载字幕 \(index + 1)/\(subtitles.count)")
            do {
                out[subtitle.path] = try await transport.download(subtitle.path)
            } catch let error as P115Error where error == .authExpired || error == .blocked {
                throw error
            } catch {
                DiagnosticLog.shared.write("p115", "subtitle_download_failed", ["file": subtitle.fileName, "error": "\(error)"])
            }
        }
        return out
    }

    private func ensureSource(_ folder: RemoteEntry) async throws -> String {
        let name = folder.path == "0" ? P115Client.sourceName : "\(P115Client.sourceName) / \(folder.name)"
        let now = Date.now
        return try await database.writer.write { db in
            if var existing = try ImportedFolder.filter(
                Column("type") == "p115" && Column("server_id") == P115Client.sourceId && Column("remote_path") == folder.path
            ).fetchOne(db) {
                existing.displayName = name
                existing.updatedAt = now
                try existing.update(db)
                return existing.id
            }
            let source = ImportedFolder(
                id: UUID().uuidString.lowercased(), displayName: name, bookmarkBase64: "", type: "p115",
                serverId: P115Client.sourceId, remotePath: folder.path, createdAt: now, updatedAt: now
            )
            try source.insert(db)
            return source.id
        }
    }
}

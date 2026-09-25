import Foundation

/// `tonari_backup.json` at the root of a backup folder, written last by the
/// exporter as its completion marker.
public struct BackupManifest: Codable, Sendable {
    public let formatVersion: Int
    public let schemaVersion: Int
    /// Local time without offset, e.g. `2026-09-24T20:46:35.730600`.
    public let createdAt: String
    public let dirs: [String]
    public let includesSecrets: Bool
}

/// Restores a backup exported by the Flutter build. The folder is first
/// copied into `Documents/restore_pending`; `applyPending` swaps it in on the
/// next launch, before the database is opened.
public enum BackupRestore {
    public static let manifestName = "tonari_backup.json"
    static let pendingDirName = "restore_pending"
    static let formatVersion = 2
    /// Diagnostic capture state belongs to the device it runs on; restoring it
    /// would silently end a capture in progress.
    static let skippedPrefPrefix = "diagnostic."

    public struct Invalid: LocalizedError {
        public let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    public struct Summary: Sendable {
        public let prefs: Int
        public let secrets: Int
        public let dirs: [String]
    }

    public static func inspect(_ backup: URL) throws -> BackupManifest {
        let url = backup.appending(path: manifestName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Invalid("不是有效的 Tonari 备份文件夹（缺少 \(manifestName)）")
        }
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: Data(contentsOf: url))
        guard manifest.formatVersion == formatVersion else {
            throw Invalid("不支持的备份格式版本 \(manifest.formatVersion)")
        }
        guard (Schema.flutterVersion...Schema.version).contains(manifest.schemaVersion) else {
            throw Invalid(manifest.schemaVersion > Schema.version
                ? "备份来自更新版本的 Tonari（数据库版本 \(manifest.schemaVersion)），请先升级 App 再恢复"
                : "备份的数据库版本是 \(manifest.schemaVersion)，太旧了，请从最新的 Flutter 版重新导出")
        }
        return manifest
    }

    /// Copies the backup into the pending folder, reporting bytes copied.
    public static func stage(
        _ backup: URL,
        into documents: URL,
        progress: (_ done: Int64, _ total: Int64) -> Void
    ) throws {
        _ = try inspect(backup)
        let fm = FileManager.default
        let pending = documents.appending(path: pendingDirName)
        if fm.fileExists(atPath: pending.path) {
            try fm.removeItem(at: pending)
        }
        let files = try regularFiles(under: backup).filter { $0.relative != manifestName }
        let total = files.reduce(Int64(0)) { $0 + $1.size }
        var done: Int64 = 0
        progress(0, total)
        for file in files {
            let target = pending.appending(path: file.relative)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: file.url, to: target)
            done += file.size
            progress(done, total)
        }
        // Manifest last: its presence marks the staged copy as complete.
        try fm.copyItem(at: backup.appending(path: manifestName), to: pending.appending(path: manifestName))
    }

    /// Applies a completely staged restore; nil when there is none.
    public static func applyPending(
        in documents: URL,
        defaults: UserDefaults,
        applySecrets: ([String: String]) throws -> Void
    ) throws -> Summary? {
        let fm = FileManager.default
        let pending = documents.appending(path: pendingDirName)
        guard fm.fileExists(atPath: pending.appending(path: manifestName).path) else { return nil }

        var prefCount = 0
        let prefsURL = pending.appending(path: "prefs.json")
        if fm.fileExists(atPath: prefsURL.path) {
            let prefs = try JSONSerialization.jsonObject(with: Data(contentsOf: prefsURL)) as! [String: [String: Any]]
            for (key, entry) in prefs where !key.hasPrefix(skippedPrefPrefix) {
                defaults.set(prefValue(entry), forKey: key)
                prefCount += 1
            }
        }

        var secretCount = 0
        let secretsURL = pending.appending(path: "secrets.json")
        if fm.fileExists(atPath: secretsURL.path) {
            let secrets = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: secretsURL))
            try applySecrets(secrets)
            secretCount = secrets.count
        }

        // A directory the backup left out keeps its live copy.
        var restoredDirs: [String] = []
        for dir in BackupDir.allCases.map(\.folder) {
            let staged = pending.appending(path: dir)
            guard fm.fileExists(atPath: staged.path) else { continue }
            let live = documents.appending(path: dir)
            if fm.fileExists(atPath: live.path) {
                try fm.removeItem(at: live)
            }
            try fm.moveItem(at: staged, to: live)
            restoredDirs.append(dir)
        }

        let stagedDB = pending.appending(path: AppDatabase.fileName)
        if fm.fileExists(atPath: stagedDB.path) {
            for suffix in ["", "-wal", "-shm"] {
                let live = documents.appending(path: AppDatabase.fileName + suffix)
                if fm.fileExists(atPath: live.path) {
                    try fm.removeItem(at: live)
                }
            }
            try fm.moveItem(at: stagedDB, to: documents.appending(path: AppDatabase.fileName))
        }

        try fm.removeItem(at: pending)
        return Summary(prefs: prefCount, secrets: secretCount, dirs: restoredDirs)
    }

    /// Prefs are dumped with a type tag: 's'tring, 'b'ool, 'i'nt, 'd'ouble,
    /// string 'l'ist.
    private static func prefValue(_ entry: [String: Any]) -> Any {
        let value = entry["v"]!
        return switch entry["t"] as! String {
        case "s": value as! String
        case "b": value as! Bool
        case "i": value as! Int
        case "d": (value as! NSNumber).doubleValue
        case "l": value as! [String]
        case let type: fatalError("Unknown pref type \(type)")
        }
    }

    static func regularFiles(under root: URL) throws -> [(url: URL, relative: String, size: Int64)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys)!
        let rootPath = root.resolvingSymlinksInPath().path + "/"
        var files: [(URL, String, Int64)] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile! else { continue }
            let relative = String(url.resolvingSymlinksInPath().path.dropFirst(rootPath.count))
            files.append((url, relative, Int64(values.fileSize!)))
        }
        return files
    }
}

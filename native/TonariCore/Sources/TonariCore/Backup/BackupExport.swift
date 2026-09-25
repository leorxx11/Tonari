import Foundation
import GRDB

/// Documents subdirectories a backup can carry; everything else there is the
/// database itself or disposable. Raw values are the manifest's names.
public enum BackupDir: String, CaseIterable, Sendable {
    case images
    case videoCovers

    public var folder: String {
        switch self {
        case .images: "images"
        case .videoCovers: "video_covers"
        }
    }

    public var label: String {
        switch self {
        case .images: "图片"
        case .videoCovers: "视频封面"
        }
    }

    public func size(in documents: URL) throws -> Int64 {
        let root = documents.appending(path: folder)
        guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
        return try BackupRestore.regularFiles(under: root).reduce(0) { $0 + $1.size }
    }
}

/// Writes `Tonari备份_<time>/` in the same layout the Flutter build exports,
/// so either build can restore it.
public enum BackupExport {
    public static let lastExportedKey = "backup.lastExportedAt"

    /// `done` and `total` are bytes while copying folders, 0 / 1 for the
    /// small stages.
    public typealias Progress = (_ stage: String, _ done: Int64, _ total: Int64) -> Void

    /// Returns the backup folder. The manifest is written last, so a folder
    /// cut short is never taken for a backup.
    public static func run(
        database: AppDatabase,
        documents: URL,
        into target: URL,
        dirs: [BackupDir],
        prefs: [String: Any],
        secrets: [String: String],
        date: Date = .now,
        progress: Progress
    ) throws -> URL {
        let fm = FileManager.default
        let out = target.appending(path: "Tonari备份_\(date.formatted(folderStamp))")
        try fm.createDirectory(at: out, withIntermediateDirectories: false)

        progress("导出数据库", 0, 1)
        let snapshot = URL.temporaryDirectory.appending(path: "backup_\(UUID().uuidString).sqlite")
        try database.writer.writeWithoutTransaction { try $0.execute(sql: "VACUUM INTO ?", arguments: [snapshot.path]) }
        try fm.copyItem(at: snapshot, to: out.appending(path: AppDatabase.fileName))
        try fm.removeItem(at: snapshot)
        progress("导出数据库", 1, 1)

        for dir in dirs {
            let root = documents.appending(path: dir.folder)
            guard fm.fileExists(atPath: root.path) else { continue }
            let files = try BackupRestore.regularFiles(under: root)
            let total = files.reduce(Int64(0)) { $0 + $1.size }
            var done: Int64 = 0
            progress("导出\(dir.label)", 0, total)
            for file in files {
                let destination = out.appending(path: dir.folder).appending(path: file.relative)
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: file.url, to: destination)
                done += file.size
                progress("导出\(dir.label)", done, total)
            }
        }

        progress("导出设置", 0, 1)
        try JSONSerialization.data(withJSONObject: encodePrefs(prefs)).write(to: out.appending(path: "prefs.json"))
        try JSONEncoder().encode(secrets).write(to: out.appending(path: "secrets.json"))
        let manifest = BackupManifest(
            formatVersion: BackupRestore.formatVersion,
            schemaVersion: Schema.version,
            createdAt: date.formatted(manifestStamp),
            dirs: dirs.map(\.rawValue),
            includesSecrets: true
        )
        try JSONEncoder().encode(manifest).write(to: out.appending(path: BackupRestore.manifestName))
        progress("导出设置", 1, 1)
        return out
    }

    /// Tags each value with its type as the Flutter build does: 's'tring,
    /// 'b'ool, 'i'nt, 'd'ouble, string 'l'ist. Values of other types are
    /// ones system frameworks write into the app's domain, not settings.
    static func encodePrefs(_ prefs: [String: Any]) -> [String: [String: Any]] {
        prefs.compactMapValues { value -> [String: Any]? in
            switch value {
            case let string as String: ["t": "s", "v": string]
            case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID(): ["t": "b", "v": number.boolValue]
            case let number as NSNumber where CFNumberIsFloatType(number): ["t": "d", "v": number.doubleValue]
            case let number as NSNumber: ["t": "i", "v": number.intValue]
            case let list as [String]: ["t": "l", "v": list]
            default: nil
            }
        }
    }

    private static let folderStamp = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)_\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)",
        timeZone: .current, calendar: Calendar(identifier: .gregorian)
    )

    /// Local time without an offset, as Dart's `toIso8601String` writes it.
    private static let manifestStamp = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits).\(secondFraction: .fractional(3))",
        timeZone: .current, calendar: Calendar(identifier: .gregorian)
    )
}

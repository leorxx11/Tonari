import Foundation

/// MetricKit crash and hang diagnostics, kept as the JSON MetricKit hands
/// over: sideloaded builds get crash reports nowhere else. Unlike the
/// diagnostic log they are always collected.
public struct CrashReports: Sendable {
    public enum Kind: String, Sendable {
        case crash, hang
    }

    public struct Report: Identifiable, Sendable {
        public let url: URL
        public let kind: Kind
        public let receivedAt: Date
        public var id: URL { url }
    }

    public static let shared = CrashReports(directory: URL.documentsDirectory.appending(path: "crash-reports"))
    static let retained = 20

    let directory: URL

    public func save(_ json: Data, kind: Kind, at date: Date = .now) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // One payload can carry several diagnostics received at the same instant.
        let name = "\(kind.rawValue)-\(Int64(date.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8)).json"
        try json.write(to: directory.appending(path: name))
        for stale in try all().dropFirst(Self.retained) {
            try FileManager.default.removeItem(at: stale.url)
        }
    }

    /// Newest first.
    public func all() throws -> [Report] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map { url in
                let parts = url.deletingPathExtension().lastPathComponent.split(separator: "-")
                return Report(
                    url: url,
                    kind: Kind(rawValue: String(parts[0]))!,
                    receivedAt: Date(timeIntervalSince1970: Double(parts[1])! / 1000)
                )
            }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    public func delete(_ report: Report) throws {
        try FileManager.default.removeItem(at: report.url)
    }
}

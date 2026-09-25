import Foundation
import TonariCore

/// Works read from DLsite and their chobit previews, a JSON file each under
/// Caches, so a page opened before shows at once and offline. A work's file
/// date says when it was last brought up to date.
enum OnlineWorkCache {
    nonisolated static let directory = URL.cachesDirectory.appending(path: "dlsite-works")

    static func work(_ productId: String) -> (work: Work, savedAt: Date)? {
        let name = "\(productId).json"
        guard let work = load(Work.self, name) else { return nil }
        let date = try! FileManager.default.attributesOfItem(atPath: directory.appending(path: name).path)[.modificationDate] as! Date
        return (work, date)
    }

    /// Nil when never looked up; no tracks when the work has no preview.
    static func sample(_ productId: String) -> ChobitSample? {
        load(ChobitSample.self, "\(productId).sample.json")
    }

    static func save(_ work: Work) {
        save(work, "\(work.productId).json")
    }

    static func save(_ sample: ChobitSample, for productId: String) {
        save(sample, "\(productId).sample.json")
    }

    private static func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        let file = directory.appending(path: name)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: file))
        } catch {
            DiagnosticLog.shared.write("discover", "cache_unreadable", ["file": name, "error": "\(error)"])
            return nil
        }
    }

    private static func save(_ value: some Encodable, _ name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: directory.appending(path: name), options: .atomic)
        } catch {
            DiagnosticLog.shared.write("discover", "cache_failed", ["file": name, "error": "\(error)"])
        }
    }
}

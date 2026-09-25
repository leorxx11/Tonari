import Foundation
import TonariCore

/// Reads a work's bundled files wherever they live: inside the user's local
/// folder under its security scope, or on 115, downloaded on first open and
/// kept in Caches so later opens don't hit the rate limit.
enum WorkFileAccess {
    @concurrent
    static func data(_ file: WorkFile, source: ImportedFolder?) async throws -> Data {
        switch source?.type {
        case "p115":
            let cached = URL.cachesDirectory.appending(path: "p115-files/\(file.filePath)")
            if let data = try? Data(contentsOf: cached) { return data }
            let data = try await P115Client.shared.download(pickcode: file.filePath)
            try FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: cached)
            return data
        case "local":
            let folder = try source!.scopedURL()
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            return try Data(contentsOf: URL(filePath: file.filePath))
        default:
            return try Data(contentsOf: URL(filePath: file.filePath))
        }
    }
}

extension ImportedFolder {
    /// The local folder this source's bookmark points at.
    nonisolated func scopedURL() throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: Data(base64Encoded: bookmarkBase64)!, bookmarkDataIsStale: &stale)
    }
}

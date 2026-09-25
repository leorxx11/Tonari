import Foundation
import TonariCore

/// A file to preview: one bundled with a work, or one met while browsing
/// 115. Local files are read under their folder's security scope; 115 files
/// download on first open and stay in Caches, keyed by pickcode, so later
/// opens don't hit the rate limit.
enum PreviewFile: Hashable, Identifiable {
    case work(WorkFile, source: ImportedFolder?)
    case p115(RemoteEntry)

    var id: String {
        switch self {
        case .work(let file, _): file.id
        case .p115(let entry): entry.id
        }
    }

    var name: String {
        switch self {
        case .work(let file, _): file.fileName
        case .p115(let entry): entry.name
        }
    }

    @concurrent
    func data() async throws -> Data {
        switch self {
        case .work(let file, let source) where source?.type == "p115":
            return try await Self.p115(pickcode: file.filePath)
        case .work(let file, let source) where source?.type == "local":
            let folder = try source!.scopedURL()
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            return try Data(contentsOf: URL(filePath: file.filePath))
        case .work(let file, _):
            return try Data(contentsOf: URL(filePath: file.filePath))
        case .p115(let entry):
            return try await Self.p115(pickcode: entry.pickcode!)
        }
    }

    nonisolated static let p115Cache = URL.cachesDirectory.appending(path: "p115-files")

    @concurrent
    private static func p115(pickcode: String) async throws -> Data {
        let cached = p115Cache.appending(path: pickcode)
        if let data = try? Data(contentsOf: cached) { return data }
        let data = try await P115Client.shared.download(pickcode: pickcode)
        try FileManager.default.createDirectory(at: p115Cache, withIntermediateDirectories: true)
        try data.write(to: cached)
        return data
    }
}

extension ImportedFolder {
    /// The local folder this source's bookmark points at.
    nonisolated func scopedURL() throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: Data(base64Encoded: bookmarkBase64)!, bookmarkDataIsStale: &stale)
    }
}

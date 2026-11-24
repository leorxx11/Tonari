import Foundation
import TonariCore

/// A file to preview: one bundled with a work, or one met while browsing
/// 115 or WebDAV. Local files are read under their folder's security scope;
/// 115 files download on first open and stay in Caches, keyed by pickcode,
/// so later opens don't hit the rate limit.
enum PreviewFile: Hashable, Identifiable {
    case work(WorkFile, source: ImportedFolder?)
    case remote(RemoteEntry)

    var id: String {
        switch self {
        case .work(let file, _): file.id
        case .remote(let entry): entry.id
        }
    }

    nonisolated var name: String {
        switch self {
        case .work(let file, _): file.fileName
        case .remote(let entry): entry.name
        }
    }

    @concurrent
    func data(_ database: AppDatabase) async throws -> Data {
        switch self {
        case .work(let file, let source?) where source.isRemote:
            return try await Self.download(RemoteEntry(file: file.filePath, name: file.fileName, of: source), database)
        case .work(let file, let source) where source?.type == "local":
            let folder = try source!.scopedURL()
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            return try Data(contentsOf: URL(filePath: file.filePath))
        case .work(let file, _):
            return try Data(contentsOf: URL(filePath: file.filePath))
        case .remote(let entry):
            return try await Self.download(entry, database)
        }
    }

    /// A copy under its own name in the temporary folder, for Quick Look,
    /// which reads a file by URL and goes by its extension.
    @concurrent
    func temporaryCopy(_ database: AppDatabase) async throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: "previews/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try await data(database).write(to: url)
        return url
    }

    nonisolated static let p115Cache = URL.cachesDirectory.appending(path: "p115-files")

    @concurrent
    private static func download(_ file: RemoteEntry, _ database: AppDatabase) async throws -> Data {
        guard let pickcode = file.pickcode else { return try await RemoteFiles(database).download(file) }
        let cached = p115Cache.appending(path: pickcode)
        if let data = try? Data(contentsOf: cached) { return data }
        let data = try await RemoteFiles(database).download(file)
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

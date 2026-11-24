import Foundation

/// Reaches files on either remote source: 115 through the app-wide client,
/// WebDAV through the server an entry names.
public struct RemoteFiles: Sendable {
    let database: AppDatabase

    public init(_ database: AppDatabase) {
        self.database = database
    }

    public func list(_ folder: RemoteEntry) async throws -> [RemoteEntry] {
        folder.sourceId == P115Client.sourceId
            ? try await P115Client.shared.list(folder.path)
            : try await database.webdavClient(folder.sourceId).list(folder.path)
    }

    public func media(_ file: RemoteEntry) async throws -> ResolvedMedia {
        file.sourceId == P115Client.sourceId
            ? try await P115Client.shared.resolve(pickcode: file.pickcode!)
            : try database.webdavClient(file.sourceId).media(file.path)
    }

    public func download(_ file: RemoteEntry) async throws -> Data {
        file.sourceId == P115Client.sourceId
            ? try await P115Client.shared.download(pickcode: file.pickcode!)
            : try await database.webdavClient(file.sourceId).download(file.path)
    }
}

extension RemoteEntry {
    /// A file of a work imported from 115 or WebDAV, by the path its row
    /// keeps: the pickcode or the server path.
    public init(file path: String, name: String, of source: ImportedFolder) {
        let p115 = source.type == "p115"
        self.init(
            id: path, path: path, name: name, kind: .init(FileKind(fileName: name)),
            pickcode: p115 ? path : nil, sourceId: p115 ? P115Client.sourceId : source.serverId!
        )
    }
}

extension ImportedFolder {
    public var isRemote: Bool { type == "p115" || type == "webdav" }
}

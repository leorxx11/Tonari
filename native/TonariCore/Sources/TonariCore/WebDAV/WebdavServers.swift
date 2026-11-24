import Foundation
import GRDB

/// WebDAV servers the user added; passwords live in the Keychain under the
/// Flutter build's key, so backups carry them.
public enum WebdavServers {
    public static func all(_ db: Database) throws -> [WebdavServer] {
        try WebdavServer.order(Column("created_at")).fetchAll(db)
    }

    static func keychainKey(_ serverId: String) -> String { "webdav_password:\(serverId)" }

    public static func password(_ serverId: String, keychain: KeychainStore = .shared) throws -> String? {
        try keychain.string(for: keychainKey(serverId))
    }

    /// What deleting a server takes with it.
    public static func dependents(of serverId: String, _ db: Database) throws -> (works: Int, videos: Int) {
        let works = try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM works WHERE imported_folder_id IN
                (SELECT id FROM imported_folders WHERE type = 'webdav' AND server_id = ?)
            """, arguments: [serverId])!
        let videos = try VideoItem.filter(Column("source_kind") == "webdav" && Column("source_id") == serverId).fetchCount(db)
        return (works, videos)
    }
}

extension WebdavServer {
    public init(name: String, scheme: String, host: String, port: Int?, basePath: String?, username: String?) {
        let now = Date.now
        self.init(
            id: UUID().uuidString.lowercased(), name: name, scheme: scheme, host: host, port: port,
            basePath: basePath, username: username, createdAt: now, updatedAt: now
        )
    }

    public var origin: String {
        "\(scheme)://\(host)" + (port.map { ":\($0)" } ?? "")
    }

    /// The folder browsing starts at: the base path, `/` when none is set.
    public var rootPath: String {
        "/" + (basePath ?? "").trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public var address: String {
        origin + (rootPath == "/" ? "" : rootPath)
    }

    public var root: RemoteEntry {
        RemoteEntry(id: rootPath, path: rootPath, name: name, kind: .folder, sourceId: id)
    }
}

extension AppDatabase {
    /// Adds or updates a server. A nil password keeps the stored one.
    public func saveWebdavServer(_ server: WebdavServer, password: String?, keychain: KeychainStore = .shared) throws {
        var server = server
        server.updatedAt = .now
        try writer.write { try server.save($0) }
        if let password { try keychain.set(password, for: WebdavServers.keychainKey(server.id)) }
    }

    /// Deletes a server along with every source imported from it and their
    /// works, and its videos and play history, none of which can be reached
    /// without it.
    public func deleteWebdavServer(_ id: String, keychain: KeychainStore = .shared) throws {
        try writer.write { db in
            let folderIds = try String.fetchAll(db, ImportedFolder.filter(Column("type") == "webdav" && Column("server_id") == id).select(Column("id")))
            for folderId in folderIds { try Self.deleteSource(folderId, db) }
            let videoIds = try String.fetchAll(db, VideoItem.filter(Column("source_kind") == "webdav" && Column("source_id") == id).select(Column("id")))
            try CollectionVideo.filter(videoIds.contains(Column("video_id"))).deleteAll(db)
            try VideoItem.filter(keys: videoIds).deleteAll(db)
            try PlayHistoryEntry.filter(Column("source_kind") == "webdav" && Column("source_id") == id).deleteAll(db)
            _ = try WebdavServer.deleteOne(db, key: id)
        }
        try keychain.remove(WebdavServers.keychainKey(id))
    }

    public func webdavClient(_ serverId: String, keychain: KeychainStore = .shared) throws -> WebdavClient {
        guard let server = try reader.read({ try WebdavServer.fetchOne($0, key: serverId) }) else { throw WebdavError.serverGone }
        return WebdavClient(server: server, password: try WebdavServers.password(serverId, keychain: keychain))
    }
}

extension RemoteImport {
    public static func webdav(_ database: AppDatabase, client: WebdavClient) -> RemoteImport {
        RemoteImport(database: database, source: .webdav(
            client.server,
            list: { try await client.list($0) },
            download: { try await client.download($0) }
        ))
    }
}

extension RemoteImport.Source {
    static func webdav(
        _ server: WebdavServer,
        list: @escaping @Sendable (String) async throws -> [RemoteEntry],
        download: @escaping @Sendable (String) async throws -> Data
    ) -> Self {
        Self(
            type: "webdav", serverId: server.id, name: server.name, rootPath: server.rootPath,
            list: list, download: download,
            failure: { error in
                switch error as? WebdavError {
                case .unauthorized: .auth
                case .unreachable: .unavailable
                default: nil
                }
            },
            categoryHint: { FolderScanner.categoryHint(parentDir: $0, fileName: $1) }
        )
    }
}

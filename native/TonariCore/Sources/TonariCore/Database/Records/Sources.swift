import Foundation
import GRDB

/// A media source the user imported: a local folder (security-scoped bookmark)
/// or a WebDAV / 115 directory.
public struct ImportedFolder: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "imported_folders"

    public var id: String
    public var displayName: String
    /// Empty for remote sources.
    public var bookmarkBase64: String
    /// local / webdav / p115
    public var type: String
    public var serverId: String?
    /// Remote directory, or the resolved path of a local folder (used to
    /// de-duplicate local sources).
    public var remotePath: String?
    public var createdAt: Date
    public var updatedAt: Date
}

public struct WebdavServer: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "webdav_servers"

    public var id: String
    public var name: String
    public var scheme: String
    public var host: String
    public var port: Int?
    public var basePath: String?
    public var username: String?
    public var createdAt: Date
    public var updatedAt: Date
}

public struct LlmProvider: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "llm_providers"

    public var id: String
    public var name: String
    public var baseUrl: String
    public var model: String
    public var systemPrompt: String?
    public var isDefault: Bool
    public var createdAt: Date
    public var updatedAt: Date
}

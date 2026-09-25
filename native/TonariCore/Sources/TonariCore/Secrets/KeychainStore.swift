import Foundation
import Security

/// Credentials (115 cookie, WebDAV passwords, LLM API keys) as generic
/// passwords. Keys match the Flutter build: `p115_cookie`,
/// `webdav_password:<serverId>`, `llm_provider_key:<providerId>`.
public struct KeychainStore: Sendable {
    public static let shared = KeychainStore(service: "com.leo.tonari.secrets")

    public struct Failure: Error, CustomStringConvertible {
        public let status: OSStatus

        public var description: String {
            "OSStatus \(status)：\(SecCopyErrorMessageString(status, nil).map { $0 as String } ?? "未知错误")"
        }
    }

    let service: String

    private var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    }

    public func string(for key: String) throws -> String? {
        var query = base
        query[kSecAttrAccount as String] = key
        query[kSecReturnData as String] = true
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return String(decoding: result as! Data, as: UTF8.self)
    }

    public func set(_ value: String, for key: String) throws {
        var query = base
        query[kSecAttrAccount as String] = key
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    public func remove(_ key: String) throws {
        var query = base
        query[kSecAttrAccount as String] = key
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }

    public func allKeys() throws -> [String] {
        var query = base
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return (result as! [[String: Any]]).map { $0[kSecAttrAccount as String] as! String }
    }

    /// Every credential by key, for a backup.
    public func all() throws -> [String: String] {
        var query = base
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [:] }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return Dictionary(uniqueKeysWithValues: (result as! [[String: Any]]).map {
            ($0[kSecAttrAccount as String] as! String, String(decoding: $0[kSecValueData as String] as! Data, as: UTF8.self))
        })
    }
}

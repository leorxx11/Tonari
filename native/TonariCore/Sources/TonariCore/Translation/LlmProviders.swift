import Foundation
import GRDB

/// OpenAI-compatible services used for translation. One is always the
/// default while any exist; API keys live in the Keychain.
public enum LlmProviders {
    public static func all(_ db: Database) throws -> [LlmProvider] {
        try LlmProvider.order(Column("created_at")).fetchAll(db)
    }

    public static func defaultProvider(_ db: Database) throws -> LlmProvider? {
        try LlmProvider.filter(Column("is_default") == true).fetchOne(db)
    }

    public static func keychainKey(_ providerId: String) -> String { "llm_provider_key:\(providerId)" }

    public static func apiKey(_ providerId: String, keychain: KeychainStore = .shared) throws -> String? {
        try keychain.string(for: keychainKey(providerId))
    }

    /// Quick-fill presets on the add page.
    public struct Template: Sendable, Hashable {
        public let name: String
        public let baseUrl: String
        public let model: String
    }

    public static let templates = [
        Template(name: "DeepSeek", baseUrl: "https://api.deepseek.com/v1", model: "deepseek-v4-flash"),
        Template(name: "Gemini", baseUrl: "https://generativelanguage.googleapis.com/v1beta/openai", model: "gemini-2.5-flash"),
    ]
}

extension AppDatabase {
    /// The first provider becomes the default.
    @discardableResult
    public func addProvider(
        name: String, baseUrl: String, model: String, systemPrompt: String?, apiKey: String,
        keychain: KeychainStore = .shared, at date: Date = .now
    ) throws -> String {
        let id = UUID().uuidString.lowercased()
        try writer.write { db in
            try LlmProvider(
                id: id, name: name, baseUrl: baseUrl, model: model, systemPrompt: systemPrompt,
                isDefault: try LlmProvider.fetchCount(db) == 0, createdAt: date, updatedAt: date
            ).insert(db)
        }
        try keychain.set(apiKey, for: LlmProviders.keychainKey(id))
        return id
    }

    /// A nil key keeps the stored one.
    public func updateProvider(
        _ id: String, name: String, baseUrl: String, model: String, systemPrompt: String?, apiKey: String?,
        keychain: KeychainStore = .shared
    ) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE llm_providers SET name = ?, base_url = ?, model = ?, system_prompt = ?, updated_at = ? WHERE id = ?",
                arguments: [name, baseUrl, model, systemPrompt, Date.now, id]
            )
        }
        if let apiKey { try keychain.set(apiKey, for: LlmProviders.keychainKey(id)) }
    }

    /// Deleting the default hands it to the oldest remaining provider.
    public func deleteProvider(_ id: String, keychain: KeychainStore = .shared) throws {
        try writer.write { db in
            let wasDefault = try LlmProvider.fetchOne(db, key: id)!.isDefault
            _ = try LlmProvider.deleteOne(db, key: id)
            if wasDefault, let next = try LlmProvider.order(Column("created_at")).fetchOne(db) {
                try db.execute(sql: "UPDATE llm_providers SET is_default = 1, updated_at = ? WHERE id = ?", arguments: [Date.now, next.id])
            }
        }
        try keychain.remove(LlmProviders.keychainKey(id))
    }

    public func setDefaultProvider(_ id: String) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE llm_providers SET is_default = (id = ?), updated_at = ?", arguments: [id, Date.now])
        }
    }
}

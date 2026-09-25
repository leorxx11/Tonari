import Foundation
import GRDB

/// Translates a work's title, description and track names with the default
/// provider. Translations are cached on the rows (`title_zh`,
/// `description_html_zh`, `tracks.title_zh`); only missing ones are sent
/// unless `force` redoes them all.
public struct WorkTranslation: Sendable {
    public enum Stage: Sendable {
        case title
        case description(done: Int, total: Int)
        case trackNames(done: Int, total: Int)
    }

    private let database: AppDatabase
    private let keychain: KeychainStore
    private let send: TranslationService.Send

    public init(database: AppDatabase, keychain: KeychainStore = .shared, send: @escaping TranslationService.Send = TranslationService.urlSession) {
        self.database = database
        self.keychain = keychain
        self.send = send
    }

    public func translate(_ productId: String, force: Bool, progress: @escaping @Sendable (Stage) -> Void) async throws {
        let (provider, work, tracks) = try await database.reader.read { db in
            (
                try LlmProviders.defaultProvider(db),
                try Work.fetchOne(db, key: productId)!,
                try Track.filter(Column("work_id") == productId).order(Column("file_path")).fetchAll(db)
            )
        }
        guard let provider else {
            throw TranslationService.Failure("还没有翻译服务，请到「设置 → 翻译」添加")
        }
        guard let apiKey = try LlmProviders.apiKey(provider.id, keychain: keychain) else {
            throw TranslationService.Failure("「\(provider.name)」缺少 API Key")
        }
        let service = TranslationService(
            .init(baseUrl: provider.baseUrl, model: provider.model, apiKey: apiKey, systemPrompt: provider.systemPrompt),
            send: send
        )

        if force || work.titleZh?.isEmpty != false {
            progress(.title)
            let title = try await service.translateTitle(work.title)
            try await database.writer.write { db in
                try db.execute(sql: "UPDATE works SET title_zh = ?, updated_at = ? WHERE product_id = ?", arguments: [title, Date.now, productId])
            }
        }

        if let html = work.descriptionHtml, !html.isEmpty, force || work.descriptionHtmlZh?.isEmpty != false {
            let translated = try await service.translateDescription(html) { progress(.description(done: $0, total: $1)) }
            try await database.writer.write { db in
                try db.execute(
                    sql: "UPDATE works SET description_html_zh = ?, updated_at = ? WHERE product_id = ?",
                    arguments: [translated, Date.now, productId]
                )
            }
        }

        let pending = force ? tracks : tracks.filter { $0.titleZh?.isEmpty != false }
        guard !pending.isEmpty else { return }
        let names = try await service.translateTrackNames(pending.map(\.title)) { progress(.trackNames(done: $0, total: $1)) }
        try await database.writer.write { db in
            for (track, name) in zip(pending, names) {
                try db.execute(sql: "UPDATE tracks SET title_zh = ?, updated_at = ? WHERE id = ?", arguments: [name, Date.now, track.id])
            }
        }
    }
}

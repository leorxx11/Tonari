import Foundation
import GRDB
import Synchronization
import Testing
@testable import TonariCore

/// A chat endpoint that prefixes every item with 中: and answers titles
/// with 标题; `short` answers that many batches one item short first.
private final class FakeChat: Sendable {
    let calls = Mutex(0)
    let short = Mutex(0)

    var send: TranslationService.Send {
        { request in
            self.calls.withLock { $0 += 1 }
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let user = (body["messages"] as! [[String: String]]).last!["content"]!
            let content: String
            if let items = try? JSONDecoder().decode([String].self, from: Data(user.utf8)) {
                var answer = items.map { "中:\($0)" }
                if self.short.withLock({ count in defer { count = max(0, count - 1) }; return count > 0 }) { answer.removeLast() }
                content = "```json\n\(String(decoding: try JSONEncoder().encode(answer), as: UTF8.self))\n```"
            } else {
                content = "标题"
            }
            let response = ["choices": [["message": ["content": content]]]]
            return (try JSONSerialization.data(withJSONObject: response), 200)
        }
    }
}

struct TranslationTests {
    let config = TranslationService.Config(baseUrl: "https://llm.test/v1/", model: "m", apiKey: "k", systemPrompt: nil)

    @Test func descriptionKeepsMarkupAndImages() async throws {
        let chat = FakeChat()
        let html = #"<p>こんにちは<br><img src="a.jpg">世界</p><p> </p>"#
        let translated = try await TranslationService(config, send: chat.send).translateDescription(html)
        #expect(translated.contains("中:こんにちは"))
        #expect(translated.contains("中:世界"))
        #expect(translated.contains(#"<img src="a.jpg""#))
        #expect(chat.calls.withLock { $0 } == 1)
    }

    @Test func batchesAndRetriesAShortAnswer() async throws {
        let chat = FakeChat()
        chat.short.withLock { $0 = 1 }
        let names = (1...20).map { "\($0).トラック" }
        let translated = try await TranslationService(config, send: chat.send).translateTrackNames(names)
        #expect(translated == names.map { "中:\($0)" })
        #expect(chat.calls.withLock { $0 } == 3)
    }

    @Test func reportsServiceErrors() async throws {
        let service = TranslationService(config) { _ in (Data(#"{"error":"bad key"}"#.utf8), 401) }
        let error = await #expect(throws: TranslationService.Failure.self) { try await service.testConnection() }
        #expect(error?.errorDescription?.contains("401") == true)
    }
}

struct WorkTranslationTests {
    let database = try! AppDatabase.inMemory()
    let keychain = KeychainStore(service: "com.leo.tonari.tests.\(UUID().uuidString)")

    private func track(_ id: String, zh: String?) -> Track {
        Track(
            id: id, workId: "RJ01000001", filePath: "/x/\(id)", relativePath: id, fileName: id, fileFormat: "mp3",
            fileSizeBytes: 1, durationMs: 1000, sampleRate: nil, bitRate: nil, categoryHint: nil, userCategory: nil,
            parentDirName: "", trackNumber: nil, title: "トラック\(id)", alternateQualityPathsJson: [:],
            lastPositionMs: 0, playCount: 0, createdAt: Fixtures.date, updatedAt: Fixtures.date, titleZh: zh
        )
    }

    @Test func needsAProvider() async throws {
        try await database.writer.write { try Fixtures.work("RJ01000001").insert($0) }
        let error = await #expect(throws: TranslationService.Failure.self) {
            try await WorkTranslation(database: database, keychain: keychain, send: FakeChat().send).translate("RJ01000001", force: false) { _ in }
        }
        #expect(error?.errorDescription?.contains("设置 → 翻译") == true)
    }

    @Test func translatesWhatIsMissingUnlessForced() async throws {
        var work = Fixtures.work("RJ01000001")
        work.descriptionHtml = "<p>説明</p>"
        try await database.writer.write { [work] db in
            try work.insert(db)
            try track("1", zh: "已译").insert(db)
            try track("2", zh: nil).insert(db)
        }
        let first = try database.addProvider(name: "A", baseUrl: "https://llm.test/v1", model: "m", systemPrompt: nil, apiKey: "k", keychain: keychain)
        let second = try database.addProvider(name: "B", baseUrl: "https://llm.test/v1", model: "m", systemPrompt: nil, apiKey: "k", keychain: keychain)
        defer {
            try! database.deleteProvider(first, keychain: keychain)
            try! database.deleteProvider(second, keychain: keychain)
        }
        let translation = WorkTranslation(database: database, keychain: keychain, send: FakeChat().send)

        try await translation.translate("RJ01000001", force: false) { _ in }
        var (row, titles) = try await read()
        #expect(row.titleZh == "标题")
        #expect(row.descriptionHtmlZh == "<p>中:説明</p>")
        #expect(titles == ["已译", "中:トラック2"])

        try await translation.translate("RJ01000001", force: true) { _ in }
        (row, titles) = try await read()
        #expect(titles == ["中:トラック1", "中:トラック2"])
    }

    @Test func deletingTheDefaultPromotesTheOldest() throws {
        let a = try database.addProvider(name: "A", baseUrl: "u", model: "m", systemPrompt: nil, apiKey: "ka", keychain: keychain, at: Date(timeIntervalSince1970: 1))
        let b = try database.addProvider(name: "B", baseUrl: "u", model: "m", systemPrompt: nil, apiKey: "kb", keychain: keychain, at: Date(timeIntervalSince1970: 2))
        let c = try database.addProvider(name: "C", baseUrl: "u", model: "m", systemPrompt: nil, apiKey: "kc", keychain: keychain, at: Date(timeIntervalSince1970: 3))
        #expect(try database.reader.read(LlmProviders.defaultProvider)?.id == a)
        try database.setDefaultProvider(c)
        #expect(try database.reader.read(LlmProviders.defaultProvider)?.id == c)
        try database.deleteProvider(c, keychain: keychain)
        #expect(try database.reader.read(LlmProviders.defaultProvider)?.id == a)
        #expect(try LlmProviders.apiKey(c, keychain: keychain) == nil)
        #expect(try LlmProviders.apiKey(b, keychain: keychain) == "kb")
        try database.deleteProvider(a, keychain: keychain)
        try database.deleteProvider(b, keychain: keychain)
        #expect(try database.reader.read(LlmProviders.all).isEmpty)
    }

    private func read() async throws -> (Work, [String]) {
        try await database.reader.read { db in
            (try Work.fetchOne(db, key: "RJ01000001")!, try String.fetchAll(db, sql: "SELECT title_zh FROM tracks ORDER BY id"))
        }
    }
}

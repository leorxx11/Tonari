import Foundation
import SwiftSoup

/// Chat completions against an OpenAI-compatible endpoint, with the Flutter
/// build's prompts. Lists go out in batches of 15: long ones make models drop
/// or merge items and can overflow a provider's default output limit.
public struct TranslationService: Sendable {
    public struct Config: Sendable {
        public let baseUrl: String
        public let model: String
        public let apiKey: String
        public let systemPrompt: String?

        public init(baseUrl: String, model: String, apiKey: String, systemPrompt: String?) {
            self.baseUrl = baseUrl
            self.model = model
            self.apiKey = apiKey
            self.systemPrompt = systemPrompt
        }
    }

    public struct Failure: LocalizedError {
        public let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// Sends a request and returns the body with its HTTP status.
    public typealias Send = @Sendable (URLRequest) async throws -> (Data, Int)

    static let batchSize = 15

    private static let titlePrompt = "你是 DLsite 作品标题翻译助手。请把日文作品标题翻译为简洁自然的中文。保留作品中的特殊符号、波浪号、标点。不要加任何引号、解释、注释。直接输出译文一行。"
    private static let descriptionPrompt = "你是 DLsite 作品简介翻译助手。输入是一个 JSON 字符串数组，每个元素是日文段落或短语。请把每个元素翻译为自然流畅的中文，保持数组长度与顺序完全一致。直接输出 JSON 字符串数组，不要包裹 markdown 代码块，不要任何解释。"
    private static let trackNamePrompt = "你是 DLsite 音声作品的音轨名翻译助手。输入是一个 JSON 字符串数组，每个元素是一条日文音轨名。请把每条翻译为简洁自然的中文，严格保留开头的编号或序号前缀（如 \"#6B.\"、\"01.\"、\"track02_\"）以及原有的括号、波浪号等符号风格，保持数组长度与顺序完全一致。直接输出 JSON 字符串数组，不要包裹 markdown 代码块，不要任何解释。"

    private let config: Config
    private let send: Send

    public init(_ config: Config, send: @escaping Send = TranslationService.urlSession) {
        self.config = config
        self.send = send
    }

    public static let urlSession: Send = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as! HTTPURLResponse).statusCode)
    }

    public func testConnection() async throws {
        _ = try await chat([["role": "user", "content": "ping"]])
    }

    public func translateTitle(_ title: String) async throws -> String {
        do {
            return try await chat(system: Self.titlePrompt, user: title)
        } catch {
            return try await chat(system: Self.titlePrompt, user: title)
        }
    }

    /// Translates the text between tags and puts it back, so images and
    /// markup come through as they were.
    public func translateDescription(_ html: String, progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async throws -> String {
        let document = try SwiftSoup.parseBodyFragment(html)
        document.outputSettings().prettyPrint(pretty: false)
        let body = document.body()!
        var nodes: [TextNode] = []
        func walk(_ node: Node) {
            if let text = node as? TextNode {
                if !text.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { nodes.append(text) }
                return
            }
            guard let element = node as? Element, !["script", "style"].contains(element.tagName()) else { return }
            element.getChildNodes().forEach(walk)
        }
        walk(body)
        guard !nodes.isEmpty else { return html }
        let translated = try await translateList(nodes.map { $0.getWholeText() }, prompt: Self.descriptionPrompt, progress: progress)
        // Replaced rather than edited: SwiftSoup keeps serializing the parsed
        // source after a text-only change.
        for (node, text) in zip(nodes, translated) { try node.replaceWith(TextNode(text, nil)) }
        return try body.html()
    }

    /// Keeps numbering prefixes; same length and order as `names`.
    public func translateTrackNames(_ names: [String], progress: (_ done: Int, _ total: Int) -> Void = { _, _ in }) async throws -> [String] {
        try await translateList(names, prompt: Self.trackNamePrompt, progress: progress)
    }

    private func translateList(_ items: [String], prompt: String, progress: (Int, Int) -> Void) async throws -> [String] {
        var result: [String] = []
        for start in stride(from: 0, to: items.count, by: Self.batchSize) {
            progress(start, items.count)
            let batch = Array(items[start..<min(start + Self.batchSize, items.count)])
            result += try await translateBatch(batch, prompt: prompt)
        }
        progress(items.count, items.count)
        return result
    }

    /// Up to three tries: models sometimes answer with the wrong count.
    private func translateBatch(_ batch: [String], prompt: String) async throws -> [String] {
        let input = String(decoding: try JSONEncoder().encode(batch), as: UTF8.self)
        var lastError: any Error = Failure("翻译失败")
        for _ in 0..<3 {
            do {
                let output = try Self.parseList(try await chat(system: prompt, user: input))
                guard output.count == batch.count else {
                    throw Failure("译文条数不符：\(output.count) / \(batch.count)")
                }
                return output
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Tolerates a markdown fence around the array.
    static func parseList(_ text: String) throws -> [String] {
        let cleaned = text
            .replacing(/^```(?:json)?/, with: "")
            .replacing(/```$/, with: "")
        do {
            return try JSONDecoder().decode([String].self, from: Data(cleaned.utf8))
        } catch {
            throw Failure("译文不是 JSON 字符串数组")
        }
    }

    private func chat(system: String, user: String) async throws -> String {
        let extra = config.systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return try await chat([
            ["role": "system", "content": extra.isEmpty ? system : "\(system)\n\n\(extra)"],
            ["role": "user", "content": user],
        ])
    }

    private func chat(_ messages: [[String: String]]) async throws -> String {
        var base = config.baseUrl.trimmingCharacters(in: .whitespaces)
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/chat/completions") else { throw Failure("Base URL 无效：\(config.baseUrl)") }
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": config.model, "messages": messages, "temperature": 0.3,
        ] as [String: Any])
        let (data, status) = try await send(request)
        guard status == 200 else {
            throw Failure("服务返回 \(status)：\(String(decoding: data.prefix(300), as: UTF8.self))")
        }
        struct Response: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let content = try JSONDecoder().decode(Response.self, from: data).choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { throw Failure("服务返回了空内容") }
        return content
    }
}

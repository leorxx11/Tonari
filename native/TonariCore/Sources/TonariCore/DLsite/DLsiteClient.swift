import Foundation

/// Raw requests to DLsite. `adultchecked` skips the age gate; `locale=zh-cn`
/// selects the Chinese page the parser reads.
public struct DLsiteClient: Sendable {
    public struct Failure: LocalizedError {
        public let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    public func workPage(_ productId: String) async throws -> String {
        let data = try await get("https://www.dlsite.com/maniax/work/=/product_id/\(productId).html", productId)
        return String(decoding: data, as: UTF8.self)
    }

    public func productInfo(_ productId: String) async throws -> Data {
        try await get("https://www.dlsite.com/maniax/product/info/ajax?product_id=\(productId)", productId)
    }

    /// Downloads an image into `target`; image hosts expect a DLsite referer.
    public func download(_ url: URL, to target: URL) async throws {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.dlsite.com/", forHTTPHeaderField: "Referer")
        let (temp, response) = try await session.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure("下载图片失败 \((response as? HTTPURLResponse)?.statusCode ?? 0)：\(url.lastPathComponent)")
        }
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.moveItem(at: temp, to: target)
    }

    private func get(_ url: String, _ productId: String) async throws -> Data {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("adultchecked=1; locale=zh-cn", forHTTPHeaderField: "Cookie")
        let (data, response) = try await session.data(for: request)
        let status = (response as! HTTPURLResponse).statusCode
        guard status == 200, !data.isEmpty else {
            throw Failure("DLsite 返回 \(status)：\(productId)")
        }
        return data
    }
}

import Foundation

/// A file or folder in a remote source (115 or WebDAV).
public struct RemoteEntry: Sendable, Hashable, Identifiable, Codable {
    public enum Kind: String, Sendable, Codable {
        case folder, audio, video, image, subtitle, text, other
    }

    public let id: String
    /// 115: the folder cid or file id. WebDAV: the path.
    public let path: String
    public let name: String
    public let kind: Kind
    public let size: Int?
    /// 115 only: the handle used to fetch a file's direct link.
    public let pickcode: String?
    public let sourceId: String

    public var isFolder: Bool { kind == .folder }

    public init(id: String, path: String, name: String, kind: Kind, size: Int? = nil, pickcode: String? = nil, sourceId: String) {
        self.id = id
        self.path = path
        self.name = name
        self.kind = kind
        self.size = size
        self.pickcode = pickcode
        self.sourceId = sourceId
    }
}

/// A streamable URL plus the headers the server insists on.
public struct ResolvedMedia: Sendable {
    public let url: URL
    public let headers: [(name: String, value: String)]
    /// When a signed link stops working; nil when it doesn't expire.
    public let expiresAt: Date?
}

public enum P115Error: LocalizedError, Equatable {
    case notLoggedIn
    case authExpired
    /// 115 answered with an HTML page (verification, rate limit, WAF). The
    /// cookie is still good; the user should retry later.
    case blocked
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn: "尚未登录 115"
        case .authExpired: "115 登录已失效，请重新扫码登录"
        case .blocked: "115 暂时限制了访问，可能是短时间请求过多或需在网页端验证，请稍后重试或切换网络。"
        case .failed(let message): message
        }
    }
}

/// 115 web APIs authenticated with the cookie from a TV-QR login.
public actor P115Client {
    /// One client app-wide, so every 115 request shares the same pacing.
    public static let shared = P115Client()
    public static let sourceId = "p115"
    public static let sourceName = "115 网盘"
    static let cookieKey = "p115_cookie"
    static let userAgent = "Mozilla/5.0 115Browser/30.4.0"

    private let keychain: KeychainStore
    private let session: URLSession
    private let minInterval: Duration
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var lastRequest: ContinuousClock.Instant?

    public init(keychain: KeychainStore = .shared, minInterval: Duration = .milliseconds(1200)) {
        self.keychain = keychain
        self.minInterval = minInterval
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        // Cookies are assembled by hand: the CDN needs the login cookie plus
        // the anti-leech ones picked up along the downurl redirect chain.
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        session = URLSession(configuration: config)
    }

    public enum LoginState: Equatable, Sendable {
        case loggedIn, loggedOut
        /// The Keychain could not be read.
        case unreadable(String)
    }

    public nonisolated var loginState: LoginState {
        do {
            return try keychain.string(for: Self.cookieKey) == nil ? .loggedOut : .loggedIn
        } catch {
            DiagnosticLog.shared.write("p115", "cookie_unreadable", ["error": "\(error)"])
            return .unreadable("\(error)")
        }
    }

    /// A folder's entries, folders first, each group by name.
    public func list(_ cid: String) async throws -> [RemoteEntry] {
        var entries: [RemoteEntry] = []
        var offset = 0
        let limit = 500
        while true {
            var components = URLComponents(string: "https://webapi.115.com/files")!
            components.queryItems = [
                "aid": "1", "cid": cid, "offset": "\(offset)", "limit": "\(limit)", "show_dir": "1",
                "fc_mix": "0", "natsort": "1", "format": "json",
            ].map { URLQueryItem(name: $0.key, value: $0.value) }
            var request = URLRequest(url: components.url!)
            request.setValue(try cookie(), forHTTPHeaderField: "Cookie")
            let json = try await throttled { try await json(request) }
            let page = Self.entries(json)
            entries += page
            offset += page.count
            let count = Self.int(json["count"] ?? json["total"]) ?? 0
            if page.count < limit || (count > 0 && offset >= count) { break }
        }
        return entries.sorted {
            $0.isFolder != $1.isFolder ? $0.isFolder : $0.name.lowercased() < $1.name.lowercased()
        }
    }

    /// The signed CDN link for a file. The CDN answers 403 "no cookie value"
    /// unless it gets the session cookie plus the anti-leech cookies 115 sets
    /// while redirecting the downurl request, and a 115 referer.
    public func resolve(pickcode: String) async throws -> ResolvedMedia {
        let sessionCookie = try cookie()
        let (json, setCookies): ([String: Any], [String]) = try await throttled {
            var request = URLRequest(url: URL(string: "https://proapi.115.com/app/chrome/downurl")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            let form = "data=" + P115Cipher.encrypt(["pickcode": pickcode]).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
            request.httpBody = Data(form.utf8)
            return try await followRedirects(request, sessionCookie: sessionCookie)
        }
        guard Self.truthy(json["state"]) else {
            if Self.isAuthError(json) { throw P115Error.authExpired }
            throw P115Error.failed("\(json["error"] ?? json["message"] ?? "获取直链失败")")
        }
        let decrypted = P115Cipher.decrypt(json["data"] as! String)
        let data = try JSONSerialization.jsonObject(with: Data(decrypted.utf8))
        let url = URL(string: try Self.downloadURL(data))!
        let cookie = Self.mergeCookies(sessionCookie, setCookies)
        let expiry = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "t" }?.value.flatMap(TimeInterval.init)
        DiagnosticLog.shared.write("p115", "resolved", ["host": url.host() ?? "", "expiresIn": expiry.map { Int($0 - Date.now.timeIntervalSince1970) } ?? -1])
        return ResolvedMedia(
            url: url,
            // FFmpeg only honours a caller User-Agent after a line break, so
            // it must not come first.
            headers: [("Cookie", cookie), ("Referer", "https://115.com/"), ("User-Agent", Self.userAgent)],
            expiresAt: expiry.map(Date.init(timeIntervalSince1970:))
        )
    }

    /// Whole-file download straight from the CDN, for subtitles.
    public func download(pickcode: String) async throws -> Data {
        let media = try await resolve(pickcode: pickcode)
        var request = URLRequest(url: media.url)
        for header in media.headers { request.setValue(header.value, forHTTPHeaderField: header.name) }
        let (data, response) = try await session.data(for: request)
        let status = (response as! HTTPURLResponse).statusCode
        if status == 401 || status == 403 { throw P115Error.authExpired }
        guard status == 200 || status == 206 else { throw P115Error.failed("115 文件下载失败：\(status)") }
        return data
    }

    // MARK: - Internals

    /// One request at a time, at least `minInterval` apart: 115 throttles
    /// bursts across all cookie-backed endpoints, so listing, subtitle
    /// downloads and playback links share one rhythm.
    private func throttled<T>(_ body: () async throws -> T) async throws -> T {
        if busy {
            await withCheckedContinuation { waiting.append($0) }
        }
        busy = true
        defer {
            if waiting.isEmpty { busy = false } else { waiting.removeFirst().resume() }
        }
        if let lastRequest {
            let wait = minInterval - (ContinuousClock.now - lastRequest)
            if wait > .zero { try await Task.sleep(for: wait) }
        }
        lastRequest = .now
        return try await body()
    }

    private func cookie() throws -> String {
        guard let cookie = try keychain.string(for: Self.cookieKey) else { throw P115Error.notLoggedIn }
        return cookie
    }

    private func json(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await send(request)
        try Self.checkStatus(response)
        let json = try Self.parse(data)
        guard Self.truthy(json["state"]) else {
            if Self.isAuthError(json) { throw P115Error.authExpired }
            throw P115Error.failed("\(json["error"] ?? json["message"] ?? "115 请求失败")")
        }
        return json
    }

    /// downurl answers with a redirect to a gateway serving the encrypted
    /// JSON; each hop may set cookies the CDN later requires.
    private func followRedirects(_ first: URLRequest, sessionCookie: String) async throws -> ([String: Any], [String]) {
        var (data, response) = try await send(first)
        var setCookies = Self.setCookies(response)
        for _ in 0..<5 {
            guard let location = response.value(forHTTPHeaderField: "Location"), !location.isEmpty else { break }
            var request = URLRequest(url: URL(string: location, relativeTo: response.url)!.absoluteURL)
            request.setValue(Self.mergeCookies(sessionCookie, setCookies), forHTTPHeaderField: "Cookie")
            request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
            (data, response) = try await send(request)
            setCookies += Self.setCookies(response)
        }
        try Self.checkStatus(response)
        return (try Self.parse(data), setCookies)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request, delegate: NoRedirects())
            return (data, response as! HTTPURLResponse)
        } catch let error as URLError {
            let message = switch error.code {
            case .timedOut: "连接 115 超时，请检查网络后重试"
            case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost, .cannotFindHost: "无法连接到 115，请检查网络"
            default: "115 请求失败：\(error.localizedDescription)"
            }
            throw P115Error.failed(message)
        }
    }

    private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
            nil
        }
    }

    private static func checkStatus(_ response: HTTPURLResponse) throws {
        if response.statusCode == 401 || response.statusCode == 403 { throw P115Error.authExpired }
    }

    private static func parse(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw P115Error.blocked }
        return json
    }

    static func entries(_ json: [String: Any]) -> [RemoteEntry] {
        (json["data"] as? [[String: Any]] ?? []).map { item in
            let fid = item["fid"].map { "\($0)" } ?? ""
            let name = "\(item["n"] ?? item["name"] ?? item["file_name"] ?? "")"
            guard !fid.isEmpty, fid != "0" else {
                let cid = "\(item["cid"] ?? item["file_id"] ?? "")"
                return RemoteEntry(id: cid, path: cid, name: name, kind: .folder, sourceId: sourceId)
            }
            return RemoteEntry(
                id: fid, path: fid, name: name, kind: RemoteEntry.Kind(FileKind(fileName: name)),
                size: int(item["s"] ?? item["file_size"]), pickcode: "\(item["pc"] ?? item["pick_code"] ?? "")", sourceId: sourceId
            )
        }
    }

    static func downloadURL(_ data: Any) throws -> String {
        let map = data as! [String: Any]
        if let url = map["url"] as? String { return url }
        for value in map.values {
            let url = (value as? [String: Any])?["url"]
            if let url = url as? String { return url }
            if let url = (url as? [String: Any])?["url"] as? String { return url }
        }
        throw P115Error.failed("115 未返回可播放直链")
    }

    static func mergeCookies(_ base: String, _ setCookies: [String]) -> String {
        var names: [String] = []
        var values: [String: String] = [:]
        let pairs = base.split(separator: ";") + setCookies.map { $0.split(separator: ";").first ?? "" }
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let name = String(trimmed[..<eq])
            if values[name] == nil { names.append(name) }
            values[name] = String(trimmed[trimmed.index(after: eq)...])
        }
        return names.map { "\($0)=\(values[$0]!)" }.joined(separator: "; ")
    }

    private static func setCookies(_ response: HTTPURLResponse) -> [String] {
        // URLSession folds repeated Set-Cookie headers into one, comma-joined.
        HTTPCookie.cookies(withResponseHeaderFields: response.allHeaderFields as! [String: String], for: response.url!)
            .map { "\($0.name)=\($0.value)" }
    }

    static func truthy(_ value: Any?) -> Bool {
        (value as? Bool) == true || (value as? Int) == 1
    }

    private static func isAuthError(_ json: [String: Any]) -> Bool {
        ["401", "403", "911"].contains("\(json["errno"] ?? json["errNo"] ?? json["code"] ?? "")")
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let n as NSNumber: n.intValue
        case let s as String: Int(s)
        default: nil
        }
    }
}

extension RemoteEntry.Kind {
    init(_ kind: FileKind) {
        self = switch kind {
        case .audio: .audio
        case .video: .video
        case .image: .image
        case .subtitle: .subtitle
        case .text: .text
        case .other: .other
        }
    }
}

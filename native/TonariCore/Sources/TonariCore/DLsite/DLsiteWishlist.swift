import Foundation
import Synchronization

/// The DLsite login, kept as the cookies DLsite set when the user signed in
/// on its own page (the app never sees the password), with that page's
/// user agent: requests present themselves as the same browser.
public enum DLsiteAccount {
    static let cookieKey = "dlsite_cookie"
    static let userAgentKey = "dlsite_user_agent"

    /// `name=value; …` for a Cookie header, when signed in.
    public static func cookie(keychain: KeychainStore = .shared) throws -> String? {
        try keychain.string(for: cookieKey)
    }

    public static func userAgent(keychain: KeychainStore = .shared) throws -> String? {
        try keychain.string(for: userAgentKey)
    }

    public static func isSignedIn(keychain: KeychainStore = .shared) throws -> Bool {
        try cookie(keychain: keychain) != nil && userAgent(keychain: keychain) != nil
    }

    public static func save(_ cookies: [(name: String, value: String)], userAgent: String, keychain: KeychainStore = .shared) throws {
        try keychain.set(cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "), for: cookieKey)
        try keychain.set(userAgent, for: userAgentKey)
    }

    public static func signOut(keychain: KeychainStore = .shared) throws {
        try keychain.remove(cookieKey)
        try keychain.remove(userAgentKey)
    }

    /// DLsite's own pages treat this cookie as "signed in".
    public static let loginCookie = "loginchecked"
}

/// The DLsite account's wishlist, through the endpoints DLsite's web pages
/// call: a JSON list of product ids, and cart AJAX modes to add and remove.
public final class DLsiteWishlist: Sendable {
    public enum Failure: LocalizedError, Equatable {
        case signedOut
        /// DLsite answered as if logged out: the saved login has lapsed.
        case expired
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .signedOut: "还没有登录 DLsite"
            case .expired: "DLsite 登录已失效，请重新登录"
            case .failed(let message): message
            }
        }
    }

    /// Sends a request and returns the body with the response.
    public typealias Send = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let cookie: Mutex<String>
    private let userAgent: String
    private let send: Send
    /// Where DLsite's cookie updates are written back; nil in tests.
    private let keychain: KeychainStore?

    /// Nil when signed out.
    public init?(keychain: KeychainStore = .shared, send: @escaping Send = DLsiteWishlist.urlSession) throws {
        guard let cookie = try DLsiteAccount.cookie(keychain: keychain),
              let userAgent = try DLsiteAccount.userAgent(keychain: keychain)
        else { return nil }
        self.cookie = Mutex(cookie)
        self.userAgent = userAgent
        self.send = send
        self.keychain = keychain
    }

    init(cookie: String, userAgent: String = DLsiteClient.userAgent, send: @escaping Send) {
        self.cookie = Mutex(cookie)
        self.userAgent = userAgent
        self.send = send
        keychain = nil
    }

    /// An ephemeral session: the saved login is the only cookie source, not
    /// whatever the shared cookie store picked up.
    public static let urlSession: Send = { request in
        let (data, response) = try await session.data(for: request)
        return (data, response as! HTTPURLResponse)
    }

    private static let session = URLSession(configuration: .ephemeral)

    /// Newest first, as DLsite lists them. The answer is JSON (served as
    /// text/html) with the ids under `favorites`; a logged-out session gets
    /// the login page instead.
    public func productIds() async throws -> [String] {
        struct Favorites: Decodable { let favorites: [String] }
        let url = URL(string: "https://www.dlsite.com/maniax/load/favorite/product?_=\(Int(Date.now.timeIntervalSince1970))")!
        var request = request(url)
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        let (data, response) = try await exchange(request)
        guard response.statusCode == 200, let ids = try? JSONDecoder().decode(Favorites.self, from: data).favorites else {
            Self.log("favorites_unexpected", response, data)
            throw response.statusCode == 200 ? Failure.expired : Failure.failed("DLsite 返回 \(response.statusCode)")
        }
        return ids
    }

    public func add(_ productId: String) async throws {
        try await cart(mode: "wishlist", productId)
    }

    public func remove(_ productId: String) async throws {
        try await cart(mode: "wishlist_remove", productId)
    }

    /// The cart endpoint answers XML with `result_code` -1 on failure and
    /// the reason in `res_msg`.
    private func cart(mode: String, _ productId: String) async throws {
        var request = request(URL(string: "https://www.dlsite.com/maniax/cart/ajax")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = Data("mode=\(mode)&obj_nocheck=1&product_id=\(productId)".utf8)
        let (data, response) = try await exchange(request)
        guard response.statusCode == 200 else {
            Self.log("cart_unexpected", response, data)
            throw Failure.failed("DLsite 返回 \(response.statusCode)")
        }
        let xml = String(decoding: data, as: UTF8.self)
        guard let code = Self.element("result_code", in: xml) else {
            Self.log("cart_unexpected", response, data)
            throw Failure.expired
        }
        guard code != "-1" else { throw Failure.failed(Self.element("res_msg", in: xml) ?? "DLsite 拒绝了这次操作") }
    }

    /// Sends and, like a browser, keeps whatever cookies DLsite renews, so
    /// the login lasts as long as it would on the website.
    private func exchange(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await send(request)
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { $0["\($1.key)"] = "\($1.value)" }
        let renewed = HTTPCookie.cookies(withResponseHeaderFields: headers, for: request.url!)
        if !renewed.isEmpty {
            let updated = cookie.withLock { current in
                current = Self.merge(current, renewed)
                return current
            }
            try keychain?.set(updated, for: DLsiteAccount.cookieKey)
        }
        return (data, response)
    }

    /// Replaces or adds the renewed values; expired ones drop out.
    static func merge(_ header: String, _ renewed: [HTTPCookie], now: Date = .now) -> String {
        var pairs: [(String, String)] = header.split(separator: "; ").map { pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
        }
        for cookie in renewed {
            pairs.removeAll { $0.0 == cookie.name }
            if cookie.expiresDate.map({ $0 > now }) ?? true { pairs.append((cookie.name, cookie.value)) }
        }
        return pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "; ")
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("adultchecked=1; locale=zh-cn; \(cookie.withLock { $0 })", forHTTPHeaderField: "Cookie")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    /// What DLsite sent instead of the expected answer, to tell a lapsed
    /// login from a changed endpoint.
    private static func log(_ event: String, _ response: HTTPURLResponse, _ data: Data) {
        DiagnosticLog.shared.write("dlsite", event, [
            "status": response.statusCode,
            "url": response.url?.absoluteString ?? "",
            "type": response.value(forHTTPHeaderField: "Content-Type") ?? "",
            "body": String(decoding: data.prefix(300), as: UTF8.self),
        ])
    }

    static func element(_ name: String, in xml: String) -> String? {
        guard let start = xml.range(of: "<\(name)>"), let end = xml.range(of: "</\(name)>", range: start.upperBound..<xml.endIndex) else { return nil }
        return String(xml[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

import Foundation

/// 115's TV QR-code login: show the code, poll until the 115 app confirms,
/// then trade the session for a cookie kept in the Keychain.
public struct P115Auth: Sendable {
    public struct Token: Sendable, Equatable {
        public let uid: String
        let time: Int
        let sign: String

        public var imageURL: URL {
            var components = URLComponents(string: "https://qrcodeapi.115.com/api/1.0/tv/1.0/qrcode")!
            components.queryItems = [URLQueryItem(name: "uid", value: uid)]
            return components.url!
        }
    }

    public enum Status: Int, Sendable {
        case waiting = 0, scanned = 1, confirmed = 2, expired = -1, canceled = -2
    }

    private let keychain: KeychainStore
    private let session = URLSession(configuration: .ephemeral)

    public init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
    }

    public func token() async throws -> Token {
        let data = try await call(URLRequest(url: URL(string: "https://qrcodeapi.115.com/api/1.0/tv/1.0/token/")!))
        return Token(uid: "\(data["uid"]!)", time: P115Client.int(data["time"])!, sign: "\(data["sign"]!)")
    }

    public func status(of token: Token) async throws -> Status {
        var components = URLComponents(string: "https://qrcodeapi.115.com/get/status/")!
        components.queryItems = [
            URLQueryItem(name: "uid", value: token.uid),
            URLQueryItem(name: "time", value: "\(token.time)"),
            URLQueryItem(name: "sign", value: token.sign),
            URLQueryItem(name: "_", value: "\(Int(Date.now.timeIntervalSince1970 * 1000))"),
        ]
        let data = try await call(URLRequest(url: components.url!))
        return Status(rawValue: P115Client.int(data["status"])!) ?? .waiting
    }

    /// Completes a confirmed login and stores the cookie.
    public func finish(_ token: Token) async throws {
        var request = URLRequest(url: URL(string: "https://passportapi.115.com/app/1.0/tv/1.0/login/qrcode/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(P115Client.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = Data("account=\(token.uid)&app=tv".utf8)
        let data = try await call(request)
        let cookie: String
        if let fields = data["cookie"] as? [String: Any] {
            cookie = ["UID", "CID", "SEID", "KID"].map { "\($0)=\(fields[$0].map { "\($0)" } ?? "")" }.joined(separator: "; ")
        } else {
            cookie = "\(data["cookie"]!)"
        }
        try keychain.set(cookie, for: P115Client.cookieKey)
    }

    public func logout() throws {
        try keychain.remove(P115Client.cookieKey)
    }

    private func call(_ request: URLRequest) async throws -> [String: Any] {
        let (body, _) = try await session.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { throw P115Error.blocked }
        guard P115Client.truthy(json["state"]) else {
            throw P115Error.failed("\(json["error"] ?? json["message"] ?? "115 登录失败")")
        }
        return json["data"] as! [String: Any]
    }
}

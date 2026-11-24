import Foundation

public enum WebdavError: LocalizedError, Equatable {
    case unauthorized
    case notFound
    case notWebdav
    case status(Int)
    case unreachable(String)
    case serverGone

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "认证失败，请检查用户名和密码"
        case .notFound: "路径不存在（404），请检查路径设置"
        case .notWebdav: "服务器不支持 WebDAV，请检查地址和路径"
        case .status(let code): "WebDAV 服务器返回 \(code)"
        case .unreachable(let message): message
        case .serverGone: "WebDAV 服务器已删除"
        }
    }
}

/// One WebDAV server: PROPFIND listings, whole-file downloads for subtitles
/// and previews, and links the players stream with Basic auth in a header.
/// Paths are decoded absolute server paths, base path included.
public struct WebdavClient: Sendable {
    public let server: WebdavServer
    let password: String?

    public init(server: WebdavServer, password: String?) {
        self.server = server
        self.password = password
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    /// A folder's entries, folders first, each group by name.
    public func list(_ path: String) async throws -> [RemoteEntry] {
        let data = try await propfind(path, depth: 1)
        return RemoteSort.name.sorted(try Self.entries(data, in: path, sourceId: server.id), ascending: true)
    }

    /// Lists the base path itself, for 测试连接.
    public func check() async throws {
        _ = try await propfind(server.rootPath, depth: 0, timeout: 10)
    }

    /// Probes the server after a playback failed: nil when it answers,
    /// otherwise what is wrong with it, named, so a sleeping NAS doesn't
    /// read as a broken file.
    public func probe() async -> String? {
        do {
            try await check()
            return nil
        } catch WebdavError.unreachable {
            return "WebDAV「\(server.name)」连不上，请检查网络或服务器是否开机"
        } catch {
            return "WebDAV「\(server.name)」：\(error.localizedDescription)"
        }
    }

    public func download(_ path: String) async throws -> Data {
        var request = URLRequest(url: url(path))
        authorize(&request)
        let (data, response) = try await send(request)
        try Self.check(response.statusCode)
        return data
    }

    public func media(_ path: String) -> ResolvedMedia {
        ResolvedMedia(url: url(path), headers: authorization.map { [("Authorization", $0)] } ?? [], expiresAt: nil)
    }

    // MARK: - Requests

    static let propfindBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:getcontentlength/><d:getlastmodified/></d:prop></d:propfind>
        """

    private func propfind(_ path: String, depth: Int, timeout: TimeInterval = 20) async throws -> Data {
        var request = URLRequest(url: url(path, directory: true), timeoutInterval: timeout)
        request.httpMethod = "PROPFIND"
        request.setValue("\(depth)", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.propfindBody.utf8)
        authorize(&request)
        let (data, response) = try await send(request)
        if response.statusCode == 405 { throw WebdavError.notWebdav }
        try Self.check(response.statusCode)
        return data
    }

    var authorization: String? {
        guard let username = server.username, !username.isEmpty else { return nil }
        return "Basic " + Data("\(username):\(password ?? "")".utf8).base64EncodedString()
    }

    private func authorize(_ request: inout URLRequest) {
        if let authorization { request.setValue(authorization, forHTTPHeaderField: "Authorization") }
    }

    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    func url(_ path: String, directory: Bool = false) -> URL {
        var encoded = path.split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: Self.unreserved)! }
            .joined(separator: "/")
        if directory && !encoded.hasSuffix("/") { encoded += "/" }
        return URL(string: server.origin + encoded)!
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await Self.session.data(for: request)
            return (data, response as! HTTPURLResponse)
        } catch let error as URLError {
            throw switch error.code {
            case .cancelled: CancellationError()
            case .timedOut: WebdavError.unreachable("连接 WebDAV 服务器超时，请检查网络")
            case .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed:
                WebdavError.unreachable("无法连接到 WebDAV 服务器，请检查地址、端口和网络")
            case .secureConnectionFailed: WebdavError.unreachable("HTTPS 连接失败，请检查协议和端口")
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                WebdavError.unreachable("HTTPS 证书校验失败")
            default: WebdavError.unreachable("WebDAV 请求失败：\(error.localizedDescription)")
            }
        }
    }

    private static func check(_ status: Int) throws {
        switch status {
        case 200..<300: return
        case 401, 403: throw WebdavError.unauthorized
        case 404: throw WebdavError.notFound
        default: throw WebdavError.status(status)
        }
    }

    // MARK: - Multistatus

    /// The children in a PROPFIND body; the folder itself is listed too and
    /// dropped. Hrefs may be absolute URLs or paths, percent-encoded.
    static func entries(_ data: Data, in folder: String, sourceId: String) throws -> [RemoteEntry] {
        let reader = MultistatusReader()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = reader
        guard parser.parse() else { throw WebdavError.notWebdav }
        let folder = trimmingSlash(folder)
        return reader.items.compactMap { item in
            let path = trimmingSlash(decodedPath(item.href))
            guard path != folder else { return nil }
            let name = String(path.split(separator: "/").last!)
            return RemoteEntry(
                id: path, path: path, name: name, kind: item.isFolder ? .folder : .init(FileKind(fileName: name)),
                size: item.isFolder ? nil : item.size, modifiedAt: item.modifiedAt, sourceId: sourceId
            )
        }
    }

    static func decodedPath(_ href: String) -> String {
        var path = Substring(href)
        if let scheme = href.range(of: "://") {
            let rest = href[scheme.upperBound...]
            path = rest.firstIndex(of: "/").map { rest[$0...] } ?? "/"
        }
        return path.removingPercentEncoding ?? String(path)
    }

    static func trimmingSlash(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}

/// Reads `response` elements by local name, so any namespace prefix works.
/// Values in a 404 propstat are empty and skipped, which leaves the 200 one.
private final class MultistatusReader: NSObject, XMLParserDelegate {
    struct Item {
        var href = ""
        var isFolder = false
        var size: Int?
        var modifiedAt: Date?
    }

    var items: [Item] = []
    private var current: Item?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        text = ""
        switch elementName {
        case "response": current = Item()
        case "collection": current?.isFolder = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        text = ""
        guard !value.isEmpty || elementName == "response" else { return }
        switch elementName {
        case "href": current?.href = value
        case "getcontentlength": current?.size = Int(value)
        case "getlastmodified": current?.modifiedAt = try? Date(value, strategy: .http)
        case "response":
            items.append(current!)
            current = nil
        default: break
        }
    }
}

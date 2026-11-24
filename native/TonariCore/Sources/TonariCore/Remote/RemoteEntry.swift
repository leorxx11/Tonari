import Foundation

/// A file or folder in a remote source (115 or WebDAV).
public struct RemoteEntry: Sendable, Hashable, Identifiable, Codable {
    public enum Kind: String, Sendable, Codable {
        case folder, audio, video, image, subtitle, text, document, other
    }

    public let id: String
    /// 115: the folder cid or file id. WebDAV: the path.
    public let path: String
    public let name: String
    public let kind: Kind
    public let size: Int?
    public let modifiedAt: Date?
    /// 115 only: the handle used to fetch a file's direct link.
    public let pickcode: String?
    /// `p115`, or the WebDAV server's id.
    public let sourceId: String

    public var isFolder: Bool { kind == .folder }

    public init(id: String, path: String, name: String, kind: Kind, size: Int? = nil, modifiedAt: Date? = nil, pickcode: String? = nil, sourceId: String) {
        self.id = id
        self.path = path
        self.name = name
        self.kind = kind
        self.size = size
        self.modifiedAt = modifiedAt
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

extension RemoteEntry.Kind {
    init(_ kind: FileKind) {
        self = switch kind {
        case .audio: .audio
        case .video: .video
        case .image: .image
        case .subtitle: .subtitle
        case .text: .text
        case .document: .document
        case .other: .other
        }
    }
}

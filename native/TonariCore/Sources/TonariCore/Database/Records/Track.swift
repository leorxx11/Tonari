import Foundation
import GRDB

public struct Track: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "tracks"

    public var id: String
    public var workId: String
    /// Absolute local path, or the remote path for WebDAV / 115 works.
    public var filePath: String
    public var relativePath: String
    public var fileName: String
    public var fileFormat: String
    public var fileSizeBytes: Int
    public var durationMs: Int
    public var sampleRate: Int?
    public var bitRate: Int?
    public var categoryHint: String?
    public var userCategory: String?
    public var parentDirName: String
    public var trackNumber: Int?
    public var title: String
    public var alternateQualityPathsJson: [String: String]
    public var lastPositionMs: Int
    public var playCount: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var titleZh: String?
}

public struct WorkFile: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "work_files"

    public var id: String
    public var workId: String
    public var filePath: String
    public var relativePath: String
    public var fileName: String
    /// audio / video / image / subtitle / text / other
    public var fileKind: String
    public var fileSizeBytes: Int
    public var createdAt: Date
    public var updatedAt: Date
}

public struct Subtitle: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "subtitles"

    public struct Line: Codable, Sendable, Hashable {
        public var startMs: Int
        public var endMs: Int
        public var text: String

        enum CodingKeys: String, CodingKey {
            case startMs = "s"
            case endMs = "e"
            case text = "t"
        }
    }

    public var id: String
    public var trackId: String
    public var filePath: String
    public var fileFormat: String
    public var fileHash: String
    public var timeOffsetMs: Int
    public var originalLinesJson: [Line]
    public var translatedLinesJson: [Line]?
    public var translatedAt: Date?
    public var translatedByModel: String?
    public var createdAt: Date
    public var updatedAt: Date
}

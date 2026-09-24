import Foundation
import GRDB

/// Message-inbox entry; repeats of the same event bump `count` and `lastAt`.
public struct AppEvent: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "app_events"

    public var id: String
    public var createdAt: Date
    public var lastAt: Date
    public var category: String
    public var severity: String
    public var title: String
    public var detail: String
    public var productId: String?
    public var workTitle: String?
    public var sourceName: String?
    public var actionKey: String?
    public var count: Int
    public var read: Bool
}

public struct PlayHistoryEntry: DriftRecord, Identifiable, Hashable {
    public static let databaseTableName = "play_history_entries"

    public var id: String
    /// work / video
    public var kind: String
    public var title: String
    public var workId: String?
    public var sourceKind: String?
    public var sourceId: String?
    public var sourceName: String?
    public var path: String?
    public var fileName: String?
    public var pickcode: String?
    public var size: Int?
    public var positionMs: Int
    public var durationMs: Int?
    public var playedAt: Date
}

/// Listening time per local calendar day and work. No foreign key: totals
/// outlive deleted works.
public struct ListenLog: DriftRecord, Hashable {
    public static let databaseTableName = "listen_logs"

    /// Local date as `yyyy-MM-dd`.
    public var day: String
    public var workId: String
    public var listenedMs: Int
}

import Foundation
import GRDB

/// The message inbox: background failures (imports, metadata, 115 auth) and
/// the outcome of long jobs the user walked away from, like backups. Kept
/// across launches so they outlive the alert that first reported them.
public enum AppEvents {
    static let retained = 200

    public enum Severity: String, Sendable {
        case error, warning, info
    }

    /// A shortcut the inbox offers next to the message.
    public enum Action: String, Sendable {
        /// Retry enrichment of works that used up their attempts.
        case enrich
        /// Sign in to 115 again.
        case reauth
        /// Sign in to DLsite again.
        case dlsiteLogin
    }

    public static func all(_ db: Database) throws -> [AppEvent] {
        try AppEvent.order(Column("last_at").desc).fetchAll(db)
    }

    public static func unreadCount(_ db: Database) throws -> Int {
        try AppEvent.filter(Column("read") == false).fetchCount(db)
    }
}

extension AppDatabase {
    /// A repeat of the same category, title and work bumps the earlier entry
    /// instead of adding a row: 115 rate limiting fails in bursts.
    public func logEvent(
        category: String,
        severity: AppEvents.Severity = .error,
        title: String,
        detail: String = "",
        productId: String? = nil,
        workTitle: String? = nil,
        sourceName: String? = nil,
        action: AppEvents.Action? = nil,
        at date: Date = .now
    ) throws {
        try writer.write { db in
            let existing = try AppEvent
                .filter(Column("category") == category && Column("title") == title)
                .filter(sql: "product_id IS ?", arguments: [productId])
                .order(Column("last_at").desc)
                .fetchOne(db)
            if var event = existing {
                event.detail = detail
                event.lastAt = date
                event.count += 1
                event.read = false
                try event.update(db)
                return
            }
            try AppEvent(
                id: UUID().uuidString.lowercased(), createdAt: date, lastAt: date,
                category: category, severity: severity.rawValue, title: title, detail: detail,
                productId: productId, workTitle: workTitle, sourceName: sourceName, actionKey: action?.rawValue,
                count: 1, read: false
            ).insert(db)
            try db.execute(
                sql: "DELETE FROM app_events WHERE id NOT IN (SELECT id FROM app_events ORDER BY last_at DESC LIMIT ?)",
                arguments: [AppEvents.retained]
            )
        }
    }

    public func markEventsRead() throws {
        try writer.write { try $0.execute(sql: "UPDATE app_events SET read = 1 WHERE read = 0") }
    }

    public func dismissEvent(_ id: String) throws {
        _ = try writer.write { try AppEvent.deleteOne($0, key: id) }
    }

    public func clearEvents() throws {
        _ = try writer.write { try AppEvent.deleteAll($0) }
    }
}

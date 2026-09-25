import Foundation
import GRDB

/// What the home tab shows: where listening left off, what to pick next.
public enum HomeQueries {
    /// Works unplayed for this long count as 好久没听.
    public static let forgottenDays = 30
    /// Voice actors and tags rank by listening over this many days.
    public static let recentDays = 30

    public struct ContinueListening: Sendable {
        public let work: Work
        /// 1-based position of the last track within its folder.
        public let trackNumber: Int?
        /// Left in that track, when its duration is known.
        public let remainingMs: Int?
    }

    /// A tag with how many library works carry it and how long it was
    /// listened to lately.
    public struct Tag: Sendable, Hashable {
        public let name: String
        public let count: Int
        public let listenedMs: Int
    }

    /// The work of the latest audio entry in the play history.
    public static func continueListening(_ db: Database) throws -> ContinueListening? {
        let entries = try PlayHistoryEntry.filter(Column("kind") == "work").order(Column("played_at").desc).fetchAll(db)
        for entry in entries {
            guard let work = try entry.workId.flatMap({ try Work.fetchOne(db, key: $0) }), !work.isRemoved else { continue }
            let track = try work.lastPlayedTrackId.flatMap { try Track.fetchOne(db, key: $0) }
            let remaining = track.flatMap { $0.durationMs > 0 ? max(0, $0.durationMs - $0.lastPositionMs) : nil }
            return ContinueListening(work: work, trackNumber: try trackNumber(of: work, db), remainingMs: remaining)
        }
        return nil
    }

    /// Position of the work's last track within its folder, as its track
    /// list numbers it.
    public static func trackNumber(of work: Work, _ db: Database) throws -> Int? {
        guard let track = try work.lastPlayedTrackId.flatMap({ try Track.fetchOne(db, key: $0) }) else { return nil }
        let folder = try WorkQueries.tracks(of: work.productId).fetchAll(db).filter { $0.folderPath == track.folderPath }
        return WorkTree.playbackOrder(WorkTree.build(tracks: folder, files: [])).firstIndex { $0.id == track.id }.map { $0 + 1 }
    }

    /// Played before, but not in the last `forgottenDays`; longest ago first.
    public static func forgotten(limit: Int? = nil, now: Date = .now, _ db: Database) throws -> [Work] {
        // Dates are stored as Unix seconds; a Date argument would bind as text.
        let cutoff = Int(Calendar.current.date(byAdding: .day, value: -forgottenDays, to: now)!.timeIntervalSince1970)
        var request = Work
            .filter(Column("is_removed") == false && Column("last_played_at") != nil && Column("last_played_at") < cutoff)
            .order(Column("last_played_at"))
        if let limit { request = request.limit(limit) }
        return try request.fetchAll(db)
    }

    public static func recentlyAdded(limit: Int, _ db: Database) throws -> [Work] {
        try Work.filter(Column("is_removed") == false)
            .order(Column("local_imported_at").desc, Column("product_id"))
            .limit(limit)
            .fetchAll(db)
    }

    /// Voice actors by listening time over the last `recentDays`.
    public static func topVoiceActors(limit: Int, now: Date = .now, _ db: Database) throws -> [String] {
        let totals = try recentListening(now: now, db)
        var byName: [String: Int] = [:]
        for (work, ms) in totals {
            for name in Set(work.voiceActors) where !name.isEmpty { byName[name, default: 0] += ms }
        }
        return Array(byName.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(limit).map(\.key))
    }

    /// Every tag in the library: listened lately first (most listening
    /// first), then the rest by how many works carry it.
    public static func tags(now: Date = .now, _ db: Database) throws -> [Tag] {
        let works = try Work.filter(Column("is_removed") == false).fetchAll(db)
        var listened: [String: Int] = [:]
        for (work, ms) in try recentListening(now: now, db) {
            for name in Set(work.genreNames) { listened[name, default: 0] += ms }
        }
        return LibraryStats(works).genres
            .map { Tag(name: $0.name, count: $0.count, listenedMs: listened[$0.name] ?? 0) }
            .sorted { ($0.listenedMs, $0.count, $1.name) > ($1.listenedMs, $1.count, $0.name) }
    }

    /// A random work carrying every one of `tags`.
    public static func random(tagged tags: Set<String>, _ db: Database) throws -> Work? {
        try Work.filter(Column("is_removed") == false).fetchAll(db)
            .filter { tags.isSubset(of: $0.genreNames) }
            .randomElement()
    }

    private static func recentListening(now: Date, _ db: Database) throws -> [(Work, Int)] {
        let since = PlaybackStore.dayKey(Calendar.current.date(byAdding: .day, value: -recentDays, to: now)!)
        let rows = try Row.fetchAll(
            db, sql: "SELECT work_id, SUM(listened_ms) AS ms FROM listen_logs WHERE day >= ? GROUP BY work_id", arguments: [since]
        )
        let totals = Dictionary(uniqueKeysWithValues: rows.map { ($0["work_id"] as String, $0["ms"] as Int) })
        return try Work.filter(keys: totals.keys).fetchAll(db).map { ($0, totals[$0.productId]!) }
    }
}

import Foundation
import GRDB

/// A work ready to play: its tracks in playback order and where they live.
public struct WorkQueue: Sendable {
    public let work: Work
    public var tracks: [Track]
    /// Nil for works imported before sources were recorded; their track
    /// paths are absolute local paths.
    public let source: ImportedFolder?
}

/// What the mini player comes back with after a cold start.
public enum RestoredPlayback: Sendable {
    case work(WorkQueue, index: Int)
    case file(RemoteEntry, sourceName: String, positionMs: Int, durationMs: Int)
}

/// The database side of playback: progress, recents, play counts and
/// listening time, written the way the Flutter build did.
public struct PlaybackStore: Sendable {
    public static let maxHistoryEntries = 200

    let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// A work's tracks in one folder: what a play from that folder queues.
    public func queue(for productId: String, folder: [String]) throws -> WorkQueue {
        try database.reader.read { db in
            let work = try Work.fetchOne(db, key: productId)!
            let tracks = try WorkQueries.tracks(of: productId).fetchAll(db).filter { $0.folderPath == folder }
            return WorkQueue(
                work: work,
                tracks: WorkTree.playbackOrder(WorkTree.build(tracks: tracks, files: [])),
                source: try work.importedFolderId.flatMap { try ImportedFolder.fetchOne(db, key: $0) }
            )
        }
    }

    /// Where a work picks up: its last track, queued with that track's
    /// folder; the track carries the position it was left at.
    public func resumePoint(for productId: String) throws -> (queue: WorkQueue, index: Int)? {
        let track = try database.reader.read { db in
            try Work.fetchOne(db, key: productId)?.lastPlayedTrackId.flatMap { try Track.fetchOne(db, key: $0) }
        }
        guard let track else { return nil }
        let queue = try queue(for: productId, folder: track.folderPath)
        return (queue, queue.tracks.firstIndex { $0.id == track.id }!)
    }

    /// Whatever was played last, work or remote file, judged by the play
    /// history both kinds write to.
    public func lastPlayed() throws -> RestoredPlayback? {
        let entry = try database.reader.read { db in
            try PlayHistoryEntry.filter(["work", "audio"].contains(Column("kind")))
                .order(Column("played_at").desc).fetchOne(db)
        }
        guard let entry else { return nil }
        if let file = entry.remoteFile {
            return .file(file, sourceName: entry.sourceName!, positionMs: entry.positionMs, durationMs: entry.durationMs ?? 0)
        }
        let work = try database.reader.read { db in
            try entry.workId.flatMap { try Work.filter(key: $0).filter(Column("is_removed") == false).fetchOne(db) }
        }
        guard let work, let resume = try resumePoint(for: work.productId) else { return nil }
        return .work(resume.queue, index: resume.index)
    }

    public func trackStarted(_ track: Track, of work: Work, at date: Date = .now) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE works SET last_played_at = ?, last_played_track_id = ?, updated_at = ? WHERE product_id = ?",
                arguments: [date.unixSeconds, track.id, date.unixSeconds, work.productId]
            )
            try recordWork(work, at: date, db)
        }
    }

    public func savePosition(_ positionMs: Int, of track: Track, in work: Work, at date: Date = .now) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE tracks SET last_position_ms = ? WHERE id = ?", arguments: [positionMs, track.id])
            try db.execute(
                sql: "UPDATE works SET last_played_at = ?, updated_at = ? WHERE product_id = ?",
                arguments: [date.unixSeconds, date.unixSeconds, work.productId]
            )
            try recordWork(work, at: date, db)
        }
    }

    public func saveFilePosition(_ positionMs: Int, durationMs: Int, of entry: RemoteEntry, at date: Date = .now) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE play_history_entries SET position_ms = ?, duration_ms = ?, played_at = ? WHERE id = ?",
                arguments: [positionMs, durationMs, date.unixSeconds, Self.historyId(entry)]
            )
        }
    }

    /// Positive delays the subtitle; subtitles are keyed by their track.
    public func shiftSubtitle(of trackId: String, byMs delta: Int) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE subtitles SET time_offset_ms = time_offset_ms + ?, updated_at = ? WHERE id = ?",
                arguments: [delta, Date.now.unixSeconds, trackId]
            )
        }
    }

    public func resetSubtitleOffset(of trackId: String) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE subtitles SET time_offset_ms = 0, updated_at = ? WHERE id = ?",
                arguments: [Date.now.unixSeconds, trackId]
            )
        }
    }

    public func trackCompleted(_ track: Track) throws {
        try database.writer.write { db in
            try db.execute(sql: "UPDATE tracks SET play_count = play_count + 1 WHERE id = ?", arguments: [track.id])
        }
    }

    /// Imports don't read audio headers for remote files, so the length is
    /// learnt the first time a track loads.
    public func recordDuration(_ durationMs: Int, of track: Track) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE tracks SET duration_ms = ?, updated_at = ? WHERE id = ?",
                arguments: [durationMs, Date.now.unixSeconds, track.id]
            )
        }
    }

    public func addListening(_ ms: Int, to workId: String, at date: Date) throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO listen_logs (day, work_id, listened_ms) VALUES (?, ?, ?)
                    ON CONFLICT (day, work_id) DO UPDATE SET listened_ms = listened_ms + excluded.listened_ms
                    """,
                arguments: [Self.dayKey(date), workId, ms]
            )
        }
    }

    /// A remote file played straight from a browser, keyed like the Flutter
    /// build so its history rows carry over.
    public func recordFile(_ entry: RemoteEntry, sourceName: String, at date: Date = .now) throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO play_history_entries
                        (id, kind, title, source_kind, source_id, source_name, path, file_name, pickcode, size, position_ms, played_at)
                    VALUES (?, 'audio', ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                    ON CONFLICT (id) DO UPDATE SET
                        title = excluded.title, source_name = excluded.source_name, path = excluded.path,
                        file_name = excluded.file_name, size = excluded.size, position_ms = 0, played_at = excluded.played_at
                    """,
                arguments: [
                    Self.historyId(entry), Self.fileTitle(entry.name), entry.sourceId == P115Client.sourceId ? "p115" : "webdav",
                    entry.sourceId, sourceName, entry.path, entry.name, entry.pickcode, entry.size, date.unixSeconds,
                ]
            )
            try trimHistory(db)
        }
    }

    /// The video played last, when nothing was played after it, for the
    /// mini player to come back with.
    public func lastPlayedVideo() throws -> (entry: RemoteEntry, sourceName: String, positionMs: Int, durationMs: Int)? {
        let latest = try database.reader.read { db in
            try PlayHistoryEntry.filter(["work", "audio", "video"].contains(Column("kind")))
                .order(Column("played_at").desc).fetchOne(db)
        }
        guard let latest, latest.kind == "video", let file = latest.remoteFile else { return nil }
        return (file, latest.sourceName!, latest.positionMs, latest.durationMs ?? 0)
    }

    /// A video keeps its place across plays, unlike an audio file, which
    /// the history restarts from the top.
    public func recordVideo(_ entry: RemoteEntry, sourceName: String, at date: Date = .now) throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO play_history_entries
                        (id, kind, title, source_kind, source_id, source_name, path, file_name, pickcode, size, position_ms, played_at)
                    VALUES (?, 'video', ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
                    ON CONFLICT (id) DO UPDATE SET
                        kind = 'video', title = excluded.title, source_name = excluded.source_name, path = excluded.path,
                        file_name = excluded.file_name, size = excluded.size, played_at = excluded.played_at
                    """,
                arguments: [
                    Self.historyId(entry), Self.fileTitle(entry.name), entry.sourceId == P115Client.sourceId ? "p115" : "webdav",
                    entry.sourceId, sourceName, entry.path, entry.name, entry.pickcode, entry.size, date.unixSeconds,
                ]
            )
            try trimHistory(db)
        }
    }

    /// Where to pick a video up: its saved position, or the start when it
    /// was never played or was watched to the last few seconds.
    public func videoResumeMs(_ entry: RemoteEntry) throws -> Int {
        let row = try database.reader.read { try PlayHistoryEntry.fetchOne($0, key: Self.historyId(entry)) }
        guard let row, row.kind == "video" else { return 0 }
        if let duration = row.durationMs, duration > 0, row.positionMs >= duration - Self.videoEndSlackMs { return 0 }
        return row.positionMs
    }

    /// The tail of a video that counts as finished.
    public static let videoEndSlackMs = 10_000

    public func removeHistory(_ id: String) throws {
        try database.writer.write { db in _ = try PlayHistoryEntry.deleteOne(db, key: id) }
    }

    public func clearHistory() throws {
        try database.writer.write { db in _ = try PlayHistoryEntry.deleteAll(db) }
    }

    public static func historyId(_ entry: RemoteEntry) -> String {
        if let pickcode = entry.pickcode, !pickcode.isEmpty { "p115:\(pickcode)" } else { "webdav:\(entry.sourceId):\(entry.path)" }
    }

    public static func fileTitle(_ fileName: String) -> String {
        (fileName as NSString).deletingPathExtension
    }

    /// `yyyy-MM-dd` in local time, which also sorts chronologically.
    public static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    private func recordWork(_ work: Work, at date: Date, _ db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO play_history_entries (id, kind, title, work_id, played_at) VALUES (?, 'work', ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET title = excluded.title, work_id = excluded.work_id, played_at = excluded.played_at
                """,
            arguments: ["work:\(work.productId)", work.title, work.productId, date.unixSeconds]
        )
        try trimHistory(db)
    }

    private func trimHistory(_ db: Database) throws {
        try db.execute(
            sql: "DELETE FROM play_history_entries WHERE id NOT IN (SELECT id FROM play_history_entries ORDER BY played_at DESC LIMIT ?)",
            arguments: [Self.maxHistoryEntries]
        )
    }
}

extension PlayHistoryEntry {
    /// A 115 audio file played from the browser, playable again as is.
    /// The 115 file an audio or video entry played, to play it again.
    public var remoteFile: RemoteEntry? {
        guard kind == "audio" || kind == "video", sourceKind == "p115", let pickcode, let path, let fileName, let sourceId else { return nil }
        return RemoteEntry(id: path, path: path, name: fileName, kind: kind == "video" ? .video : .audio, size: size, pickcode: pickcode, sourceId: sourceId)
    }
}

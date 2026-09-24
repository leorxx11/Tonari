import Foundation
import GRDB

/// Listening time summed from `listen_logs`, as the Flutter stats page
/// showed it: totals, the last 30 days, and what gets played most.
public struct ListenStats: Sendable {
    public struct Day: Sendable, Identifiable {
        public let date: Date
        public let ms: Int
        public var id: Date { date }
    }

    public struct Ranked<Item: Sendable>: Sendable {
        public let item: Item
        public let ms: Int
    }

    public static let dailyWindow = 30
    public static let topCount = 5

    public let totalMs: Int
    public let weekMs: Int
    public let monthMs: Int
    /// Oldest first, days without listening included as zero.
    public let daily: [Day]
    public let topWorks: [Ranked<Work>]
    public let topVoiceActors: [Ranked<String>]
    public let topCircles: [Ranked<String>]

    public var isEmpty: Bool { totalMs == 0 }

    public static func fetch(_ db: Database, now: Date = .now) throws -> ListenStats {
        let logs = try ListenLog.fetchAll(db)
        let works = try Work.filter(keys: Set(logs.map(\.workId))).fetchAll(db)
        return compute(logs: logs, works: Dictionary(uniqueKeysWithValues: works.map { ($0.productId, $0) }), now: now)
    }

    static func compute(logs: [ListenLog], works: [String: Work], now: Date, calendar: Calendar = .current) -> ListenStats {
        let today = calendar.startOfDay(for: now)
        // Weeks start on Monday; `weekday` counts Sunday as 1.
        let sinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let weekStart = PlaybackStore.dayKey(calendar.date(byAdding: .day, value: -sinceMonday, to: today)!)
        let monthStart = PlaybackStore.dayKey(calendar.date(from: calendar.dateComponents([.year, .month], from: today))!)

        var total = 0, week = 0, month = 0
        var byDay: [String: Int] = [:]
        var byWork: [String: Int] = [:]
        for log in logs {
            total += log.listenedMs
            // yyyy-MM-dd keys compare chronologically as strings.
            if log.day >= weekStart { week += log.listenedMs }
            if log.day >= monthStart { month += log.listenedMs }
            byDay[log.day, default: 0] += log.listenedMs
            byWork[log.workId, default: 0] += log.listenedMs
        }

        var voiceActors: [String: Int] = [:]
        var circles: [String: Int] = [:]
        var rankedWorks: [Ranked<Work>] = []
        for (id, ms) in byWork {
            guard let work = works[id] else { continue }
            rankedWorks.append(Ranked(item: work, ms: ms))
            for name in Set(work.voiceActors) { voiceActors[name, default: 0] += ms }
            if let circle = work.circleName, !circle.isEmpty { circles[circle, default: 0] += ms }
        }

        let daily = (0..<dailyWindow).reversed().map { back in
            let date = calendar.date(byAdding: .day, value: -back, to: today)!
            return Day(date: date, ms: byDay[PlaybackStore.dayKey(date)] ?? 0)
        }
        return ListenStats(
            totalMs: total, weekMs: week, monthMs: month, daily: daily,
            topWorks: Array(rankedWorks.sorted { ($0.ms, $1.item.productId) > ($1.ms, $0.item.productId) }.prefix(topCount)),
            topVoiceActors: top(voiceActors), topCircles: top(circles)
        )
    }

    private static func top(_ totals: [String: Int]) -> [Ranked<String>] {
        Array(totals.map { Ranked(item: $0.key, ms: $0.value) }.sorted { ($0.ms, $1.item) > ($1.ms, $0.item) }.prefix(topCount))
    }
}

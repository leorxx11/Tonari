import Foundation

enum Formatting {
    /// `2023-09-10`
    static func date(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    /// `12,345`
    static func count(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic))
    }

    /// `01:23:45`
    static func clock(ms: Int) -> String {
        let seconds = ms / 1000
        return String(format: "%02d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    /// `3:05` or `1:02:03`
    static func trackTime(ms: Int) -> String {
        Duration.milliseconds(ms).formatted(.time(pattern: ms >= 3_600_000 ? .hourMinuteSecond : .minuteSecond))
    }

    /// `2.5h` / `45m` for card footers.
    static func hours(ms: Int) -> String {
        let minutes = ms / 60_000
        return minutes >= 60 ? String(format: "%.1fh", Double(minutes) / 60) : "\(minutes)m"
    }

    /// `45 分钟` / `3 小时` / `3 小时 12 分`, as the stats pages word it.
    static func listening(ms: Int) -> String {
        let minutes = ms / 60_000
        guard minutes >= 60 else { return "\(minutes) 分钟" }
        return minutes % 60 == 0 ? "\(minutes / 60) 小时" : "\(minutes / 60) 小时 \(minutes % 60) 分"
    }

    static func bytes(_ n: Int) -> String {
        Int64(n).formatted(.byteCount(style: .file))
    }
}

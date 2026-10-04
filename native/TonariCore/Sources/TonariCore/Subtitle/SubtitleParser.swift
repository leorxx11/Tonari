import Foundation

/// Parses srt / vtt / lrc / ass / ssa into timed lines. Cues that don't
/// parse are skipped rather than failing the file.
public enum SubtitleParser {
    public static let formats: Set<String> = ["srt", "vtt", "lrc", "ass", "ssa"]

    public static func supports(_ format: String) -> Bool { formats.contains(format.lowercased()) }

    /// ass / ssa, which a track only gets when it has no plain subtitle.
    public static func isStyled(_ format: String) -> Bool { ["ass", "ssa"].contains(format.lowercased()) }

    public static func parse(_ content: String, format: String) -> [Subtitle.Line] {
        switch format.lowercased() {
        case "lrc": parseLRC(content)
        case "ass", "ssa": parseASS(content)
        default: parseSRTOrVTT(content)
        }
    }

    private static func lines(_ content: String) -> [Substring] {
        content.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
    }

    private static func parseSRTOrVTT(_ content: String) -> [Subtitle.Line] {
        let lines = lines(content)
        var result: [Subtitle.Line] = []
        var i = 0
        while i < lines.count {
            guard let m = lines[i].firstMatch(of: /(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[,.](\d{1,3})\s*-->\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{1,2})[,.](\d{1,3})/) else {
                i += 1
                continue
            }
            let start = ms(m.1, m.2, m.3, m.4)
            let end = ms(m.5, m.6, m.7, m.8)
            i += 1
            var text: [Substring] = []
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                text.append(lines[i])
                i += 1
            }
            let cleaned = text.joined(separator: "\n")
                .replacing(/<[^>]+>/, with: "")
                .replacing(/\{[^}]+\}/, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty && end > start {
                result.append(Subtitle.Line(startMs: start, endMs: end, text: cleaned))
            }
        }
        return result
    }

    private static func ms(_ h: Substring?, _ m: Substring, _ s: Substring, _ frac: Substring) -> Int {
        let fraction = frac.count >= 3 ? String(frac.prefix(3)) : frac.padding(toLength: 3, withPad: "0", startingAt: 0)
        return ((Int(h ?? "0")! * 60 + Int(m)!) * 60 + Int(s)!) * 1000 + Int(fraction)!
    }

    /// `Dialogue:` lines of the `[Events]` section, read through its
    /// `Format:` line. Lines sharing a time (say a Japanese and a Chinese
    /// layer) stay separate, in file order.
    private static func parseASS(_ content: String) -> [Subtitle.Line] {
        var inEvents = false
        var columns: [String] = []
        var rows: [(index: Int, line: Subtitle.Line)] = []
        for line in lines(content) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                inEvents = trimmed.lowercased() == "[events]"
                continue
            }
            guard inEvents, let colon = trimmed.firstIndex(of: ":") else { continue }
            let value = trimmed[trimmed.index(after: colon)...]
            switch trimmed[..<colon].lowercased() {
            case "format":
                columns = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            case "dialogue":
                guard let startColumn = columns.firstIndex(of: "start"), let endColumn = columns.firstIndex(of: "end"),
                      let textColumn = columns.firstIndex(of: "text") else { continue }
                // Text is the last column and may itself contain commas.
                let fields = value.split(separator: ",", maxSplits: columns.count - 1, omittingEmptySubsequences: false)
                guard fields.count == columns.count, let start = assTime(fields[startColumn]),
                      let end = assTime(fields[endColumn]) else { continue }
                let text = String(fields[textColumn])
                    .replacing(/\{[^}]*\}/, with: "")
                    .replacing(/\\[Nn]/, with: "\n")
                    .replacing("\\h", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && end > start {
                    rows.append((rows.count, Subtitle.Line(startMs: start, endMs: end, text: text)))
                }
            default:
                continue
            }
        }
        return rows.sorted { ($0.line.startMs, $0.index) < ($1.line.startMs, $1.index) }.map(\.line)
    }

    /// `h:mm:ss.cc`.
    private static func assTime(_ field: Substring) -> Int? {
        field.trimmingCharacters(in: .whitespaces).wholeMatch(of: /(\d+):(\d{1,2}):(\d{1,2})[.:](\d{1,3})/)
            .map { ms($0.1[...], $0.2[...], $0.3[...], $0.4[...]) }
    }

    private static func parseLRC(_ content: String) -> [Subtitle.Line] {
        var rows: [(start: Int, text: String)] = []
        for line in lines(content) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.firstMatch(of: /^(?i)\[(ar|ti|al|au|by|length|offset|re|ve|hash)\s*:/) != nil { continue }
            let matches = line.matches(of: /\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]/)
            guard let last = matches.last else { continue }
            let text = line[last.range.upperBound...].trimmingCharacters(in: .whitespaces)
            for m in matches {
                let fraction: Int = switch m.3 {
                case nil: 0
                case let f? where f.count == 2: Int(f)! * 10
                case let f?: Int(f.padding(toLength: 3, withPad: "0", startingAt: 0).prefix(3))!
                }
                rows.append(((Int(m.1)! * 60 + Int(m.2)!) * 1000 + fraction, text))
            }
        }
        rows.sort { $0.start < $1.start }
        var result: [Subtitle.Line] = []
        for (index, row) in rows.enumerated() where !row.text.isEmpty {
            let end = index + 1 < rows.count ? rows[index + 1].start : row.start + 5000
            if end > row.start {
                result.append(Subtitle.Line(startMs: row.start, endMs: end, text: row.text))
            }
        }
        return result
    }
}

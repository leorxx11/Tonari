import Foundation

/// Opt-in JSONL event log the user exports to report problems. Writes are
/// fire-and-forget and serialized on a private queue, so it can be called
/// from any thread, including media-engine callbacks.
public final class DiagnosticLog: @unchecked Sendable {
    public static let shared = DiagnosticLog(
        directory: URL.documentsDirectory,
        defaults: .standard
    )

    private static let enabledKey = "diagnostic.log.enabled"
    private static let sessionKey = "diagnostic.log.session"

    private let file: URL
    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "tonari.diagnostic-log")
    private var _enabled: Bool
    private var _session: String

    public init(directory: URL, defaults: UserDefaults) {
        file = directory.appending(path: "tonari-diagnostic.jsonl")
        self.defaults = defaults
        _enabled = defaults.bool(forKey: Self.enabledKey)
        _session = defaults.string(forKey: Self.sessionKey) ?? ""
        if _enabled && _session.isEmpty {
            _session = Self.newSessionId()
            defaults.set(_session, forKey: Self.sessionKey)
        }
    }

    public var enabled: Bool { queue.sync { _enabled } }
    public var session: String { queue.sync { _session } }

    public func startSession() {
        let session = Self.newSessionId()
        queue.sync {
            _session = session
            _enabled = true
            try? Data().write(to: file)
        }
        defaults.set(session, forKey: Self.sessionKey)
        defaults.set(true, forKey: Self.enabledKey)
        write("diagnostic", "session_start", ["sessionId": session])
    }

    /// Re-enables collection under the previous session id without clearing
    /// the log, so a stopped session can keep accumulating.
    public func resumeSession() {
        guard !session.isEmpty else { return startSession() }
        queue.sync { _enabled = true }
        defaults.set(true, forKey: Self.enabledKey)
        write("diagnostic", "session_resume", ["sessionId": session])
    }

    public func stopSession() {
        write("diagnostic", "session_stop", ["sessionId": session])
        queue.sync { _enabled = false }
        defaults.set(false, forKey: Self.enabledKey)
    }

    public func write(_ source: String, _ event: String, _ fields: [String: any Sendable] = [:]) {
        let ts = Date().formatted(Self.timestampStyle)
        queue.async { [self] in
            guard _enabled else { return }
            let head: [String: Any] = ["ts": ts, "session": _session, "source": source, "event": event]
            appendLine(Self.json(head, then: fields))
        }
    }

    public func read() -> String {
        queue.sync { (try? String(contentsOf: file, encoding: .utf8)) ?? "" }
    }

    public func clear() {
        queue.sync { try? Data().write(to: file) }
    }

    /// Copies the log to a `.txt` in the temp directory for the share sheet;
    /// nil when there is nothing to share.
    public func exportTxt() throws -> URL? {
        let content = read()
        guard !content.isEmpty else { return nil }
        let name = session.isEmpty ? "tonari-diagnostic" : "tonari-\(session)"
        let out = URL.temporaryDirectory.appending(path: "\(name).txt")
        try content.write(to: out, atomically: true, encoding: .utf8)
        return out
    }

    private func appendLine(_ line: String) {
        let data = Data((line + "\n").utf8)
        guard let handle = try? FileHandle(forWritingTo: file) else {
            try? data.write(to: file)
            return
        }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }

    /// Keeps ts/session/source/event first so lines stay readable, followed by
    /// the caller's fields.
    private static func json(_ head: [String: Any], then fields: [String: any Sendable]) -> String {
        func encode(_ object: [String: Any], keys: [String]) -> [String] {
            keys.map { key in
                let pair = try! JSONSerialization.data(withJSONObject: [key: object[key]!], options: [.withoutEscapingSlashes, .fragmentsAllowed])
                return String(decoding: pair.dropFirst().dropLast(), as: UTF8.self)
            }
        }
        let parts = encode(head, keys: ["ts", "session", "source", "event"])
            + encode(fields, keys: fields.keys.sorted())
        return "{" + parts.joined(separator: ",") + "}"
    }

    private static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)

    private static func newSessionId() -> String {
        String(Int64(Date().timeIntervalSince1970 * 1_000_000), radix: 36)
    }
}

import Foundation
import Testing
@testable import TonariCore

struct DiagnosticLogTests {
    let directory: URL
    let defaults: UserDefaults

    init() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "DiagnosticLogTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    private func lines(_ log: DiagnosticLog) -> [[String: Any]] {
        log.read().split(separator: "\n").map {
            try! JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any]
        }
    }

    @Test func writesNothingUntilASessionStarts() {
        let log = DiagnosticLog(directory: directory, defaults: defaults)
        log.write("player", "play")
        #expect(log.read().isEmpty)
        #expect(!log.enabled)
    }

    @Test func sessionRecordsEventsWithFields() {
        let log = DiagnosticLog(directory: directory, defaults: defaults)
        log.startSession()
        log.write("player", "prepare", ["ok": true, "ms": 120, "url": "http://a/b.mkv"])

        let records = lines(log)
        #expect(records.map { $0["event"] as! String } == ["session_start", "prepare"])
        #expect(records[1]["source"] as! String == "player")
        #expect(records[1]["session"] as! String == log.session)
        #expect(records[1]["ms"] as! Int == 120)
        #expect(records[1]["url"] as! String == "http://a/b.mkv")
        #expect(log.read().hasPrefix("{\"ts\":"))
    }

    @Test func stopThenResumeKeepsSessionAndLog() {
        let log = DiagnosticLog(directory: directory, defaults: defaults)
        log.startSession()
        let session = log.session
        log.stopSession()
        log.write("player", "ignored")
        log.resumeSession()

        #expect(log.session == session)
        #expect(lines(log).map { $0["event"] as! String } == ["session_start", "session_stop", "session_resume"])
    }

    @Test func startSessionClearsPreviousLog() throws {
        let log = DiagnosticLog(directory: directory, defaults: defaults)
        log.startSession()
        log.write("player", "old")
        log.startSession()

        #expect(lines(log).map { $0["event"] as! String } == ["session_start"])
    }

    @Test func stateSurvivesRelaunch() {
        let first = DiagnosticLog(directory: directory, defaults: defaults)
        first.startSession()
        let second = DiagnosticLog(directory: directory, defaults: defaults)
        #expect(second.enabled)
        #expect(second.session == first.session)
    }

    @Test func exportsSessionNamedTxt() throws {
        let log = DiagnosticLog(directory: directory, defaults: defaults)
        #expect(try log.exportTxt() == nil)
        log.startSession()
        let url = try #require(try log.exportTxt())
        #expect(url.lastPathComponent == "tonari-\(log.session).txt")
        #expect(try String(contentsOf: url, encoding: .utf8) == log.read())
    }
}

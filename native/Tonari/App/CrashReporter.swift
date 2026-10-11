import MetricKit
import TonariCore

/// Saves MetricKit crash and hang diagnostics and reports each in the inbox.
/// MetricKit delivers them on a later launch, on a queue of its own.
nonisolated final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                let detail = [
                    crash.exceptionReason?.composedMessage,
                    crash.terminationReason,
                    crash.signal.map { "signal \($0)" },
                    "构建 \(crash.metaData.applicationBuildVersion)",
                ].compactMap(\.self).joined(separator: " · ")
                record(crash, kind: .crash, title: "Tonari 崩溃了", detail: detail)
            }
            for hang in payload.hangDiagnostics ?? [] {
                let seconds = hang.hangDuration.converted(to: .seconds).value.formatted(.number.precision(.fractionLength(1)))
                record(hang, kind: .hang, title: "Tonari 卡住了", detail: "无响应 \(seconds) 秒 · 构建 \(hang.metaData.applicationBuildVersion)")
            }
        }
    }

    private func record(_ diagnostic: MXDiagnostic, kind: CrashReports.Kind, title: String, detail: String) {
        try! CrashReports.shared.save(diagnostic.jsonRepresentation(), kind: kind)
        try! database.logEvent(category: "crash", title: title, detail: detail, action: .crashReports)
        DiagnosticLog.shared.write("metrickit", kind.rawValue, ["detail": detail])
    }
}

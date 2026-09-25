import SwiftUI
import TonariCore

/// Version, build and schema, plus the diagnostic log ready to share.
struct AboutView: View {
    @Environment(\.appDatabase) private var database
    @State private var schemaVersion = 0
    @State private var logFile: URL?

    static var version: String { Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String }
    static var build: String { Bundle.main.infoDictionary!["CFBundleVersion"] as! String }

    var body: some View {
        List {
            Section {
                LabeledContent("版本", value: Self.version)
                LabeledContent("构建号", value: Self.build)
                LabeledContent("数据库版本", value: "\(schemaVersion)")
            }
            Section {
                if let logFile {
                    ShareLink(item: logFile) {
                        Label("导出诊断日志", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Label("导出诊断日志", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(logFile == nil ? "还没有诊断日志。可在「诊断日志」里开始记录。" : "导出当前这次记录的日志，用于反馈问题。")
            }
        }
        .navigationTitle("关于 Tonari")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            schemaVersion = try! database.reader.read { try Int.fetchOne($0, sql: "PRAGMA user_version")! }
            do {
                logFile = try DiagnosticLog.shared.exportTxt()
            } catch {
                DiagnosticLog.shared.write("about", "log_export_failed", ["error": "\(error)"])
            }
        }
    }
}

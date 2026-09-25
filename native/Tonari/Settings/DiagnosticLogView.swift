import SwiftUI
import TonariCore
import UIKit

struct DiagnosticLogView: View {
    @Environment(AppModel.self) private var model
    private let log = DiagnosticLog.shared
    @State private var active = false
    @State private var session = ""
    @State private var content = ""
    @State private var exportURL: URL?

    var body: some View {
        List {
            Section {
                if active {
                    row("停止采集", "stop.circle", subtitle: "会话 \(session)") {
                        log.stopSession()
                        refresh()
                    }
                } else {
                    if !session.isEmpty {
                        row("继续采集", "play.circle", subtitle: "沿用会话 \(session)，不清空日志") {
                            log.resumeSession()
                            refresh()
                        }
                    }
                    row("开始新会话", "arrow.counterclockwise", subtitle: "清空旧日志并开始新的诊断会话") {
                        log.startSession()
                        refresh()
                    }
                }
            }

            Section {
                row("复制日志", "doc.on.doc") {
                    UIPasteboard.general.string = content
                    model.notices.show("日志已复制")
                }
                .disabled(content.isEmpty)
                if let exportURL {
                    ShareLink(item: exportURL, subject: Text("诊断日志")) {
                        Label("导出 txt", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Label("导出 txt", systemImage: "square.and.arrow.up").foregroundStyle(.secondary)
                }
                row("刷新", "arrow.clockwise") { refresh() }
                row("清空", "trash") {
                    log.clear()
                    refresh()
                }
                .disabled(content.isEmpty)
            }

            Section {
                Text(content.isEmpty ? "暂无日志" : content)
                    .font(.caption.monospaced())
                    .foregroundStyle(content.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("诊断日志")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func row(_ title: String, _ icon: String, subtitle: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                VStack(alignment: .leading) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: icon)
            }
        }
    }

    private func refresh() {
        active = log.enabled
        session = log.session
        content = log.read()
        exportURL = try? log.exportTxt()
    }
}

import SwiftUI
import TonariCore

/// The inbox behind the 消息 row: background failures and finished jobs,
/// newest first, each with its shortcut when there is one. Opening it
/// marks everything read.
struct MessagesView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @State private var events: [AppEvent] = []

    var body: some View {
        List {
            Section {
                ForEach(events) { row($0) }
                    .onDelete { offsets in
                        for index in offsets { try! database.dismissEvent(events[index].id) }
                    }
            }
            Section {
                NavigationLink(value: Route.diagnostics) {
                    Label("导出诊断日志", systemImage: "stethoscope")
                }
            }
        }
        .overlay {
            if events.isEmpty { ContentUnavailableView("暂无消息", systemImage: "bell") }
        }
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !events.isEmpty {
                Button("清空") { try! database.clearEvents() }
            }
        }
        .onAppear { try! database.markEventsRead() }
        .onDisappear { try! database.markEventsRead() }
        .task {
            await database.observe(AppEvents.all) { events = $0 }
        }
    }

    private func row(_ event: AppEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            severityIcon(event.severity)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.count > 1 ? "\(event.title) ×\(event.count)" : event.title).font(.body.weight(.medium))
                if !event.detail.isEmpty {
                    Text(event.detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                }
                Text(([event.workTitle, event.sourceName].compactMap(\.self) + [event.lastAt.formatted(.relative(presentation: .named))]).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let action = event.actionKey.flatMap(AppEvents.Action.init) {
                    actionButton(action).padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private func severityIcon(_ severity: String) -> some View {
        switch AppEvents.Severity(rawValue: severity)! {
        case .error: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        case .warning: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .info: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }

    @ViewBuilder private func actionButton(_ action: AppEvents.Action) -> some View {
        switch action {
        case .enrich:
            Button(enrichment.isActive ? "补全中…" : "补全资料") {
                Task { await enrichment.runPending(reset: true) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(enrichment.isActive)
        case .reauth:
            Button("重新登录") { model.push(.p115Login) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

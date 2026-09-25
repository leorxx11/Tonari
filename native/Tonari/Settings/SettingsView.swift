import SwiftUI
import TonariCore

/// After the iOS Settings app: tinted icon tiles, the current value on the
/// right. 消息 sits on top with the unread count the tab badge shows too.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database
    @State private var confirmingStats = false
    @State private var p115 = P115Client.LoginState.loggedOut
    @State private var sourceCount = 0
    @State private var removedCount = 0
    @State private var clearable: Int?
    @State private var unread = 0
    @State private var translator: String?
    @AppStorage(Appearance.preferenceKey) private var appearance = Appearance.system
    @AppStorage(PrivacyShield.preferenceKey) private var blur = true
    @AppStorage(Self.statsRefreshedKey) private var statsRefreshedAt = 0.0
    @AppStorage(BackupExport.lastExportedKey) private var lastBackupAt = 0.0

    private static let statsRefreshedKey = "dlsite.statsRefreshedAt"

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.settingsPath) {
            List {
                Section {
                    NavigationLink(value: Route.messages) {
                        LabeledContent {
                            if unread > 0 {
                                Text("\(unread)")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.red, in: .capsule)
                            }
                        } label: {
                            Label { Text("消息") } icon: { SettingsIcon(systemImage: "bell.fill", tint: .red) }
                        }
                    }
                }
                Section("通用") {
                    row("外观", systemImage: "circle.lefthalf.filled", tint: .blue, value: appearance.label, route: .appearance)
                    row("播放", systemImage: "play.fill", tint: .red, value: "步长 \(player.prefs.seekStep) 秒", route: .playbackSettings)
                    row("隐私", systemImage: "hand.raised.fill", tint: .blue, value: blur ? "后台模糊" : nil, route: .privacy)
                }
                Section("账户与服务") {
                    row(P115Client.sourceName, systemImage: "icloud.fill", tint: .blue, value: p115.label, route: .p115Settings)
                    row("翻译", systemImage: "character.bubble.fill", tint: .indigo, value: translator ?? "未设置", route: .translation)
                }
                Section("媒体库") {
                    row("媒体来源", systemImage: "folder.fill", tint: .orange, value: "\(sourceCount)", route: .mediaSources)
                    row("已移除作品", systemImage: "trash.fill", tint: .gray, value: "\(removedCount)", route: .removedWorks)
                    Button { confirmingStats = true } label: {
                        LabeledContent {
                            Text(statsRefreshedAt > 0 ? Date(timeIntervalSince1970: statsRefreshedAt).formatted(.relative(presentation: .named)) : "从未")
                        } label: {
                            Label { Text("更新 DLsite 统计数据") } icon: { SettingsIcon(systemImage: "chart.bar.fill", tint: .green) }
                        }
                    }
                    .tint(.primary)
                    .disabled(model.tasks.isBusy)
                }
                Section("数据") {
                    row(
                        "备份与恢复", systemImage: "externaldrive.fill", tint: .teal,
                        value: lastBackupAt > 0 ? Date(timeIntervalSince1970: lastBackupAt).formatted(.relative(presentation: .named)) : nil,
                        route: .backup
                    )
                    row("存储空间", systemImage: "internaldrive.fill", tint: .gray, value: clearable.map(Formatting.bytes), route: .storage)
                }
                Section("支持") {
                    row("诊断日志", systemImage: "stethoscope", tint: .indigo, value: nil, route: .diagnostics)
                    row("关于 Tonari", systemImage: "info", tint: .gray, value: "\(AboutView.version) (\(AboutView.build))", route: .about)
                }
            }
            .navigationTitle("设置")
            .appDestinations()
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .alert("更新统计数据", isPresented: $confirmingStats) {
                Button("取消", role: .cancel) {}
                Button("开始更新", action: refreshAllStats)
            } message: {
                Text("将逐个向 DLsite 请求全部作品的售出、评分、价格和排名，作品多时需要一些时间。确定开始吗？")
            }
            .onAppear {
                p115 = P115Client.shared.loginState
                Task { clearable = await StorageView.clearableBytes() }
            }
            .task {
                await database.observe({ db in
                    (
                        try SourceQueries.all(db).count, try SourceQueries.removedWorks(db).count,
                        try AppEvents.unreadCount(db), try LlmProviders.defaultProvider(db)?.name
                    )
                }) {
                    sourceCount = $0.0
                    removedCount = $0.1
                    unread = $0.2
                    translator = $0.3
                }
            }
        }
    }

    private func row(_ title: String, systemImage: String, tint: Color, value: String?, route: Route) -> some View {
        NavigationLink(value: route) {
            LabeledContent {
                if let value { Text(value) }
            } label: {
                Label { Text(title) } icon: { SettingsIcon(systemImage: systemImage, tint: tint) }
            }
        }
    }

    private func refreshAllStats() {
        let tasks = model.tasks
        let service = enrichment.service
        Task {
            await tasks.run("更新统计数据", detail: "准备中") {
                let failed = await service.refreshAllStats { done, total in
                    Task { @MainActor in tasks.report("正在更新 \(done)/\(total)…") }
                }
                statsRefreshedAt = Date.now.timeIntervalSince1970
                return failed == 0 ? "统计数据已更新" : "更新完成，\(failed) 个作品失败"
            }
        }
    }
}

/// The white symbol on a colored rounded square the iOS Settings app uses.
struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(tint.gradient, in: .rect(cornerRadius: 7))
    }
}

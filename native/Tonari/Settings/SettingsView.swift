import SwiftUI
import TonariCore

/// A seal header with the library at a glance, then plain gray symbols with
/// the current value on the right. Opens as a sheet from the home tab's gear;
/// 消息 sits under the header with the unread count the gear shows too.
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
    @State private var library = LibrarySummary(works: 0, durationMs: 0, monthListenedMs: 0)
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
                    NavigationLink(value: Route.about) {
                        HStack(spacing: 12) {
                            SealBadge()
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tonari").font(.headline)
                                Text("版本 \(AboutView.version) (\(AboutView.build))").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    HStack {
                        summary("作品", Formatting.count(library.works))
                        Divider()
                        summary("总时长", Formatting.hours(ms: library.durationMs))
                        Divider()
                        summary("本月收听", Formatting.hours(ms: library.monthListenedMs))
                    }
                    .padding(.vertical, 2)
                }
                Section {
                    NavigationLink(value: Route.messages) {
                        LabeledContent {
                            if unread > 0 {
                                Text("\(unread)")
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.seal, in: .capsule)
                            }
                        } label: {
                            Label { Text("消息") } icon: { SettingsIcon(systemImage: "bell") }
                        }
                    }
                }
                Section("通用") {
                    row("外观", systemImage: "circle.lefthalf.filled", value: appearance.label, route: .appearance)
                    row("播放", systemImage: "play", value: "步长 \(player.prefs.seekStep) 秒", route: .playbackSettings)
                    row("隐私", systemImage: "hand.raised", value: blur ? "后台模糊" : nil, route: .privacy)
                }
                Section("账户与服务") {
                    row(P115Client.sourceName, systemImage: "icloud", value: p115.label, route: .p115Settings)
                    row("DLsite", systemImage: "cart", value: model.wishlist.isSignedIn ? "已登录" : "未登录", route: .dlsiteAccount)
                    row("翻译", systemImage: "character.bubble", value: translator ?? "未设置", route: .translation)
                }
                Section("媒体库") {
                    row("媒体来源", systemImage: "folder", value: "\(sourceCount)", route: .mediaSources)
                    row("已移除作品", systemImage: "trash", value: "\(removedCount)", route: .removedWorks)
                    Button { confirmingStats = true } label: {
                        LabeledContent {
                            Text(statsRefreshedAt > 0 ? Date(timeIntervalSince1970: statsRefreshedAt).formatted(.relative(presentation: .named)) : "从未")
                        } label: {
                            Label { Text("更新 DLsite 统计数据") } icon: { SettingsIcon(systemImage: "chart.bar") }
                        }
                    }
                    .tint(.primary)
                    .disabled(model.tasks.isBusy)
                }
                Section("数据") {
                    row(
                        "备份与恢复", systemImage: "externaldrive",
                        value: lastBackupAt > 0 ? Date(timeIntervalSince1970: lastBackupAt).formatted(.relative(presentation: .named)) : nil,
                        route: .backup
                    )
                    row("存储空间", systemImage: "internaldrive", value: clearable.map(Formatting.bytes), route: .storage)
                }
                Section("支持") {
                    row("诊断日志", systemImage: "stethoscope", value: nil, route: .diagnostics)
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("设置")
            .toolbar {
                // Not the confirmation placement: its accent-tinted button would outshine the seal.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成", systemImage: "checkmark") { model.showingSettings = false }
                }
            }
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
                        try AppEvents.unreadCount(db), try LlmProviders.defaultProvider(db)?.name,
                        try LibrarySummary.fetch(db)
                    )
                }) {
                    sourceCount = $0.0
                    removedCount = $0.1
                    unread = $0.2
                    translator = $0.3
                    library = $0.4
                }
            }
        }
    }

    private func row(_ title: String, systemImage: String, value: String?, route: Route) -> some View {
        NavigationLink(value: route) {
            LabeledContent {
                if let value { Text(value) }
            } label: {
                Label { Text(title) } icon: { SettingsIcon(systemImage: systemImage) }
            }
        }
    }

    private func summary(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

/// A plain gray symbol: the seal header carries the page's only color.
struct SettingsIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28)
    }
}

/// The app icon's vermilion seal, drawn from the tab bar glyph.
private struct SealBadge: View {
    var body: some View {
        Image("TabSeal")
            .resizable()
            .padding(6)
            .foregroundStyle(Color.sealInk)
            .frame(width: 52, height: 52)
            .background(.seal, in: .rect(cornerRadius: 12))
    }
}

private nonisolated struct LibrarySummary: Equatable, Sendable {
    let works: Int
    let durationMs: Int
    let monthListenedMs: Int

    static func fetch(_ db: Database) throws -> LibrarySummary {
        let row = try Row.fetchOne(db, sql: """
            SELECT COUNT(DISTINCT w.product_id) AS works, COALESCE(SUM(t.duration_ms), 0) AS duration
            FROM works w LEFT JOIN tracks t ON t.work_id = w.product_id
            WHERE w.is_removed = 0
            """)!
        return LibrarySummary(works: row["works"], durationMs: row["duration"], monthListenedMs: try ListenStats.fetch(db).monthMs)
    }
}

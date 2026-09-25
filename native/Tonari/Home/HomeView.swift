import SwiftUI
import TonariCore

/// The first tab: what to listen to now. Pick up where listening left off
/// (with a sleep timer on the way), let chance or a tag choose, or revisit
/// what's recent, forgotten or new. Settings open from the gear.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database
    @State private var content = Content()
    @State private var unread = 0
    @State private var pickingTags = false

    private static let rowLimit = 10

    nonisolated private struct Content: Sendable {
        var resume: HomeQueries.ContinueListening?
        var recent: [RecentItem] = []
        var watching = ContinueWatching()
        var forgotten: [Work] = []
        var added: [Work] = []
        var voiceActors: [String] = []
        var trackCounts: [String: Int] = [:]
        var hasWorks = false
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let resume = content.resume { ResumeCard(resume: resume).padding(.horizontal, 16) }
                    sleepSection
                    pickButtons
                    if !content.recent.isEmpty {
                        section("最近播放", route: .playHistory) {
                            row(content.recent) { RecentTile(item: $0) }
                        }
                    }
                    if !content.watching.progress.isEmpty {
                        section("继续观看", route: nil) { ContinueWatchingRow(watching: content.watching) }
                    }
                    if !content.forgotten.isEmpty {
                        section("好久没听", route: .forgotten) {
                            row(content.forgotten) { work in
                                WorkTile(work: work, caption: work.lastPlayedAt!.formatted(.relative(presentation: .named)), trackCount: content.trackCounts[work.productId])
                            }
                        }
                    }
                    if !content.added.isEmpty {
                        section("最近添加", action: showAllAdded) {
                            row(content.added) { work in
                                WorkTile(work: work, caption: work.creditLine(), trackCount: content.trackCounts[work.productId])
                            }
                        }
                    }
                    if !content.voiceActors.isEmpty { voiceActorSection }
                }
                .padding(.vertical, 8)
            }
            .overlay {
                if !content.hasWorks {
                    ContentUnavailableView {
                        Label("还没有作品", systemImage: "music.note")
                    } description: {
                        Text("到「资料库」点 ＋ 导入包含 RJ 编号的文件夹")
                    }
                }
            }
            .navigationTitle("Tonari")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("设置", systemImage: "gearshape") { model.showingSettings = true }
                        .badge(unread)
                }
            }
            .sheet(isPresented: $pickingTags) { TagPickerSheet() }
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .appDestinations()
        }
        .task {
            await database.observe(AppEvents.unreadCount) { unread = $0 }
        }
        .task {
            await database.observe({ db in
                Content(
                    resume: try HomeQueries.continueListening(db),
                    recent: try RecentItem.fetch(limit: Self.rowLimit, db),
                    watching: try ContinueWatching.fetch(db),
                    forgotten: try HomeQueries.forgotten(limit: Self.rowLimit, db),
                    added: try HomeQueries.recentlyAdded(limit: Self.rowLimit, db),
                    voiceActors: try HomeQueries.topVoiceActors(limit: 8, db),
                    trackCounts: try WorkQueries.trackCounts(db),
                    hasWorks: try Work.filter(Column("is_removed") == false).fetchCount(db) > 0
                )
            }) { content = $0 }
        }
    }

    // MARK: - Sections

    private func section(_ title: String, route: Route?, @ViewBuilder content: () -> some View) -> some View {
        section(title, action: route.map { route in { model.push(route) } }, content: content)
    }

    private func section(_ title: String, action: (() -> Void)?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(title).font(.title3.bold())
                        Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            } else {
                Text(title).font(.title3.bold()).padding(.horizontal, 16)
            }
            content()
        }
    }

    private func row<Item: Identifiable>(_ items: [Item], @ViewBuilder tile: @escaping (Item) -> some View) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(items) { tile($0) }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("睡眠定时").font(.title3.bold())
            HStack(spacing: 8) {
                ForEach([15, 30, 60], id: \.self) { minutes in
                    sleepChip(minutes == 60 ? "1 小时" : "\(minutes) 分钟", active: player.sleep.countdown == minutes * 60) {
                        player.sleep.start(seconds: minutes * 60)
                    }
                }
                sleepChip("播完本曲", active: player.sleep.remainingTracks == 1 || player.sleep.waitingTrackEnd) {
                    player.sleep.stopAfter(tracks: 1)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    /// A second tap on the running preset cancels it. With nothing playing,
    /// a preset also starts playback: the paused item, or the resume card's
    /// work.
    private func sleepChip(_ title: String, active: Bool, start: @escaping () -> Void) -> some View {
        Button {
            if active { return player.sleep.cancel() }
            if !player.isPlaying {
                if player.hasCurrent {
                    player.play()
                } else if let resume = content.resume {
                    player.playWork(resume.work.productId, database: database)
                }
            }
            start()
        } label: {
            Label(title, systemImage: "moon.fill")
                .labelStyle(ChipLabelStyle(showsIcon: active))
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(active ? Color(.systemBackground) : .primary)
                .background(active ? Color.primary : Color(.tertiarySystemFill), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(!player.hasCurrent && content.resume == nil)
    }

    private var pickButtons: some View {
        HStack(spacing: 12) {
            pickButton("随机一部", systemImage: "shuffle") { model.openRandomWork(database: database) }
            pickButton("按标签挑", systemImage: "tag") { pickingTags = true }
        }
        .padding(.horizontal, 16)
        .disabled(!content.hasWorks)
    }

    private func pickButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var voiceActorSection: some View {
        section("常听声优", route: nil) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(content.voiceActors, id: \.self) { name in
                        NavigationLink(value: Route.chip(WorkChip(.voiceActor, name))) {
                            VStack(spacing: 6) {
                                Monogram(name: name).frame(width: 64, height: 64)
                                Text(name).font(.caption).lineLimit(1)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }

    /// 最近添加's arrow opens the whole wall sorted by when works came in.
    private func showAllAdded() {
        model.sort = WorkSort(field: .addedAt, descending: true)
        model.push(.works)
    }
}

/// The last audio work played, as a large cover: the cover opens the work,
/// the button resumes it (or opens the player when it is the one playing).
private struct ResumeCard: View {
    let resume: HomeQueries.ContinueListening
    @Environment(AppModel.self) private var model
    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database

    var body: some View {
        let playing = player.work?.productId == resume.work.productId && player.isPlaying
        NavigationLink(value: Route.work(resume.work.productId)) {
            LocalImage(path: resume.work.mainImageLocalPath)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("继续收听").font(.caption).opacity(0.8)
                        Text(resume.work.displayTitle).font(.headline).lineLimit(2)
                        if let detail { Text(detail).font(.caption).opacity(0.85) }
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 14)
                    .padding(.trailing, 110)
                    .padding(.bottom, 14)
                }
                .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            Button {
                if playing { model.showingPlayer = true } else { player.playWork(resume.work.productId, database: database) }
            } label: {
                Label(playing ? "播放中" : "播放", systemImage: playing ? "waveform" : "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .workContextMenu(resume.work, trackCount: nil)
    }

    private var detail: String? {
        let parts = [
            resume.trackNumber.map { "第 \($0) 首" },
            resume.remainingMs.map { "剩 \(max(1, $0 / 60_000)) 分钟" },
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// A cover with two lines under it, for the home rows.
private struct WorkTile: View {
    let work: Work
    let caption: String
    let trackCount: Int?

    var body: some View {
        NavigationLink(value: Route.work(work.productId)) {
            VStack(alignment: .leading, spacing: 2) {
                LocalImage(path: work.mainImageLocalPath)
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
                    .padding(.bottom, 4)
                Text(work.displayTitle).font(.subheadline).lineLimit(1)
                Text(caption).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(width: 150)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .workContextMenu(work, trackCount: trackCount)
    }
}

/// A voice actor has no picture: the first character on a color derived
/// from the name, the same every launch.
private struct Monogram: View {
    let name: String

    private static let palette: [Color] = [.pink, .orange, .teal, .indigo, .purple, .green, .blue, .brown]

    var body: some View {
        let color = Self.palette[name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Self.palette.count]
        Circle()
            .fill(color.gradient)
            .overlay {
                Text(String(name.prefix(1))).font(.title2.weight(.semibold)).foregroundStyle(.white)
            }
    }
}

/// Shows the icon only while the chip is on, like the running timer's moon.
private struct ChipLabelStyle: LabelStyle {
    let showsIcon: Bool

    func makeBody(configuration: LabelStyleConfiguration) -> some View {
        HStack(spacing: 4) {
            if showsIcon { configuration.icon.font(.caption) }
            configuration.title
        }
    }
}

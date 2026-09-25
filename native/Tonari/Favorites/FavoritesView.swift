import SwiftUI
import TonariCore

/// The favorites tab after Apple Music's library: category rows, recently
/// played covers, then groups as a grid of collages.
struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var recent: [RecentItem] = []
    @State private var favoriteCount = 0
    @State private var weekMs = 0
    @State private var summaries: [CollectionQueries.Summary] = []
    @State private var naming: NamingTarget?
    @State private var name = ""
    @State private var deleting: LibraryCollection?
    @AppStorage(CollectionSort.preferenceKey) private var sort = CollectionSort.createdAt

    private enum NamingTarget: Identifiable {
        case create
        case rename(LibraryCollection)
        var id: String {
            if case .rename(let c) = self { c.id } else { "create" }
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.favoritesPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    categories
                    if !recent.isEmpty { recentSection }
                    groupsSection
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("收藏")
            .toolbar {
                Button("新建分组", systemImage: "plus", action: startCreating)
            }
            .alert(namingTitle, isPresented: Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })) {
                TextField("分组名称", text: $name)
                Button("取消", role: .cancel) {}
                Button("确定", action: commitName)
            }
            .alert(
                "删除「\(deleting?.name ?? "")」？",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
            ) {
                Button("取消", role: .cancel) {}
                Button("删除分组", role: .destructive) {
                    try! database.deleteCollection(deleting!.id)
                }
            } message: {
                Text("只删除分组本身，里面的作品不受影响。")
            }
            .appDestinations()
        }
        .task {
            await database.observe({ db in
                (
                    try RecentItem.fetch(limit: 12, db),
                    try Work.filter(Column("is_favorite") == true && Column("is_removed") == false).fetchCount(db)
                        + VideoItem.filter(Column("is_favorite") == true).fetchCount(db),
                    try CollectionQueries.summaries(db),
                    try ListenStats.fetch(db).weekMs
                )
            }) {
                recent = $0.0
                favoriteCount = $0.1
                summaries = $0.2
                weekMs = $0.3
            }
        }
    }

    // MARK: - Sections

    private var categories: some View {
        VStack(spacing: 0) {
            categoryRow("全部收藏", systemImage: "heart", detail: "\(favoriteCount)", route: .favoriteItems)
            Divider().padding(.leading, 52)
            categoryRow("播放历史", systemImage: "clock.arrow.circlepath", detail: nil, route: .playHistory)
            Divider().padding(.leading, 52)
            categoryRow("收听统计", systemImage: "chart.bar.xaxis", detail: "本周 \(Formatting.listening(ms: weekMs))", route: .listenStats)
        }
        .padding(.horizontal, 16)
    }

    private func categoryRow(_ title: String, systemImage: String, detail: String?, route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 26)
                Text(title).font(.title3)
                Spacer()
                if let detail { Text(detail).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近播放").font(.title3.bold())
                Spacer()
                NavigationLink("全部", value: Route.playHistory)
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(recent) { RecentTile(item: $0) }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("分组").font(.title3.bold())
                Spacer()
                Menu("排序") {
                    Picker("排序", selection: $sort) {
                        ForEach(CollectionSort.allCases, id: \.self) { Text($0.label) }
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                ForEach(sort.sorted(summaries)) { summary in
                    NavigationLink(value: Route.collection(summary.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            CollageCover(covers: summary.covers)
                                .padding(.bottom, 4)
                            Text(summary.collection.name).font(.subheadline).lineLimit(1)
                            Text(countText(summary)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("重命名", systemImage: "pencil") {
                            name = summary.collection.name
                            naming = .rename(summary.collection)
                        }
                        Button("删除分组", systemImage: "trash", role: .destructive) {
                            deleting = summary.collection
                        }
                    }
                }
                Button(action: startCreating) {
                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .overlay { Image(systemName: "plus").font(.title2).foregroundStyle(.secondary) }
                            .padding(.bottom, 4)
                        Text("新建分组").font(.subheadline).foregroundStyle(.secondary)
                        Text(" ").font(.subheadline)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Naming

    private func startCreating() {
        name = ""
        naming = .create
    }

    private var namingTitle: String {
        if case .rename = naming { "重命名分组" } else { "新建分组" }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let naming else { return }
        switch naming {
        case .create: try! database.createCollection(named: trimmed)
        case .rename(let collection): try! database.renameCollection(collection.id, to: trimmed)
        }
    }

    private func countText(_ summary: CollectionQueries.Summary) -> String {
        let parts = [summary.workCount > 0 ? "\(summary.workCount) 部" : nil, summary.videoCount > 0 ? "\(summary.videoCount) 视频" : nil]
            .compactMap(\.self)
        return parts.isEmpty ? "空" : parts.joined(separator: " · ")
    }
}

/// A group's cover: four covers in a grid once it has four, else the one
/// added last, else a placeholder.
struct CollageCover: View {
    let covers: [String]
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if covers.count >= 4 {
                Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    GridRow {
                        LocalImage(path: covers[0])
                        LocalImage(path: covers[1])
                    }
                    GridRow {
                        LocalImage(path: covers[2])
                        LocalImage(path: covers[3])
                    }
                }
            } else if let cover = covers.first {
                LocalImage(path: cover)
            } else {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "rectangle.stack").font(.title).foregroundStyle(.tertiary)
                }
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

/// A play-history entry with the cover and target it opens.
nonisolated struct RecentItem: Identifiable, Sendable {
    let entry: PlayHistoryEntry
    let coverPath: String?
    /// Set when the entry is a work still in the library.
    let workId: String?
    /// 1-based position of the work's last track within its folder.
    let trackNumber: Int?

    var id: String { entry.id }

    static func fetch(limit: Int, _ db: Database) throws -> [RecentItem] {
        let entries = try CollectionQueries.recentlyPlayed(limit: limit, db)
        let works = try Work.filter(keys: entries.compactMap(\.workId)).filter(Column("is_removed") == false).fetchAll(db)
        let worksById = Dictionary(uniqueKeysWithValues: works.map { ($0.productId, $0) })
        let videos = try VideoItem.filter(keys: entries.map(\.id)).fetchAll(db)
        let coversById = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, $0.coverPath) })
        return try entries.map { entry in
            if entry.kind == "work", let work = entry.workId.flatMap({ worksById[$0] }) {
                RecentItem(entry: entry, coverPath: work.mainImageLocalPath, workId: work.productId, trackNumber: try trackNumber(of: work, db))
            } else {
                RecentItem(entry: entry, coverPath: coversById[entry.id] ?? nil, workId: nil, trackNumber: nil)
            }
        }
    }

    private static func trackNumber(of work: Work, _ db: Database) throws -> Int? {
        guard let track = try work.lastPlayedTrackId.flatMap({ try Track.fetchOne(db, key: $0) }) else { return nil }
        let folder = try WorkQueries.tracks(of: work.productId).fetchAll(db).filter { $0.folderPath == track.folderPath }
        return WorkTree.playbackOrder(WorkTree.build(tracks: folder, files: [])).firstIndex { $0.id == track.id }.map { $0 + 1 }
    }

    var caption: String {
        if let trackNumber { return "听到第 \(trackNumber) 首" }
        if let duration = entry.durationMs, duration > 0 {
            return "看到 \(min(100, entry.positionMs * 100 / duration))%"
        }
        return entry.playedAt.formatted(.relative(presentation: .named))
    }
}

private struct RecentTile: View {
    let item: RecentItem
    @Environment(PlaybackController.self) private var player

    var body: some View {
        let tile = VStack(alignment: .leading, spacing: 2) {
            LocalImage(path: item.coverPath)
                .aspectRatio(4 / 3, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.bottom, 4)
            Text(item.entry.title).font(.subheadline).lineLimit(1)
            Text(item.caption).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(width: 150)
        .contentShape(.rect)
        if let workId = item.workId {
            NavigationLink(value: Route.work(workId)) { tile }.buttonStyle(.plain)
        } else if let file = item.entry.remoteFile {
            Button {
                player.play(files: [file], at: 0, sourceName: item.entry.sourceName ?? P115Client.sourceName)
            } label: {
                tile
            }
            .buttonStyle(.plain)
        } else {
            tile
        }
    }
}

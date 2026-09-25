import SwiftUI
import TonariCore

/// The library tab after Apple Music's library: category rows, the groups,
/// then what was added last. The ＋ gathers every way to add things.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @State private var counts = Counts()
    @State private var summaries: [CollectionQueries.Summary] = []
    @State private var recent: [Work] = []
    @State private var trackCounts: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []
    @State private var naming: NamingTarget?
    @State private var name = ""
    @State private var deleting: LibraryCollection?
    /// One importer serves both kinds: SwiftUI honors only one per view.
    @State private var importing = false
    @State private var importingVideos = false
    @AppStorage(CollectionSort.preferenceKey) private var sort = CollectionSort.createdAt

    private struct Counts: Sendable {
        var works = 0
        var videos = 0
        var favorites = 0
        var weekMs = 0
    }

    private enum NamingTarget: Identifiable {
        case create
        case rename(LibraryCollection)
        var id: String {
            if case .rename(let c) = self { c.id } else { "create" }
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.libraryPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    categories
                    groupsSection
                    if !recent.isEmpty { recentSection }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("资料库")
            .toolbar {
                Menu("添加", systemImage: "plus") {
                    Button("导入本地文件夹", systemImage: "folder.badge.plus") {
                        importingVideos = false
                        importing = true
                    }
                    Button("从 115 导入", systemImage: "icloud.and.arrow.down") { model.openP115() }
                    Button("从「文件」导入视频", systemImage: "film") {
                        importingVideos = true
                        importing = true
                    }
                }
                .disabled(model.tasks.isBusy)
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: importingVideos ? LocalVideoImport.contentTypes : [.folder],
                allowsMultipleSelection: importingVideos
            ) { result in
                guard case .success(let urls) = result, !urls.isEmpty else { return }
                if importingVideos {
                    Task { await model.importVideos(urls, database: database) }
                } else {
                    Task { await model.importLocalFolder(urls[0], database: database, enrichment: enrichment) }
                }
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
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .appDestinations()
        }
        .task {
            await database.observe({ db in
                (
                    Counts(
                        works: try Work.filter(Column("is_removed") == false).fetchCount(db),
                        videos: try VideoItem.fetchCount(db),
                        favorites: try Work.filter(Column("is_favorite") == true && Column("is_removed") == false).fetchCount(db)
                            + VideoItem.filter(Column("is_favorite") == true).fetchCount(db),
                        weekMs: try ListenStats.fetch(db).weekMs
                    ),
                    try CollectionQueries.summaries(db),
                    try HomeQueries.recentlyAdded(limit: 8, db),
                    try WorkQueries.trackCounts(db),
                    try WorkQueries.remoteFolderIds(db)
                )
            }) {
                counts = $0.0
                summaries = $0.1
                recent = $0.2
                trackCounts = $0.3
                remoteIds = $0.4
            }
        }
    }

    // MARK: - Sections

    private var categories: some View {
        VStack(spacing: 0) {
            categoryRow("作品", systemImage: "headphones", detail: "\(counts.works)", route: .works)
            categoryRow("视频", systemImage: "film", detail: "\(counts.videos)", route: .videos)
            categoryRow("收藏", systemImage: "heart", detail: "\(counts.favorites)", route: .favoriteItems)
            categoryRow("声优", systemImage: "music.mic", detail: nil, route: .categories(.voiceActor))
            categoryRow("社团", systemImage: "person.2", detail: nil, route: .categories(.circle))
            categoryRow("标签", systemImage: "tag", detail: nil, route: .categories(.genre))
            categoryRow("播放历史", systemImage: "clock.arrow.circlepath", detail: nil, route: .playHistory)
            categoryRow("收听统计", systemImage: "chart.bar.xaxis", detail: "本周 \(Formatting.listening(ms: counts.weekMs))", route: .listenStats, last: true)
        }
        .padding(.horizontal, 16)
    }

    private func categoryRow(_ title: String, systemImage: String, detail: String?, route: Route, last: Bool = false) -> some View {
        VStack(spacing: 0) {
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
                .padding(.vertical, 11)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if !last { Divider().padding(.leading, 40) }
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

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近添加").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                ForEach(recent) { work in
                    NavigationLink(value: Route.work(work.productId)) {
                        WorkGridCell(work: work, isRemote: work.importedFolderId.map(remoteIds.contains) ?? false)
                    }
                    .buttonStyle(.plain)
                    .workContextMenu(work, trackCount: trackCounts[work.productId] ?? 0)
                }
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


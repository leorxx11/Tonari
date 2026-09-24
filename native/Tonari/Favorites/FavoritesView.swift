import SwiftUI
import TonariCore

struct FavoritesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var recent: [RecentItem] = []
    @State private var favoriteCount = 0
    @State private var summaries: [CollectionQueries.Summary] = []
    @State private var naming: NamingTarget?
    @State private var name = ""
    @State private var deleting: LibraryCollection?

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
            List {
                if !recent.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(recent) { item in
                                    RecentTile(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } header: {
                        Text("最近播放")
                    }
                }
                Section {
                    NavigationLink(value: Route.favoriteItems) {
                        LabeledContent {
                            Text("\(favoriteCount)")
                        } label: {
                            Label("全部收藏", systemImage: "heart.fill").tint(.pink)
                        }
                    }
                }
                Section("分组") {
                    ForEach(summaries) { summary in
                        NavigationLink(value: Route.collection(summary.id)) {
                            LabeledContent {
                                Text(countText(summary))
                            } label: {
                                Label(summary.collection.name, systemImage: "folder")
                            }
                        }
                        .contextMenu {
                            Button("重命名", systemImage: "pencil") {
                                name = summary.collection.name
                                naming = .rename(summary.collection)
                            }
                            Button("删除分组", systemImage: "trash", role: .destructive) {
                                deleting = summary.collection
                            }
                        }
                        .swipeActions {
                            Button("删除", systemImage: "trash", role: .destructive) { deleting = summary.collection }
                        }
                    }
                    if summaries.isEmpty {
                        Text("还没有分组，点右上角新建，或在媒体库长按作品加入分组")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("收藏")
            .toolbar {
                Button("新建分组", systemImage: "plus") {
                    name = ""
                    naming = .create
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
            .appDestinations()
        }
        .task {
            await database.observe({ db in
                (
                    try RecentItem.fetch(limit: 12, db),
                    try Work.filter(Column("is_favorite") == true && Column("is_removed") == false).fetchCount(db)
                        + VideoItem.filter(Column("is_favorite") == true).fetchCount(db),
                    try CollectionQueries.summaries(db)
                )
            }) {
                recent = $0.0
                favoriteCount = $0.1
                summaries = $0.2
            }
        }
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
        [summary.workCount > 0 ? "\(summary.workCount) 作品" : nil, summary.videoCount > 0 ? "\(summary.videoCount) 视频" : nil]
            .compactMap(\.self).joined(separator: " · ")
    }
}

/// A play-history entry with the cover and target it opens.
nonisolated struct RecentItem: Identifiable, Sendable {
    let entry: PlayHistoryEntry
    let coverPath: String?
    /// Set when the entry is a work still in the library.
    let workId: String?

    var id: String { entry.id }

    static func fetch(limit: Int, _ db: Database) throws -> [RecentItem] {
        let entries = try CollectionQueries.recentlyPlayed(limit: limit, db)
        let works = try Work.filter(keys: entries.compactMap(\.workId)).filter(Column("is_removed") == false).fetchAll(db)
        let worksById = Dictionary(uniqueKeysWithValues: works.map { ($0.productId, $0) })
        let videos = try VideoItem.filter(keys: entries.map(\.id)).fetchAll(db)
        let coversById = Dictionary(uniqueKeysWithValues: videos.map { ($0.id, $0.coverPath) })
        return entries.map { entry in
            if entry.kind == "work", let work = entry.workId.flatMap({ worksById[$0] }) {
                RecentItem(entry: entry, coverPath: work.mainImageLocalPath, workId: work.productId)
            } else {
                RecentItem(entry: entry, coverPath: coversById[entry.id] ?? nil, workId: nil)
            }
        }
    }

    var caption: String {
        if let duration = entry.durationMs, duration > 0 {
            return "看到 \(min(100, entry.positionMs * 100 / duration))%"
        }
        return entry.playedAt.formatted(.relative(presentation: .named))
    }
}

private struct RecentTile: View {
    let item: RecentItem

    var body: some View {
        let tile = VStack(alignment: .leading, spacing: 4) {
            LocalImage(path: item.coverPath)
                .frame(width: 120, height: item.entry.kind == "video" ? 68 : 90)
                .clipShape(.rect(cornerRadius: 8))
            Text(item.entry.title).font(.caption).lineLimit(2, reservesSpace: true)
            Text(item.caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 120)
        if let workId = item.workId {
            NavigationLink(value: Route.work(workId)) { tile }.buttonStyle(.plain)
        } else {
            tile
        }
    }
}

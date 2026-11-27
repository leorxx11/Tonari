import SwiftUI
import TonariCore

/// Every voice actor, circle or tag in the library with its work count;
/// the same list the search tab browses, as a page of its own.
struct CategoryBrowseView: View {
    let kind: WorkChip.Kind

    @Environment(\.appDatabase) private var database
    @State private var entries: [LibraryStats.Entry] = []
    @State private var byName = false
    @State private var filter = ""

    var body: some View {
        List(shown, id: \.name) { entry in
            NavigationLink(value: Route.chip(WorkChip(kind, entry.name))) {
                HStack(spacing: 14) {
                    Image(systemName: SearchView.symbol(kind))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemFill), in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name).lineLimit(1)
                        Text("\(entry.count) 部作品").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $filter, prompt: "筛选\(kind.label)")
        .navigationTitle(kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(byName ? "按作品数" : "按名称") { byName.toggle() }
        }
        .task {
            await database.observe({ db in
                LibraryStats(try Work.filter(Column("is_removed") == false).fetchAll(db)).entries(for: kind)
            }) { entries = $0 }
        }
    }

    private var shown: [LibraryStats.Entry] {
        let matching = filter.isEmpty ? entries : entries.filter { $0.name.localizedStandardContains(filter) }
        return byName ? matching.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : matching
    }
}

/// A home shelf in full: 好久没听 or 还没听过.
struct ShelfWorksView: View {
    let shelf: HomeShelf

    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var trackCounts: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []

    var body: some View {
        List(works) { work in
            NavigationLink(value: Route.work(work.productId)) {
                WorkListRow(work: work, isRemote: work.importedFolderId.map(remoteIds.contains) ?? false, trackCount: trackCounts[work.productId] ?? 0)
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .workContextMenu(work, trackCount: trackCounts[work.productId] ?? 0)
        }
        .listStyle(.plain)
        .overlay {
            if works.isEmpty {
                switch shelf {
                case .forgotten:
                    ContentUnavailableView("没有好久没听的作品", systemImage: "clock", description: Text("一个月以上没播放过的作品会出现在这里"))
                case .unplayed:
                    ContentUnavailableView("作品都听过了", systemImage: "checkmark.circle", description: Text("导入后还没播放过的作品会出现在这里"))
                }
            }
        }
        .navigationTitle(shelf.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await database.observe({ [shelf] db in
                (try shelf.works(db), try WorkQueries.trackCounts(db), try WorkQueries.remoteFolderIds(db))
            }) {
                works = $0.0
                trackCounts = $0.1
                remoteIds = $0.2
            }
        }
    }
}

nonisolated enum HomeShelf: Hashable, Sendable {
    /// Played before, not for a month; longest ago first.
    case forgotten
    /// Never played since import; longest in the library first.
    case unplayed

    var title: String {
        switch self {
        case .forgotten: "好久没听"
        case .unplayed: "还没听过"
        }
    }

    func works(limit: Int? = nil, _ db: Database) throws -> [Work] {
        switch self {
        case .forgotten: try HomeQueries.forgotten(limit: limit, db)
        case .unplayed: try HomeQueries.unplayed(limit: limit, db)
        }
    }
}

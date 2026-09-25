import SwiftUI
import TonariCore

/// A DLsite list as its own page, with DLsite's sort menu when the list
/// can be reordered.
struct CatalogListView: View {
    @State private var query: CatalogQuery

    init(query: CatalogQuery) {
        _query = State(initialValue: query)
    }

    var body: some View {
        CatalogList(query: query)
            .navigationTitle(query.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let sort = query.sort { CatalogSortMenu(sort: sort) { query = query.sorted($0) } }
            }
    }
}

/// Searches DLsite (with the account's usual conditions) from the discover
/// tab, apart from the library search.
struct CatalogSearchView: View {
    @State private var text = ""
    @State private var query: CatalogQuery?
    @State private var searching = true

    var body: some View {
        Group {
            if let query {
                CatalogList(query: query)
            } else {
                ContentUnavailableView("搜索 DLsite", systemImage: "magnifyingglass", description: Text("在音声・ASMR 里按标题、社团、声优、标签搜索"))
            }
        }
        .searchable(text: $text, isPresented: $searching, prompt: "搜索 DLsite")
        .onSubmit(of: .search) {
            let keyword = text.trimmingCharacters(in: .whitespaces)
            if !keyword.isEmpty { query = .search(keyword, query?.sort ?? .popular) }
        }
        .navigationTitle("搜索 DLsite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let query, let sort = query.sort { CatalogSortMenu(sort: sort) { self.query = query.sorted($0) } }
        }
    }
}

struct CatalogSortMenu: View {
    let sort: CatalogSort
    let pick: (CatalogSort) -> Void

    var body: some View {
        Menu("排序", systemImage: "arrow.up.arrow.down") {
            Picker("排序", selection: Binding(get: { sort }, set: pick)) {
                ForEach(CatalogSort.allCases, id: \.self) { Text($0.label) }
            }
        }
    }
}

/// One DLsite list: rankings with their numbers, the rest loading more as
/// the end scrolls in.
private struct CatalogList: View {
    let query: CatalogQuery

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @AppStorage(DiscoverStore.floorKey) private var floor = DLsiteFloor.maniax
    @State private var owned: Set<String> = []

    var body: some View {
        let list = model.discover.list(query, floor: floor)
        List {
            ForEach(Array(list.items.enumerated()), id: \.element.id) { index, item in
                NavigationLink(value: Route.onlineWork(item.productId)) {
                    CatalogRow(item: item, rank: query.isPaged ? nil : index + 1, owned: owned.contains(item.productId))
                }
                .navigationLinkIndicatorVisibility(.hidden)
                .onAppear {
                    if index == list.items.count - 1 { Task { await model.discover.loadMore(query, floor: floor) } }
                }
            }
            if list.loading {
                ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .overlay {
            if let error = list.error, list.items.isEmpty {
                ContentUnavailableView {
                    Label("加载失败", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("重试") { Task { await model.discover.load(query, floor: floor, refresh: true) } }
                }
            } else if !list.loading, list.pages > 0, list.items.isEmpty {
                ContentUnavailableView("没有作品", systemImage: "tray")
            }
        }
        .refreshable { await model.discover.load(query, floor: floor, refresh: true) }
        .task(id: QueryKey(query: query, floor: floor)) { await model.discover.load(query, floor: floor) }
        .task { await database.observe(LibraryIds.fetch) { owned = $0 } }
    }
}

private struct QueryKey: Hashable {
    let query: CatalogQuery
    let floor: DLsiteFloor
}

/// Product ids in the library, to mark what's already owned.
enum LibraryIds {
    nonisolated static func fetch(_ db: Database) throws -> Set<String> {
        try Set(String.fetchAll(db, sql: "SELECT product_id FROM works WHERE is_removed = 0"))
    }
}

/// Rank, cover, two-line title, credits, price and sales.
struct CatalogRow: View {
    let item: CatalogItem
    let rank: Int?
    let owned: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(rank <= 3 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 28)
            }
            RemoteCover(url: item.coverURL).frame(width: 96)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2)
                Text(item.creditLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                PriceLine(item: item)
                if let sales = item.sales {
                    HStack(spacing: 6) {
                        Text("售出 \(Formatting.count(sales))")
                        if owned { OwnedLabel() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if owned {
                    OwnedLabel().font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// A cover with two lines and the price, for the discover tab's rows.
struct CatalogTile: View {
    let item: CatalogItem
    let owned: Bool

    var body: some View {
        NavigationLink(value: Route.onlineWork(item.productId)) {
            VStack(alignment: .leading, spacing: 2) {
                RemoteCover(url: item.coverURL)
                    .overlay(alignment: .topLeading) {
                        if owned {
                            Label("已有", systemImage: "checkmark")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.55), in: .rect(cornerRadius: 5))
                                .padding(6)
                        }
                    }
                    .padding(.bottom, 4)
                Text(item.title).font(.subheadline).lineLimit(1)
                Text(item.creditLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                PriceLine(item: item)
            }
            .frame(width: 150)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct PriceLine: View {
    let item: CatalogItem

    var body: some View {
        if let price = item.price {
            HStack(spacing: 5) {
                Text("\(Formatting.count(price)) 円").foregroundStyle(.tint).fontWeight(.semibold)
                if let discount = item.discountRate, let official = item.officialPrice {
                    Text("\(Formatting.count(official)) 円").strikethrough().foregroundStyle(.secondary)
                    Text("\(discount)%OFF")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .background(.red, in: .rect(cornerRadius: 3))
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
    }
}

struct OwnedLabel: View {
    var body: some View {
        Label("已在资料库", systemImage: "checkmark").foregroundStyle(.green)
    }
}

/// A DLsite image loaded over the network (not kept on disk), in the 4:3
/// frame covers use.
struct RemoteCover: View {
    let url: URL
    var cornerRadius: CGFloat = 8

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    EmptyView()
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

extension CatalogItem {
    /// Circle · voice actors, whichever the list gave.
    var creditLine: String {
        ([circle].compactMap(\.self) + voiceActors.prefix(2)).joined(separator: " · ")
    }
}

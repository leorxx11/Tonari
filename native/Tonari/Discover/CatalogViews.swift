import SwiftUI
import TonariCore

/// A DLsite list as its own page, with DLsite's sort menu when the list
/// can be reordered.
struct CatalogListView: View {
    @State private var query: CatalogQuery
    /// Shared with the discover tab's ranking picker.
    @AppStorage("discover.rankingTerm") private var rankingTerm = CatalogQuery.Term.day

    init(query: CatalogQuery) {
        _query = State(initialValue: query)
    }

    var body: some View {
        CatalogList(query: query)
            .navigationTitle(query.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let sort = query.sort { CatalogSortMenu(sort: sort) { query = query.sorted($0) } }
                if case .ranking(let term) = query {
                    Menu {
                        Picker("榜单", selection: Binding(get: { term }, set: { new in
                            query = .ranking(new)
                            rankingTerm = new
                        })) {
                            ForEach(CatalogQuery.Term.allCases, id: \.self) { Text($0.label) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(term.label)
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        }
                    }
                }
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
            if list.items.isEmpty && list.error == nil && (list.loading || list.pages == 0) {
                ForEach(0..<8, id: \.self) { index in
                    CatalogRowPlaceholder(rank: query.isPaged ? nil : index + 1)
                }
            } else if list.loading {
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
                    Button("重试") { Task { await model.discover.refresh(query, floor: floor) } }
                }
            } else if !list.loading, list.pages > 0, list.items.isEmpty {
                ContentUnavailableView("没有作品", systemImage: "tray")
            }
        }
        .refreshable { await model.discover.refresh(query, floor: floor) }
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
            // Every row the same height: two title lines reserved, the
            // sales line always there.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2, reservesSpace: true)
                Text(item.creditLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                PriceLine(item: item)
                HStack(spacing: 6) {
                    Text(item.sales.map { "售出 \(Formatting.count($0))" } ?? " ")
                    if owned { OwnedLabel() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

/// Price, and when discounted the list price struck through with the
/// rate; a blank line when DLsite gave none, to keep rows even.
struct PriceLine: View {
    let item: CatalogItem

    var body: some View {
        HStack(spacing: 5) {
            if let price = item.price {
                Text("\(Formatting.count(price)) 円").foregroundStyle(.tint).fontWeight(.semibold)
                if let discount = item.discountRate, let official = item.officialPrice {
                    Text("\(Formatting.count(official)) 円").strikethrough().foregroundStyle(.secondary)
                    Text("\(discount)%OFF")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .background(.red, in: .rect(cornerRadius: 3))
                }
            } else {
                Text(" ")
            }
        }
        .font(.caption)
        .lineLimit(1)
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
                RemoteImage(url: url) { image in
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

/// Stands where a row will be while its list loads, the same size, so
/// nothing moves when the works arrive.
struct CatalogRowPlaceholder: View {
    let rank: Int?

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)").font(.headline.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 28)
            }
            PlaceholderCover().frame(width: 96)
            VStack(alignment: .leading, spacing: 3) {
                Text("作品标题作品标题作品标题作品标题作品标题作品标题").font(.subheadline.weight(.medium)).lineLimit(2, reservesSpace: true)
                Text("社团 · 声优").font(.caption)
                Text("0,000 円").font(.caption)
                Text("售出 0,000").font(.caption)
            }
            .redacted(reason: .placeholder)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

struct CatalogTilePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            PlaceholderCover().padding(.bottom, 4)
            Group {
                Text("作品标题作品标题").font(.subheadline)
                Text("社团 · 声优").font(.caption)
                Text("0,000 円").font(.caption)
            }
            .lineLimit(1)
            .redacted(reason: .placeholder)
        }
        .frame(width: 150)
    }
}

private struct PlaceholderCover: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.secondarySystemBackground))
            .aspectRatio(4 / 3, contentMode: .fit)
    }
}

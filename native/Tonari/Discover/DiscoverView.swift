import SwiftUI
import TonariCore

/// What's new on DLsite: the top five of a ranking, new releases and what's
/// on sale, voice works on the chosen floor. Works already in the library
/// are marked.
struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @AppStorage(DiscoverStore.floorKey) private var floor = DLsiteFloor.maniax
    @AppStorage("discover.rankingTerm") private var term = CatalogQuery.Term.day
    @State private var owned: Set<String> = []

    private static let rankingPreview = 5

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.discoverPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    rankingSection
                    rowSection(.all(.popular), title: "音声・ASMR 人气作品")
                    rowSection(.newReleases, title: "新作")
                    rowSection(.onSale, title: "特价中")
                }
                .padding(.vertical, 8)
            }
            .refreshable { await load(refresh: true) }
            .navigationTitle("发现")
            .toolbar {
                NavigationLink(value: Route.catalogSearch) { Label("搜索 DLsite", systemImage: "magnifyingglass") }
                NavigationLink(value: Route.wishlist) { Label("愿望单", systemImage: "heart") }
                Menu("筛选", systemImage: "line.3.horizontal.decrease") {
                    Picker("分区", selection: $floor) {
                        ForEach(DLsiteFloor.allCases, id: \.self) { Text($0.label) }
                    }
                }
            }
            .appDestinations()
        }
        .task(id: floor) { await load(refresh: false) }
        .task(id: term) { await model.discover.load(.ranking(term), floor: floor) }
        .task { await database.observe(LibraryIds.fetch) { owned = $0 } }
    }

    private func load(refresh: Bool) async {
        let store = model.discover
        func run(_ query: CatalogQuery) async {
            if refresh { await store.refresh(query, floor: floor) } else { await store.load(query, floor: floor) }
        }
        async let ranking: Void = run(.ranking(term))
        async let popular: Void = run(.all(.popular))
        async let new: Void = run(.newReleases)
        async let sale: Void = run(.onSale)
        _ = await (ranking, popular, new, sale)
    }

    // MARK: - Sections

    private func header(_ title: String, query: CatalogQuery) -> some View {
        Button { model.push(.catalog(query)) } label: {
            HStack(spacing: 4) {
                Text(title).font(.title3.bold())
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var rankingSection: some View {
        let list = model.discover.list(.ranking(term), floor: floor)
        return VStack(alignment: .leading, spacing: 10) {
            header("排行榜", query: .ranking(term))
            Picker("榜单", selection: $term) {
                ForEach(CatalogQuery.Term.allCases, id: \.self) { Text($0.label) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            VStack(spacing: 0) {
                ForEach(0..<Self.rankingPreview, id: \.self) { index in
                    Group {
                        if index < list.items.count {
                            let item = list.items[index]
                            NavigationLink(value: Route.onlineWork(item.productId)) {
                                CatalogRow(item: item, rank: index + 1, owned: owned.contains(item.productId)).contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        } else {
                            CatalogRowPlaceholder(rank: index + 1)
                        }
                    }
                    .padding(.vertical, 6)
                    if index < Self.rankingPreview - 1 { Divider().padding(.leading, 40) }
                }
            }
            .padding(.horizontal, 16)
            .overlay { retry(list, query: .ranking(term)) }
        }
    }

    private func rowSection(_ query: CatalogQuery, title: String) -> some View {
        let list = model.discover.list(query, floor: floor)
        return VStack(alignment: .leading, spacing: 10) {
            header(title, query: query)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    if list.items.isEmpty {
                        ForEach(0..<3, id: \.self) { _ in CatalogTilePlaceholder() }
                    } else {
                        ForEach(list.items) { CatalogTile(item: $0, owned: owned.contains($0.productId)) }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollDisabled(list.items.isEmpty)
            .overlay { retry(list, query: query) }
        }
    }

    /// Over the placeholders of a list that failed to load.
    @ViewBuilder private func retry(_ list: DiscoverStore.List, query: CatalogQuery) -> some View {
        if list.items.isEmpty, !list.loading, list.error != nil {
            Button("加载失败，点此重试", systemImage: "arrow.clockwise") {
                Task { await model.discover.refresh(query, floor: floor) }
            }
            .font(.subheadline)
            .buttonStyle(.bordered)
        }
    }
}

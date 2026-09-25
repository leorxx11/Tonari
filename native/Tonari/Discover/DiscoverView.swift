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
                    rowSection(.newReleases)
                    rowSection(.onSale)
                }
                .padding(.vertical, 8)
            }
            .refreshable { await load(refresh: true) }
            .navigationTitle("发现")
            .toolbar {
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
        async let ranking: Void = model.discover.load(.ranking(term), floor: floor, refresh: refresh)
        async let new: Void = model.discover.load(.newReleases, floor: floor, refresh: refresh)
        async let sale: Void = model.discover.load(.onSale, floor: floor, refresh: refresh)
        _ = await (ranking, new, sale)
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
                ForEach(Array(list.items.prefix(Self.rankingPreview).enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: Route.onlineWork(item.productId)) {
                        CatalogRow(item: item, rank: index + 1, owned: owned.contains(item.productId)).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    if index < min(list.items.count, Self.rankingPreview) - 1 { Divider().padding(.leading, 40) }
                }
            }
            .padding(.horizontal, 16)
            .overlay { status(list, query: .ranking(term)) }
        }
    }

    private func rowSection(_ query: CatalogQuery) -> some View {
        let list = model.discover.list(query, floor: floor)
        return VStack(alignment: .leading, spacing: 10) {
            header(query.title, query: query)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(list.items) { CatalogTile(item: $0, owned: owned.contains($0.productId)) }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .frame(minHeight: list.items.isEmpty ? 120 : nil)
            .overlay { status(list, query: query) }
        }
    }

    @ViewBuilder private func status(_ list: DiscoverStore.List, query: CatalogQuery) -> some View {
        if list.items.isEmpty {
            if list.loading {
                ProgressView()
            } else if list.error != nil {
                Button("加载失败，点此重试", systemImage: "arrow.clockwise") {
                    Task { await model.discover.load(query, floor: floor, refresh: true) }
                }
                .font(.subheadline)
            }
        }
    }
}

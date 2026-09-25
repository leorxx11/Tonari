import SwiftUI
import TonariCore

/// The search tab, after Apple Music, in three states: browsing circles,
/// voice actors and tags before the field is touched; recent searches
/// once it is focused; works and names grouped by kind once something is
/// typed, with the scope bar appearing only then.
struct SearchView: View {
    enum Scope: String, CaseIterable {
        case all = "全部"
        case works = "作品"
        case voiceActors = "声优"
        case circles = "社团"
        case genres = "标签"
    }

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var query = ""
    @State private var scope = Scope.all
    @State private var works: [Work] = []
    @State private var stats = LibraryStats([])
    @State private var recents = RecentSearches()
    @State private var browseKind = WorkChip.Kind.circle
    @State private var browseByName = false

    private static let browseKinds: [WorkChip.Kind] = [.circle, .voiceActor, .genre]

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.searchPath) {
            List {
                SearchPhase { searching in
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        results
                    } else if searching {
                        recent
                    } else {
                        browse
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("搜索")
            .searchable(text: $query, prompt: "作品、声优、社团、#标签")
            .searchScopes($scope, activation: .onTextEntry) {
                ForEach(Scope.allCases, id: \.self) { Text($0.rawValue) }
            }
            .onSubmit(of: .search) {
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { recents.record(.query(trimmed)) }
            }
            .appDestinations()
        }
        .task {
            await database.observe({ db in
                let works = try WorkQueries.library(sort: WorkSort(field: .releaseDate, descending: true), source: .all).fetchAll(db)
                return (works, LibraryStats(works))
            }) {
                works = $0.0
                stats = $0.1
            }
        }
    }

    // MARK: - Empty field

    @ViewBuilder private var recent: some View {
        if recents.items.isEmpty {
            Text("输入作品名、RJ 号、声优、社团，或用 # 搜标签")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .listRowSeparator(.hidden)
        } else {
            Section {
                ForEach(recents.items) { item in
                    recentRow(item)
                }
                .onDelete { recents.remove(at: $0) }
            } header: {
                HStack {
                    Text("最近搜索").font(.title3.bold()).foregroundStyle(.primary)
                    Spacer()
                    Button("清除") { recents.clear() }.font(.body)
                }
                .textCase(nil)
            }
        }
    }

    private var browse: some View {
        Section {
            ForEach(browseEntries, id: \.name) { entry in
                chipRow(WorkChip(browseKind, entry.name), count: entry.count, showsKind: false)
            }
        } header: {
            VStack(spacing: 10) {
                HStack {
                    Text("分类浏览").font(.title3.bold()).foregroundStyle(.primary)
                    Spacer()
                    Button(browseByName ? "按作品数" : "按名称") { browseByName.toggle() }.font(.body)
                }
                Picker("分类", selection: $browseKind) {
                    ForEach(Self.browseKinds, id: \.self) { Text($0.label) }
                }
                .pickerStyle(.segmented)
            }
            .textCase(nil)
            .padding(.bottom, 6)
        }
    }

    private var browseEntries: [LibraryStats.Entry] {
        let entries = stats.entries(for: browseKind)
        return browseByName ? entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } : entries
    }

    @ViewBuilder private func recentRow(_ item: RecentSearches.Item) -> some View {
        switch item {
        case .query(let text):
            Button {
                query = text
                recents.record(item)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(width: 48, height: 48)
                    Text(text)
                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        case .work(let productId, let title, let cover):
            workRow(productId: productId, title: title, cover: cover, detail: "作品 · \(productId)")
        case .chip(let chip):
            chipRow(chip, count: stats.entries(for: chip.kind).first { $0.name == chip.value }?.count, showsKind: true)
        }
    }

    // MARK: - Results

    @ViewBuilder private var results: some View {
        let result = LibrarySearch(query, works: works, stats: stats)
        let shown = [
            scope == .all || scope == .works ? !result.works.isEmpty : false,
            scope == .all || scope == .voiceActors ? !result.voiceActors.isEmpty : false,
            scope == .all || scope == .circles ? !result.circles.isEmpty : false,
            scope == .all || scope == .genres ? !result.genres.isEmpty : false,
        ]
        if !shown.contains(true) {
            ContentUnavailableView.search(text: query)
                .listRowSeparator(.hidden)
        }
        if shown[0] {
            Section("作品") {
                ForEach(result.works) { work in
                    workRow(
                        productId: work.productId, title: work.displayTitle, cover: work.mainImageLocalPath,
                        detail: [work.productId, work.circleName].compactMap(\.self).joined(separator: " · ")
                    )
                }
            }
        }
        if shown[1] { names("声优", result.voiceActors, kind: .voiceActor) }
        if shown[2] { names("社团", result.circles, kind: .circle) }
        if shown[3] { names("标签", result.genres, kind: .genre) }
    }

    private func names(_ title: String, _ entries: [LibraryStats.Entry], kind: WorkChip.Kind) -> some View {
        Section(title) {
            ForEach(entries, id: \.name) { entry in
                chipRow(WorkChip(kind, entry.name), count: entry.count, showsKind: false)
            }
        }
    }

    // MARK: - Rows

    private func workRow(productId: String, title: String, cover: String?, detail: String) -> some View {
        Button {
            recents.record(.work(productId: productId, title: title, cover: cover))
            model.searchPath.append(Route.work(productId))
        } label: {
            HStack(spacing: 14) {
                LocalImage(path: cover)
                    .frame(width: 48, height: 48)
                    .clipShape(.rect(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).lineLimit(2)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func chipRow(_ chip: WorkChip, count: Int?, showsKind: Bool) -> some View {
        Button {
            recents.record(.chip(chip))
            model.searchPath.append(Route.chip(chip))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: Self.symbol(chip.kind))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Color(.tertiarySystemFill), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(chip.value).lineLimit(1)
                    let detail = [showsKind ? chip.kind.label : nil, count.map { "\($0) 部作品" }].compactMap(\.self)
                    if !detail.isEmpty {
                        Text(detail.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    static func symbol(_ kind: WorkChip.Kind) -> String {
        switch kind {
        case .voiceActor: "person.fill"
        case .circle: "building.2.fill"
        case .genre: "number"
        case .series: "books.vertical.fill"
        case .scenarioWriter: "pencil"
        case .illustrator: "paintbrush.fill"
        case .musician: "music.note"
        }
    }
}

/// Hands `isSearching` to the list; it is only set for views inside the
/// searchable container, not the view that declares it.
private struct SearchPhase<Content: View>: View {
    @Environment(\.isSearching) private var isSearching
    @ViewBuilder let content: (Bool) -> Content

    var body: some View { content(isSearching) }
}

/// Searches picked on this device, newest first. Kept in user defaults, not
/// the database, so backups leave them out.
@Observable
final class RecentSearches {
    enum Item: Codable, Hashable, Identifiable {
        case query(String)
        case work(productId: String, title: String, cover: String?)
        case chip(WorkChip)

        var id: String {
            switch self {
            case .query(let text): "query:\(text)"
            case .work(let productId, _, _): "work:\(productId)"
            case .chip(let chip): "chip:\(chip.kind.rawValue):\(chip.value)"
            }
        }
    }

    private static let key = "search.recent"
    private static let limit = 20

    private(set) var items: [Item]

    init() {
        items = UserDefaults.standard.string(forKey: Self.key).map { try! JSONDecoder().decode([Item].self, from: Data($0.utf8)) } ?? []
    }

    func record(_ item: Item) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        items = Array(items.prefix(Self.limit))
        save()
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        // A JSON string rather than data, so backups (string / number / list prefs only) carry it.
        UserDefaults.standard.set(String(decoding: try! JSONEncoder().encode(items), as: UTF8.self), forKey: Self.key)
    }
}

/// Every work sharing a voice actor, circle, series or tag, in the
/// library's sort and view mode.
struct ChipWorksView: View {
    let chip: WorkChip

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var trackCounts: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []

    var body: some View {
        WorkCollectionView(works: works, trackCounts: trackCounts, remoteIds: remoteIds)
            .navigationTitle(chip.value)
            .navigationSubtitle("\(chip.kind.label) · \(works.count) 部作品")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: model.sort) {
                let request = WorkQueries.library(sort: model.sort, source: .all)
                let chip = chip
                await database.observe({ db in
                    (
                        try request.fetchAll(db).filter { chip.matches($0) },
                        try WorkQueries.trackCounts(db),
                        try WorkQueries.remoteFolderIds(db)
                    )
                }) {
                    works = $0.0
                    trackCounts = $0.1
                    remoteIds = $0.2
                }
            }
    }
}

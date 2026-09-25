import Foundation
import Observation
import TonariCore

/// DLsite lists per list and floor. The discover tab's own lists are kept
/// on disk: a launch shows the last ones at once and swaps in fresh ones
/// when they arrive (or keeps the old ones when offline). Other lists live
/// for the session; pull to refresh fetches any list again.
@Observable
final class DiscoverStore {
    struct Key: Hashable {
        let query: CatalogQuery
        let floor: DLsiteFloor
    }

    struct List {
        var items: [CatalogItem] = []
        var total: Int?
        var pages = 0
        var loading = false
        var error: String?

        var hasMore: Bool { total.map { items.count < $0 } ?? false }
    }

    static let floorKey = "discover.floor"

    private(set) var lists: [Key: List] = [:]
    private let catalog = DLsiteCatalog()
    /// Lists fetched since launch; the rest show what's saved until then.
    private var fresh: Set<Key> = []
    private var saved: [String: SavedList]

    init() {
        saved = (try? JSONDecoder().decode([String: SavedList].self, from: Data(contentsOf: Self.file))) ?? [:]
    }

    func list(_ query: CatalogQuery, floor: DLsiteFloor) -> List {
        lists[Key(query: query, floor: floor)] ?? List()
    }

    /// Shows the saved first page right away, then fetches it once per
    /// launch (or again on `refresh`), replacing what's shown on success.
    func load(_ query: CatalogQuery, floor: DLsiteFloor, refresh: Bool = false) async {
        let key = Key(query: query, floor: floor)
        if lists[key] == nil, let saved = Self.savedKey(key).flatMap({ saved[$0] }) {
            lists[key] = List(items: saved.items, total: saved.total, pages: 1)
        }
        guard refresh || !fresh.contains(key), lists[key]?.loading != true else { return }
        await fetch(key, replacing: true)
    }

    func loadMore(_ query: CatalogQuery, floor: DLsiteFloor) async {
        let key = Key(query: query, floor: floor)
        guard let list = lists[key], query.isPaged, list.hasMore, !list.loading, fresh.contains(key) else { return }
        await fetch(key, replacing: false)
    }

    private func fetch(_ key: Key, replacing: Bool) async {
        var list = lists[key] ?? List()
        list.loading = true
        list.error = nil
        lists[key] = list
        do {
            let page = try await catalog.page(key.query, floor: key.floor, page: replacing ? 1 : list.pages + 1)
            if replacing {
                list.items = page.items
                list.pages = 1
                fresh.insert(key)
                save(key, page)
            } else {
                let known = Set(list.items.map(\.id))
                list.items += page.items.filter { !known.contains($0.id) }
                list.pages += 1
            }
            list.total = page.total
        } catch {
            DiagnosticLog.shared.write("discover", "load_failed", ["query": key.query.title, "error": "\(error)"])
            list.error = error.localizedDescription
        }
        list.loading = false
        lists[key] = list
    }

    // MARK: - Saved lists

    private struct SavedList: Codable {
        let items: [CatalogItem]
        let total: Int?
    }

    nonisolated static let file = URL.cachesDirectory.appending(path: "discover.json")

    /// Only the discover tab's own lists are kept.
    private static func savedKey(_ key: Key) -> String? {
        let name: String? = switch key.query {
        case .ranking(let term): "ranking.\(term.rawValue)"
        case .newReleases: "new"
        case .onSale: "sale"
        case .all(.popular): "popular"
        case .creator, .circle, .genre, .series, .all, .search: nil
        }
        return name.map { "\(key.floor.rawValue).\($0)" }
    }

    private func save(_ key: Key, _ page: CatalogPage) {
        guard let name = Self.savedKey(key) else { return }
        saved[name] = SavedList(items: page.items, total: page.total)
        do {
            try JSONEncoder().encode(saved).write(to: Self.file, options: .atomic)
        } catch {
            DiagnosticLog.shared.write("discover", "save_failed", ["error": "\(error)"])
        }
    }
}

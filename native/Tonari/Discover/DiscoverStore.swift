import Foundation
import Observation
import TonariCore

/// DLsite lists per list and floor. The discover tab's own lists are kept
/// on disk with when they were fetched: they show from disk, and only a
/// cold start refetches the ones older than `staleAfter` (pull to refresh
/// fetches any list on demand). Other lists live for the session.
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
    static let staleAfter: TimeInterval = 12 * 3600

    private(set) var lists: [Key: List] = [:]
    private let catalog = DLsiteCatalog()
    private var saved: [String: SavedList]

    init() {
        let file = Self.file
        saved = FileManager.default.fileExists(atPath: file.path)
            ? (try? JSONDecoder().decode([String: SavedList].self, from: Data(contentsOf: file))) ?? [:]
            : [:]
    }

    func list(_ query: CatalogQuery, floor: DLsiteFloor) -> List {
        lists[Key(query: query, floor: floor)] ?? List()
    }

    /// What's saved, else the first page from DLsite when this list has
    /// never been fetched.
    func load(_ query: CatalogQuery, floor: DLsiteFloor) async {
        let key = Key(query: query, floor: floor)
        guard lists[key] == nil else { return }
        if let saved = Self.name(key).flatMap({ saved[$0] }) {
            lists[key] = List(items: saved.items, total: saved.total, pages: 1)
        } else {
            await fetch(key, replacing: true)
        }
    }

    /// Pull to refresh.
    func refresh(_ query: CatalogQuery, floor: DLsiteFloor) async {
        let key = Key(query: query, floor: floor)
        guard lists[key]?.loading != true else { return }
        await fetch(key, replacing: true)
    }

    func loadMore(_ query: CatalogQuery, floor: DLsiteFloor) async {
        let key = Key(query: query, floor: floor)
        guard let list = lists[key], query.isPaged, list.hasMore, !list.loading else { return }
        await fetch(key, replacing: false)
    }

    /// At launch: refetches, one after another, the saved lists older than
    /// `staleAfter`.
    func refreshStale(now: Date = .now) async {
        let stale = saved.filter { now.timeIntervalSince($0.value.fetchedAt) > Self.staleAfter }
        DiagnosticLog.shared.write("discover", "refresh_stale", ["lists": stale.keys.sorted().joined(separator: ",")])
        for entry in stale.values {
            await fetch(Key(query: entry.list.query, floor: entry.floor), replacing: true)
        }
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

    /// The discover tab's own lists, the only ones kept.
    private enum SavedQuery: Codable {
        case ranking(CatalogQuery.Term)
        case popular, newReleases, onSale

        init?(_ query: CatalogQuery) {
            switch query {
            case .ranking(let term): self = .ranking(term)
            case .all(.popular): self = .popular
            case .newReleases: self = .newReleases
            case .onSale: self = .onSale
            case .creator, .circle, .genre, .series, .all, .search: return nil
            }
        }

        var name: String {
            switch self {
            case .ranking(let term): "ranking.\(term.rawValue)"
            case .popular: "popular"
            case .newReleases: "new"
            case .onSale: "sale"
            }
        }

        var query: CatalogQuery {
            switch self {
            case .ranking(let term): .ranking(term)
            case .popular: .all(.popular)
            case .newReleases: .newReleases
            case .onSale: .onSale
            }
        }
    }

    private struct SavedList: Codable {
        let list: SavedQuery
        let floor: DLsiteFloor
        let items: [CatalogItem]
        let total: Int?
        let fetchedAt: Date
    }

    nonisolated static let file = URL.cachesDirectory.appending(path: "discover.json")

    private static func name(_ key: Key) -> String? {
        SavedQuery(key.query).map { "\(key.floor.rawValue).\($0.name)" }
    }

    private func save(_ key: Key, _ page: CatalogPage) {
        guard let list = SavedQuery(key.query), let name = Self.name(key) else { return }
        saved[name] = SavedList(list: list, floor: key.floor, items: page.items, total: page.total, fetchedAt: .now)
        do {
            try JSONEncoder().encode(saved).write(to: Self.file, options: .atomic)
        } catch {
            DiagnosticLog.shared.write("discover", "save_failed", ["error": "\(error)"])
        }
    }
}

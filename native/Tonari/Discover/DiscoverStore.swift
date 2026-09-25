import Observation
import TonariCore

/// DLsite lists fetched this session, per list and floor, so going back and
/// forth doesn't refetch; pull to refresh fetches again.
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

    func list(_ query: CatalogQuery, floor: DLsiteFloor) -> List {
        lists[Key(query: query, floor: floor)] ?? List()
    }

    /// The first page, unless it is already here.
    func load(_ query: CatalogQuery, floor: DLsiteFloor, refresh: Bool = false) async {
        let key = Key(query: query, floor: floor)
        if !refresh, lists[key]?.pages ?? 0 > 0 { return }
        lists[key] = List()
        await fetch(key)
    }

    func loadMore(_ query: CatalogQuery, floor: DLsiteFloor) async {
        let key = Key(query: query, floor: floor)
        guard let list = lists[key], query.isPaged, list.hasMore, !list.loading else { return }
        await fetch(key)
    }

    private func fetch(_ key: Key) async {
        lists[key]!.loading = true
        lists[key]!.error = nil
        do {
            let page = try await catalog.page(key.query, floor: key.floor, page: lists[key]!.pages + 1)
            let known = Set(lists[key]!.items.map(\.id))
            lists[key]!.items += page.items.filter { !known.contains($0.id) }
            lists[key]!.total = page.total
            lists[key]!.pages += 1
        } catch {
            DiagnosticLog.shared.write("discover", "load_failed", ["query": key.query.title, "error": "\(error)"])
            lists[key]!.error = error.localizedDescription
        }
        lists[key]!.loading = false
    }
}

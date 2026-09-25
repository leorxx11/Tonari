import Observation
import TonariCore

/// The DLsite wishlist this session: which works are on it (for the ♡ on a
/// work page) and their list details for the wishlist page. A lapsed login
/// signs out and says so in the inbox.
@Observable
final class WishlistStore {
    private(set) var isSignedIn: Bool
    /// Nil until fetched.
    private(set) var ids: [String]?
    private(set) var items: [CatalogItem] = []
    private(set) var loading = false
    private(set) var error: String?
    private let database: AppDatabase
    private let notices: Notices

    init(database: AppDatabase, notices: Notices) {
        self.database = database
        self.notices = notices
        isSignedIn = try! DLsiteAccount.isSignedIn()
    }

    func contains(_ productId: String) -> Bool {
        ids?.contains(productId) ?? false
    }

    func signedIn() {
        isSignedIn = true
        ids = nil
        items = []
    }

    func signOut() {
        try! DLsiteAccount.signOut()
        isSignedIn = false
        ids = nil
        items = []
    }

    /// The ids, and with `details` the works' titles and prices too.
    func load(details: Bool) async {
        guard let wishlist = try! DLsiteWishlist(), !loading else { return }
        loading = true
        error = nil
        do {
            let ids = try await wishlist.productIds()
            self.ids = ids
            if details { items = try await DLsiteCatalog().items(ids, floor: .maniax) }
        } catch {
            fail(error)
        }
        loading = false
    }

    func toggle(_ productId: String) async {
        guard let wishlist = try! DLsiteWishlist() else { return }
        let adding = !contains(productId)
        do {
            if adding {
                try await wishlist.add(productId)
                ids = [productId] + (ids ?? [])
                notices.show("已加入 DLsite 愿望单")
            } else {
                try await wishlist.remove(productId)
                ids?.removeAll { $0 == productId }
                items.removeAll { $0.productId == productId }
                notices.show("已移出 DLsite 愿望单")
            }
        } catch {
            fail(error)
        }
    }

    /// A lapsed login stays signed in here (logging in again replaces it);
    /// the inbox offers the way back in.
    private func fail(_ error: any Error) {
        DiagnosticLog.shared.write("dlsite", "wishlist_failed", ["error": "\(error)"])
        if error as? DLsiteWishlist.Failure == .expired {
            try! database.logEvent(category: "auth", title: "DLsite 登录已失效", detail: error.localizedDescription, action: .dlsiteLogin)
        }
        self.error = error.localizedDescription
        notices.show(error.localizedDescription, .failure)
    }
}

import Observation
import SwiftUI
import TonariCore

enum AppTab: Hashable {
    case library, favorites, browse, settings
}

enum Route: Hashable {
    case work(String)
    case files(String)
    case categories
    case favoriteItems
    case collection(String)
}

/// App-wide navigation plus the library's filter and display preferences,
/// shared so a CV / tag / circle tapped anywhere can reopen the library
/// filtered by it.
@Observable
final class AppModel {
    enum LibraryKind: String, CaseIterable {
        case audio = "音声"
        case video = "视频"
    }

    enum ViewMode: String, CaseIterable {
        case card, grid, list

        var label: String {
            switch self {
            case .card: "大卡片"
            case .grid: "网格"
            case .list: "列表"
            }
        }

        var systemImage: String {
            switch self {
            case .card: "rectangle.grid.1x2"
            case .grid: "square.grid.2x2"
            case .list: "list.bullet"
            }
        }
    }

    static let viewModeKey = "library.view.works"
    static let fileEntryKey = "appearance.fileEntryPosition"

    var tab = AppTab.library
    /// Work whose group membership sheet is showing.
    var collectionPickerWork: Work?
    /// Work awaiting confirmation to be removed from the library.
    var removingWork: Work?
    let tasks = LibraryTasks()
    var libraryPath = NavigationPath()
    var favoritesPath = NavigationPath()

    var libraryKind = LibraryKind.audio
    var filter = WorkFilter()
    var sort: WorkSort {
        didSet { UserDefaults.standard.set(sort.preference, forKey: WorkSort.preferenceKey) }
    }
    var viewMode: ViewMode {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: Self.viewModeKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        sort = WorkSort(preference: defaults.string(forKey: WorkSort.preferenceKey))
        viewMode = ViewMode(rawValue: defaults.string(forKey: Self.viewModeKey) ?? "") ?? .card
    }

    func showInLibrary(_ chip: WorkChip) {
        filter.add(chip)
        libraryKind = .audio
        libraryPath = NavigationPath()
        tab = .library
    }

    /// The seal that opens a work's files sits in the cover's bottom-left
    /// corner unless the user moved it right.
    var fileEntryOnLeft: Bool {
        UserDefaults.standard.string(forKey: Self.fileEntryKey) != "bottomRight"
    }
}

extension View {
    /// Destinations reachable from any tab's navigation stack.
    func appDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .work(let id): WorkDetailView(productId: id)
            case .files(let id): WorkFilesView(productId: id)
            case .categories: CategoriesView()
            case .favoriteItems: CollectionDetailView(collectionId: nil)
            case .collection(let id): CollectionDetailView(collectionId: id)
            }
        }
    }
}

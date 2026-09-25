import Observation
import SwiftUI
import TonariCore

enum AppTab: Hashable {
    case library, favorites, browse, settings, search
}

enum Route: Hashable {
    case p115Folder([RemoteEntry])
    case p115Login
    case p115Settings
    case playbackSettings
    case playHistory
    case listenStats
    case mediaSources
    case removedWorks
    case backup
    case diagnostics
    case work(String)
    case files(String)
    /// Works sharing a voice actor, circle, series or tag.
    case chip(WorkChip)
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
        case grid, list, cover

        var label: String {
            switch self {
            case .grid: "网格"
            case .list: "列表"
            case .cover: "大封面"
            }
        }

        var systemImage: String {
            switch self {
            case .grid: "square.grid.2x2"
            case .list: "list.bullet"
            case .cover: "rectangle.grid.1x2"
            }
        }
    }

    static let viewModeKey = "library.view.works"

    var tab = AppTab.library
    /// Work whose group membership sheet is showing.
    var showingPlayer = false
    var collectionPickerWork: Work?
    /// Work awaiting confirmation to be removed from the library.
    var removingWork: Work?
    let tasks = LibraryTasks()
    var libraryPath = NavigationPath()
    var favoritesPath = NavigationPath()
    var browsePath = NavigationPath()
    var searchPath = NavigationPath()

    var libraryKind = LibraryKind.audio
    var source = SourceFilter.all
    var sort: WorkSort {
        didSet { UserDefaults.standard.set(sort.preference, forKey: WorkSort.preferenceKey) }
    }
    var viewMode: ViewMode {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: Self.viewModeKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        sort = WorkSort(preference: defaults.string(forKey: WorkSort.preferenceKey))
        viewMode = ViewMode(rawValue: defaults.string(forKey: Self.viewModeKey) ?? "") ?? .grid
    }

    /// Opens 115 where the user left off, or its login when signed out.
    func openP115() {
        browsePath = NavigationPath(
            P115Client.shared.loginState == .loggedIn ? BrowseLocation.routes(P115Client.sourceId) : [Route.p115Login]
        )
        tab = .browse
    }

    /// Pushes onto whichever tab is showing, for links inside views that
    /// are themselves links, like the chips on a library card.
    func push(_ route: Route) {
        switch tab {
        case .library: libraryPath.append(route)
        case .favorites: favoritesPath.append(route)
        case .browse: browsePath.append(route)
        case .search: searchPath.append(route)
        case .settings: break
        }
    }

    func openWork(_ productId: String) {
        libraryPath = NavigationPath([Route.work(productId)])
        tab = .library
    }
}

extension View {
    /// Destinations reachable from any tab's navigation stack.
    func appDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .p115Folder(let stack): P115BrowserView(stack: stack)
            case .p115Login: P115LoginView()
            case .p115Settings: P115SettingsView()
            case .playbackSettings: PlaybackSettingsView()
            case .playHistory: PlayHistoryView()
            case .listenStats: ListenStatsView()
            case .mediaSources: MediaSourcesView()
            case .removedWorks: RemovedWorksView()
            case .backup: BackupView()
            case .diagnostics: DiagnosticLogView()
            case .work(let id): WorkDetailView(productId: id)
            case .files(let id): WorkFilesView(productId: id)
            case .chip(let chip): ChipWorksView(chip: chip)
            case .favoriteItems: CollectionDetailView(collectionId: nil)
            case .collection(let id): CollectionDetailView(collectionId: id)
            }
        }
    }
}

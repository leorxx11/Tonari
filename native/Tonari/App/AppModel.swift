import Observation
import SwiftUI
import TonariCore

enum AppTab: Hashable {
    case home, discover, library, browse, search
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
    case messages
    case privacy
    case translation
    /// Nil adds a new service.
    case llmProvider(String?)
    case diagnostics
    case storage
    case appearance
    case about
    case work(String)
    case files(String, folder: [String] = [], highlight: String? = nil)
    /// Works sharing a voice actor, circle, series or tag.
    case chip(WorkChip)
    case favoriteItems
    case collection(String)
    /// The library's full work wall, formerly the 媒体库 tab.
    case works
    case videos
    /// Works not played for a month, longest ago first.
    case forgotten
    /// Every voice actor, circle or tag in the library.
    case categories(WorkChip.Kind)
    /// A DLsite list: a ranking, new releases, a creator's works…
    case catalog(CatalogQuery)
    /// A work read live from DLsite, in the library or not.
    case onlineWork(String)
}

/// App-wide navigation plus the library's filter and display preferences,
/// shared so a CV / tag / circle tapped anywhere can reopen the library
/// filtered by it.
@Observable
final class AppModel {
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

    var tab = AppTab.home
    var showingPlayer = false
    var showingSettings = false
    var showingVideo = false
    /// The work or video whose group membership sheet is showing.
    var collectionPicker: CollectionMember?
    /// Work awaiting confirmation to be removed from the library.
    var removingWork: Work?
    let tasks: LibraryTasks
    let notices: Notices
    let discover = DiscoverStore()
    var homePath = NavigationPath()
    var discoverPath = NavigationPath()
    var libraryPath = NavigationPath()
    var browsePath = NavigationPath()
    var searchPath = NavigationPath()
    var settingsPath = NavigationPath()

    var source = SourceFilter.all
    var sort: WorkSort {
        didSet { UserDefaults.standard.set(sort.preference, forKey: WorkSort.preferenceKey) }
    }
    var viewMode: ViewMode {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: Self.viewModeKey) }
    }

    init(database: AppDatabase) {
        let notices = Notices()
        self.notices = notices
        tasks = LibraryTasks(database: database, notices: notices)
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

    /// Pushes onto whichever stack is showing (the settings sheet over a
    /// tab), for links inside views that are themselves links, like the
    /// chips on a library card.
    func push(_ route: Route) {
        if showingSettings { return settingsPath.append(route) }
        switch tab {
        case .home: homePath.append(route)
        case .discover: discoverPath.append(route)
        case .library: libraryPath.append(route)
        case .browse: browsePath.append(route)
        case .search: searchPath.append(route)
        }
    }

    /// Starts a video and opens its player over everything.
    func playVideo(_ playable: PlayableVideo, origin: [RemoteEntry]? = nil, with video: VideoController) {
        video.play(playable, origin: origin)
        showingVideo = true
    }

    /// Pops `count` pages off whichever stack is showing.
    func pop(_ count: Int) {
        if showingSettings { return settingsPath.removeLast(count) }
        switch tab {
        case .home: homePath.removeLast(count)
        case .discover: discoverPath.removeLast(count)
        case .library: libraryPath.removeLast(count)
        case .browse: browsePath.removeLast(count)
        case .search: searchPath.removeLast(count)
        }
    }

    func openWork(_ productId: String) {
        libraryPath = NavigationPath([Route.work(productId)])
        tab = .library
    }

    /// Opens a random work on the stack showing, or says the library is empty.
    func openRandomWork(tagged tags: Set<String> = [], database: AppDatabase) {
        let work = try! database.reader.read { db in
            tags.isEmpty ? try WorkQueries.random(db) : try HomeQueries.random(tagged: tags, db)
        }
        if let work {
            push(.work(work.productId))
        } else {
            notices.show(tags.isEmpty ? "资料库还是空的" : "没有同时带这些标签的作品", .info)
        }
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
            case .messages: MessagesView()
            case .privacy: PrivacySettingsView()
            case .translation: TranslationSettingsView()
            case .llmProvider(let id): LlmProviderEditView(providerId: id)
            case .diagnostics: DiagnosticLogView()
            case .storage: StorageView()
            case .appearance: AppearanceSettingsView()
            case .about: AboutView()
            case .work(let id): WorkDetailView(productId: id)
            case .files(let id, let folder, let highlight): WorkFilesView(productId: id, path: folder, highlight: highlight)
            case .chip(let chip): ChipWorksView(chip: chip)
            case .favoriteItems: CollectionDetailView(collectionId: nil)
            case .collection(let id): CollectionDetailView(collectionId: id)
            case .works: WorksView()
            case .videos: VideoLibraryView()
            case .forgotten: ForgottenWorksView()
            case .categories(let kind): CategoryBrowseView(kind: kind)
            case .catalog(let query): CatalogListView(query: query)
            case .onlineWork(let id): OnlineWorkView(productId: id)
            }
        }
    }
}

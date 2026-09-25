import AVFoundation
import SwiftUI
import TonariCore

@main
struct TonariApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel
    @State private var enrichment: EnrichmentQueue
    @State private var player: PlaybackController
    @State private var video: VideoController
    @State private var nowPlaying: NowPlaying
    @AppStorage(Appearance.preferenceKey) private var appearance = Appearance.system
    private let database: AppDatabase

    init() {
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        let documents = URL.documentsDirectory
        do {
            // Must run before the database opens: it may replace the file.
            if let summary = try BackupRestore.applyPending(in: documents, defaults: .standard, applySecrets: { secrets in
                for (key, value) in secrets {
                    try KeychainStore.shared.set(value, for: key)
                }
            }) {
                DiagnosticLog.shared.write("backup", "restore_applied", [
                    "prefs": summary.prefs, "secrets": summary.secrets, "dirs": summary.dirs,
                ])
            }
            database = try AppDatabase.open(in: documents)
            _model = State(initialValue: AppModel(database: database))
            _enrichment = State(initialValue: EnrichmentQueue(database: database))
            let player = PlaybackController(database: database)
            let video = VideoController(database: database, sleep: player.sleep)
            _player = State(initialValue: player)
            _video = State(initialValue: video)
            _nowPlaying = State(initialValue: NowPlaying(audio: player, video: video))
        } catch {
            fatalError("Failed to open the library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(enrichment)
                .environment(player)
                .environment(video)
                .environment(nowPlaying)
                .environment(\.appDatabase, database)
                .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            DiagnosticLog.shared.write("app", "lifecycle", ["phase": "\(phase)"])
            PrivacyShield.update(phase)
            if phase == .background { player.savePosition() }
        }
    }
}

extension EnvironmentValues {
    @Entry var appDatabase: AppDatabase = .empty
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(PlaybackController.self) private var player
    @Environment(VideoController.self) private var video
    @Environment(NowPlaying.self) private var nowPlaying
    @Environment(\.appDatabase) private var database
    @Namespace private var playerTransition
    @State private var unreadEvents = 0

    var body: some View {
        @Bindable var model = model
        @Bindable var player = player
        TabView(selection: $model.tab) {
            Tab("媒体库", systemImage: "music.note.list", value: AppTab.library) {
                LibraryView()
            }
            Tab("收藏", systemImage: "heart", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("浏览", systemImage: "folder", value: AppTab.browse) {
                BrowseView()
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
            .badge(unreadEvents)
            Tab("搜索", systemImage: "magnifyingglass", value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .background { SubtitlePiPHost(pip: player.pip).frame(width: 1, height: 1) }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: nowPlaying.front == .video ? video.hasCurrent : player.hasCurrent) {
            MiniPlayer().matchedTransitionSource(id: "player", in: playerTransition)
        }
        .fullScreenCover(isPresented: $model.showingPlayer) {
            PlayerView().navigationTransition(.zoom(sourceID: "player", in: playerTransition))
        }
        .fullScreenCover(isPresented: $model.showingVideo) {
            VideoPlayerView().navigationTransition(.zoom(sourceID: "player", in: playerTransition))
        }
        .alert(
            "无法播放视频",
            isPresented: Binding(get: { video.errorMessage != nil }, set: { if !$0 { video.errorMessage = nil } })
        ) {} message: {
            Text(video.errorMessage ?? "")
        }
        .alert(
            "无法播放",
            isPresented: Binding(get: { player.errorMessage != nil }, set: { if !$0 { player.errorMessage = nil } })
        ) {} message: {
            Text(player.errorMessage ?? "")
        }
        .sheet(item: $model.collectionPicker) { CollectionPickerSheet(member: $0) }
        .alert(
            "从媒体库移除",
            isPresented: Binding(get: { model.removingWork != nil }, set: { if !$0 { model.removingWork = nil } })
        ) {
            Button("取消", role: .cancel) {}
            Button("移除", role: .destructive) {
                try! database.removeWork(model.removingWork!.productId)
            }
        } message: {
            Text("将清除该作品在 App 内的快照（音轨、文件、字幕），云盘/本地的原文件不受影响。重新导入可找回。")
        }
        .alert(
            model.tasks.result ?? "",
            isPresented: Binding(get: { model.tasks.result != nil }, set: { if !$0 { model.tasks.result = nil } })
        ) {}
        .task {
            await database.observe(AppEvents.unreadCount) { unreadEvents = $0 }
        }
        .task {
            await LocalImport(database: database).rescanFlaggedLocalWorks()
            await enrichment.runPending()
        }
    }
}

import AVFoundation
import SwiftUI
import TonariCore

@main
struct TonariApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppModel()
    private let database: AppDatabase

    init() {
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
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
        } catch {
            fatalError("Failed to open the library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(\.appDatabase, database)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            DiagnosticLog.shared.write("app", "lifecycle", ["phase": "\(phase)"])
        }
    }
}

extension EnvironmentValues {
    @Entry var appDatabase: AppDatabase = .empty
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("媒体库", systemImage: "music.note.list", value: AppTab.library) {
                LibraryView()
            }
            Tab("收藏", systemImage: "heart", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("浏览", systemImage: "folder", value: AppTab.browse) {
                PlaceholderView(title: "浏览", systemImage: "folder", note: "N4 实现")
            }
            Tab("设置", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .sheet(item: $model.collectionPickerWork) { work in
            CollectionPickerSheet(work: work)
        }
    }
}

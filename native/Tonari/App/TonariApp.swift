import AVFoundation
import SwiftUI
import TonariCore

@main
struct TonariApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("媒体库", systemImage: "music.note.list") }
            PlaceholderView(title: "收藏", systemImage: "heart", note: "N2 实现")
                .tabItem { Label("收藏", systemImage: "heart") }
            PlaceholderView(title: "浏览", systemImage: "folder", note: "N4 实现")
                .tabItem { Label("浏览", systemImage: "folder") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

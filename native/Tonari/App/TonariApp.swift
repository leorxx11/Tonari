import AVFoundation
import SwiftUI
import TonariCore

@main
struct TonariApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("视频播放验证") { VideoSpikeView() }
                    NavigationLink("诊断日志") { DiagnosticLogView() }
                }
                .navigationTitle("Tonari N0")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            DiagnosticLog.shared.write("app", "lifecycle", ["phase": "\(phase)"])
        }
    }
}

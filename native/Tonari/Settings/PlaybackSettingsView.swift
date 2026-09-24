import SwiftUI

struct PlaybackSettingsView: View {
    @Environment(PlaybackController.self) private var player

    var body: some View {
        @Bindable var prefs = player.prefs
        List {
            Section {
                ForEach(PlayerPrefs.seekStepPresets, id: \.self) { seconds in
                    Button {
                        prefs.seekStep = seconds
                    } label: {
                        LabeledContent("\(seconds) 秒") {
                            if prefs.seekStep == seconds { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }
                    .tint(.primary)
                }
                Stepper("自定义：\(prefs.seekStep) 秒", value: $prefs.seekStep, in: 1...600)
            } header: {
                Text("快进 / 快退步长")
            } footer: {
                Text("播放页的前进、后退按钮每次跳过的时长。")
            }
        }
        .navigationTitle("播放")
        .navigationBarTitleDisplayMode(.inline)
    }
}

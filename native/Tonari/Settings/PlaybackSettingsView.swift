import PhotosUI
import SwiftUI
import TonariCore

struct PlaybackSettingsView: View {
    @Environment(PlaybackController.self) private var player
    @AppStorage(VideoThumbnail.defaultCoverKey) private var defaultCover: String?
    @State private var pickedCover: PhotosPickerItem?

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
            }
            Section {
                Toggle("默认播完本曲再停", isOn: $prefs.sleepFinishCurrentTrack)
            } header: {
                Text("睡眠定时")
            }
            Section {
                HStack(spacing: 14) {
                    VideoThumbnail(coverPath: nil, cornerRadius: 6).frame(width: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(defaultCover == nil ? "选择图片" : "更换图片", selection: $pickedCover, matching: .images)
                        if defaultCover != nil {
                            Button("恢复默认", role: .destructive) { setDefaultCover(nil) }
                        }
                    }
                }
            } header: {
                Text("默认视频封面")
            }
        }
        .onChange(of: pickedCover) { _, item in
            guard let item else { return }
            Task {
                do {
                    let data = try await item.loadTransferable(type: Data.self)
                    let jpeg = UIImage(data: data!)!.jpegData(compressionQuality: 0.9)!
                    let relative = "video_covers/default-\(Int(Date.now.timeIntervalSince1970 * 1000)).jpg"
                    let url = URL.documentsDirectory.appending(path: relative)
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try jpeg.write(to: url)
                    setDefaultCover(relative)
                } catch {
                    DiagnosticLog.shared.write("settings", "default_cover_failed", ["error": "\(error)"])
                }
                pickedCover = nil
            }
        }
        .navigationTitle("播放")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Replaces the stored default, deleting the picture it pointed at.
    private func setDefaultCover(_ relative: String?) {
        if let old = defaultCover {
            do {
                try FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: old))
            } catch {
                DiagnosticLog.shared.write("settings", "default_cover_remove_failed", ["error": "\(error)"])
            }
        }
        defaultCover = relative
    }
}

import SwiftUI
import UniformTypeIdentifiers

struct VideoSpikeView: View {
    @State private var model = VideoSpikeModel()
    @State private var pickingFile = false
    @State private var scrubMs: Double?

    var body: some View {
        List {
            Section {
                VideoSurface(player: model.player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .listRowInsets(EdgeInsets())
                Slider(
                    value: Binding(
                        get: { scrubMs ?? Double(model.positionMs) },
                        set: { scrubMs = $0 }
                    ),
                    in: 0...Double(max(model.durationMs, 1)),
                    onEditingChanged: { editing in
                        guard !editing, let target = scrubMs else { return }
                        model.seek(toMs: Int64(target))
                        scrubMs = nil
                    }
                )
                HStack {
                    Text("\(format(model.positionMs)) / \(format(model.durationMs))")
                    Spacer()
                    Text("缓冲 \(format(model.bufferedMs))")
                    Button(model.isPlaying ? "暂停" : "播放") { model.togglePlay() }
                        .buttonStyle(.borderedProminent)
                }
                .font(.footnote.monospacedDigit())
            }

            Section("来源") {
                Button("选择本地文件") { pickingFile = true }
                TextField("URL", text: $model.urlText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("请求头（每行 Name: Value）", text: $model.headersText, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(3...8)
                Button("打开 URL") { Task { await model.openRemote() } }
            }

            Section("媒体信息") {
                if let info = model.videoInfo {
                    LabeledContent("编码", value: info.codec)
                    LabeledContent("像素格式", value: info.pixelFormat)
                    LabeledContent("分辨率", value: "\(info.width)×\(info.height) @ \(info.frameRate.formatted())")
                }
                LabeledContent("解码器", value: model.decoder)
            }

            Section("日志") {
                ForEach(model.log.reversed(), id: \.self) { line in
                    Text(line).font(.caption.monospaced())
                }
            }
        }
        .navigationTitle("视频播放验证")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            Task { await model.openLocal(url) }
        }
    }

    private func format(_ ms: Int64) -> String {
        Duration.milliseconds(ms).formatted(.time(pattern: .minuteSecond))
    }
}

import SwiftUI
import TonariCore

/// One folder of a work's files. Each level is its own page, like the 115
/// browser, so back steps up a single folder. `highlight` is a track to
/// scroll to and flash, when arriving from the detail page.
struct WorkFilesView: View {
    let productId: String
    let path: [String]
    let highlight: String?

    @Environment(AppModel.self) private var model
    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database
    @State private var tree: [WorkTreeNode] = []
    @State private var source: ImportedFolder?
    @State private var matched: [String: MatchedSubtitle] = [:]
    @State private var loaded = false
    @State private var flashing: String?
    @State private var subtitlePreview: SubtitlePreviewSource?
    @State private var textPreview: WorkFile?
    @State private var gallery: GallerySelection?
    @Namespace private var galleryZoom

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if loaded { rows }
            }
            .listStyle(.plain)
            .task(id: loaded) {
                guard loaded, let highlight else { return }
                proxy.scrollTo(highlight, anchor: .center)
                for _ in 0..<2 {
                    withAnimation(.easeInOut(duration: 0.35)) { flashing = highlight }
                    try? await Task.sleep(for: .milliseconds(450))
                    withAnimation(.easeInOut(duration: 0.35)) { flashing = nil }
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
        }
        .overlay {
            if loaded && level.isEmpty {
                ContentUnavailableView("没有文件", systemImage: "folder")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // Same as the 115 browser: the folder name sits beside the back
        // button and stays put while scrolling.
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: 220, alignment: .leading)
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            if !path.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    // One page per folder row tapped, plus the root page.
                    Button("回到作品详情", systemImage: "house") {
                        model.pop(WorkTree.steps(tree, to: path).count + 1)
                    }
                    .disabled(!loaded)
                }
            }
        }
        .sheet(item: $subtitlePreview) { SubtitlePreviewSheet(source: $0) }
        .sheet(item: $textPreview) { TextPreviewSheet(file: $0, source: source) }
        .fullScreenCover(item: $gallery) { GalleryView(selection: $0, namespace: galleryZoom) }
        .task {
            await database.observe({ [productId] db in
                let work = try WorkQueries.work(productId).fetchOne(db)
                return (
                    WorkTree.build(tracks: try WorkQueries.tracks(of: productId).fetchAll(db), files: try WorkQueries.files(of: productId).fetchAll(db)),
                    try work?.importedFolderId.flatMap { try ImportedFolder.fetchOne(db, key: $0) },
                    try WorkQueries.matchedSubtitles(of: productId, db)
                )
            }) {
                tree = $0.0
                source = $0.1
                matched = $0.2
                loaded = true
            }
        }
    }

    private var title: String {
        path.isEmpty ? productId : (loaded ? WorkTree.steps(tree, to: path).last!.label : path.last!)
    }

    private var level: [WorkTreeNode] { WorkTree.level(tree, at: path) }

    @ViewBuilder private var rows: some View {
        let level = level
        let tracks = level.compactMap { node -> Track? in if case .track(let track) = node { track } else { nil } }
        let subtitledTracks = Set(matched.values.map(\.trackId))
        if !tracks.isEmpty {
            Button {
                play(tracks[0])
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 34, height: 34)
                        .background(Color.primary, in: .circle)
                    Text("播放本文件夹").fontWeight(.semibold)
                    Spacer()
                    Text("\(tracks.count) 首").foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
        let trackFolder = TrackFolderMemory.resolve(WorkTree.audioFolders(tree), tree: tree, productId: productId)?.path
        ForEach(WorkTree.folderEntries(level, at: path), id: \.path) { entry in
            NavigationLink(value: Route.files(productId, folder: entry.path)) {
                FileNodeRow(icon: "folder.fill", tint: .blue, title: entry.label, detail: Self.summary(entry.node.kindCounts)) {
                    if let trackFolder, trackFolder.starts(with: entry.path) {
                        Image(systemName: "checkmark").font(.footnote.weight(.semibold)).foregroundStyle(.tint)
                    }
                }
            }
        }
        ForEach(level.filter { if case .folder = $0 { false } else { true } }) { node in
            switch node {
            case .track(let track):
                trackRow(track, subtitled: subtitledTracks.contains(track.id))
            case .file(let file):
                fileRow(file, images: level.compactMap { node -> WorkFile? in
                    if case .file(let file) = node, file.fileKind == "image" { file } else { nil }
                })
            case .folder:
                EmptyView()
            }
        }
    }

    private func trackRow(_ track: Track, subtitled: Bool) -> some View {
        let playing = player.currentTrack?.id == track.id
        let detail: String = [String?]([
            playing ? "正在播放" : (track.durationMs > 0 ? Formatting.trackTime(ms: track.durationMs) : nil),
            Formatting.bytes(track.fileSizeBytes),
        ]).compactMap(\.self).joined(separator: " · ")
        return Button {
            play(track)
        } label: {
            FileNodeRow(icon: playing ? "waveform" : "music.note", tint: .pink, title: track.titleZh ?? track.title, detail: detail) {
                if subtitled {
                    Image(systemName: "captions.bubble").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .tint(.primary)
        .listRowBackground(flashing == track.id ? Color.accentColor.opacity(0.18) : nil)
        .id(track.id)
        .contextMenu {
            if subtitled {
                Button("预览字幕", systemImage: "captions.bubble") { subtitlePreview = .track(track) }
            }
        }
    }

    @ViewBuilder private func fileRow(_ file: WorkFile, images: [WorkFile]) -> some View {
        let (icon, tint) = Self.icon(for: file.fileKind)
        switch file.fileKind {
        case "subtitle":
            let match = matched[file.filePath]
            Button {
                if let match {
                    subtitlePreview = .track(track(match.trackId))
                } else {
                    subtitlePreview = .file(file, source: source)
                }
            } label: {
                FileNodeRow(icon: icon, tint: tint, title: file.fileName, detail: match.map { "字幕 · \($0.lineCount) 句" } ?? "字幕 · \(Formatting.bytes(file.fileSizeBytes))")
            }
            .tint(.primary)
            // Matched subtitles already show on their track.
            .opacity(match == nil ? 1 : 0.5)
        case "image":
            Button {
                gallery = GallerySelection(images: images.map { .workFile($0, source: source) }, index: images.firstIndex(of: file)!)
            } label: {
                FileNodeRow(icon: icon, tint: tint, title: file.fileName, detail: Formatting.bytes(file.fileSizeBytes))
            }
            .matchedTransitionSource(id: file.id, in: galleryZoom)
            .tint(.primary)
        case "text":
            Button {
                textPreview = file
            } label: {
                FileNodeRow(icon: icon, tint: tint, title: file.fileName, detail: Formatting.bytes(file.fileSizeBytes))
            }
            .tint(.primary)
        default:
            FileNodeRow(icon: icon, tint: tint, title: file.fileName, detail: Formatting.bytes(file.fileSizeBytes))
        }
    }

    /// The track a matched subtitle belongs to, wherever it sits in the work.
    private func track(_ id: String) -> Track {
        WorkTree.playbackOrder(tree).first { $0.id == id }!
    }

    /// Plays this folder from `track` and makes it the detail page's folder.
    private func play(_ track: Track) {
        let queue = try! PlaybackStore(database: database).queue(for: productId, folder: path)
        player.play(queue, at: queue.tracks.firstIndex { $0.id == track.id }!)
        TrackFolderMemory.remember(path, for: productId)
    }

    /// `24 首 · 字幕 24`, `12 张图片`.
    static func summary(_ counts: [String: Int]) -> String {
        let parts: [(String, (Int) -> String)] = [
            ("audio", { "\($0) 首" }), ("subtitle", { "字幕 \($0)" }), ("image", { "\($0) 张图片" }),
            ("text", { "\($0) 个文本" }), ("video", { "\($0) 个视频" }), ("other", { "\($0) 个其他文件" }),
        ]
        return parts.compactMap { kind, text in counts[kind].map(text) }.joined(separator: " · ")
    }

    static func icon(for kind: String) -> (String, Color) {
        switch kind {
        case "image": ("photo", .green)
        case "subtitle": ("captions.bubble", .cyan)
        case "text": ("doc.text", .orange)
        case "video": ("film", .purple)
        default: ("doc", .gray)
        }
    }
}

private struct FileNodeRow<Accessory: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).lineLimit(3)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            accessory
        }
    }
}

extension FileNodeRow where Accessory == EmptyView {
    init(icon: String, tint: Color, title: String, detail: String) {
        self.init(icon: icon, tint: tint, title: title, detail: detail) { EmptyView() }
    }
}

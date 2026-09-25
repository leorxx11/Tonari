import SwiftUI
import TonariCore
import UniformTypeIdentifiers

/// The media library's video side: what's half watched (library or not,
/// straight from the play history), then the videos the user kept, as a
/// two-column 16:9 grid; the + in the bar adds more.
struct VideoLibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(VideoController.self) private var video
    @Environment(\.appDatabase) private var database
    @State private var progress: [VideoProgress] = []
    @State private var covers: [String: String] = [:]
    @State private var items: [VideoItem] = []
    @State private var importing = false
    @State private var renaming: VideoItem?
    @State private var newTitle = ""
    @State private var removing: VideoItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !progress.isEmpty { continueSection }
                librarySection
            }
            .padding(.vertical, 8)
        }
        .overlay {
            if progress.isEmpty && items.isEmpty {
                ContentUnavailableView("还没有视频", systemImage: "film", description: Text("点右上角的 ＋ 从「文件」导入，或在 115 浏览里长按视频加入"))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("添加视频", systemImage: "plus") {
                    Button("从「文件」导入", systemImage: "folder") { importing = true }
                        .disabled(model.tasks.isBusy)
                    Button("从 115 添加", systemImage: "icloud") { model.openP115() }
                }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: LocalVideoImport.contentTypes, allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            Task { await importVideos(urls) }
        }
        .alert("重命名", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("标题", text: $newTitle)
            Button("取消", role: .cancel) {}
            Button("恢复文件名") { try! database.renameVideo(renaming!.id, to: nil) }
            Button("确定") { try! database.renameVideo(renaming!.id, to: newTitle) }
        }
        .alert("移出视频库？", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), presenting: removing) { item in
            Button("取消", role: .cancel) {}
            Button("移出", role: .destructive) { remove(item) }
        } message: { item in
            Text(item.sourceKind == "local" ? "会删除 App 内的这份视频副本，播放记录保留。" : "只移出视频库，115 上的文件不受影响。")
        }
        .task {
            await database.observe({ db in
                let progress = try PlaybackStore.continueWatching(limit: 12, db)
                let rows = try VideoItem.filter(keys: progress.map(\.id)).fetchAll(db)
                return (
                    progress,
                    Dictionary(uniqueKeysWithValues: rows.compactMap { row in row.coverPath.map { (row.id, $0) } }),
                    try VideoItem.order(Column("added_at").desc).fetchAll(db)
                )
            }) {
                progress = $0.0
                covers = $0.1
                items = $0.2
            }
        }
    }

    // MARK: - Sections

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("继续观看").font(.title3.bold()).padding(.horizontal, 16)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(progress) { item in
                        Button { model.playVideo(item.video, with: video) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                VideoThumbnail(coverPath: covers[item.id])
                                    .overlay(alignment: .bottom) { progressBar(item) }
                                    .padding(.bottom, 4)
                                Text(item.video.title).font(.subheadline).lineLimit(1)
                                Text("\(item.video.sourceName) · 剩 \(Self.remaining(item))")
                                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(width: 220)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 16, for: .scrollContent)
        }
    }

    private func progressBar(_ item: VideoProgress) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35))
                Capsule().fill(.white).frame(width: proxy.size.width * Double(item.positionMs) / Double(item.durationMs))
            }
        }
        .frame(height: 4)
        .padding(8)
    }

    private static func remaining(_ item: VideoProgress) -> String {
        let minutes = max(1, (item.durationMs - item.positionMs) / 60_000)
        return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分钟" : "\(minutes) 分钟"
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("视频库").font(.title3.bold())
                Text("\(items.count) 个").font(.subheadline).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                ForEach(items) { item in
                    Button { model.playVideo(PlayableVideo(item), with: video) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            VideoThumbnail(coverPath: item.coverPath)
                                .overlay(alignment: .bottomTrailing) {
                                    if item.isFavorite {
                                        Image(systemName: "heart.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(5)
                                            .background(.black.opacity(0.45), in: .circle)
                                            .padding(6)
                                    }
                                }
                                .padding(.bottom, 4)
                            Text(item.displayTitle).font(.subheadline).lineLimit(1)
                            Text(item.sourceName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(item) }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder private func menu(_ item: VideoItem) -> some View {
        Button("重命名", systemImage: "pencil") {
            newTitle = item.displayTitle
            renaming = item
        }
        Button(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "heart.slash" : "heart") {
            try! database.setVideoFavorite(item.id, !item.isFavorite)
        }
        Button("加入分组…", systemImage: "folder.badge.plus") { model.collectionPicker = .video(item) }
        Button("移出视频库", systemImage: "trash", role: .destructive) { removing = item }
    }

    // MARK: - Actions

    private func importVideos(_ urls: [URL]) async {
        await model.tasks.run("导入视频", detail: "0 / \(urls.count)") {
            for (index, url) in urls.enumerated() {
                let video = try await LocalVideoImport.adopt(url)
                try database.addVideo(video)
                model.tasks.report("\(index + 1) / \(urls.count)")
            }
            return "已导入 \(urls.count) 个视频"
        }
    }

    private func remove(_ item: VideoItem) {
        if video.video?.id == item.id, item.sourceKind == "local" { video.close() }
        try! database.removeVideo(item.id)
        if item.sourceKind == "local" { LocalVideoImport.discard(item.path) }
    }
}

/// Videos picked in Files are copied in, as the Flutter build did, under
/// `videos/<uuid>/<name>`, so they play without the original's permission.
enum LocalVideoImport {
    static let contentTypes: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie]
        + ["mkv", "webm", "ts", "m4v"].compactMap { UTType(filenameExtension: $0) }

    @concurrent
    static func adopt(_ url: URL) async throws -> PlayableVideo {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let relative = "videos/\(UUID().uuidString.lowercased())/\(url.lastPathComponent)"
        let target = URL.documentsDirectory.appending(path: relative)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url, to: target)
        let size = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return PlayableVideo(localPath: relative, fileName: url.lastPathComponent, size: size)
    }

    /// Deletes an imported copy with the folder made for it.
    static func discard(_ relativePath: String) {
        let folder = URL.documentsDirectory.appending(path: relativePath).deletingLastPathComponent()
        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            DiagnosticLog.shared.write("video", "discard_failed", ["path": relativePath, "error": "\(error)"])
        }
    }
}

struct VideoRow: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            VideoThumbnail(coverPath: video.coverPath, cornerRadius: 6)
                .frame(width: 96)
            VStack(alignment: .leading, spacing: 3) {
                Text(video.displayTitle).font(.subheadline.weight(.medium)).lineLimit(2)
                Text(video.sourceName).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

extension VideoItem {
    var displayTitle: String { customTitle ?? PlaybackStore.fileTitle(fileName) }
}

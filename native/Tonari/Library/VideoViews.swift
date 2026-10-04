import SwiftUI
import TonariCore
import UniformTypeIdentifiers

/// The videos the user kept, laid out and sorted like the works wall; what's
/// half watched is on the home page, not here.
struct VideoLibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(VideoController.self) private var video
    @Environment(\.appDatabase) private var database
    @State private var items: [VideoItem] = []
    @State private var loaded = false
    @State private var importing = false
    @State private var renaming: VideoItem?
    @State private var newTitle = ""
    @State private var removing: VideoItem?

    var body: some View {
        collection
            .overlay {
                if loaded && items.isEmpty {
                    ContentUnavailableView("还没有视频", systemImage: "film", description: Text("点右上角的 ⋯ 从「文件」导入，或在 115 浏览里长按视频加入"))
                }
            }
            .navigationTitle("视频")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .fileImporter(isPresented: $importing, allowedContentTypes: LocalVideoImport.contentTypes, allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result, !urls.isEmpty else { return }
                Task { await model.importVideos(urls, database: database) }
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
            .task(id: QueryKey(sort: model.videoSort, source: model.videoSource)) {
                let request = VideoQueries.library(sort: model.videoSort, source: model.videoSource)
                await database.observe({ try request.fetchAll($0) }) {
                    items = $0
                    loaded = true
                }
            }
    }

    private struct QueryKey: Equatable {
        let sort: VideoSort
        let source: SourceFilter
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        @Bindable var model = model
        ToolbarItem(placement: .topBarTrailing) {
            Menu("更多", systemImage: "ellipsis") {
                Section("添加") {
                    Button("从「文件」导入", systemImage: "folder") { importing = true }
                        .disabled(model.tasks.isBusy)
                    Button("从 115 添加", systemImage: "icloud") { model.openP115() }
                }
                Section("排序") {
                    ForEach(VideoSortField.allCases, id: \.self) { field in
                        Button {
                            model.videoSort = model.videoSort.selecting(field)
                        } label: {
                            if model.videoSort.field == field {
                                Label(field.label, systemImage: model.videoSort.descending ? "arrow.down" : "arrow.up")
                            } else {
                                Text(field.label)
                            }
                        }
                    }
                }
                Section("视图") {
                    Picker("视图", selection: $model.videoViewMode) {
                        ForEach(AppModel.ViewMode.allCases, id: \.self) {
                            Label($0.label, systemImage: $0.systemImage)
                        }
                    }
                }
                Section("来源") {
                    Picker("来源", selection: $model.videoSource) {
                        ForEach(SourceFilter.allCases, id: \.self) { Text($0.label) }
                    }
                }
            }
        }
    }

    // MARK: - Layouts

    @ViewBuilder private var collection: some View {
        switch model.videoViewMode {
        case .grid:
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                    ForEach(items) { item in
                        cell(item) {
                            VStack(alignment: .leading, spacing: 2) {
                                thumbnail(item, cornerRadius: 8).padding(.bottom, 4)
                                Text(item.displayTitle).font(.subheadline).lineLimit(1)
                                Text(item.sourceName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        case .list:
            List(items) { item in
                cell(item) { VideoRow(video: item) }
                    .swipeActions(edge: .leading) {
                        Button(item.isFavorite ? "取消收藏" : "收藏", systemImage: item.isFavorite ? "heart.slash" : "heart") {
                            try! database.setVideoFavorite(item.id, !item.isFavorite)
                        }
                        .tint(.pink)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("移出", systemImage: "trash", role: .destructive) { removing = item }
                    }
            }
            .listStyle(.plain)
        case .cover:
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(items) { item in
                        cell(item) {
                            VStack(alignment: .leading, spacing: 2) {
                                thumbnail(item, cornerRadius: 12).padding(.bottom, 6)
                                Text(item.displayTitle).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                                Text(item.sourceName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func cell(_ item: VideoItem, @ViewBuilder label: () -> some View) -> some View {
        Button { model.playVideo(PlayableVideo(item), with: video) } label: {
            label().contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu { menu(item) }
    }

    private func thumbnail(_ item: VideoItem, cornerRadius: CGFloat) -> some View {
        VideoThumbnail(coverPath: item.coverPath, cornerRadius: cornerRadius)
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

    private func remove(_ item: VideoItem) {
        if video.video?.id == item.id, item.sourceKind == "local" { video.close() }
        try! database.removeVideo(item.id)
        if item.sourceKind == "local" { LocalVideoImport.discard(item.path) }
    }
}

/// Videos half watched, library or not, straight from the play history.
nonisolated struct ContinueWatching: Sendable {
    var progress: [VideoProgress] = []
    var covers: [String: String] = [:]

    static func fetch(_ db: Database) throws -> ContinueWatching {
        let progress = try PlaybackStore.continueWatching(limit: 12, db)
        let rows = try VideoItem.filter(keys: progress.map(\.id)).fetchAll(db)
        return ContinueWatching(
            progress: progress,
            covers: Dictionary(uniqueKeysWithValues: rows.compactMap { row in row.coverPath.map { (row.id, $0) } })
        )
    }
}

/// 16:9 frames with a progress bar, paging sideways; a tap resumes.
struct ContinueWatchingRow: View {
    let watching: ContinueWatching
    @Environment(AppModel.self) private var model
    @Environment(VideoController.self) private var video

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(watching.progress) { item in
                    Button { model.playVideo(item.video, with: video) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            VideoThumbnail(coverPath: watching.covers[item.id])
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

    static func remaining(_ item: VideoProgress) -> String {
        let minutes = max(1, (item.durationMs - item.positionMs) / 60_000)
        return minutes >= 60 ? "\(minutes / 60) 小时 \(minutes % 60) 分钟" : "\(minutes) 分钟"
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

import SwiftUI
import TonariCore

/// A work after Apple Music's album page: cover, title and a play button,
/// the tracks of one folder paging sideways, then App Store style info.
struct WorkDetailView: View {
    let productId: String

    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var fetching = false
    @State private var work: Work?
    @State private var tracks: [Track] = []
    @State private var fileCount = 0
    @State private var subtitled: Set<String> = []
    @State private var chosenFolder: [String]?
    @State private var showsOriginal = false
    @State private var gallery: GallerySelection?
    @State private var coverIndex = 0
    @Namespace private var galleryZoom
    @State private var loaded = false
    @State private var subtitlePreview: SubtitlePreviewSource?

    var body: some View {
        ScrollView {
            if let work {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        cover(work)
                        titleBlock(work)
                        if loaded { playButtons(work) }
                    }
                    .padding(.horizontal, 16)
                    if loaded {
                        trackSection(work)
                        Group {
                            WorkInfoSection(work: work)
                            WorkTagsSection(work: work)
                            WorkCreditsSection(work: work)
                            WorkDescriptionSection(work: work, showsOriginal: showsOriginal, galleryZoom: galleryZoom) { gallery = $0 }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            // Only the cover and title go into the push transition's first
            // frame: a primary-key read keeps the tap responsive, and the rest
            // arrives from the observation a few frames later.
            if work == nil { work = try! database.reader.read { try WorkQueries.work(productId).fetchOne($0) } }
        }
        .navigationTitle(productId)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .fullScreenCover(item: $gallery) { GalleryView(selection: $0, namespace: galleryZoom) }
        .sheet(item: $subtitlePreview) { SubtitlePreviewSheet(source: $0) }
        .safeAreaInset(edge: .bottom) { TaskBanner() }
        .onChange(of: work?.isRemoved) { _, removed in
            if removed == true { dismiss() }
        }
        .task(id: work?.productId) {
            // Opening a work that was never enriched fetches it right away
            // instead of waiting for the background queue.
            guard let work, MetadataEnrichment.needsEnrichment(work, documents: .documentsDirectory) else { return }
            fetching = true
            do {
                try await enrichment.service.enrich(productId)
            } catch {
                DiagnosticLog.shared.write("metadata", "detail_enrich_failed", ["productId": productId, "error": "\(error)"])
            }
            fetching = false
        }
        .task {
            await database.observe(fetch, update: apply)
        }
    }

    private struct Snapshot: Sendable {
        let work: Work?
        let tracks: [Track]
        let fileCount: Int
        let subtitled: Set<String>
    }

    private var fetch: @Sendable (Database) throws -> Snapshot {
        { [productId] db in
            Snapshot(
                work: try WorkQueries.work(productId).fetchOne(db),
                tracks: try WorkQueries.tracks(of: productId).fetchAll(db),
                fileCount: try WorkQueries.tracks(of: productId).fetchCount(db) + WorkQueries.files(of: productId).fetchCount(db),
                subtitled: try WorkQueries.subtitledTrackIds(of: productId, db)
            )
        }
    }

    private func apply(_ snapshot: Snapshot) {
        work = snapshot.work
        tracks = snapshot.tracks
        fileCount = snapshot.fileCount
        subtitled = snapshot.subtitled
        loaded = true
    }

    // MARK: - Folders

    private var tree: [WorkTreeNode] { WorkTree.build(tracks: tracks, files: []) }

    private var folders: [AudioFolder] { WorkTree.audioFolders(tree) }

    private var folder: AudioFolder? {
        folders.first { $0.path == chosenFolder } ?? TrackFolderMemory.resolve(folders, tree: tree, productId: productId)
    }

    private func folderName(_ folder: AudioFolder) -> String {
        folder.path.isEmpty ? "根目录" : folder.path.joined(separator: " · ")
    }

    private func trackTitle(_ track: Track) -> String {
        if !showsOriginal, let zh = track.titleZh, !zh.isEmpty { zh } else { track.title }
    }

    // MARK: - Sections

    private func cover(_ work: Work) -> some View {
        let images = [work.mainImageLocalPath].compactMap(\.self) + work.sampleImageLocalPaths
        return TabView(selection: $coverIndex) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, path in
                LocalImage(path: path, contentMode: .fit)
                    .matchedTransitionSource(id: path, in: galleryZoom)
                    .onTapGesture {
                        gallery = GallerySelection(images: images.map(GalleryImage.local), index: index) { coverIndex = $0 }
                    }
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
        .aspectRatio(4 / 3, contentMode: .fit)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func titleBlock(_ work: Work) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if fetching {
                Label("正在获取 DLsite 资料…", systemImage: "arrow.down.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(showsOriginal ? work.title : work.displayTitle)
                .font(.title2.bold())
                .textSelection(.enabled)
            if !work.voiceActors.isEmpty {
                FlowLayout(spacing: 0, lineSpacing: 2) {
                    ForEach(Array(work.voiceActors.enumerated()), id: \.offset) { index, name in
                        Button((index > 0 ? "、" : "") + name) { model.push(.chip(WorkChip(.voiceActor, name))) }
                    }
                }
                .font(.body)
            }
            HStack(spacing: 0) {
                let circle = work.circleName.flatMap { $0.isEmpty ? nil : $0 }
                if let circle {
                    Button(circle) { model.push(.chip(WorkChip(.circle, circle))) }
                        .foregroundStyle(.secondary)
                }
                let rest = [work.releaseDate.map(Formatting.date), work.supportedLanguages.isEmpty ? nil : work.supportedLanguages.joined(separator: "、")]
                    .compactMap(\.self)
                ForEach(Array(rest.enumerated()), id: \.offset) { index, part in
                    Text((circle == nil && index == 0 ? "" : " · ") + part)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    /// Apple Music's black capsule (white in dark mode) between shuffle and
    /// favorite: resumes a work already started, else plays the shown folder.
    /// Works without audio still get the favorite button; play and shuffle
    /// are disabled.
    private func playButtons(_ work: Work) -> some View {
        let resumeTrack = tracks.first { $0.id == work.lastPlayedTrackId }
        return HStack(spacing: 14) {
            circleButton("随机播放", systemImage: "shuffle", tint: .primary) { shuffle(folder!) }
                .disabled(folder == nil)
            Button {
                if resumeTrack != nil { player.playWork(productId, database: database) } else { playFromStart(folder!) }
            } label: {
                Label(resumeTrack.map { "继续播放 · \(trackTitle($0))" } ?? "播放", systemImage: "play.fill")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.primary.opacity(folder == nil ? 0.3 : 1), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(folder == nil)
            circleButton(
                work.isFavorite ? "取消收藏" : "添加收藏", systemImage: work.isFavorite ? "heart.fill" : "heart",
                tint: work.isFavorite ? .pink : .primary
            ) {
                try! database.setFavorite(productId, !work.isFavorite)
            }
        }
    }

    private func circleButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(Color(.tertiarySystemFill), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder private func trackSection(_ work: Work) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let folder {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("曲目").font(.title3.bold())
                    Text("\(folder.tracks.count) 首").font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    if folders.count > 1 { folderMenu(folder) }
                }
                .padding(.horizontal, 16)
                TrackPager(
                    tracks: folder.tracks,
                    focusId: [player.currentTrack?.id, work.lastPlayedTrackId].compactMap(\.self)
                        .first { id in folder.tracks.contains { $0.id == id } },
                    subtitled: subtitled,
                    showsOriginal: showsOriginal
                ) { index in
                    let queue = try! PlaybackStore(database: database).queue(for: productId, folder: folder.path)
                    player.play(queue, at: index)
                } previewSubtitle: {
                    subtitlePreview = .track($0)
                } reveal: {
                    reveal($0)
                }
            }
            if fileCount > 0 {
                NavigationLink(value: Route.files(productId)) {
                    HStack {
                        Text("全部文件")
                        Spacer()
                        Text("\(fileCount) 项").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
        }
    }

    private func folderMenu(_ folder: AudioFolder) -> some View {
        Menu {
            ForEach(folders, id: \.path) { option in
                Toggle(isOn: Binding(get: { option.path == folder.path }, set: { _ in
                    chosenFolder = option.path
                    TrackFolderMemory.remember(option.path, for: productId)
                })) {
                    Text(folderName(option))
                    Text("\(option.tracks.count) 首")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(folderName(folder)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
            }
            .font(.subheadline)
        }
    }

    /// Turns shuffle on and starts the folder at a random track.
    private func shuffle(_ folder: AudioFolder) {
        player.prefs.mode = .shuffle
        let queue = try! PlaybackStore(database: database).queue(for: productId, folder: folder.path)
        player.play(queue, at: queue.tracks.indices.randomElement()!)
    }

    /// Opens the files page one folder at a time down to the track, so back
    /// steps up through each level, and flashes the track there.
    private func reveal(_ track: Track) {
        let files = try! database.reader.read { try WorkQueries.files(of: productId).fetchAll($0) }
        let steps = WorkTree.steps(WorkTree.build(tracks: tracks, files: files), to: track.folderPath)
        model.push(.files(productId, highlight: steps.isEmpty ? track.id : nil))
        for (index, step) in steps.enumerated() {
            model.push(.files(productId, folder: step.path, highlight: index == steps.count - 1 ? track.id : nil))
        }
    }

    private func playFromStart(_ folder: AudioFolder) {
        let queue = try! PlaybackStore(database: database).queue(for: productId, folder: folder.path)
        if player.currentTrack?.id == queue.tracks[0].id { player.seek(to: 0) }
        player.play(queue, at: 0)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if let work {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu("更多", systemImage: "ellipsis") {
                    Button("加入分组…", systemImage: "folder.badge.plus") { model.collectionPickerWork = work }
                    Link(destination: DLsite.workURL(productId)) {
                        Label("在 DLsite 中打开", systemImage: "safari")
                    }
                    Section("DLsite") {
                        Button("刷新元数据", systemImage: "arrow.triangle.2.circlepath") {
                            runRefresh("刷新元数据", done: "元数据已刷新") { try await $0.refreshMetadata(productId, onImage: $1) }
                        }
                        Button("只刷新图片", systemImage: "photo.on.rectangle") {
                            runRefresh("刷新图片", done: "图片已刷新") { try await $0.refreshImages(productId, onImage: $1) }
                        }
                        Button("更新统计数据", systemImage: "chart.bar") {
                            runRefresh("更新统计数据", done: "统计数据已更新") { service, _ in try await service.refreshStats(productId) }
                        }
                    }
                    .disabled(model.tasks.isBusy)
                    Section {
                        Button(showsOriginal ? "显示译文" : "显示原文", systemImage: "character.book.closed") {
                            showsOriginal.toggle()
                        }
                        Button("重新扫描此作品", systemImage: "arrow.clockwise") {
                            Task {
                                await model.tasks.run("重新扫描作品", detail: work.productId) {
                                    let summary = try await model.reimport(work, database: database)
                                    return "作品已重新扫描：\(summary.tracksTotal) 个音轨"
                                }
                            }
                        }
                        .disabled(model.tasks.isBusy)
                        Button("从媒体库移除", systemImage: "trash", role: .destructive) { model.removingWork = work }
                    }
                }
            }
        }
    }

    /// Runs a DLsite refresh as a library task, reporting image progress.
    private func runRefresh(
        _ title: String, done: String,
        _ operation: @escaping (MetadataEnrichment, @escaping MetadataEnrichment.ImageProgress) async throws -> Void
    ) {
        let tasks = model.tasks
        Task {
            await tasks.run(title, detail: productId) {
                try await operation(enrichment.service) { completed, total, label in
                    Task { @MainActor in tasks.report("\(label)（\(completed)/\(total)）") }
                }
                ThumbnailCache.shared.evict(prefix: "images/\(productId)/")
                return done
            }
        }
    }
}

enum DLsite {
    static func workURL(_ productId: String) -> URL {
        URL(string: "https://www.dlsite.com/maniax/work/=/product_id/\(productId).html/?locale=zh_CN")!
    }
}

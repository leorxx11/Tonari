import SwiftUI
import TonariCore

/// One 115 folder. Each level is its own page on the navigation stack, so
/// back steps up a single folder and the title names the current one. RJ
/// folders already in the library show their cover and title, looked up
/// locally so browsing costs no extra 115 requests; subfolders show no
/// summary for the same reason.
struct P115BrowserView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @Environment(PlaybackController.self) private var player
    @Environment(VideoController.self) private var video
    /// From the 115 root down to this folder.
    let stack: [RemoteEntry]
    @State private var entries: [RemoteEntry] = []
    @State private var loaded = false
    @State private var loading = false
    @State private var error: Error?
    @State private var confirmingImport = false
    @State private var imported: [String: Work] = [:]
    @State private var subtitlePreview: SubtitlePreviewSource?
    @State private var textPreview: PreviewFile?
    @State private var gallery: GallerySelection?
    @Namespace private var galleryZoom

    private var current: RemoteEntry { stack.last! }

    var body: some View {
        List {
            if loaded && !entries.isEmpty { rows }
        }
        .listStyle(.plain)
        .overlay { overlay }
        .safeAreaInset(edge: .bottom) { TaskBanner() }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        // The folder name sits beside the back button and stays put while
        // scrolling; the title is kept for the back button's history menu.
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // The bar sizes an item once from what it reports; without an
                // ideal width of its own a short name can end up truncated.
                Text(current.name)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: 220, alignment: .leading)
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Kept out of the list, where it was easy to hit by accident.
                Button("导入此文件夹", systemImage: "square.and.arrow.down") { confirmingImport = true }
                    .disabled(!loaded || model.tasks.isBusy)
                if stack.count > 1 {
                    Button("回到浏览首页", systemImage: "house") {
                        model.browsePath = NavigationPath()
                    }
                }
            }
        }
        .alert("导入到媒体库", isPresented: $confirmingImport) {
            Button("取消", role: .cancel) {}
            Button("导入") { startImport(current) }
        } message: {
            let rjIds = entries.filter(\.isFolder).compactMap { RJID.extract($0.name) }
            let progress = rjIds.isEmpty ? "" : "这里有 \(rjIds.count) 个 RJ 文件夹，已导入 \(rjIds.count { imported[$0] != nil }) 个。\n"
            Text("扫描「\(current.name)」下的所有 RJ 作品并导入媒体库？\n\(progress)导入在后台进行，可以继续浏览。")
        }
        .sheet(item: $subtitlePreview) { SubtitlePreviewSheet(source: $0) }
        .sheet(item: $textPreview) { TextPreviewSheet(file: $0) }
        .fullScreenCover(item: $gallery) { GalleryView(selection: $0, namespace: galleryZoom) }
        .refreshable { await load() }
        // Coming back from a subfolder keeps the listing instead of spending
        // another rate-limited request on it.
        .task { if !loaded { await load() } }
        .task(id: entries.map(\.id)) {
            let ids = entries.filter(\.isFolder).compactMap { RJID.extract($0.name) }
            await database.observe({ db in
                try Work.filter(ids.contains(Column("product_id"))).filter(Column("is_removed") == false).fetchAll(db)
            }) { works in
                imported = Dictionary(uniqueKeysWithValues: works.map { ($0.productId, $0) })
            }
        }
        .onAppear { BrowseLocation.save(stack, P115Client.sourceId) }
    }

    @ViewBuilder private var rows: some View {
        let audio = entries.filter { $0.kind == .audio }
        let images = entries.filter { $0.kind == .image }
        if !audio.isEmpty {
            Button {
                player.play(files: audio, at: 0, sourceName: P115Client.sourceName)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 34, height: 34)
                        .background(Color.primary, in: .circle)
                    Text("播放本文件夹").fontWeight(.semibold)
                    Spacer()
                    Text("\(audio.count) 首").foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
        ForEach(entries) { entry in
            if entry.isFolder {
                folderRow(entry)
            } else {
                fileRow(entry, audio: audio, images: images)
            }
        }
    }

    @ViewBuilder private func folderRow(_ entry: RemoteEntry) -> some View {
        let rjId = RJID.extract(entry.name)
        let work = rjId.flatMap { imported[$0] }
        NavigationLink(value: Route.p115Folder(stack + [entry])) {
            if let work {
                HStack(spacing: 12) {
                    LocalImage(path: work.mainImageLocalPath)
                        .frame(width: 64, height: 48)
                        .clipShape(.rect(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(work.displayTitle).font(.subheadline).lineLimit(2)
                        Text("\(work.productId) · 已导入").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else {
                FileRow(icon: "folder.fill", tint: .blue, title: entry.name, detail: rjId.map { "\($0) · 未导入" } ?? "文件夹")
            }
        }
        .contextMenu {
            if let work {
                Button("打开作品", systemImage: "music.note.list") { model.browsePath.append(Route.work(work.productId)) }
            }
        }
        .swipeActions(edge: .trailing) {
            if rjId != nil && work == nil {
                Button("导入", systemImage: "square.and.arrow.down") { startImport(entry) }
                    .tint(.blue)
                    .disabled(model.tasks.isBusy)
            }
        }
    }

    @ViewBuilder private func fileRow(_ entry: RemoteEntry, audio: [RemoteEntry], images: [RemoteEntry]) -> some View {
        let (icon, tint) = fileIcon(entry.kind.rawValue)
        let size = entry.size.map(Formatting.bytes) ?? ""
        switch entry.kind {
        case .audio:
            let playing = player.currentFile?.id == entry.id
            Button {
                player.play(files: audio, at: audio.firstIndex(of: entry)!, sourceName: P115Client.sourceName)
            } label: {
                FileRow(icon: playing ? "waveform" : icon, tint: tint, title: entry.name, detail: playing ? "正在播放 · \(size)" : size)
            }
            .tint(.primary)
        case .subtitle:
            Button { subtitlePreview = .file(.p115(entry)) } label: {
                FileRow(icon: icon, tint: tint, title: entry.name, detail: size)
            }
            .tint(.primary)
        case .image:
            Button {
                gallery = GallerySelection(images: images.map { .file(.p115($0)) }, index: images.firstIndex(of: entry)!)
            } label: {
                FileRow(icon: icon, tint: tint, title: entry.name, detail: size)
            }
            .tint(.primary)
            .matchedTransitionSource(id: entry.id, in: galleryZoom)
        case .text:
            Button { textPreview = .p115(entry) } label: {
                FileRow(icon: icon, tint: tint, title: entry.name, detail: size)
            }
            .tint(.primary)
        case .video:
            Button {
                model.playVideo(entry, sourceName: P115Client.sourceName, with: video)
            } label: {
                FileRow(icon: video.entry?.id == entry.id ? "play.rectangle.fill" : icon, tint: tint, title: entry.name, detail: size)
            }
            .tint(.primary)
        case .folder, .other:
            FileRow(icon: icon, tint: tint, title: entry.name, detail: size)
        }
    }

    @ViewBuilder private var overlay: some View {
        if let error {
            ContentUnavailableView {
                Label("加载失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                if error as? P115Error == .authExpired || error as? P115Error == .notLoggedIn {
                    NavigationLink("重新登录", value: Route.p115Login)
                } else {
                    Button("重试") { Task { await load() } }
                }
            }
        } else if loading && entries.isEmpty {
            ProgressView()
        } else if !loading && loaded && entries.isEmpty {
            ContentUnavailableView("此目录为空", systemImage: "folder")
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            entries = try await P115Client.shared.list(current.path)
            loaded = true
        } catch is CancellationError {
        } catch {
            self.error = error
            DiagnosticLog.shared.write("p115", "list_failed", ["cid": current.path, "error": "\(error)"])
        }
        loading = false
    }

    private func startImport(_ folder: RemoteEntry) {
        Task { await model.importP115Folder(folder, database: database, enrichment: enrichment) }
    }
}

/// The folder stack last browsed per source, as the Flutter build stored it
/// under `browse_stack_<sourceId>`: `[{id, path, name, sourceId}]`.
enum BrowseLocation {
    static let p115Root = RemoteEntry(id: "0", path: "0", name: P115Client.sourceName, kind: .folder, sourceId: P115Client.sourceId)

    private struct Stored: Codable {
        let id: String
        let path: String
        let name: String
        let sourceId: String
    }

    static func load(_ sourceId: String) -> [RemoteEntry]? {
        guard let raw = UserDefaults.standard.string(forKey: "browse_stack_\(sourceId)"),
              let stored = try? JSONDecoder().decode([Stored].self, from: Data(raw.utf8)), !stored.isEmpty
        else { return nil }
        return stored.map { RemoteEntry(id: $0.id, path: $0.path, name: $0.name, kind: .folder, sourceId: $0.sourceId) }
    }

    /// A page per level of the stack last browsed, or the root.
    static func routes(_ sourceId: String) -> [Route] {
        let stack = load(sourceId) ?? [p115Root]
        return stack.indices.map { .p115Folder(Array(stack.prefix($0 + 1))) }
    }

    static func save(_ stack: [RemoteEntry], _ sourceId: String) {
        let stored = stack.map { Stored(id: $0.id, path: $0.path, name: $0.name, sourceId: $0.sourceId) }
        UserDefaults.standard.set(String(decoding: try! JSONEncoder().encode(stored), as: UTF8.self), forKey: "browse_stack_\(sourceId)")
    }
}

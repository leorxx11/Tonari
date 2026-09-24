import SwiftUI
import TonariCore

/// One 115 folder. Each level is its own page on the navigation stack, so
/// back steps up a single folder and the title names the current one.
/// Playing files arrives with the player (N3) and video library (N5).
struct P115BrowserView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    /// From the 115 root down to this folder.
    let stack: [RemoteEntry]
    @State private var entries: [RemoteEntry] = []
    @State private var loaded = false
    @State private var loading = false
    @State private var error: Error?
    @State private var confirmingImport = false

    private var current: RemoteEntry { stack.last! }

    var body: some View {
        List {
            ForEach(entries) { entry in
                if entry.isFolder {
                    NavigationLink(value: Route.p115Folder(stack + [entry])) {
                        RemoteEntryRow(entry: entry)
                    }
                } else {
                    RemoteEntryRow(entry: entry)
                }
            }
        }
        .listStyle(.plain)
        .overlay { overlay }
        .safeAreaInset(edge: .bottom) { TaskBanner() }
        .navigationTitle(current.name)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("导入到媒体库", systemImage: "square.and.arrow.down") { confirmingImport = true }
                    .disabled(model.tasks.isBusy)
            }
        }
        .alert("导入到媒体库", isPresented: $confirmingImport) {
            Button("取消", role: .cancel) {}
            Button("导入") { startImport(current) }
        } message: {
            Text("扫描「\(current.name)」下的所有 RJ 作品并导入媒体库？\n导入在后台进行，可以继续浏览。")
        }
        .refreshable { await load() }
        // Coming back from a subfolder keeps the listing instead of spending
        // another rate-limited request on it.
        .task { if !loaded { await load() } }
        .onAppear { BrowseLocation.save(stack, P115Client.sourceId) }
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
        } else if !loading && entries.isEmpty {
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
        let tasks = model.tasks
        let importer = P115Import(database: database, client: .shared)
        Task {
            await tasks.run("导入 115 网盘", detail: folder.name) {
                let summary = try await importer.importFolder(folder) { found, current in
                    Task { @MainActor in tasks.report("已找到 \(found) 个作品 · \(current)") }
                }
                return summary.resultText
            }
            await enrichment.runPending()
        }
    }
}

struct RemoteEntryRow: View {
    let entry: RemoteEntry

    var body: some View {
        HStack(spacing: 12) {
            let (icon, tint) = Self.icon(entry.kind)
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.subheadline).lineLimit(3)
                if let size = entry.size {
                    Text(Formatting.bytes(size)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    static func icon(_ kind: RemoteEntry.Kind) -> (String, Color) {
        switch kind {
        case .folder: ("folder.fill", .blue)
        case .audio: ("music.note", .pink)
        case .video: ("film", .purple)
        case .image: ("photo", .green)
        case .subtitle: ("captions.bubble", .cyan)
        case .text: ("doc.text", .orange)
        case .other: ("doc", .gray)
        }
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

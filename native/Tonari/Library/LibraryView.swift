import SwiftUI
import TonariCore

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var durations: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []
    @State private var libraryEmpty = false
    @State private var pickingFolder = false

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.libraryPath) {
            Group {
                switch model.libraryKind {
                case .audio:
                    WorkCollectionView(works: works, durations: durations, remoteIds: remoteIds)
                        .overlay { emptyState }
                case .video:
                    VideoListView()
                }
            }
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
            .alert("音声库还是空的", isPresented: $libraryEmpty) {}
            .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                Task { await importFolder(url) }
            }
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .appDestinations()
        }
        .task(id: QueryKey(sort: model.sort, source: model.source)) {
            let request = WorkQueries.library(sort: model.sort, source: model.source)
            await database.observe({ try request.fetchAll($0) }) { works = $0 }
        }
        .task {
            await database.observe({ db in
                (try WorkQueries.durations(db), try WorkQueries.remoteFolderIds(db))
            }) {
                durations = $0.0
                remoteIds = $0.1
            }
        }
    }

    /// Works still missing DLsite metadata or their cover.
    private var pendingEnrichment: Int {
        works.count { MetadataEnrichment.needsEnrichment($0, documents: .documentsDirectory) }
    }

    private struct QueryKey: Equatable {
        let sort: WorkSort
        let source: SourceFilter
    }

    @ViewBuilder private var emptyState: some View {
        if works.isEmpty {
            ContentUnavailableView {
                Label("媒体库还是空的", systemImage: "music.note")
            } description: {
                Text("导入一个包含 RJ 编号的文件夹开始使用")
            } actions: {
                Button("导入本地文件夹") { pickingFolder = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        @Bindable var model = model
        ToolbarItem(placement: .principal) {
            Picker("媒体库", selection: $model.libraryKind) {
                ForEach(AppModel.LibraryKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        if model.libraryKind == .audio {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("随机来一部", systemImage: "dice", action: pickRandom)
                Menu("更多", systemImage: "ellipsis") {
                    Section("导入") {
                        Button("导入本地文件夹", systemImage: "folder.badge.plus") { pickingFolder = true }
                            .disabled(model.tasks.isBusy)
                        Button("从 115 导入", systemImage: "icloud.and.arrow.down") {
                            model.openP115()
                        }
                        if pendingEnrichment > 0 && !enrichment.isActive {
                            Button("补全 \(pendingEnrichment) 个作品的资料", systemImage: "arrow.down.circle") {
                                Task { await enrichment.runPending(reset: true) }
                            }
                        }
                    }
                    Section("排序") {
                        ForEach(WorkSortField.allCases, id: \.self) { field in
                            Button {
                                model.sort = model.sort.selecting(field)
                            } label: {
                                if model.sort.field == field {
                                    Label(field.label, systemImage: model.sort.descending ? "arrow.down" : "arrow.up")
                                } else {
                                    Text(field.label)
                                }
                            }
                        }
                    }
                    Section("视图") {
                        Picker("视图", selection: $model.viewMode) {
                            ForEach(AppModel.ViewMode.allCases, id: \.self) {
                                Label($0.label, systemImage: $0.systemImage)
                            }
                        }
                    }
                    Section("来源") {
                        Picker("来源", selection: $model.source) {
                            ForEach(SourceFilter.allCases, id: \.self) { Text($0.label) }
                        }
                    }
                }
            }
        }
    }

    private func importFolder(_ url: URL) async {
        let flow = LocalImport(database: database)
        await model.tasks.run("导入本地文件夹", detail: url.lastPathComponent) {
            let folder = try flow.addFolder(url)
            let summary = try await flow.importFolder(folder)
            if summary.workIds.isEmpty { try flow.removeIfEmpty(folder) }
            return summary.resultText
        }
        await enrichment.runPending()
    }

    private func pickRandom() {
        if let work = try! database.reader.read(WorkQueries.random) {
            model.libraryPath.append(Route.work(work.productId))
        } else {
            libraryEmpty = true
        }
    }
}

/// Works in the chosen layout: full-width cards, a two-column grid or
/// compact rows.
struct WorkCollectionView: View {
    let works: [Work]
    let durations: [String: Int]
    let remoteIds: Set<String>

    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.viewMode {
        case .list:
            List(works) { work in
                NavigationLink(value: Route.work(work.productId)) {
                    WorkRow(work: work, durationMs: durations[work.productId])
                }
                .workContextMenu(work)
            }
            .listStyle(.plain)
        case .grid:
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(works) { work in
                        NavigationLink(value: Route.work(work.productId)) {
                            WorkGridCell(work: work, isRemote: isRemote(work), durationMs: durations[work.productId])
                        }
                        .buttonStyle(.plain)
                        .workContextMenu(work)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemGroupedBackground))
        case .card:
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(works) { work in
                        NavigationLink(value: Route.work(work.productId)) {
                            WorkCard(work: work, isRemote: isRemote(work), durationMs: durations[work.productId])
                        }
                        .buttonStyle(.plain)
                        .workContextMenu(work)
                    }
                }
                .padding(12)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private func isRemote(_ work: Work) -> Bool {
        work.importedFolderId.map(remoteIds.contains) ?? false
    }
}

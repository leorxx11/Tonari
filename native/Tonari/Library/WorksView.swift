import SwiftUI
import TonariCore

/// Every work in the library as a wall, reached from the library tab's
/// 作品 row: three layouts, sort, source filter, random and imports.
struct WorksView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var trackCounts: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []
    @State private var pickingFolder = false

    var body: some View {
        WorkCollectionView(works: works, trackCounts: trackCounts, remoteIds: remoteIds)
            .overlay { emptyState }
            .navigationTitle("作品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                Task { await model.importLocalFolder(url, database: database, enrichment: enrichment) }
            }
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .task(id: QueryKey(sort: model.sort, source: model.source)) {
                let request = WorkQueries.library(sort: model.sort, source: model.source)
                await database.observe({ try request.fetchAll($0) }) { works = $0 }
            }
            .task {
                await database.observe({ db in
                    (try WorkQueries.trackCounts(db), try WorkQueries.remoteFolderIds(db))
                }) {
                    trackCounts = $0.0
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
                Label("还没有作品", systemImage: "music.note")
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

    private func pickRandom() {
        model.openRandomWork(database: database)
    }
}

/// Works in the chosen layout: a cover grid, compact rows or one full-width
/// cover per row.
struct WorkCollectionView: View {
    let works: [Work]
    let trackCounts: [String: Int]
    let remoteIds: Set<String>

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database

    var body: some View {
        switch model.viewMode {
        case .grid:
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
                    ForEach(works) { work in
                        link(work) { WorkGridCell(work: work, isRemote: isRemote(work)) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        case .list:
            List(works) { work in
                NavigationLink(value: Route.work(work.productId)) {
                    WorkListRow(work: work, isRemote: isRemote(work), trackCount: trackCounts[work.productId] ?? 0)
                }
                .navigationLinkIndicatorVisibility(.hidden)
                .workContextMenu(work, trackCount: trackCounts[work.productId] ?? 0)
                .swipeActions(edge: .leading) {
                    Button(work.isFavorite ? "取消收藏" : "收藏", systemImage: work.isFavorite ? "heart.slash" : "heart") {
                        try! database.setFavorite(work.productId, !work.isFavorite)
                    }
                    .tint(.pink)
                }
                .swipeActions(edge: .trailing) {
                    Button("移除", systemImage: "trash", role: .destructive) { model.removingWork = work }
                }
            }
            .listStyle(.plain)
        case .cover:
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(works) { work in
                        link(work) { WorkCoverCell(work: work, isRemote: isRemote(work)) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func link(_ work: Work, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink(value: Route.work(work.productId), label: label)
            .buttonStyle(.plain)
            .workContextMenu(work, trackCount: trackCounts[work.productId] ?? 0)
    }

    private func isRemote(_ work: Work) -> Bool {
        work.importedFolderId.map(remoteIds.contains) ?? false
    }
}

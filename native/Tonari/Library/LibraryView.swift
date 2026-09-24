import SwiftUI
import TonariCore

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var durations: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []
    @State private var libraryEmpty = false

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.libraryPath) {
            Group {
                switch model.libraryKind {
                case .audio:
                    WorkCollectionView(works: visibleWorks, durations: durations, remoteIds: remoteIds)
                        .overlay { emptyState }
                        .searchable(text: $model.filter.searchText, prompt: "搜索 RJ、标题、CV、社团，#标签")
                        .safeAreaInset(edge: .top) { chipBar }
                case .video:
                    VideoListView()
                }
            }
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
            .alert("音声库还是空的", isPresented: $libraryEmpty) {}
            .appDestinations()
        }
        .task(id: QueryKey(sort: model.sort, source: model.filter.source)) {
            let request = WorkQueries.library(sort: model.sort, source: model.filter.source)
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

    private struct QueryKey: Equatable {
        let sort: WorkSort
        let source: SourceFilter
    }

    private var visibleWorks: [Work] {
        model.filter.isEmpty ? works : works.filter(model.filter.matches)
    }

    @ViewBuilder private var emptyState: some View {
        if works.isEmpty {
            ContentUnavailableView("媒体库还是空的", systemImage: "music.note", description: Text("导入一个包含 RJ 编号的文件夹开始使用"))
        } else if visibleWorks.isEmpty {
            ContentUnavailableView.search
        }
    }

    @ViewBuilder private var chipBar: some View {
        if !model.filter.chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.filter.chips, id: \.self) { chip in
                        Button {
                            model.filter.chips.removeAll { $0 == chip }
                        } label: {
                            HStack(spacing: 4) {
                                Text(chip.label)
                                Image(systemName: "xmark").font(.caption2.bold())
                            }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .background(.bar)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        @Bindable var model = model
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink(value: Route.categories) {
                Image(systemName: "tag")
            }
            .accessibilityLabel("分类")
        }
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
                        Picker("来源", selection: $model.filter.source) {
                            ForEach(SourceFilter.allCases, id: \.self) { Text($0.label) }
                        }
                    }
                }
            }
        }
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

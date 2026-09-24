import SwiftUI
import TonariCore

/// Circles, voice actors and tags across the library; picking one filters the
/// library by it.
struct CategoriesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var stats: LibraryStats?
    @State private var kind = WorkChip.Kind.circle
    @State private var query = ""
    @State private var byName = false

    private static let kinds: [(WorkChip.Kind, String)] = [(.circle, "社团"), (.voiceActor, "声优"), (.genre, "标签")]

    var body: some View {
        List(entries, id: \.name) { entry in
            Button {
                model.showInLibrary(WorkChip(kind, entry.name))
            } label: {
                LabeledContent(entry.name) {
                    Text("\(entry.count)").monospacedDigit()
                }
            }
            .tint(.primary)
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "搜索社团、声优、标签…")
        .safeAreaInset(edge: .top) {
            Picker("分类", selection: $kind) {
                ForEach(Self.kinds, id: \.0) { Text($0.1).tag($0.0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .overlay {
            if stats != nil && entries.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView("没有数据", systemImage: "tag", description: Text("作品抓取元数据后会出现在这里"))
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("分类")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(byName ? "按作品数排序" : "按名称排序", systemImage: byName ? "number" : "textformat") {
                byName.toggle()
            }
        }
        .task {
            await database.observe({ db in
                LibraryStats(try Work.filter(Column("is_removed") == false).fetchAll(db))
            }) { stats = $0 }
        }
    }

    private var entries: [LibraryStats.Entry] {
        var entries = stats?.entries(for: kind) ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !trimmed.isEmpty { entries = entries.filter { $0.name.lowercased().contains(trimmed) } }
        if byName { entries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        return entries
    }
}

import SwiftUI
import TonariCore

/// Imported sources with how many works each holds; deleting one takes its
/// works with it.
struct MediaSourcesView: View {
    @Environment(\.appDatabase) private var database
    @State private var sources: [SourceQueries.Source] = []
    @State private var deleting: SourceQueries.Source?

    var body: some View {
        List(sources) { source in
            VStack(alignment: .leading, spacing: 2) {
                Label(source.folder.displayName, systemImage: source.folder.type == "local" ? "folder" : "icloud")
                Text("\(Self.label(source.folder.type)) · \(source.workCount) 个作品")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .swipeActions {
                Button("删除", systemImage: "trash", role: .destructive) { deleting = source }
            }
            .contextMenu {
                Button("删除来源", systemImage: "trash", role: .destructive) { deleting = source }
            }
        }
        .overlay {
            if sources.isEmpty {
                ContentUnavailableView("还没有导入任何来源", systemImage: "folder")
            }
        }
        .navigationTitle("媒体来源")
        .navigationBarTitleDisplayMode(.inline)
        .alert("删除来源", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                try! database.deleteSource(deleting!.id)
            }
        } message: {
            if let deleting {
                Text(deleting.workCount == 0
                    ? "将移除来源「\(deleting.folder.displayName)」。确定？"
                    : "将移除来源「\(deleting.folder.displayName)」及其下 \(deleting.workCount) 个作品（含播放记录、收藏），不可恢复。确定？")
            }
        }
        .task {
            await database.observe(SourceQueries.all) { sources = $0 }
        }
    }

    static func label(_ type: String) -> String {
        switch type {
        case "local": "本地"
        case "webdav": "WebDAV"
        case "p115": "115 网盘"
        default: type
        }
    }
}

/// Tombstoned works: reimport brings one back; deleting forgets it so the
/// next import adds it as new.
struct RemovedWorksView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var works: [Work] = []
    @State private var forgetting: Work?

    var body: some View {
        List(works) { work in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(work.displayTitle).lineLimit(2)
                    Text("\(work.productId) · 快照已清除").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("重新导入", systemImage: "arrow.clockwise") {
                    Task {
                        await model.tasks.run("重新导入作品", detail: work.productId) {
                            _ = try await model.reimport(work, database: database)
                            return "已重新导入 \(work.displayTitle)"
                        }
                    }
                }
                .labelStyle(.iconOnly)
                .disabled(model.tasks.isBusy)
                Button("彻底移除", systemImage: "trash", role: .destructive) { forgetting = work }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .overlay {
            if works.isEmpty {
                ContentUnavailableView("没有已移除作品", systemImage: "trash")
            }
        }
        .safeAreaInset(edge: .bottom) { TaskBanner() }
        .navigationTitle("已移除作品")
        .navigationBarTitleDisplayMode(.inline)
        .alert("彻底移除", isPresented: Binding(get: { forgetting != nil }, set: { if !$0 { forgetting = nil } })) {
            Button("取消", role: .cancel) {}
            Button("彻底移除", role: .destructive) {
                try! database.deleteWorkPermanently(forgetting!.productId)
            }
        } message: {
            if let forgetting {
                Text("将永久删除「\(forgetting.displayTitle)」的移除记录。下次导入会作为新作品加入。确定？")
            }
        }
        .task {
            await database.observe(SourceQueries.removedWorks) { works = $0 }
        }
    }
}

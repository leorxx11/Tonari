import Observation
import SwiftUI
import TonariCore

/// The import or rescan currently running, shown as a banner over the
/// library; the outcome shows as a notice, and failures also go to the
/// message inbox, where they outlive it.
@Observable
final class LibraryTasks {
    private let database: AppDatabase
    private let notices: Notices
    struct Running: Equatable {
        let title: String
        var detail: String
    }

    private(set) var running: Running?

    var isBusy: Bool { running != nil }

    init(database: AppDatabase, notices: Notices) {
        self.database = database
        self.notices = notices
    }

    /// Updates the running task's detail line, e.g. with progress.
    func report(_ detail: String) {
        running?.detail = detail
    }

    func run(_ title: String, detail: String, _ operation: () async throws -> String) async {
        running = Running(title: title, detail: detail)
        DiagnosticLog.shared.write("library_task", "start", ["title": title, "detail": detail])
        do {
            notices.show(try await operation())
            DiagnosticLog.shared.write("library_task", "done", ["title": title])
        } catch {
            notices.show("\(title)失败：\(error.localizedDescription)", .failure)
            DiagnosticLog.shared.write("library_task", "failed", ["title": title, "error": "\(error)"])
            try! database.logEvent(
                category: "task", title: "\(title)失败", detail: error.localizedDescription,
                action: error as? P115Error == .authExpired ? .reauth : nil
            )
        }
        running = nil
    }
}

extension AppModel {
    /// Adds a folder picked in Files as a source and imports its RJ works.
    func importLocalFolder(_ url: URL, database: AppDatabase, enrichment: EnrichmentQueue) async {
        let flow = LocalImport(database: database)
        await tasks.run("导入本地文件夹", detail: url.lastPathComponent) {
            let folder = try flow.addFolder(url)
            let summary = try await flow.importFolder(folder)
            if summary.workIds.isEmpty { try flow.removeIfEmpty(folder) }
            return summary.resultText
        }
        await enrichment.runPending()
    }

    /// Imports RJ works found in a 115 folder, or the one work it is.
    func importP115Folder(_ folder: RemoteEntry, database: AppDatabase, enrichment: EnrichmentQueue) async {
        let importer = P115Import(database: database, client: .shared)
        let tasks = tasks
        await tasks.run("导入 115 网盘", detail: folder.name) {
            let summary = try await importer.importFolder(folder) { found, current in
                Task { @MainActor in tasks.report("已找到 \(found) 个作品 · \(current)") }
            }
            if !summary.incompleteWorks.isEmpty {
                try database.logEvent(
                    category: "import", severity: .warning, title: "\(summary.incompleteWorks.count) 个作品扫描失败",
                    detail: "疑似 115 风控，已跳过，可稍后重新导入整个文件夹。", sourceName: folder.name
                )
            }
            return summary.resultText
        }
        await enrichment.runPending()
    }
    /// Copies videos picked in Files into the app and adds them to the library.
    func importVideos(_ urls: [URL], database: AppDatabase) async {
        let tasks = tasks
        await tasks.run("导入视频", detail: "0 / \(urls.count)") {
            for (index, url) in urls.enumerated() {
                try database.addVideo(try await LocalVideoImport.adopt(url))
                tasks.report("\(index + 1) / \(urls.count)")
            }
            return "已导入 \(urls.count) 个视频"
        }
    }

    /// Rescans one work from its source, reviving it if removed.
    func reimport(_ work: Work, database: AppDatabase) async throws -> ImportSummary {
        let folder = try await database.reader.read { db in
            try work.importedFolderId.flatMap { try ImportedFolder.fetchOne(db, key: $0) }
        }
        guard let folder else { throw LocalImport.Failure("原始导入位置已不存在，无法重新扫描") }
        switch folder.type {
        case "local": return try await LocalImport(database: database).reimportWork(work, from: folder)
        case "p115": return try await P115Import(database: database, client: .shared).reimportWork(work)
        default: throw LocalImport.Failure("暂不支持重新扫描 WebDAV 来源")
        }
    }
}

/// Progress of the running library task, pinned above the bottom edge.
struct TaskBanner: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment

    var body: some View {
        if let running = model.tasks.running {
            banner(running.title, running.detail)
        } else if let current = enrichment.current {
            banner("补全资料 \(enrichment.done + 1)/\(enrichment.total)", current)
        }
    }

    private func banner(_ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

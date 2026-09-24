import Observation
import SwiftUI
import TonariCore

/// The import or rescan currently running, shown as a banner over the
/// library, and the result of the last one.
@Observable
final class LibraryTasks {
    struct Running: Equatable {
        let title: String
        var detail: String
    }

    private(set) var running: Running?
    /// Outcome text to show once a task finishes.
    var result: String?

    var isBusy: Bool { running != nil }

    /// Updates the running task's detail line, e.g. with progress.
    func report(_ detail: String) {
        running?.detail = detail
    }

    func run(_ title: String, detail: String, _ operation: () async throws -> String) async {
        running = Running(title: title, detail: detail)
        DiagnosticLog.shared.write("library_task", "start", ["title": title, "detail": detail])
        do {
            result = try await operation()
            DiagnosticLog.shared.write("library_task", "done", ["title": title])
        } catch {
            result = "\(title)失败：\(error.localizedDescription)"
            DiagnosticLog.shared.write("library_task", "failed", ["title": title, "error": "\(error)"])
        }
        running = nil
    }
}

extension AppModel {
    /// Rescans one work from its source, reviving it if removed.
    func reimport(_ work: Work, database: AppDatabase) async throws -> ImportSummary {
        let folder = try await database.reader.read { db in
            try work.importedFolderId.flatMap { try ImportedFolder.fetchOne(db, key: $0) }
        }
        guard let folder else { throw LocalImport.Failure("原始导入位置已不存在，无法重新扫描") }
        switch folder.type {
        case "local": return try await LocalImport(database: database).reimportWork(work, from: folder)
        case "p115": return try await P115Import(database: database, client: .shared).reimportWork(work)
        default: throw LocalImport.Failure("WebDAV 来源的重新扫描将在 N4b 支持")
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

import SwiftUI
import TonariCore

/// Export runs as a background task (progress in the task banner, outcome
/// in the inbox); restore stages the copy here and applies on next launch.
struct BackupView: View {
    private enum Phase {
        case idle
        case confirming(URL, BackupManifest)
        case staging(done: Int64, total: Int64)
        case staged
        case failed(String)
    }

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var phase = Phase.idle
    @State private var picking = false
    @State private var pickingForExport = false
    @State private var included = Set(BackupDir.allCases)
    @State private var sizes: [BackupDir: Int64] = [:]
    @State private var confirmingExport = false

    var body: some View {
        List {
            Section {
                ForEach(BackupDir.allCases, id: \.self) { dir in
                    Toggle(isOn: Binding(
                        get: { included.contains(dir) },
                        set: { if $0 { included.insert(dir) } else { included.remove(dir) } }
                    )) {
                        Text(dir.label)
                        Text(sizes[dir].map { Formatting.bytes(Int($0)) } ?? "计算中…")
                    }
                }
                Button("导出备份…") { confirmingExport = true }
                    .disabled(model.tasks.isBusy)
            } header: {
                Text("导出")
            }

            Section {
                Button("从备份恢复…") {
                    pickingForExport = false
                    picking = true
                }
                .disabled(isBusy)
                switch phase {
                case .staging(let done, let total):
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView("正在复制备份", value: Double(done), total: Double(max(total, 1)))
                        Text("\(done.formatted(.byteCount(style: .file))) / \(total.formatted(.byteCount(style: .file)))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                case .staged:
                    VStack(alignment: .leading, spacing: 2) {
                        Label("备份已就绪", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("从后台完全关闭 App 再打开，即完成恢复").font(.subheadline).foregroundStyle(.secondary)
                    }
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                case .idle, .confirming:
                    EmptyView()
                }
            } header: {
                Text("恢复")
            }
        }
        .navigationTitle("备份与恢复")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            sizes = await Self.sizes()
        }
        .confirmationDialog("导出备份", isPresented: $confirmingExport, titleVisibility: .visible) {
            Button("选择保存位置…") {
                pickingForExport = true
                picking = true
            }
        } message: {
            Text("备份包含 115、DLsite 登录和翻译 API Key 等账号凭据，请妥善保管。导出在后台进行，完成后会在消息里通知。")
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            if pickingForExport { export(to: url) } else { inspect(url) }
        }
        .alert("确认恢复？", isPresented: isConfirming) {
            Button("取消", role: .cancel) {
                if case .confirming(let url, _) = phase { url.stopAccessingSecurityScopedResource() }
                phase = .idle
            }
            Button("恢复", role: .destructive) {
                if case .confirming(let url, _) = phase { stage(url) }
            }
        } message: {
            if case .confirming(_, let manifest) = phase {
                Text("备份时间：\(manifest.createdAt.prefix(16).replacingOccurrences(of: "T", with: " "))\n恢复会覆盖当前的媒体库数据和设置，且无法撤销。本地文件夹来源之后需要重新授权一次。")
            }
        }
    }

    @concurrent
    private static func sizes() async -> [BackupDir: Int64] {
        Dictionary(uniqueKeysWithValues: BackupDir.allCases.map { ($0, try! $0.size(in: .documentsDirectory)) })
    }

    private func export(to url: URL) {
        let tasks = model.tasks
        let database = database
        let dirs = BackupDir.allCases.filter(included.contains)
        Task {
            await tasks.run("备份", detail: "准备中") {
                let backup = try await Self.write(database: database, into: url, dirs: dirs, tasks: tasks)
                UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: BackupExport.lastExportedKey)
                try database.logEvent(category: "backup", severity: .info, title: "备份完成", detail: backup.lastPathComponent)
                return "备份完成：\(backup.lastPathComponent)"
            }
        }
    }

    @concurrent
    private static func write(database: AppDatabase, into url: URL, dirs: [BackupDir], tasks: LibraryTasks) async throws -> URL {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        var reported = ""
        return try BackupExport.run(
            database: database,
            documents: .documentsDirectory,
            into: url,
            dirs: dirs,
            prefs: UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier!)!,
            secrets: try KeychainStore.shared.all()
        ) { stage, done, total in
            // Image folders are thousands of small files; report per percent.
            let text = total > 1
                ? "\(stage) \(done * 100 / total)% · \(total.formatted(.byteCount(style: .file)))"
                : stage
            guard text != reported else { return }
            reported = text
            Task { @MainActor in tasks.report(text) }
        }
    }

    private var isBusy: Bool {
        if case .staging = phase { return true }
        return false
    }

    private var isConfirming: Binding<Bool> {
        Binding(
            get: { if case .confirming = phase { true } else { false } },
            set: { if !$0, case .confirming = phase { phase = .idle } }
        )
    }

    private func inspect(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        do {
            phase = .confirming(url, try BackupRestore.inspect(url))
        } catch {
            url.stopAccessingSecurityScopedResource()
            phase = .failed(error.localizedDescription)
        }
    }

    private func stage(_ url: URL) {
        phase = .staging(done: 0, total: 0)
        DiagnosticLog.shared.write("backup", "restore_stage_start", ["backup": url.lastPathComponent])
        Task {
            let result = await Task.detached {
                defer { url.stopAccessingSecurityScopedResource() }
                var reported = -1
                return Result {
                    try BackupRestore.stage(url, into: URL.documentsDirectory) { done, total in
                        let percent = total == 0 ? 100 : Int(done * 100 / total)
                        guard percent != reported else { return }
                        reported = percent
                        Task { @MainActor in phase = .staging(done: done, total: total) }
                    }
                }
            }.value
            switch result {
            case .success:
                DiagnosticLog.shared.write("backup", "restore_staged")
                phase = .staged
            case .failure(let error):
                DiagnosticLog.shared.write("backup", "restore_stage_failed", ["error": "\(error)"])
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

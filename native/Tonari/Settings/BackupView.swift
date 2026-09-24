import SwiftUI
import TonariCore

struct BackupView: View {
    private enum Phase {
        case idle
        case confirming(URL, BackupManifest)
        case staging(done: Int64, total: Int64)
        case staged
        case failed(String)
    }

    @State private var phase = Phase.idle
    @State private var picking = false
    @State private var keychainSummary = ""

    var body: some View {
        List {
            Section {
                Button("从备份恢复") { picking = true }
                    .disabled(isBusy)
            } footer: {
                Text("选择 Flutter 版导出的「Tonari备份」文件夹（zip 需先在「文件」App 里解压）。恢复会覆盖当前的媒体库数据和设置，且无法撤销。")
            }

            switch phase {
            case .staging(let done, let total):
                Section("正在复制备份") {
                    ProgressView(value: Double(done), total: Double(max(total, 1)))
                    Text("\(done.formatted(.byteCount(style: .file))) / \(total.formatted(.byteCount(style: .file)))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            case .staged:
                Section {
                    Label("备份已就绪", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } footer: {
                    Text("请完全关闭 App（从后台上滑移除），再重新打开即完成恢复。本地文件夹来源之后需要重新授权一次才能访问。")
                }
            case .failed(let message):
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            case .idle, .confirming:
                EmptyView()
            }

            Section("当前数据") {
                LabeledContent("钥匙串凭据", value: keychainSummary)
            }
        }
        .navigationTitle("备份与恢复")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                keychainSummary = "\(try KeychainStore.shared.allKeys().count) 个"
            } catch {
                keychainSummary = "读取失败 \(error)"
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            inspect(url)
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
                Text("备份时间：\(manifest.createdAt.prefix(16).replacingOccurrences(of: "T", with: " "))\n恢复会覆盖当前的媒体库数据和设置，且无法撤销。")
            }
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

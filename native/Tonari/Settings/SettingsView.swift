import SwiftUI

import TonariCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @State private var confirmingStats = false

    var body: some View {
        NavigationStack {
            List {
                Section("DLsite") {
                    Button {
                        confirmingStats = true
                    } label: {
                        Label("更新统计数据", systemImage: "chart.bar")
                    }
                    .disabled(model.tasks.isBusy)
                }
                Section("数据") {
                    NavigationLink {
                        MediaSourcesView()
                    } label: {
                        Label("媒体来源", systemImage: "folder")
                    }
                    NavigationLink {
                        RemovedWorksView()
                    } label: {
                        Label("已移除作品", systemImage: "trash")
                    }
                    NavigationLink {
                        BackupView()
                    } label: {
                        Label("备份与恢复", systemImage: "externaldrive")
                    }
                }
                Section("支持") {
                    NavigationLink {
                        DiagnosticLogView()
                    } label: {
                        Label("诊断日志", systemImage: "stethoscope")
                    }
                }
            }
            .navigationTitle("设置")
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .alert("更新统计数据", isPresented: $confirmingStats) {
                Button("取消", role: .cancel) {}
                Button("开始更新", action: refreshAllStats)
            } message: {
                Text("将逐个向 DLsite 请求全部作品的售出、评分、价格和排名，作品多时需要一些时间。确定开始吗？")
            }
        }
    }

    private func refreshAllStats() {
        let tasks = model.tasks
        let service = enrichment.service
        Task {
            await tasks.run("更新统计数据", detail: "准备中") {
                let failed = await service.refreshAllStats { done, total in
                    Task { @MainActor in tasks.report("正在更新 \(done)/\(total)…") }
                }
                return failed == 0 ? "统计数据已更新" : "更新完成，\(failed) 个作品失败"
            }
        }
    }
}

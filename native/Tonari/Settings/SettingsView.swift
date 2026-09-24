import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("数据") {
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
        }
    }
}

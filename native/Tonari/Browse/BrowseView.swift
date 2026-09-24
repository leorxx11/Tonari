import SwiftUI
import TonariCore

/// Remote sources to browse and import from.
struct BrowseView: View {
    @Environment(AppModel.self) private var model
    @State private var p115 = P115Client.LoginState.loggedOut

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.browsePath) {
            List {
                Section("网盘") {
                    Button { model.openP115() } label: {
                        LabeledContent {
                            HStack {
                                Text(p115.label)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        } label: {
                            Label(P115Client.sourceName, systemImage: "icloud")
                        }
                    }
                    .tint(.primary)
                }
                Section("WebDAV") {
                    Text("WebDAV 将在 N4b 接入").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("浏览")
            .appDestinations()
            .onAppear { p115 = P115Client.shared.loginState }
        }
    }
}

/// Reached from settings, whose stack navigates by value like every other.
struct P115SettingsView: View {
    @State private var state = P115Client.LoginState.loggedOut
    @State private var storedKeys = ""
    @State private var confirmingLogout = false

    var body: some View {
        List {
            Section {
                LabeledContent("状态", value: state.label)
                if case .unreadable(let error) = state {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                Text("钥匙串中的凭据：\(storedKeys)")
            }
            Section {
                if state == .loggedIn {
                    Button("退出 115 登录", role: .destructive) { confirmingLogout = true }
                } else {
                    NavigationLink("登录 115", value: Route.p115Login)
                }
            }
        }
        .navigationTitle(P115Client.sourceName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            state = P115Client.shared.loginState
            do {
                storedKeys = try KeychainStore.shared.allKeys().sorted().joined(separator: "、")
            } catch {
                storedKeys = "读取失败 \(error)"
            }
        }
        .alert("退出登录", isPresented: $confirmingLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                try! P115Auth().logout()
                state = P115Client.shared.loginState
            }
        } message: {
            Text("将清除本机保存的 115 登录信息（Cookie）。需要时可重新扫码登录。")
        }
    }
}

extension P115Client.LoginState {
    var label: String {
        switch self {
        case .loggedIn: "已登录"
        case .loggedOut: "未登录"
        case .unreadable: "读取失败"
        }
    }
}

import SwiftUI
import TonariCore

/// Places to browse, after the Files app's locations: 115 and each WebDAV
/// server, where each was left, and a local folder picked through Files to
/// import.
struct BrowseView: View {
    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @State private var p115 = P115Client.LoginState.loggedOut
    @State private var p115Location: [RemoteEntry] = []
    @State private var servers: [WebdavServer] = []
    @State private var serverStacks: [String: [RemoteEntry]] = [:]
    @State private var pickingFolder = false

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.browsePath) {
            List {
                Section("位置") {
                    Button { model.openP115() } label: {
                        FileRow(icon: "icloud.fill", tint: .blue, title: P115Client.sourceName, detail: p115Detail) {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                    ForEach(servers) { server in
                        Button { model.openWebdav(server) } label: {
                            FileRow(icon: "externaldrive.connected.to.line.below.fill", tint: .gray, title: server.name, detail: detail(server)) {
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                        .contextMenu {
                            Button("编辑服务器", systemImage: "pencil") { model.browsePath.append(Route.webdavServer(server.id)) }
                        }
                    }
                    Button { pickingFolder = true } label: {
                        FileRow(icon: "iphone", tint: .gray, title: "本机文件夹", detail: "从「文件」App 选取并导入")
                    }
                    .tint(.primary)
                    .disabled(model.tasks.isBusy)
                }
            }
            .navigationTitle("浏览")
            .toolbar {
                NavigationLink(value: Route.webdavServer(nil)) { Label("添加 WebDAV 服务器", systemImage: "plus") }
            }
            .appDestinations()
            .safeAreaInset(edge: .bottom) { TaskBanner() }
            .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                guard case .success(let url) = result else { return }
                Task { await model.importLocalFolder(url, database: database, enrichment: enrichment) }
            }
            .onAppear {
                p115 = P115Client.shared.loginState
                p115Location = BrowseLocation.load(P115Client.sourceId) ?? []
                loadServerLocations()
            }
            .task {
                await database.observe(WebdavServers.all) {
                    servers = $0
                    loadServerLocations()
                }
            }
        }
    }

    private func loadServerLocations() {
        serverStacks = Dictionary(uniqueKeysWithValues: servers.map { ($0.id, BrowseLocation.stack($0.root)) })
    }

    private func detail(_ server: WebdavServer) -> String {
        let names = serverStacks[server.id]!.dropFirst().map(\.name)
        return names.isEmpty ? server.address : "上次在 \(names.joined(separator: " / "))"
    }

    private var p115Detail: String {
        guard p115 == .loggedIn else { return "\(p115.label) · 点击扫码登录" }
        let names = p115Location.dropFirst().map(\.name)
        return names.isEmpty ? p115.label : "\(p115.label) · 上次在 \(names.joined(separator: " / "))"
    }
}

/// Reached from settings, whose stack navigates by value like every other.
struct P115SettingsView: View {
    @State private var state = P115Client.LoginState.loggedOut
    @State private var confirmingLogout = false

    var body: some View {
        List {
            Section {
                LabeledContent("状态", value: state.label)
                if case .unreadable(let error) = state {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
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

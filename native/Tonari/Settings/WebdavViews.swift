import SwiftUI
import TonariCore

/// The WebDAV servers to browse and import from; each also shows in 浏览.
struct WebdavServersView: View {
    @Environment(\.appDatabase) private var database
    @State private var servers: [WebdavServer] = []
    @State private var deleting: WebdavServer?

    var body: some View {
        List(servers) { server in
            NavigationLink(value: Route.webdavServer(server.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                    Text(server.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .swipeActions {
                Button("删除", systemImage: "trash", role: .destructive) { deleting = server }
            }
            .contextMenu {
                Button("删除", systemImage: "trash", role: .destructive) { deleting = server }
            }
        }
        .overlay {
            if servers.isEmpty {
                ContentUnavailableView(
                    "还没有 WebDAV 服务器", systemImage: "externaldrive.connected.to.line.below",
                    description: Text("点右上角 ＋ 添加 NAS、Alist 等 WebDAV 服务")
                )
            }
        }
        .navigationTitle("WebDAV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink(value: Route.webdavServer(nil)) { Label("添加服务器", systemImage: "plus") }
        }
        .confirmingDeletion(of: $deleting)
        .task {
            await database.observe(WebdavServers.all) { servers = $0 }
        }
    }
}

/// Adds a server or edits one; an empty password field keeps the stored
/// password. 测试连接 lists the base path with what is typed.
struct WebdavServerEditView: View {
    let serverId: String?

    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var existing: WebdavServer?
    @State private var name = ""
    @State private var scheme = "https"
    @State private var host = ""
    @State private var port = ""
    @State private var basePath = ""
    @State private var username = ""
    @State private var password = ""
    @State private var hasStoredPassword = false
    @State private var testing = false
    @State private var testResult: Result<Void, any Error>?
    @State private var deleting: WebdavServer?

    /// What the fields describe, or nil while they can't make an address.
    private var draft: WebdavServer? {
        let port = port.trimmed
        guard !host.trimmed.isEmpty, port.isEmpty || UInt16(port) != nil else { return nil }
        var server = existing ?? WebdavServer(name: "", scheme: "", host: "", port: nil, basePath: nil, username: nil)
        server.name = name.trimmed
        server.scheme = scheme
        server.host = host.trimmed
        server.port = Int(port)
        server.basePath = basePath.trimmed.isEmpty ? nil : basePath.trimmed
        server.username = username.trimmed.isEmpty ? nil : username.trimmed
        return URL(string: server.origin + "/")?.host() == nil ? nil : server
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("名称") {
                    TextField("例如 家里的 NAS", text: $name)
                }
            }
            .multilineTextAlignment(.trailing)
            Section {
                Picker("协议", selection: $scheme) {
                    Text("HTTPS").tag("https")
                    Text("HTTP").tag("http")
                }
                LabeledContent("主机") {
                    TextField("192.168.1.10 或 dav.example.com", text: $host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledContent("端口") {
                    TextField(scheme == "https" ? "443" : "80", text: $port)
                        .keyboardType(.numberPad)
                }
                LabeledContent("路径") {
                    TextField("可选，如 /dav", text: $basePath)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            } header: {
                Text("地址")
            } footer: {
                if let draft { Text(draft.address) }
            }
            .multilineTextAlignment(.trailing)
            Section("账号") {
                LabeledContent("用户名") {
                    TextField("可选", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledContent("密码") {
                    SecureField(hasStoredPassword ? "留空保留原密码" : "可选", text: $password)
                }
            }
            .multilineTextAlignment(.trailing)
            Section {
                Button {
                    Task { await test() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("测试连接")
                            if case .failure(let error) = testResult {
                                Text(error.localizedDescription).font(.caption).foregroundStyle(.red).lineLimit(3)
                            }
                        }
                        Spacer()
                        if testing {
                            ProgressView()
                        } else {
                            switch testResult {
                            case .success: Label("成功", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            case .failure: Label("失败", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                            case nil: EmptyView()
                            }
                        }
                    }
                }
                .disabled(testing || draft == nil)
            }
            if let existing {
                Section {
                    Button("删除服务器", role: .destructive) { deleting = existing }
                }
            }
        }
        .navigationTitle(serverId == nil ? "添加 WebDAV 服务器" : "编辑服务器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("保存", action: save).disabled(draft == nil || name.trimmed.isEmpty)
        }
        .onChange(of: [scheme, host, port, basePath, username, password]) { testResult = nil }
        .confirmingDeletion(of: $deleting) { dismiss() }
        .onAppear(perform: load)
    }

    private func load() {
        guard let serverId, existing == nil else { return }
        let server = try! database.reader.read { try WebdavServer.fetchOne($0, key: serverId)! }
        existing = server
        name = server.name
        scheme = server.scheme
        host = server.host
        port = server.port.map(String.init) ?? ""
        basePath = server.basePath ?? ""
        username = server.username ?? ""
        hasStoredPassword = try! WebdavServers.password(serverId) != nil
    }

    /// Tries the typed password, else the stored one.
    private func test() async {
        testing = true
        testResult = nil
        let stored = try! existing.flatMap { try WebdavServers.password($0.id) }
        do {
            try await WebdavClient(server: draft!, password: password.isEmpty ? stored : password).check()
            testResult = .success(())
        } catch {
            testResult = .failure(error)
        }
        testing = false
    }

    private func save() {
        try! database.saveWebdavServer(draft!, password: password.isEmpty ? nil : password)
        dismiss()
    }
}

extension View {
    /// Confirms deleting a server, saying how many works and videos go with it.
    func confirmingDeletion(of server: Binding<WebdavServer?>, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(WebdavServerDeletion(server: server, onDeleted: onDeleted))
    }
}

private struct WebdavServerDeletion: ViewModifier {
    @Binding var server: WebdavServer?
    let onDeleted: () -> Void
    @Environment(\.appDatabase) private var database

    func body(content: Content) -> some View {
        content.alert("删除服务器", isPresented: Binding(get: { server != nil }, set: { if !$0 { server = nil } }), presenting: server) { server in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                try! database.deleteWebdavServer(server.id)
                BrowseLocation.forget(server.id)
                onDeleted()
            }
        } message: { server in
            let (works, videos) = try! database.reader.read { try WebdavServers.dependents(of: server.id, $0) }
            let taken = [works > 0 ? "从它导入的 \(works) 个作品（含播放记录、收藏）" : nil, videos > 0 ? "视频库里的 \(videos) 个视频" : nil].compactMap(\.self)
            Text(taken.isEmpty ? "确认删除「\(server.name)」？" : "将删除「\(server.name)」及\(taken.joined(separator: "、"))，不可恢复。确定？")
        }
    }
}

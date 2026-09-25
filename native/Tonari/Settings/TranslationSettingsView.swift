import SwiftUI
import TonariCore

/// The LLM services translation can use; the starred one is what the work
/// page's 翻译为中文 calls.
struct TranslationSettingsView: View {
    @Environment(\.appDatabase) private var database
    @State private var providers: [LlmProvider] = []
    @State private var deleting: LlmProvider?

    var body: some View {
        List {
            Section {
                ForEach(providers) { provider in
                    NavigationLink(value: Route.llmProvider(provider.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: provider.isDefault ? "star.fill" : "star")
                                .foregroundStyle(provider.isDefault ? AnyShapeStyle(.yellow) : AnyShapeStyle(.tertiary))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name)
                                Text("\(provider.model) · \(provider.baseUrl)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .swipeActions {
                        Button("删除", systemImage: "trash", role: .destructive) { deleting = provider }
                        if !provider.isDefault {
                            Button("设为默认", systemImage: "star") { try! database.setDefaultProvider(provider.id) }
                                .tint(.yellow)
                        }
                    }
                    .contextMenu {
                        if !provider.isDefault {
                            Button("设为默认", systemImage: "star") { try! database.setDefaultProvider(provider.id) }
                        }
                        Button("删除", systemImage: "trash", role: .destructive) { deleting = provider }
                    }
                }
            }
        }
        .overlay {
            if providers.isEmpty {
                ContentUnavailableView(
                    "还没有翻译服务", systemImage: "character.bubble",
                    description: Text("点右上角 ＋ 添加 DeepSeek、Gemini 或其他 OpenAI 兼容服务")
                )
            }
        }
        .navigationTitle("翻译")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink(value: Route.llmProvider(nil)) { Label("添加服务", systemImage: "plus") }
        }
        .alert("删除服务", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { provider in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { try! database.deleteProvider(provider.id) }
        } message: { provider in
            Text("确认删除「\(provider.name)」？已有的译文不受影响。")
        }
        .task {
            await database.observe(LlmProviders.all) { providers = $0 }
        }
    }
}

/// Adds a service (templates fill the address and model) or edits one; an
/// empty key field keeps the stored key.
struct LlmProviderEditView: View {
    let providerId: String?

    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseUrl = ""
    @State private var model = ""
    @State private var apiKey = ""
    @State private var systemPrompt = ""
    @State private var storedKeyHint: String?
    @State private var testing = false
    @State private var testResult: Result<Void, any Error>?

    private var isValid: Bool {
        [name, baseUrl, model].allSatisfy { !$0.trimmed.isEmpty } && (providerId != nil || !apiKey.trimmed.isEmpty)
    }

    var body: some View {
        Form {
            if providerId == nil {
                Section("快速模板") {
                    HStack(spacing: 10) {
                        ForEach(LlmProviders.templates, id: \.self) { template in
                            Button(template.name) {
                                if name.isEmpty { name = template.name }
                                baseUrl = template.baseUrl
                                model = template.model
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            Section {
                LabeledContent("名称") {
                    TextField("例如 DeepSeek 主力", text: $name)
                }
                LabeledContent("Base URL") {
                    TextField("https://api.example.com/v1", text: $baseUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledContent("Model") {
                    TextField("deepseek-chat", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledContent("API Key") {
                    SecureField(storedKeyHint.map { "\($0)（留空保留）" } ?? "必填", text: $apiKey)
                }
            }
            .multilineTextAlignment(.trailing)
            Section {
                TextField("追加在内置提示词之后，如术语表、风格偏好", text: $systemPrompt, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("附加提示词（可选）")
            }
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
                .disabled(testing || baseUrl.trimmed.isEmpty || model.trimmed.isEmpty)
            }
        }
        .navigationTitle(providerId == nil ? "添加服务" : "编辑服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("保存", action: save).disabled(!isValid)
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard let providerId, name.isEmpty else { return }
        let provider = try! database.reader.read { try LlmProvider.fetchOne($0, key: providerId)! }
        name = provider.name
        baseUrl = provider.baseUrl
        model = provider.model
        systemPrompt = provider.systemPrompt ?? ""
        storedKeyHint = try! LlmProviders.apiKey(providerId).map(Self.mask)
    }

    private static func mask(_ key: String) -> String {
        key.count <= 8 ? "••••" : "\(key.prefix(4))••••\(key.suffix(4))"
    }

    /// Tries the typed key, else the stored one.
    private func test() async {
        testing = true
        testResult = nil
        let key = apiKey.trimmed.isEmpty ? providerId.flatMap { try! LlmProviders.apiKey($0) } ?? "" : apiKey.trimmed
        let service = TranslationService(.init(baseUrl: baseUrl.trimmed, model: model.trimmed, apiKey: key, systemPrompt: nil))
        do {
            try await service.testConnection()
            testResult = .success(())
        } catch {
            testResult = .failure(error)
        }
        testing = false
    }

    private func save() {
        let prompt = systemPrompt.trimmed.isEmpty ? nil : systemPrompt.trimmed
        if let providerId {
            try! database.updateProvider(
                providerId, name: name.trimmed, baseUrl: baseUrl.trimmed, model: model.trimmed,
                systemPrompt: prompt, apiKey: apiKey.trimmed.isEmpty ? nil : apiKey.trimmed
            )
        } else {
            try! database.addProvider(name: name.trimmed, baseUrl: baseUrl.trimmed, model: model.trimmed, systemPrompt: prompt, apiKey: apiKey.trimmed)
        }
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

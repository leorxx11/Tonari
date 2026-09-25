import SwiftUI
import TonariCore

/// What Tonari keeps on disk that it can fetch again, one area at a time,
/// after the iPhone Storage page. Covers and sample images stay: the
/// library and detail pages have nothing to fall back on without them.
struct StorageView: View {
    enum Area: CaseIterable, Identifiable {
        case p115Files, descriptionImages, temporary

        var id: Self { self }

        var title: String {
            switch self {
            case .p115Files: "115 文件预览"
            case .descriptionImages: "DLsite 简介图片"
            case .temporary: "临时文件"
            }
        }

        var detail: String {
            switch self {
            case .p115Files: "在资源页打开过的 115 图片、文本和字幕。清理后再次打开会重新下载。"
            case .descriptionImages: "作品简介里的长图。清理后简介里对应位置显示「未下载」，可逐部作品点击下载回本地。"
            case .temporary: "导出诊断日志、备份时生成的文件，以及旧版本在线加载图片留下的缓存。"
            }
        }

        var systemImage: String {
            switch self {
            case .p115Files: "icloud"
            case .descriptionImages: "photo.on.rectangle"
            case .temporary: "clock.arrow.circlepath"
            }
        }

        var tint: Color {
            switch self {
            case .p115Files: .blue
            case .descriptionImages: .orange
            case .temporary: .gray
            }
        }

        nonisolated var files: [URL] {
            let manager = FileManager.default
            switch self {
            case .p115Files:
                return [URL.cachesDirectory.appending(path: "p115-files")].filter { manager.fileExists(atPath: $0.path) }
            case .descriptionImages:
                let images = URL.documentsDirectory.appending(path: "images")
                let works = (try? manager.contentsOfDirectory(at: images, includingPropertiesForKeys: nil)) ?? []
                return works.flatMap { work in
                    ((try? manager.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)) ?? [])
                        .filter { $0.lastPathComponent.hasPrefix("desc") }
                }
            case .temporary:
                return (try? manager.contentsOfDirectory(at: URL.temporaryDirectory, includingPropertiesForKeys: nil)) ?? []
            }
        }
    }

    @State private var sizes: [Area: Int] = [:]
    @State private var confirming: Area?
    @State private var confirmingAll = false

    var body: some View {
        List {
            Section {
                LabeledContent("可清理", value: sizes.count == Area.allCases.count ? Formatting.bytes(sizes.values.reduce(0, +)) : "计算中…")
            }
            ForEach(Area.allCases) { area in
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: area.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(area.tint, in: .rect(cornerRadius: 7))
                        Text(area.title)
                        Spacer()
                        Text(sizes[area].map(Formatting.bytes) ?? "计算中…").foregroundStyle(.secondary)
                    }
                    Button("清理", role: .destructive) { confirming = area }
                        .disabled((sizes[area] ?? 0) == 0)
                } footer: {
                    Text(area.detail)
                }
            }
            Section {
                Button("全部清理", role: .destructive) { confirmingAll = true }
                    .frame(maxWidth: .infinity)
                    .disabled(sizes.values.reduce(0, +) == 0)
            }
        }
        .navigationTitle("存储空间")
        .navigationBarTitleDisplayMode(.inline)
        .task { await measure() }
        .confirmationDialog(
            "清理\(confirming?.title ?? "")？",
            isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
            titleVisibility: .visible,
            presenting: confirming
        ) { area in
            Button("清理 \(sizes[area].map(Formatting.bytes) ?? "")", role: .destructive) {
                Task { await clear([area]) }
            }
        } message: { area in
            Text(area.detail)
        }
        .confirmationDialog("清理全部缓存？", isPresented: $confirmingAll, titleVisibility: .visible) {
            Button("全部清理", role: .destructive) {
                Task { await clear(Area.allCases) }
            }
        } message: {
            Text("封面、样图和媒体库数据不受影响。")
        }
    }

    private func measure() async {
        for area in Area.allCases {
            sizes[area] = await Self.size(of: area.files) + (area == .temporary ? URLCache.shared.currentDiskUsage : 0)
        }
    }

    private func clear(_ areas: [Area]) async {
        for area in areas {
            await Self.remove(area.files)
            if area == .temporary { URLCache.shared.removeAllCachedResponses() }
            DiagnosticLog.shared.write("storage", "cleared", ["area": area.title, "bytes": sizes[area] ?? 0])
        }
        await measure()
    }

    @concurrent
    private static func size(of urls: [URL]) async -> Int {
        let manager = FileManager.default
        return urls.reduce(0) { total, url in
            var isDirectory: ObjCBool = false
            guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return total }
            guard isDirectory.boolValue else { return total + fileSize(url) }
            let contents = manager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])?.compactMap { $0 as? URL } ?? []
            return total + contents.reduce(0) { $0 + fileSize($1) }
        }
    }

    private nonisolated static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    @concurrent
    private static func remove(_ urls: [URL]) async {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                DiagnosticLog.shared.write("storage", "remove_failed", ["file": url.lastPathComponent, "error": "\(error)"])
            }
        }
    }
}

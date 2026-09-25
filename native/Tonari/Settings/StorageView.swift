import SwiftUI
import TonariCore

/// What Tonari keeps on disk that it can fetch again, one area at a time,
/// after the iPhone Storage page. Covers and sample images stay: the
/// library and detail pages have nothing to fall back on without them.
struct StorageView: View {
    enum Area: CaseIterable, Identifiable {
        case descriptionImages, dlsiteOnline, p115Files, temporary

        var id: Self { self }

        var title: String {
            switch self {
            case .p115Files: "115 文件预览"
            case .descriptionImages: "DLsite 简介图片"
            case .dlsiteOnline: "DLsite 在线缓存"
            case .temporary: "临时文件"
            }
        }

        var shortTitle: String {
            switch self {
            case .p115Files: "115 预览"
            case .descriptionImages: "简介图片"
            case .dlsiteOnline: "DLsite 在线"
            case .temporary: "临时文件"
            }
        }

        var detail: String {
            switch self {
            case .p115Files: "在资源页打开过的 115 图片、文本和字幕。清理后再次打开会重新下载。"
            case .descriptionImages: "作品简介里的长图。清理后简介里对应位置显示「未下载」，可在作品页一键下载回来。"
            case .dlsiteOnline: "发现页的列表、看过的在线作品，以及在线加载的封面、样图和试听。清理后再次打开会重新下载。"
            case .temporary: "导出诊断日志、备份时生成的文件。"
            }
        }

        var systemImage: String {
            switch self {
            case .p115Files: "icloud"
            case .descriptionImages: "photo.on.rectangle"
            case .dlsiteOnline: "safari"
            case .temporary: "clock.arrow.circlepath"
            }
        }

        var tint: Color {
            switch self {
            case .p115Files: .blue
            case .descriptionImages: .orange
            case .dlsiteOnline: .indigo
            case .temporary: .gray
            }
        }

        nonisolated var files: [URL] {
            let manager = FileManager.default
            switch self {
            case .p115Files:
                return [PreviewFile.p115Cache].filter { manager.fileExists(atPath: $0.path) }
            case .descriptionImages:
                let images = URL.documentsDirectory.appending(path: "images")
                let works = (try? manager.contentsOfDirectory(at: images, includingPropertiesForKeys: nil)) ?? []
                return works.flatMap { work in
                    ((try? manager.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)) ?? [])
                        .filter { $0.lastPathComponent.hasPrefix("desc") }
                }
            case .dlsiteOnline:
                return [OnlineWorkCache.directory, DiscoverStore.file].filter { manager.fileExists(atPath: $0.path) }
            case .temporary:
                return (try? manager.contentsOfDirectory(at: URL.temporaryDirectory, includingPropertiesForKeys: nil)) ?? []
            }
        }
    }

    @State private var sizes: [Area: Int] = [:]
    @State private var confirming: Area?
    @State private var confirmingAll = false

    private var total: Int? {
        sizes.count == Area.allCases.count ? sizes.values.reduce(0, +) : nil
    }

    var body: some View {
        List {
            Section { overview }
            Section {
                ForEach(Area.allCases) { area in
                    Button { confirming = area } label: {
                        HStack(spacing: 12) {
                            Image(systemName: area.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(area.tint, in: .rect(cornerRadius: 7))
                            Text(area.title)
                            Spacer()
                            Text(sizes[area].map(Formatting.bytes) ?? "计算中…").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled((sizes[area] ?? 0) == 0)
                }
            }
            Section {
                Button("全部清理", role: .destructive) { confirmingAll = true }
                    .frame(maxWidth: .infinity)
                    .disabled((total ?? 0) == 0)
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
            Button("全部清理 \(total.map(Formatting.bytes) ?? "")", role: .destructive) {
                Task { await clear(Area.allCases) }
            }
        } message: {
            Text("封面、样图和媒体库数据不受影响。")
        }
    }

    /// What can go, and how it splits, after iPhone Storage's bar.
    private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(total.map(Formatting.bytes) ?? "计算中…").font(.title2.bold())
                Text("可清理，封面、样图和媒体库数据不在其中").font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(Area.allCases) { area in
                        let share = Double(sizes[area] ?? 0) / Double(max(total ?? 0, 1))
                        if share > 0 {
                            area.tint.frame(width: max(3, (proxy.size.width - 6) * share))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemFill))
                .clipShape(.capsule)
            }
            .frame(height: 10)
            HStack(spacing: 12) {
                ForEach(Area.allCases) { area in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(area.tint).frame(width: 8, height: 8)
                        Text(area.shortTitle)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func measure() async {
        for area in Area.allCases {
            sizes[area] = await Self.size(of: area)
        }
    }

    /// Everything the page could clear, for the settings row.
    static func clearableBytes() async -> Int {
        var total = 0
        for area in Area.allCases { total += await size(of: area) }
        return total
    }

    private static func size(of area: Area) async -> Int {
        await size(of: area.files) + (area == .dlsiteOnline ? URLCache.shared.currentDiskUsage : 0)
    }

    private func clear(_ areas: [Area]) async {
        for area in areas {
            await Self.remove(area.files)
            if area == .dlsiteOnline { URLCache.shared.removeAllCachedResponses() }
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

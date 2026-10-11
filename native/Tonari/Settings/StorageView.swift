import SwiftUI
import TonariCore

/// What Tonari keeps on disk, after the iPhone Storage page: caches it can
/// fetch again, cleared by swiping, and the offline downloads. Covers and
/// sample images stay: the library and detail pages have nothing to fall
/// back on without them.
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
            case .p115Files: "资源页打开过的图片、文本和字幕"
            case .descriptionImages: "清理后可在作品页一键下载回来"
            case .dlsiteOnline: "发现页列表、看过的在线作品和试听"
            case .temporary: "导出诊断日志、备份时生成"
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

    @Environment(OfflineDownloads.self) private var offline
    @State private var sizes: [Area: Int] = [:]
    @State private var confirmingAll = false
    @State private var offlineBytes: Int?

    private var clearable: Int? {
        sizes.count == Area.allCases.count ? sizes.values.reduce(0, +) : nil
    }

    private var total: Int? {
        clearable.flatMap { clearable in offlineBytes.map { clearable + $0 } }
    }

    var body: some View {
        List {
            Section { overview }
            Section {
                ForEach(Area.allCases) { area in
                    HStack(spacing: 12) {
                        icon(area.systemImage, tint: area.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(area.title)
                            Text(area.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(sizes[area].map(Formatting.bytes) ?? "计算中…").foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if (sizes[area] ?? 0) > 0 {
                            Button("清理") { Task { await clear([area]) } }.tint(.red)
                        }
                    }
                }
                NavigationLink(value: Route.offlineDownloads) {
                    HStack(spacing: 12) {
                        icon("arrow.down.circle", tint: .green)
                        Text("离线下载")
                        Spacer()
                        Text(offlineBytes.map(Formatting.bytes) ?? "计算中…").foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("清理全部缓存 \(clearable.map(Formatting.bytes) ?? "")", role: .destructive) { confirmingAll = true }
                    .frame(maxWidth: .infinity)
                    .disabled((clearable ?? 0) == 0)
            }
        }
        .navigationTitle("存储空间")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: offline.revision) { await measure() }
        .confirmationDialog("清理全部缓存？", isPresented: $confirmingAll, titleVisibility: .visible) {
            Button("清理 \(clearable.map(Formatting.bytes) ?? "")", role: .destructive) {
                Task { await clear(Area.allCases) }
            }
        } message: {
            Text("离线下载、封面、样图和媒体库数据不受影响。")
        }
    }

    private func icon(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint, in: .rect(cornerRadius: 7))
    }

    /// What Tonari takes up, and how it splits, after iPhone Storage's bar.
    private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(total.map(Formatting.bytes) ?? "计算中…").font(.title2.bold())
                Text("Tonari 占用，封面、样图和媒体库数据不在其中").font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(segments, id: \.label) { segment in
                        let share = Double(segment.bytes) / Double(max(total ?? 0, 1))
                        if share > 0 {
                            segment.tint.frame(width: max(3, (proxy.size.width - 8) * share))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemFill))
                .clipShape(.capsule)
            }
            .frame(height: 10)
            FlowLayout(spacing: 12, lineSpacing: 4) {
                ForEach(segments, id: \.label) { segment in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(segment.tint).frame(width: 8, height: 8)
                        Text(segment.label)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var segments: [(label: String, tint: Color, bytes: Int)] {
        Area.allCases.map { ($0.shortTitle, $0.tint, sizes[$0] ?? 0) } + [("离线", .green, offlineBytes ?? 0)]
    }

    private func measure() async {
        offlineBytes = await Self.size(of: [OfflineFiles.shared.root])
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
            if area == .dlsiteOnline {
                URLCache.shared.removeAllCachedResponses()
                RemoteImages.memory.removeAllObjects()
            }
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

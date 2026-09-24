import SwiftUI
import TonariCore

struct WorkDetailView: View {
    let productId: String

    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var fetching = false
    @State private var work: Work?
    @State private var fileCount = 0
    @State private var durationMs = 0
    @State private var gallery: GallerySelection?

    var body: some View {
        ScrollView {
            if let work {
                VStack(alignment: .leading, spacing: 0) {
                    header(work)
                    VStack(alignment: .leading, spacing: 14) {
                        if fetching {
                            Label("正在获取 DLsite 资料…", systemImage: "arrow.down.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        titleBlock(work)
                        WorkStatsView(work: work, durationMs: durationMs)
                        WorkChipsView(work: work)
                        fileInfo(work)
                        actions(work)
                    }
                    .padding(16)
                    CreditsView(work: work)
                    DescriptionView(work: work) { gallery = $0 }
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(productId)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .fullScreenCover(item: $gallery) { GalleryView(selection: $0) }
        .safeAreaInset(edge: .bottom) { TaskBanner() }
        .onChange(of: work?.isRemoved) { _, removed in
            if removed == true { dismiss() }
        }
        .task(id: work?.productId) {
            // Opening a work that was never enriched fetches it right away
            // instead of waiting for the background queue.
            guard let work, MetadataEnrichment.needsEnrichment(work, documents: .documentsDirectory) else { return }
            fetching = true
            do {
                try await enrichment.service.enrich(productId)
            } catch {
                DiagnosticLog.shared.write("metadata", "detail_enrich_failed", ["productId": productId, "error": "\(error)"])
            }
            fetching = false
        }
        .task {
            await database.observe({ db in
                (
                    try WorkQueries.work(productId).fetchOne(db),
                    try WorkQueries.tracks(of: productId).fetchCount(db) + WorkQueries.files(of: productId).fetchCount(db),
                    try WorkQueries.durations(db)[productId] ?? 0
                )
            }) {
                work = $0.0
                fileCount = $0.1
                durationMs = $0.2
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if let work {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(work.isFavorite ? "取消收藏" : "添加收藏", systemImage: work.isFavorite ? "heart.fill" : "heart") {
                    try! database.setFavorite(productId, !work.isFavorite)
                }
                .tint(work.isFavorite ? .pink : nil)
                Link(destination: DLsite.workURL(productId)) {
                    Label("在 DLsite 中打开", systemImage: "safari")
                }
                Menu("更多", systemImage: "ellipsis") {
                    Button("加入分组…", systemImage: "folder.badge.plus") { model.collectionPickerWork = work }
                    Section("DLsite") {
                        Button("刷新元数据", systemImage: "arrow.triangle.2.circlepath") {
                            runRefresh("刷新元数据", done: "元数据已刷新") { try await $0.refreshMetadata(productId, onImage: $1) }
                        }
                        Button("只刷新图片", systemImage: "photo.on.rectangle") {
                            runRefresh("刷新图片", done: "图片已刷新") { try await $0.refreshImages(productId, onImage: $1) }
                        }
                        Button("更新统计数据", systemImage: "chart.bar") {
                            runRefresh("更新统计数据", done: "统计数据已更新") { service, _ in try await service.refreshStats(productId) }
                        }
                    }
                    .disabled(model.tasks.isBusy)
                    Button("重新扫描此作品", systemImage: "arrow.clockwise") {
                        Task {
                            await model.tasks.run("重新扫描作品", detail: work.productId) {
                                let summary = try await model.reimport(work, database: database)
                                return "作品已重新扫描：\(summary.tracksTotal) 个音轨"
                            }
                        }
                    }
                    .disabled(model.tasks.isBusy)
                    Button("从媒体库移除", systemImage: "trash", role: .destructive) { model.removingWork = work }
                }
            }
        }
    }

    /// Runs a DLsite refresh as a library task, reporting image progress.
    private func runRefresh(
        _ title: String, done: String,
        _ operation: @escaping (MetadataEnrichment, @escaping MetadataEnrichment.ImageProgress) async throws -> Void
    ) {
        let tasks = model.tasks
        Task {
            await tasks.run(title, detail: productId) {
                try await operation(enrichment.service) { completed, total, label in
                    Task { @MainActor in tasks.report("\(label)（\(completed)/\(total)）") }
                }
                ThumbnailCache.shared.evict(prefix: "images/\(productId)/")
                return done
            }
        }
    }

    private func header(_ work: Work) -> some View {
        let images = [work.mainImageLocalPath].compactMap(\.self) + work.sampleImageLocalPaths
        return TabView {
            ForEach(Array(images.enumerated()), id: \.offset) { index, path in
                LocalImage(path: path, contentMode: .fit)
                    .onTapGesture {
                        gallery = GallerySelection(images: images.map(GalleryImage.local), index: index)
                    }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
        .aspectRatio(4 / 3, contentMode: .fit)
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: model.fileEntryOnLeft ? .bottomLeading : .bottomTrailing) {
            if fileCount > 0 {
                NavigationLink(value: Route.files(productId)) {
                    Image("FilesSeal")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                }
                .padding(10)
                .accessibilityLabel("浏览文件")
            }
        }
    }

    private func titleBlock(_ work: Work) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(work.displayTitle)
                .font(.title3.weight(.semibold))
                .textSelection(.enabled)
            HStack(spacing: 6) {
                if let circle = work.circleName, !circle.isEmpty {
                    Button(circle) { model.showInLibrary(WorkChip(.circle, circle)) }
                }
                if work.circleName != nil, work.releaseDate != nil {
                    Text("·").foregroundStyle(.secondary)
                }
                if let date = work.releaseDate {
                    Text(Formatting.date(date)).foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            if let original = work.originalProductId {
                Link(destination: DLsite.workURL(original)) {
                    Label("翻译自 \(original)", systemImage: "character.book.closed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .underline()
                }
            }
            let badges = badges(work)
            if !badges.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(badges, id: \.text) { badge in
                        Text(badge.text)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(badge.adult ? .red : .secondary)
                            .background(badge.adult ? Color.red.opacity(0.12) : Color(.systemGray6), in: .rect(cornerRadius: 4))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func badges(_ work: Work) -> [(text: String, adult: Bool)] {
        var out: [(String, Bool)] = []
        if let age = work.ageRating, !age.isEmpty {
            out.append((age, ["R18", "18禁", "成人"].contains { age.contains($0) }))
        }
        if let type = work.workTypeName, !type.isEmpty { out.append((type, false)) }
        out += work.supportedLanguages.map { ($0, false) }
        return out
    }

    @ViewBuilder private func fileInfo(_ work: Work) -> some View {
        let parts = [work.fileSize, work.fileFormats.isEmpty ? nil : work.fileFormats.joined(separator: " + ")]
            .compactMap(\.self).filter { !$0.isEmpty }
        if !parts.isEmpty {
            Label(parts.joined(separator: " · "), systemImage: "doc")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func actions(_ work: Work) -> some View {
        HStack(spacing: 10) {
            NavigationLink(value: Route.files(productId)) {
                Label("浏览文件", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(fileCount == 0)
            Button {
                model.collectionPickerWork = work
            } label: {
                Label("加入分组", systemImage: "folder.badge.plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            Button {
                try! database.setFavorite(productId, !work.isFavorite)
            } label: {
                Label(work.isFavorite ? "已收藏" : "收藏", systemImage: work.isFavorite ? "heart.fill" : "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
        .controlSize(.regular)
        .lineLimit(1)
    }
}

enum DLsite {
    static func workURL(_ productId: String) -> URL {
        URL(string: "https://www.dlsite.com/maniax/work/=/product_id/\(productId).html/?locale=zh_CN")!
    }
}

/// Ranking, rating, sales, wishlist, total length and price.
struct WorkStatsView: View {
    let work: Work
    let durationMs: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let ranks = [("24h", work.rankDay), ("7日", work.rankWeek), ("30日", work.rankMonth)]
                .compactMap { label, rank in rank.map { (label, $0) } }
            if !ranks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "trophy").foregroundStyle(.secondary)
                    ForEach(ranks, id: \.0) { label, rank in
                        Text("\(label) 第 \(rank) 名")
                    }
                }
                .font(.subheadline)
            }
            HStack(spacing: 10) {
                if let rating = work.rating {
                    RatingStars(rating: rating, size: 14)
                    Text(rating.formatted(.number.precision(.fractionLength(2))))
                        .font(.headline)
                        .foregroundStyle(.orange)
                    if let count = work.ratingCount {
                        Text("(\(count))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let sales = work.dlCount {
                    Text("售出 \(Formatting.count(sales))")
                }
                if let wishlist = work.wishlistCount {
                    Text("收藏 \(Formatting.count(wishlist))")
                }
                if durationMs > 0 {
                    Label(Formatting.clock(ms: durationMs), systemImage: "clock")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if let price = work.currentPrice {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(price) JPY").font(.title3.weight(.semibold)).foregroundStyle(.red)
                    if let discount = work.discountRate, discount > 0, let official = work.officialPrice {
                        Text("\(official) JPY").font(.caption).strikethrough().foregroundStyle(.secondary)
                        Text("-\(discount)%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red.opacity(0.12), in: .rect(cornerRadius: 4))
                    }
                }
            }
        }
    }
}

struct CreditsView: View {
    let work: Work

    var body: some View {
        let rows = [("剧情", work.scenarioWriters), ("插画", work.illustrators), ("音乐", work.musicians)]
            .filter { !$0.1.isEmpty }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("演职员").font(.headline)
                ForEach(rows, id: \.0) { label, names in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(label).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                        Text(names.joined(separator: "、")).textSelection(.enabled)
                    }
                    .font(.subheadline)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
        }
    }
}

struct DescriptionView: View {
    let work: Work
    let openGallery: (GallerySelection) -> Void

    @State private var items: [WorkDescription.Item] = []

    var body: some View {
        let html = work.descriptionHtmlZh.flatMap { $0.isEmpty ? nil : $0 } ?? work.descriptionHtml
        VStack(alignment: .leading, spacing: 10) {
            if !items.isEmpty {
                Text("简介").font(.headline)
            }
            let images = galleryImages
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .text(let blocks):
                    Text(attributed(blocks))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .image(let url):
                    let index = WorkDescription.imageURLs(items).firstIndex(of: url)!
                    descriptionImage(images[index])
                        .onTapGesture { openGallery(GallerySelection(images: images, index: index)) }
                }
            }
        }
        .padding(16)
        .task(id: html) {
            guard let html else { return items = [] }
            do {
                items = try WorkDescription.parse(html)
            } catch {
                DiagnosticLog.shared.write("detail", "description_parse_failed", ["productId": work.productId, "error": "\(error)"])
                items = []
            }
        }
    }

    /// Downloaded copies first, falling back to the DLsite URL.
    private var galleryImages: [GalleryImage] {
        let local = work.descriptionImageLocalPaths
        return WorkDescription.imageURLs(items).enumerated().map { index, url in
            if index < local.count, FileManager.default.fileExists(atPath: URL.documentsDirectory.appending(path: local[index]).path) {
                .local(local[index])
            } else {
                .remote(URL(string: url)!)
            }
        }
    }

    @ViewBuilder private func descriptionImage(_ image: GalleryImage) -> some View {
        switch image {
        case .local(let path):
            FittedLocalImage(path: path)
                .clipShape(.rect(cornerRadius: 6))
        case .remote(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color(.secondarySystemBackground).aspectRatio(16 / 9, contentMode: .fit)
                }
            }
            .clipShape(.rect(cornerRadius: 6))
        }
    }

    private func attributed(_ blocks: [WorkDescription.Block]) -> AttributedString {
        var out = AttributedString()
        for (index, block) in blocks.enumerated() {
            if index > 0 { out += AttributedString("\n\n") }
            switch block {
            case .heading(let text):
                var run = AttributedString(text)
                run.font = .subheadline.bold()
                out += run
            case .paragraph(let text):
                var run = AttributedString(text)
                run.font = .subheadline
                out += run
            }
        }
        return out
    }
}

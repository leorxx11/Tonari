import SwiftUI
import TonariCore

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text).font(.title3.bold())
    }
}

/// App Store style label / value rows, only for what DLsite gave us.
struct WorkInfoSection: View {
    let work: Work

    var body: some View {
        let rows = rows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: "信息")
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(row.label).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        row.value.multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if index < rows.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private struct Row {
        let label: String
        let value: AnyView
    }

    private var rows: [Row] {
        var rows: [Row] = []
        func add(_ label: String, _ value: some View) { rows.append(Row(label: label, value: AnyView(value))) }
        if let rating = work.rating, rating > 0 {
            add("评分", HStack(spacing: 6) {
                RatingStars(rating: rating, size: 12)
                Text(rating.formatted(.number.precision(.fractionLength(2))) + (work.ratingCount.map { "（\(Formatting.count($0))）" } ?? ""))
            })
        }
        let popularity = [("销量", work.dlCount), ("心愿单", work.wishlistCount)].compactMap { label, n in n.map { (label, $0) } }
        if !popularity.isEmpty {
            add(popularity.map(\.0).joined(separator: " · "), Text(popularity.map { Formatting.count($0.1) }.joined(separator: " · ")))
        }
        let ranks = [("24 小时", work.rankDay), ("7 日", work.rankWeek), ("30 日", work.rankMonth)]
            .compactMap { label, rank in rank.map { "\(label)第 \($0) 名" } }
        if !ranks.isEmpty { add("排名", Text(ranks.joined(separator: " · "))) }
        if let price = work.currentPrice ?? work.officialPrice {
            add("价格", HStack(spacing: 6) {
                Text("\(Formatting.count(price)) JPY")
                if let discount = work.discountRate, discount > 0 {
                    Text("-\(discount)%").foregroundStyle(.red)
                }
            })
        }
        let file = [work.fileSize, work.fileFormats.isEmpty ? nil : work.fileFormats.joined(separator: "、")]
            .compactMap(\.self).filter { !$0.isEmpty }
        if !file.isEmpty { add("文件", Text(file.joined(separator: " · "))) }
        let kind = [work.workTypeName, work.ageRating].compactMap(\.self).filter { !$0.isEmpty }
        if !kind.isEmpty { add("类型 · 年龄", Text(kind.joined(separator: " · "))) }
        if let original = work.originalProductId {
            add("翻译自", Link(original, destination: DLsite.workURL(original)))
        }
        return rows
    }
}

extension EnvironmentValues {
    /// Where a tapped tag, series or creator leads: the library's works by
    /// default, DLsite's list on an online work.
    @Entry var chipRoute: (WorkChip) -> Route = { .chip($0) }
}

/// Tags and series as capsules that open the works sharing them.
struct WorkTagsSection: View {
    let work: Work

    @Environment(AppModel.self) private var model
    @Environment(\.chipRoute) private var chipRoute

    var body: some View {
        let chips = work.genreNames.map { WorkChip(.genre, $0) }
            + [work.seriesName].compactMap(\.self).filter { !$0.isEmpty }.map { WorkChip(.series, $0) }
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "标签")
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Button(chip.kind == .series ? chip.label : chip.value) { model.push(chipRoute(chip)) }
                            .buttonStyle(TagButtonStyle())
                    }
                }
            }
        }
    }
}

private struct TagButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill).opacity(configuration.isPressed ? 0.5 : 1), in: .capsule)
    }
}

/// Scenario, illustration and music credits; voice actors sit under the title.
struct WorkCreditsSection: View {
    let work: Work

    @Environment(AppModel.self) private var model
    @Environment(\.chipRoute) private var chipRoute

    var body: some View {
        let rows: [(WorkChip.Kind, [String])] = [
            (.scenarioWriter, work.scenarioWriters), (.illustrator, work.illustrators), (.musician, work.musicians),
        ].filter { !$0.1.isEmpty }
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle(text: "演职员")
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(row.0.label).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        FlowLayout(spacing: 0, lineSpacing: 2) {
                            ForEach(Array(row.1.enumerated()), id: \.offset) { index, name in
                                Button((index > 0 ? "、" : "") + name) { model.push(chipRoute(WorkChip(row.0, name))) }
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if index < rows.count - 1 { Divider() }
                    }
                }
            }
        }
    }
}

/// The DLsite description folded to three lines; images join it once
/// expanded and open the gallery, or offer a download where missing.
struct WorkDescriptionSection: View {
    let work: Work
    let showsOriginal: Bool
    let galleryZoom: Namespace.ID
    let openGallery: (GallerySelection) -> Void

    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @State private var items: [WorkDescription.Item] = []
    @State private var expanded = false
    /// Bumped after a download so the files on disk are looked at again.
    @State private var downloads = 0

    var body: some View {
        let translated = work.descriptionHtmlZh.flatMap { $0.isEmpty ? nil : $0 }
        let html = showsOriginal ? work.descriptionHtml : translated ?? work.descriptionHtml
        VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                SectionTitle(text: "简介")
                if expanded { full.id(downloads) } else { folded }
            }
        }
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

    private var textBlocks: [WorkDescription.Block] {
        items.flatMap { item -> [WorkDescription.Block] in
            if case .text(let blocks) = item { blocks } else { [] }
        }
    }

    /// Only the opening blocks: laying out a whole description (often over
    /// ten thousand characters) on the main thread stalls the push.
    private var folded: some View {
        var shown: [WorkDescription.Block] = []
        var length = 0
        for block in textBlocks where length < 400 {
            shown.append(block)
            length += block.text.count
        }
        let more = shown.count < textBlocks.count || length > 60 || !WorkDescription.imageURLs(items).isEmpty
        return VStack(alignment: .trailing, spacing: 4) {
            Text(attributed(shown))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if more {
                Button("更多") { withAnimation { expanded = true } }
                    .font(.subheadline.weight(.medium))
            }
        }
    }

    private var full: some View {
        let local = localImages
        let shown = local.compactMap(\.self)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .text(let blocks):
                    Text(attributed(blocks))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .image(let url):
                    if let path = local[WorkDescription.imageURLs(items).firstIndex(of: url)!] {
                        FittedLocalImage(path: path)
                            .clipShape(.rect(cornerRadius: 6))
                            .matchedTransitionSource(id: path, in: galleryZoom)
                            .onTapGesture {
                                openGallery(GallerySelection(images: shown.map(GalleryImage.local), index: shown.firstIndex(of: path)!))
                            }
                    } else {
                        missingImage
                    }
                }
            }
        }
    }

    /// Each description image's downloaded copy, nil where there is none.
    /// Images only ever show from disk, so what's on screen never depends
    /// on being online.
    private var localImages: [String?] {
        let paths = work.descriptionImageLocalPaths
        return WorkDescription.imageURLs(items).indices.map { index in
            guard index < paths.count, !paths[index].isEmpty else { return nil }
            return FileManager.default.fileExists(atPath: URL.documentsDirectory.appending(path: paths[index]).path) ? paths[index] : nil
        }
    }

    private var missingImage: some View {
        HStack(spacing: 12) {
            Label("简介图片未下载", systemImage: "photo.badge.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("下载", action: downloadImages)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(model.tasks.isBusy)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
    }

    /// Fetches whatever images the work is missing; ones on disk are kept.
    private func downloadImages() {
        let tasks = model.tasks
        let productId = work.productId
        Task {
            await tasks.run("下载简介图片", detail: productId) {
                try await enrichment.service.downloadMissingImages(productId) { completed, total, label in
                    Task { @MainActor in tasks.report("\(label)（\(completed)/\(total)）") }
                }
                return "简介图片已下载"
            }
            downloads += 1
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

private extension WorkDescription.Block {
    var text: String {
        switch self {
        case .heading(let text), .paragraph(let text): text
        }
    }
}

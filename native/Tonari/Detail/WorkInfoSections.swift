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

/// Tags and series as capsules that open the works sharing them.
struct WorkTagsSection: View {
    let work: Work

    @Environment(AppModel.self) private var model

    var body: some View {
        let chips = work.genreNames.map { WorkChip(.genre, $0) }
            + [work.seriesName].compactMap(\.self).filter { !$0.isEmpty }.map { WorkChip(.series, $0) }
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "标签")
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Button(chip.kind == .series ? chip.label : chip.value) { model.push(.chip(chip)) }
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
                                Button((index > 0 ? "、" : "") + name) { model.push(.chip(WorkChip(row.0, name))) }
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
/// expanded and open the gallery.
struct WorkDescriptionSection: View {
    let work: Work
    let showsOriginal: Bool
    let openGallery: (GallerySelection) -> Void

    @State private var items: [WorkDescription.Item] = []
    @State private var expanded = false

    var body: some View {
        let translated = work.descriptionHtmlZh.flatMap { $0.isEmpty ? nil : $0 }
        let html = showsOriginal ? work.descriptionHtml : translated ?? work.descriptionHtml
        VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                SectionTitle(text: "简介")
                if expanded { full } else { folded }
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
        let images = galleryImages
        let urls = WorkDescription.imageURLs(items)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .text(let blocks):
                    Text(attributed(blocks))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .image(let url):
                    let index = urls.firstIndex(of: url)!
                    descriptionImage(images[index])
                        .onTapGesture { openGallery(GallerySelection(images: images, index: index)) }
                }
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

private extension WorkDescription.Block {
    var text: String {
        switch self {
        case .heading(let text), .paragraph(let text): text
        }
    }
}

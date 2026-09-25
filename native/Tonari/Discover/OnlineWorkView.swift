import SwiftUI
import TonariCore

/// A work read live from DLsite, laid out like the library's work page but
/// nothing is stored and images load over the network. The description
/// starts open: the page is one lazy stack with a row per paragraph, so a
/// long description lays out only as it scrolls in.
struct OnlineWorkView: View {
    let productId: String

    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(\.appDatabase) private var database
    @State private var work: Work?
    @State private var error: String?
    @State private var owned = false

    var body: some View {
        Group {
            if let work {
                page(work)
            } else if let error {
                ContentUnavailableView {
                    Label("加载失败", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("重试") { Task { await load() } }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(productId)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu("更多", systemImage: "ellipsis") {
                Button("复制 RJ 号", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = productId
                    model.notices.show("已复制 \(productId)")
                }
                Link(destination: DLsite.workURL(productId)) {
                    Label("在 DLsite 中打开", systemImage: "safari")
                }
            }
        }
        .task { await load() }
        .task {
            await database.observe({ [productId] db in
                try Work.filter(key: productId).filter(Column("is_removed") == false).fetchCount(db) > 0
            }) { owned = $0 }
        }
    }

    private func load() async {
        error = nil
        do {
            work = try await enrichment.service.preview(productId)
        } catch {
            DiagnosticLog.shared.write("discover", "work_failed", ["productId": productId, "error": "\(error)"])
            self.error = error.localizedDescription
        }
    }

    private func page(_ work: Work) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if owned {
                    Button { model.push(.work(productId)) } label: {
                        HStack {
                            Label("已在资料库", systemImage: "checkmark.circle.fill")
                            Spacer()
                            Text("打开").fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding(12)
                        .background(.green.opacity(0.12), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                gallery(work)
                titleBlock(work)
                Link(destination: DLsite.workURL(productId)) {
                    Label("在 DLsite 中打开", systemImage: "safari")
                        .font(.headline)
                        .foregroundStyle(Color(.systemBackground))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.primary, in: .capsule)
                }
                Group {
                    WorkInfoSection(work: work)
                    WorkTagsSection(work: work)
                    WorkCreditsSection(work: work)
                }
                .padding(.top, 10)
                .environment(\.chipRoute) { Self.route($0, in: work) }
                if let html = work.descriptionHtml, let items = try? WorkDescription.parse(html), !items.isEmpty {
                    Text("简介").font(.title3.bold()).padding(.top, 10)
                    ForEach(Array(Self.rows(items).enumerated()), id: \.offset) { _, row in
                        switch row {
                        case .heading(let text): Text(text).font(.subheadline.bold()).textSelection(.enabled)
                        case .paragraph(let text): Text(text).font(.subheadline).textSelection(.enabled)
                        case .image(let url):
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit().clipShape(.rect(cornerRadius: 6))
                            } placeholder: {
                                Color(.secondarySystemBackground).aspectRatio(16 / 10, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func gallery(_ work: Work) -> some View {
        let urls = ([work.mainImageUrl].compactMap(\.self) + work.sampleImageUrls).compactMap(URL.init(string:))
        return TabView {
            ForEach(urls, id: \.self) { url in
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
        .aspectRatio(4 / 3, contentMode: .fit)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func titleBlock(_ work: Work) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(work.title).font(.title2.bold()).textSelection(.enabled)
            if !work.voiceActors.isEmpty {
                FlowLayout(spacing: 0, lineSpacing: 2) {
                    ForEach(Array(work.voiceActors.enumerated()), id: \.offset) { index, name in
                        Button((index > 0 ? "、" : "") + name) { model.push(.catalog(.creator(name))) }
                    }
                }
            }
            HStack(spacing: 0) {
                if let circle = work.circleName, !circle.isEmpty {
                    Button(circle) { model.push(.catalog(.circle(circle))) }
                }
                let rest = [work.releaseDate.map(Formatting.date), work.supportedLanguages.isEmpty ? nil : work.supportedLanguages.joined(separator: "、")]
                    .compactMap(\.self)
                ForEach(Array(rest.enumerated()), id: \.offset) { _, part in Text(" · " + part) }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    /// Tags, series and creators lead to DLsite's lists. A tag DLsite gave
    /// no id for can't be searched there, so it opens the library's instead.
    private static func route(_ chip: WorkChip, in work: Work) -> Route {
        switch chip.kind {
        case .genre:
            work.genresJson.first { $0.name == chip.value }?.id.map { .catalog(.genre(id: $0, name: chip.value)) } ?? .chip(chip)
        case .series:
            work.seriesId.map { .catalog(.series(id: $0, name: chip.value)) } ?? .chip(chip)
        case .circle:
            .catalog(.circle(chip.value))
        case .voiceActor, .scenarioWriter, .illustrator, .musician:
            .catalog(.creator(chip.value))
        }
    }

    private enum Row {
        case heading(String)
        case paragraph(String)
        case image(URL)
    }

    /// One row per heading, paragraph or image, for the lazy stack.
    private static func rows(_ items: [WorkDescription.Item]) -> [Row] {
        items.flatMap { item -> [Row] in
            switch item {
            case .text(let blocks):
                blocks.map { block in
                    switch block {
                    case .heading(let text): .heading(text)
                    case .paragraph(let text): .paragraph(text)
                    }
                }
            case .image(let url):
                [URL(string: url.hasPrefix("//") ? "https:" + url : url)].compactMap(\.self).map(Row.image)
            }
        }
    }
}

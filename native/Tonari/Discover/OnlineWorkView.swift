import SwiftUI
import TonariCore

/// A work read live from DLsite, laid out like the library's work page;
/// nothing enters the library and images load over the network. A copy
/// opened before shows at once while a fresh one loads. The description
/// starts open: the page is one lazy stack with a row per paragraph, so a
/// long description lays out only as it scrolls in. The chobit preview, if
/// any, plays in the page.
struct OnlineWorkView: View {
    let productId: String

    @Environment(AppModel.self) private var model
    @Environment(EnrichmentQueue.self) private var enrichment
    @Environment(PlaybackController.self) private var player
    @Environment(VideoController.self) private var video
    @Environment(\.appDatabase) private var database
    @State private var samples = SamplePlayer()
    @State private var work: Work?
    @State private var error: String?
    @State private var owned = false
    @State private var wanted = false

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
        .onDisappear { samples.stop() }
        .task {
            if model.wishlist.isSignedIn, model.wishlist.ids == nil { await model.wishlist.load(details: false) }
        }
        .task {
            await database.observe({ [productId] db in
                (
                    try Work.filter(key: productId).filter(Column("is_removed") == false).fetchCount(db) > 0,
                    try WantedWorks.contains(productId, db)
                )
            }) {
                owned = $0.0
                wanted = $0.1
            }
        }
    }

    /// The saved copy first, then the work and its preview fetched side by
    /// side so the preview doesn't pop in after everything else.
    private func load() async {
        error = nil
        if work == nil {
            work = OnlineWorkCache.work(productId)
            OnlineWorkCache.sample(productId).map(samples.load)
        }
        async let sample = fetchSample(productId)
        do {
            let fresh = try await enrichment.service.preview(productId)
            work = fresh
            OnlineWorkCache.save(fresh)
        } catch {
            DiagnosticLog.shared.write("discover", "work_failed", ["productId": productId, "error": "\(error)"])
            if work == nil { self.error = error.localizedDescription }
        }
        // A translation edition's preview lives under the original.
        var found = await sample
        if found == nil, let original = work?.originalProductId { found = await fetchSample(original) }
        if let found {
            samples.load(found)
            OnlineWorkCache.save(found, for: productId)
        }
    }

    private nonisolated func fetchSample(_ workno: String) async -> ChobitSample? {
        let client = DLsiteClient()
        do {
            return try await ChobitSample.fetch(workno, get: { try await client.fetch($0) })
        } catch {
            DiagnosticLog.shared.write("discover", "sample_failed", ["productId": workno, "error": "\(error)"])
            return nil
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
                actions(work)
                if !samples.tracks.isEmpty { sampleSection }
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

    /// 待入库 · the DLsite wishlist · DLsite, where the library page has
    /// shuffle · play · favorite.
    private func actions(_ work: Work) -> some View {
        let wished = model.wishlist.contains(productId)
        return HStack(spacing: 14) {
            circleButton(wanted ? "移出待入库" : "加入待入库", systemImage: wanted ? "tray.full.fill" : "tray", tint: wanted ? .pink : .primary) {
                if wanted {
                    try! database.removeWanted(productId)
                } else {
                    try! database.addWanted(WantedWork(
                        productId: productId, title: work.title, circle: work.circleName, coverUrl: work.mainImageUrl!, addedAt: .now
                    ))
                    model.notices.show("已加入待入库")
                }
            }
            Button {
                if model.wishlist.isSignedIn {
                    Task { await model.wishlist.toggle(productId) }
                } else {
                    model.showingDLsiteLogin = true
                }
            } label: {
                Label(wished ? "已在愿望单" : "加入愿望单", systemImage: wished ? "heart.fill" : "heart")
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.primary, in: .capsule)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            Link(destination: DLsite.workURL(productId)) {
                Image(systemName: "safari")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 50, height: 50)
                    .background(Color(.tertiarySystemFill), in: .circle)
            }
            .accessibilityLabel("在 DLsite 中打开")
        }
    }

    /// chobit's tracks in the library page's pager, numbered with their
    /// lengths; the playing one shows how far in.
    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("试听").font(.title3.bold())
                Text("\(samples.tracks.count) 首").font(.subheadline).foregroundStyle(.secondary)
            }
            ColumnPager(count: samples.tracks.count, focus: samples.current, identity: samples.tracks.map(\.url.absoluteString)) { index, last in
                sampleRow(index, last: last)
            }
            .padding(.horizontal, -16)
        }
        .padding(.top, 10)
    }

    private func sampleRow(_ index: Int, last: Bool) -> some View {
        let track = samples.tracks[index]
        let current = samples.current == index
        return Button { samples.toggle(index, pausing: player, video) } label: {
            HStack(spacing: 12) {
                Group {
                    if current {
                        Image(systemName: "waveform")
                            .foregroundStyle(.tint)
                            .symbolEffect(.variableColor.iterative, isActive: samples.isPlaying)
                    } else {
                        Text("\(index + 1)").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.monospacedDigit())
                .frame(width: 24)
                Text(track.title).lineLimit(1)
                Spacer(minLength: 0)
                Text(track.playtime).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(height: PagerRow.height)
            .overlay(alignment: .bottom) {
                if current {
                    ProgressView(value: samples.progress).tint(.accentColor).padding(.leading, 36)
                } else if !last {
                    Divider().padding(.leading, 36)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func circleButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 50, height: 50)
                .background(Color(.tertiarySystemFill), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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

import Foundation
import GRDB

/// Fills works with DLsite metadata and caches their images under
/// `Documents/images/<RJ>/` (stored as paths relative to Documents).
///
/// Every request goes through one serial gate with a pause between works, so
/// the background queue, manual refreshes and the detail page's auto-fetch
/// never hit DLsite concurrently and trip its rate limiting.
public actor MetadataEnrichment {
    public struct Transport: Sendable {
        public var page: @Sendable (String) async throws -> String
        public var productInfo: @Sendable (String) async throws -> Data
        public var download: @Sendable (URL, URL) async throws -> Void

        public static func live(_ client: DLsiteClient = DLsiteClient()) -> Transport {
            Transport(page: client.workPage, productInfo: client.productInfo, download: client.download)
        }
    }

    /// (completed, total, what) while downloading a work's images.
    public typealias ImageProgress = @Sendable (Int, Int, String) -> Void

    private let database: AppDatabase
    private let documents: URL
    private let transport: Transport
    private let pause: Duration
    private var gate: Task<Void, Never>?

    public init(database: AppDatabase, documents: URL, transport: Transport = .live(), pause: Duration = .milliseconds(200)) {
        self.database = database
        self.documents = documents
        self.transport = transport
        self.pause = pause
    }

    /// Whether a work still lacks metadata or its cover file.
    public nonisolated static func needsEnrichment(_ work: Work, documents: URL) -> Bool {
        guard work.scrapedAt != nil, let cover = work.mainImageLocalPath else { return true }
        return !FileManager.default.fileExists(atPath: documents.appending(path: cover).path)
    }

    /// First-time enrichment; returns immediately for a work that has it.
    public func enrich(_ productId: String, onImage: ImageProgress? = nil) async throws {
        try await serially {
            guard let row = try await self.row(productId), Self.needsEnrichment(row, documents: self.documents) else { return }
            try await self.enrichFully(productId, onImage: onImage)
        }
    }

    /// Re-fetches text and stats but keeps cached images. A translation
    /// survives unless the text it was made from changed.
    public func refreshMetadata(_ productId: String, onImage: ImageProgress? = nil) async throws {
        try await serially {
            guard let row = try await self.row(productId) else { return }
            if Self.needsEnrichment(row, documents: self.documents) {
                return try await self.enrichFully(productId, onImage: onImage)
            }
            let work = try await self.fetchWork(productId)
            let stats = try? await self.fetchStats(productId)
            try await self.update(productId) { row in
                let titleChanged = work.title != row.title
                let descriptionChanged = Self.content(work.descriptionHtml) != Self.content(row.descriptionHtml)
                Self.apply(work, stats, to: &row)
                if titleChanged { row.titleZh = nil }
                if descriptionChanged { row.descriptionHtmlZh = nil }
                row.scrapedAt = .now
            }
        }
    }

    /// What a translation is made from. Compared instead of raw HTML because
    /// serializers spell markup differently (`<img>` vs `<img />`), and a
    /// description stored by the Flutter build must still count as unchanged.
    static func content(_ html: String?) -> [WorkDescription.Item]? {
        try? html.map(WorkDescription.parse)
    }

    /// Only the fast-changing numbers: sales, rating, price, ranks.
    public func refreshStats(_ productId: String) async throws {
        try await serially {
            let stats = try await self.fetchStats(productId)
            guard !stats.isEmpty else { throw DLsiteClient.Failure("DLsite 没有 \(productId) 的统计数据") }
            try await self.update(productId) { Self.apply(stats, to: &$0) }
        }
    }

    /// Re-downloads a work's images, leaving every other column alone.
    public func refreshImages(_ productId: String, onImage: ImageProgress? = nil) async throws {
        try await downloadImages(productId, replacing: true, onImage: onImage)
    }

    /// Downloads only the images missing on disk, e.g. description images
    /// cleared from storage; the cover and samples stay where they are.
    public func downloadMissingImages(_ productId: String, onImage: ImageProgress? = nil) async throws {
        try await downloadImages(productId, replacing: false, onImage: onImage)
    }

    private func downloadImages(_ productId: String, replacing: Bool, onImage: ImageProgress?) async throws {
        try await serially {
            guard let row = try await self.row(productId) else { return }
            guard let mainUrl = row.mainImageUrl else {
                throw DLsiteClient.Failure("\(productId) 还没有抓取过元数据，无法下载图片")
            }
            let descriptionUrls = try row.descriptionHtml.map(WorkDescription.parse).map(WorkDescription.imageURLs) ?? []
            let dir = self.documents.appending(path: "images/\(productId)")
            if replacing, FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.removeItem(at: dir)
            }
            let images = try await self.cacheImages(productId, main: mainUrl, samples: row.sampleImageUrls, descriptions: descriptionUrls, onImage: onImage)
            try await self.update(productId) { images.apply(to: &$0) }
        }
    }

    /// `refreshStats` over every enriched work; returns how many failed.
    public func refreshAllStats(onProgress: @Sendable (Int, Int) -> Void) async -> Int {
        let ids = try! await database.reader.read { db in
            try String.fetchAll(db, sql: "SELECT product_id FROM works WHERE is_removed = 0 AND scraped_at IS NOT NULL ORDER BY product_id")
        }
        var failed = 0
        for (index, id) in ids.enumerated() {
            onProgress(index, ids.count)
            do {
                try await refreshStats(id)
            } catch {
                failed += 1
                DiagnosticLog.shared.write("metadata", "stats_refresh_failed", ["productId": id, "error": "\(error)"])
            }
        }
        onProgress(ids.count, ids.count)
        return failed
    }

    // MARK: - Internals

    private func serially(_ body: @escaping @Sendable () async throws -> Void) async throws {
        let previous = gate
        let pause = self.pause
        let run = Task {
            await previous?.value
            try await body()
        }
        gate = Task {
            _ = try? await run.value
            try? await Task.sleep(for: pause)
        }
        try await run.value
    }

    private func enrichFully(_ productId: String, onImage: ImageProgress?) async throws {
        let work = try await fetchWork(productId)
        let stats = try? await fetchStats(productId)
        let images = try await cacheImages(
            productId, main: work.mainImageUrl, samples: work.sampleImageUrls,
            descriptions: work.descriptionImageUrls, onImage: onImage
        )
        try await update(productId) { row in
            Self.apply(work, stats, to: &row)
            images.apply(to: &row)
            row.scrapedAt = .now
        }
    }

    /// A work straight from DLsite and not stored, for works outside the
    /// library; its images stay remote (`mainImageUrl`, `sampleImageUrls`).
    public func preview(_ productId: String) async throws -> Work {
        let work = try await fetchWork(productId)
        let stats = try? await fetchStats(productId)
        var row = Work.shell(productId, folderPath: "", folderId: nil, at: .now)
        Self.apply(work, stats, to: &row)
        row.scrapedAt = .now
        return row
    }

    /// DLsite translation editions (e.g. 大家一起来翻译) have their own RJ but a
    /// sparse page: no sample gallery, often no cast or runtime. Fetch the
    /// original and merge.
    private func fetchWork(_ productId: String) async throws -> DLsiteWork {
        let translated = try DLsiteParser.parseHTML(try await transport.page(productId), productId: productId)
        guard let originalId = translated.originalProductId else { return translated }
        do {
            let original = try DLsiteParser.parseHTML(try await transport.page(originalId), productId: originalId)
            return Self.merge(translated, original)
        } catch {
            DiagnosticLog.shared.write("metadata", "original_fetch_failed", ["productId": productId, "original": originalId, "error": "\(error)"])
            return translated
        }
    }

    private func fetchStats(_ productId: String) async throws -> DLsiteStats {
        DLsiteParser.parseAjax(try await transport.productInfo(productId), productId: productId)
    }

    /// The translation wins for localized fields (title, description,
    /// languages); the original for catalog data translation pages omit
    /// (gallery, cast, runtime, tags). Stats come from neither.
    static func merge(_ t: DLsiteWork, _ o: DLsiteWork) -> DLsiteWork {
        var m = t
        m.titleRomaji = t.titleRomaji ?? o.titleRomaji
        m.circleId = t.circleId ?? o.circleId
        m.circleName = t.circleName ?? o.circleName
        m.releaseDate = o.releaseDate ?? t.releaseDate
        m.voiceActors = o.voiceActors.isEmpty ? t.voiceActors : o.voiceActors
        m.illustrators = o.illustrators.isEmpty ? t.illustrators : o.illustrators
        m.scenarioWriters = o.scenarioWriters.isEmpty ? t.scenarioWriters : o.scenarioWriters
        m.musicians = o.musicians.isEmpty ? t.musicians : o.musicians
        m.ageRating = t.ageRating ?? o.ageRating
        m.workType = t.workType ?? o.workType
        m.workTypeName = t.workTypeName ?? o.workTypeName
        m.fileFormats = t.fileFormats.isEmpty ? o.fileFormats : t.fileFormats
        m.supportedLanguages = t.supportedLanguages.isEmpty ? o.supportedLanguages : t.supportedLanguages
        m.genres = o.genres.isEmpty ? t.genres : o.genres
        m.fileSize = o.fileSize ?? t.fileSize
        m.seriesId = t.seriesId ?? o.seriesId
        m.seriesName = t.seriesName ?? o.seriesName
        m.descriptionHtml = t.descriptionHtml ?? o.descriptionHtml
        m.mainImageUrl = o.mainImageUrl
        m.sampleImageUrls = o.sampleImageUrls.isEmpty ? t.sampleImageUrls : o.sampleImageUrls
        m.descriptionImageUrls = t.descriptionImageUrls.isEmpty ? o.descriptionImageUrls : t.descriptionImageUrls
        return m
    }

    static func apply(_ work: DLsiteWork, _ stats: DLsiteStats?, to row: inout Work) {
        if let stats { apply(stats, to: &row) }
        row.title = work.title
        row.titleRomaji = work.titleRomaji
        row.originalProductId = work.originalProductId
        row.circleId = work.circleId
        row.circleName = work.circleName
        row.releaseDate = work.releaseDate
        row.voiceActors = work.voiceActors
        row.illustrators = work.illustrators
        row.scenarioWriters = work.scenarioWriters
        row.musicians = work.musicians
        row.ageRating = work.ageRating
        row.workType = work.workType
        row.workTypeName = work.workTypeName
        row.fileFormats = work.fileFormats
        row.supportedLanguages = work.supportedLanguages
        row.genresJson = work.genres
        row.fileSize = work.fileSize
        row.seriesId = work.seriesId
        row.seriesName = work.seriesName
        row.descriptionHtml = work.descriptionHtml
        row.mainImageUrl = work.mainImageUrl
        row.sampleImageUrls = work.sampleImageUrls
    }

    static func apply(_ stats: DLsiteStats, to row: inout Work) {
        row.rating = stats.rateAverage
        row.ratingCount = stats.rateCount
        row.reviewCount = stats.reviewCount
        row.dlCount = stats.dlCount
        row.wishlistCount = stats.wishlistCount
        row.rankDay = stats.rankDay
        row.rankWeek = stats.rankWeek
        row.rankMonth = stats.rankMonth
        row.currentPrice = stats.price
        row.officialPrice = stats.officialPrice
        row.discountRate = stats.discountRate
    }

    struct CachedImages {
        let main: String
        let samples: [String]
        /// Aligned with the description's image URLs; "" where a download failed.
        let descriptions: [String]

        func apply(to row: inout Work) {
            row.mainImageLocalPath = main
            row.sampleImageLocalPaths = samples
            row.descriptionImageLocalPaths = descriptions
        }
    }

    private func cacheImages(
        _ productId: String, main: String, samples: [String], descriptions: [String], onImage: ImageProgress?
    ) async throws -> CachedImages {
        let relativeDir = "images/\(productId)"
        try FileManager.default.createDirectory(at: documents.appending(path: relativeDir), withIntermediateDirectories: true)
        enum Slot { case main, sample, description }
        let jobs: [(slot: Slot, url: String, name: String, label: String)] =
            [(.main, main, "main", "主图")]
            + samples.enumerated().map { (.sample, $1, "smp\($0 + 1)", "样本图 \($0 + 1)/\(samples.count)") }
            + descriptions.enumerated().map { (.description, $1, "desc\($0 + 1)", "描述图 \($0 + 1)/\(descriptions.count)") }

        var mainPath: String?
        var samplePaths: [String] = []
        var descriptionPaths: [String] = []
        for (done, job) in jobs.enumerated() {
            onImage?(done, jobs.count, job.label)
            let relative = "\(relativeDir)/\(job.name)\(Self.imageExtension(job.url))"
            let target = documents.appending(path: relative)
            var saved: String?
            if let size = try? FileManager.default.attributesOfItem(atPath: target.path)[.size] as? Int, size > 0 {
                saved = relative
            } else {
                do {
                    try await transport.download(URL(string: job.url)!, target)
                    saved = relative
                } catch {
                    DiagnosticLog.shared.write("metadata", "image_download_failed", ["url": job.url, "error": "\(error)"])
                }
            }
            switch job.slot {
            case .main: mainPath = saved
            case .sample: if let saved { samplePaths.append(saved) }
            case .description: descriptionPaths.append(saved ?? "")
            }
            onImage?(done + 1, jobs.count, job.label)
        }
        guard let mainPath else { throw DLsiteClient.Failure("主图下载失败：\(productId)") }
        return CachedImages(main: mainPath, samples: samplePaths, descriptions: descriptionPaths)
    }

    /// Extension from the URL, `.jpg` when missing or implausible.
    static func imageExtension(_ url: String) -> String {
        let path = URL(string: url)?.path ?? url
        let ext = (path as NSString).pathExtension
        return ext.isEmpty || ext.count > 4 ? ".jpg" : ".\(ext)"
    }

    private func row(_ productId: String) async throws -> Work? {
        try await database.reader.read { try Work.fetchOne($0, key: productId) }
    }

    private func update(_ productId: String, _ change: @escaping @Sendable (inout Work) -> Void) async throws {
        try await database.writer.write { db in
            guard var row = try Work.fetchOne(db, key: productId) else { return }
            change(&row)
            row.updatedAt = .now
            try row.update(db)
        }
    }
}

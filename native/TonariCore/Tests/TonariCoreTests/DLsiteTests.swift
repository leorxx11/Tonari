import Foundation
import GRDB
import Testing
@testable import TonariCore

private func fixture(_ name: String) throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: "Fixtures/dlsite/\(name)", withExtension: nil)!)
}

struct DLsiteParserTests {
    let work: DLsiteWork

    init() throws {
        work = try DLsiteParser.parseHTML(String(decoding: try fixture("RJ01560714.html"), as: UTF8.self), productId: "RJ01560714")
    }

    @Test func bucketsRoundUpToTheNextThousand() {
        #expect(DLsiteParser.bucket("RJ01560714") == "RJ01561000")
        #expect(DLsiteParser.bucket("RJ01561000") == "RJ01561000")
        #expect(DLsiteParser.bucket("RJ123456") == "RJ124000")
        #expect(DLsiteParser.bucket("RJ000001") == "RJ001000")
        #expect(DLsiteParser.mainImageURL("RJ01560714") == "https://img.dlsite.jp/modpub/images2/work/doujin/RJ01561000/RJ01560714_img_main.jpg")
    }

    @Test func readsCatalogFields() {
        #expect(work.title == "【ドスケベ淫語連鎖コンボ】低音ドスケベ爆乳ムチムチお姉ちゃんドスケベ淫乱ドスケベえちえちお姉ちゃんライフ【フォーリーサウンド】")
        #expect(work.titleRomaji?.contains("dosukebe") == true)
        #expect(work.circleName == "Rad.Revel")
        #expect(work.circleId == "RG60242")
        #expect(work.releaseDate == Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 9)))
        #expect(work.voiceActors == ["柚木つばめ"])
        #expect(work.illustrators == ["oekakizuki"])
        #expect(work.scenarioWriters == ["Rad.Revel"])
        #expect(work.musicians.isEmpty)
        #expect(work.ageRating == "R18")
        #expect(work.workType == "SOU")
        #expect(work.workTypeName == "音声・ASMR")
        #expect(Set(["WAV", "MP3"]).isSubset(of: work.fileFormats))
        #expect(work.fileSize == "3.6GB")
        #expect(work.supportedLanguages == ["日语"])
        #expect(work.genres.count >= 8)
        #expect(work.genres.contains(Work.Genre(id: "068", name: "淫语")))
        #expect(work.genres.map(\.name).contains("哦吼淫叫"))
        #expect(work.seriesId == nil)
        #expect(work.seriesName == nil)
        #expect(work.originalProductId == nil)
        #expect(work.descriptionHtml?.isEmpty == false)
    }

    @Test func readsImages() {
        #expect(work.mainImageUrl == "https://img.dlsite.jp/modpub/images2/work/doujin/RJ01561000/RJ01560714_img_main.jpg")
        #expect(work.sampleImageUrls.count >= 7)
        #expect(work.sampleImageUrls.allSatisfy { !$0.contains("_img_main") })
        #expect(work.sampleImageUrls.first?.hasPrefix("https://img.dlsite.jp/modpub/images2/work/doujin/RJ01561000/RJ01560714_img_smp") == true)
    }

    @Test func translationEditionPointsAtOriginal() {
        #expect(DLsiteParser.imageProductId("//img.dlsite.jp/modpub/images2/work/doujin/RJ01479000/RJ01478826_img_main.jpg") == "RJ01478826")
    }

    @Test func readsAjaxStats() throws {
        let stats = DLsiteParser.parseAjax(try fixture("RJ01560714_ajax.json"), productId: "RJ01560714")
        #expect(stats.dlCount == 3991)
        #expect(stats.wishlistCount == 5114)
        #expect(stats.rateAverage == 4.85)
        #expect(stats.rateCount == 195)
        #expect(stats.reviewCount == 1)
        #expect([stats.rankDay, stats.rankWeek, stats.rankMonth] == [2, 16, 43])
        #expect(stats.price == 1650)
        #expect(stats.officialPrice == 1650)
        #expect(stats.discountRate == 0)
    }

    @Test func ajaxEdgeCases() {
        func parse(_ body: String, _ id: String = "RJ01560714") -> DLsiteStats {
            DLsiteParser.parseAjax(Data(body.utf8), productId: id)
        }
        #expect(parse(#"{"RJ999999":{"dl_count":1}}"#).isEmpty)
        #expect(parse("not-json").isEmpty)
        let discounted = parse(#"{"RJ01560714":{"price":1100,"official_price":2200}}"#)
        #expect(discounted.discountRate == 50)
        #expect(parse(#"{"RJ01465837":{"dl_count":4714,"dl_count_total":0}}"#, "RJ01465837").dlCount == 4714)
        #expect(parse(#"{"RJ01560714":{"dl_count":42}}"#).dlCount == 42)
    }

    @Test func mergePrefersOriginalCatalogAndTranslatedText() {
        var t = DLsiteWork(productId: "RJ2", title: "译名", mainImageUrl: "t.jpg")
        t.originalProductId = "RJ1"
        t.descriptionHtml = "中文简介"
        var o = DLsiteWork(productId: "RJ1", title: "原名", mainImageUrl: "o.jpg")
        o.voiceActors = ["CV"]
        o.sampleImageUrls = ["s1"]
        o.descriptionHtml = "日本語"
        let m = MetadataEnrichment.merge(t, o)
        #expect(m.title == "译名")
        #expect(m.descriptionHtml == "中文简介")
        #expect(m.voiceActors == ["CV"])
        #expect(m.sampleImageUrls == ["s1"])
        #expect(m.mainImageUrl == "o.jpg")
        #expect(m.originalProductId == "RJ1")
    }

    @Test func imageExtensionFallsBackToJpg() {
        #expect(MetadataEnrichment.imageExtension("https://a/b/x.png?v=1") == ".png")
        #expect(MetadataEnrichment.imageExtension("https://a/b/noext") == ".jpg")
    }
}

struct MetadataEnrichmentTests {
    let documents = URL.temporaryDirectory.appending(path: UUID().uuidString)

    private func service(_ db: AppDatabase, downloads: Downloads) throws -> MetadataEnrichment {
        let html = String(decoding: try fixture("RJ01560714.html"), as: UTF8.self)
        let ajax = try fixture("RJ01560714_ajax.json")
        return MetadataEnrichment(database: db, documents: documents, transport: .init(
            page: { _ in html },
            productInfo: { _ in ajax },
            download: { url, target in
                downloads.record(url)
                try Data("img".utf8).write(to: target)
            }
        ), pause: .zero)
    }

    final class Downloads: @unchecked Sendable {
        private let lock = NSLock()
        private var urls: [URL] = []
        func record(_ url: URL) { lock.withLock { urls.append(url) } }
        var count: Int { lock.withLock { urls.count } }
    }

    @Test func enrichFillsWorkAndCachesImagesOnce() async throws {
        let db = try AppDatabase.inMemory()
        try await db.writer.write { try Work.shell("RJ01560714", folderPath: "/x", folderId: nil, at: .now).insert($0) }
        let downloads = Downloads()
        let enrichment = try service(db, downloads: downloads)

        try await enrichment.enrich("RJ01560714")
        let work = try await db.reader.read { try Work.fetchOne($0, key: "RJ01560714")! }
        #expect(work.circleName == "Rad.Revel")
        #expect(work.dlCount == 3991)
        #expect(work.mainImageLocalPath == "images/RJ01560714/main.jpg")
        #expect(work.sampleImageLocalPaths.count >= 7)
        #expect(work.scrapedAt != nil)
        #expect(!MetadataEnrichment.needsEnrichment(work, documents: documents))

        let firstCount = downloads.count
        try await enrichment.enrich("RJ01560714")
        #expect(downloads.count == firstCount)
    }

    @Test func refreshMetadataKeepsTranslationWhenTextIsUnchanged() async throws {
        let db = try AppDatabase.inMemory()
        try await db.writer.write { try Work.shell("RJ01560714", folderPath: "/x", folderId: nil, at: .now).insert($0) }
        let enrichment = try service(db, downloads: Downloads())
        try await enrichment.enrich("RJ01560714")
        try await db.writer.write { try $0.execute(sql: "UPDATE works SET title_zh = '译', description_html_zh = '译文'") }

        try await enrichment.refreshMetadata("RJ01560714")
        let kept = try await db.reader.read { try Work.fetchOne($0, key: "RJ01560714")! }
        #expect(kept.titleZh == "译")
        #expect(kept.descriptionHtmlZh == "译文")

        // Same content, markup spelled the way the Flutter build stored it.
        try await db.writer.write { try $0.execute(sql: "UPDATE works SET description_html = replace(description_html, ' />', '>')") }
        try await enrichment.refreshMetadata("RJ01560714")
        #expect(try await db.reader.read { try Work.fetchOne($0, key: "RJ01560714")! }.descriptionHtmlZh == "译文")

        try await db.writer.write { try $0.execute(sql: "UPDATE works SET title = '旧标题'") }
        try await enrichment.refreshMetadata("RJ01560714")
        let reset = try await db.reader.read { try Work.fetchOne($0, key: "RJ01560714")! }
        #expect(reset.titleZh == nil)
        #expect(reset.descriptionHtmlZh == "译文")
    }
}

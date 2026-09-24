import Foundation
import SwiftSoup

/// Catalog data from a DLsite work page (fetched with `locale=zh-cn`, so the
/// outline labels are Chinese).
public struct DLsiteWork: Sendable, Equatable {
    public var productId: String
    public var title: String
    public var titleRomaji: String?
    /// For a translation edition, the original release's RJ number, found in
    /// the og:image URL, which always points at the original's image bucket.
    public var originalProductId: String?
    public var circleId: String?
    public var circleName: String?
    public var releaseDate: Date?
    public var voiceActors: [String] = []
    public var illustrators: [String] = []
    public var scenarioWriters: [String] = []
    public var musicians: [String] = []
    public var ageRating: String?
    public var workType: String?
    public var workTypeName: String?
    public var fileFormats: [String] = []
    public var supportedLanguages: [String] = []
    public var genres: [Work.Genre] = []
    public var fileSize: String?
    public var seriesId: String?
    public var seriesName: String?
    public var descriptionHtml: String?
    public var mainImageUrl: String
    public var sampleImageUrls: [String] = []
    public var descriptionImageUrls: [String] = []
}

/// Fast-changing numbers from DLsite's product info AJAX endpoint.
public struct DLsiteStats: Sendable, Equatable {
    public var dlCount: Int?
    public var wishlistCount: Int?
    public var rateAverage: Double?
    public var rateCount: Int?
    public var reviewCount: Int?
    public var price: Int?
    public var officialPrice: Int?
    public var discountRate: Int?
    public var rankDay: Int?
    public var rankWeek: Int?
    public var rankMonth: Int?

    public var isEmpty: Bool { dlCount == nil && rateCount == nil && price == nil }
}

public enum DLsiteParser {
    /// Each field is read independently: DLsite tweaks its markup often, and
    /// one field breaking must not lose the rest.
    public static func parseHTML(_ html: String, productId: String) throws -> DLsiteWork {
        let doc = try SwiftSoup.parse(html.normalizingNewlines)
        // Keep inner HTML as served, so a refresh that finds the same text
        // doesn't discard the cached translation.
        doc.outputSettings().prettyPrint(pretty: false)
        var outline: [String: Element] = [:]
        for row in try doc.select("#work_outline tr") {
            if let th = try row.select("th").first(), let td = try row.select("td").first() {
                outline[try th.text().trimmingCharacters(in: .whitespaces)] = td
            }
        }
        let description = try doc.select("[itemprop=description]").first()
        let ogImage = try? doc.select("meta[property=og:image]").first()?.attr("content")
        let imageId = ogImage.flatMap(imageProductId)
        let original = imageId.flatMap { $0 == productId ? nil : $0 }

        func text(_ selector: String) -> String? {
            (try? doc.select(selector).first()?.text()).flatMap(nonEmpty)
        }

        var work = DLsiteWork(
            productId: productId,
            title: text("#work_name") ?? productId,
            mainImageUrl: ogImage.flatMap(nonEmpty).map(absolute) ?? mainImageURL(imageId ?? productId)
        )
        work.titleRomaji = try? doc.select("meta[itemprop=alternateName]").first()?.attr("content")
        work.originalProductId = original
        work.circleId = try? (doc.select(".ga4_event_item_\(productId)").first()
            ?? doc.select("[data-product_id][data-maker_id]").first())?.attr("data-maker_id")
        work.circleName = text(".maker_name")
        work.releaseDate = outline["发售日"].flatMap(releaseDate)
        work.voiceActors = outline["声优"].map(anchorTexts) ?? []
        work.illustrators = outline["插画"].map(anchorTexts) ?? []
        work.scenarioWriters = outline["剧情"].map(anchorTexts) ?? []
        work.musicians = outline["音乐"].map(anchorTexts) ?? []
        work.ageRating = outline["年龄指定"].flatMap(titledSpan)
        work.workType = workType(doc, outline["作品形式"])
        work.workTypeName = outline["作品形式"].flatMap(titledSpan)
        work.fileFormats = outline["文件形式"].map(fileFormats) ?? []
        work.supportedLanguages = outline["支持的语言"].map(languages) ?? []
        work.genres = outline["分类"].map(genres) ?? []
        work.fileSize = outline["文件容量"].flatMap { try? $0.text() }.flatMap(nonEmpty)
        let seriesLink = try? outline["系列名"]?.select("a").first()
        work.seriesId = (try? seriesLink?.attr("href"))?.firstMatch(of: /\/title\/=\/title_id\/(\w+)/).map { String($0.1) }
        work.seriesName = (try? seriesLink?.text()).flatMap(nonEmpty)
        work.descriptionHtml = (try? description?.html()).flatMap(nonEmpty)
        work.sampleImageUrls = (try? doc.select(".product-slider-data div[data-src]").array().compactMap { div in
            let src = try div.attr("data-src")
            return src.isEmpty || src.contains("_img_main") ? nil : absolute(src)
        }) ?? []
        work.descriptionImageUrls = (try? description?.select("img").array().compactMap { img in
            let src = try img.attr("src").isEmpty ? img.attr("data-src") : img.attr("src")
            return src.isEmpty ? nil : absolute(src)
        }) ?? []
        return work
    }

    /// Returns empty stats when the body isn't the expected JSON.
    public static func parseAjax(_ data: Data, productId: String) -> DLsiteStats {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let node = root[productId] as? [String: Any]
        else { return DLsiteStats() }
        var stats = DLsiteStats()
        // dl_count_total sums language editions and is 0 for single-edition
        // works, where dl_count carries the real figure.
        stats.dlCount = int(node["dl_count_total"]).flatMap { $0 > 0 ? $0 : nil } ?? int(node["dl_count"])
        stats.wishlistCount = int(node["wishlist_count"])
        stats.rateAverage = double(node["rate_average_2dp"]) ?? double(node["rate_average"])
        stats.rateCount = int(node["rate_count"])
        stats.reviewCount = int(node["review_count"])
        stats.price = int(node["price"])
        stats.officialPrice = int(node["official_price"])
        if let price = stats.price, let official = stats.officialPrice {
            stats.discountRate = official <= 0 || price >= official ? 0 : Int((1 - Double(price) / Double(official)) * 100 + 0.5)
        }
        for rank in node["rank"] as? [[String: Any]] ?? [] where rank["category"] as? String == "all" {
            switch rank["term"] as? String {
            case "day": stats.rankDay = int(rank["rank"])
            case "week": stats.rankWeek = int(rank["rank"])
            case "month": stats.rankMonth = int(rank["rank"])
            default: break
            }
        }
        return stats
    }

    /// Images live in buckets named after the id rounded up to the next
    /// thousand: RJ01560714 → RJ01561000.
    public static func bucket(_ productId: String) -> String {
        guard let m = productId.wholeMatch(of: /([A-Za-z]+)(\d+)/) else { return productId }
        let digits = String(m.2)
        let rounded = (Int(digits)! + 999) / 1000 * 1000
        return "\(m.1)\(String(rounded).leftPadded(to: digits.count))"
    }

    public static func mainImageURL(_ productId: String) -> String {
        "https://img.dlsite.jp/modpub/images2/work/doujin/\(bucket(productId))/\(productId)_img_main.jpg"
    }

    /// `//img.dlsite.jp/.../work/doujin/RJ01479000/RJ01478826_img_main.jpg`
    /// → `RJ01478826`.
    static func imageProductId(_ url: String) -> String? {
        url.firstMatch(of: /\/work\/[^\/]+\/[A-Za-z]+\d+\/([A-Za-z]+\d+)_img_/).map { String($0.1) }
    }

    private static func releaseDate(_ td: Element) -> Date? {
        guard let raw = try? (td.select("a").first() ?? td).text(),
              let m = raw.firstMatch(of: /(\d{4})年(\d{1,2})月(\d{1,2})日/)
        else { return nil }
        return Calendar.current.date(from: DateComponents(year: Int(m.1), month: Int(m.2), day: Int(m.3)))
    }

    private static func anchorTexts(_ td: Element) -> [String] {
        (try? td.select("a").array().compactMap { nonEmpty(try $0.text()) }) ?? []
    }

    private static func titledSpan(_ td: Element) -> String? {
        guard let span = try? td.select("span[title]").first() else { return nil }
        return (try? span.attr("title")).flatMap(nonEmpty) ?? (try? span.text()).flatMap(nonEmpty)
    }

    private static func workType(_ doc: Document, _ td: Element?) -> String? {
        if let type = (try? doc.select("[data-product_id][data-work_type]").first()?.attr("data-work_type")).flatMap(nonEmpty) {
            return type
        }
        let classes = (try? td?.select("span[class^=icon_]").first()?.classNames()) ?? []
        return classes.first { $0.hasPrefix("icon_") }.map { String($0.dropFirst("icon_".count)) }
    }

    private static func titles(_ td: Element) -> [String] {
        (try? td.select("span[title]").array().compactMap { nonEmpty(try $0.attr("title")) }) ?? []
    }

    private static func fileFormats(_ td: Element) -> [String] {
        let extras = (try? td.select(".additional_info").array().flatMap { extra in
            try extra.text().split(separator: "/").compactMap { nonEmpty(String($0)) }
        }) ?? []
        return titles(td) + extras
    }

    private static func languages(_ td: Element) -> [String] {
        let spans = titles(td)
        return spans.isEmpty ? anchorTexts(td) : spans
    }

    private static func genres(_ td: Element) -> [Work.Genre] {
        (try? td.select("a").array().compactMap { a in
            guard let name = nonEmpty(try a.text()) else { return nil }
            let id = try a.attr("href").firstMatch(of: /\/genre\/(\d+)/).map { String($0.1) }
            return Work.Genre(id: id, name: name)
        }) ?? []
    }

    private static func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func absolute(_ url: String) -> String { url.hasPrefix("//") ? "https:" + url : url }

    private static func int(_ value: Any?) -> Int? {
        switch value {
        case let n as NSNumber: n.intValue
        case let s as String: Int(s)
        default: nil
        }
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let n as NSNumber: n.doubleValue
        case let s as String: Double(s)
        default: nil
        }
    }
}

extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}

import Foundation
import SwiftSoup

/// Which DLsite storefront to browse: the adult floor or the all-ages one.
public enum DLsiteFloor: String, CaseIterable, Sendable {
    case maniax, home

    public var label: String {
        switch self {
        case .maniax: "成人向"
        case .home: "全年龄"
        }
    }
}

/// A work as a DLsite list shows it, before its page is opened.
public struct CatalogItem: Sendable, Hashable, Identifiable {
    public let productId: String
    public let title: String
    public let circle: String?
    public let voiceActors: [String]
    public let coverURL: URL
    public let price: Int?
    public let officialPrice: Int?
    public let discountRate: Int?
    public let sales: Int?

    public var id: String { productId }
}

/// The lists the discover tab reads. Voice works only.
public enum CatalogQuery: Sendable, Hashable {
    public enum Term: String, CaseIterable, Sendable {
        case day, week, month

        public var label: String {
            switch self {
            case .day: "日榜"
            case .week: "周榜"
            case .month: "月榜"
            }
        }
    }

    /// The top 100, on one page.
    case ranking(Term)
    case newReleases
    case onSale
    case creator(String)
    case circle(String)
    case genre(id: String, name: String)
    case series(id: String, name: String)

    public var title: String {
        switch self {
        case .ranking(let term): "排行榜 · \(term.label)"
        case .newReleases: "新作"
        case .onSale: "特价中"
        case .creator(let name), .circle(let name), .genre(_, let name), .series(_, let name): name
        }
    }

    public var isPaged: Bool {
        if case .ranking = self { false } else { true }
    }
}

public struct CatalogPage: Sendable {
    public let items: [CatalogItem]
    /// Works the whole list holds, when DLsite says.
    public let total: Int?
}

/// Reads DLsite's lists: the page (ranking HTML or search AJAX) gives the
/// order, circles and voice actors; one product-info request fills in the
/// title, main image and prices for the whole page, since list thumbnails
/// are square crops and list titles are sometimes masked.
public struct DLsiteCatalog: Sendable {
    public static let pageSize = 30

    public struct Transport: Sendable {
        public var get: @Sendable (URL) async throws -> Data

        public static func live(_ client: DLsiteClient = DLsiteClient()) -> Transport {
            Transport(get: { try await client.fetch($0) })
        }
    }

    private let transport: Transport

    public init(transport: Transport = .live()) {
        self.transport = transport
    }

    /// `page` counts from 1; rankings have only the first.
    public func page(_ query: CatalogQuery, floor: DLsiteFloor, page: Int) async throws -> CatalogPage {
        let entries: [Entry]
        let total: Int?
        if case .ranking(let term) = query {
            let url = URL(string: "https://www.dlsite.com/\(floor.rawValue)/ranking/\(term.rawValue)?category=voice")!
            entries = try Self.parseRanking(String(decoding: try await transport.get(url), as: UTF8.self))
            total = entries.count
        } else {
            let data = try await transport.get(Self.searchURL(query, floor: floor, page: page))
            (entries, total) = try Self.parseSearch(data)
        }
        guard !entries.isEmpty else { return CatalogPage(items: [], total: total) }
        let info = try await transport.get(Self.infoURL(entries.map(\.productId), floor: floor))
        return CatalogPage(items: try Self.merge(entries, info: info), total: total)
    }

    // MARK: - Parsing

    struct Entry: Equatable {
        let productId: String
        let circle: String?
        let voiceActors: [String]
    }

    static func parseRanking(_ html: String) throws -> [Entry] {
        let rows = try SwiftSoup.parse(html).select("#ranking_table tr")
        return try rows.array().compactMap { row in
            guard let id = try row.select("input.__product_attributes").first()?.id().dropFirst(), !id.isEmpty else { return nil }
            return Entry(
                productId: String(id),
                circle: try row.select("dd.maker_name > a").first()?.text(),
                voiceActors: try row.select("dd.maker_name .author a").array().map { try $0.text() }
            )
        }
    }

    static func parseSearch(_ data: Data) throws -> ([Entry], Int?) {
        struct Response: Decodable {
            struct PageInfo: Decodable { let count: Int }
            let searchResult: String
            let pageInfo: PageInfo?
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(Response.self, from: data)
        let items = try SwiftSoup.parseBodyFragment(response.searchResult).select("li[data-list_item_product_id]")
        let entries = try items.array().map { item in
            Entry(
                productId: try item.attr("data-list_item_product_id"),
                circle: try item.select("dd.maker_name > a").first()?.text(),
                voiceActors: try item.select(".author a").array().map { try $0.text() }
            )
        }
        return (entries, response.pageInfo?.count)
    }

    /// Keeps the page's order; works the info endpoint no longer knows
    /// (withdrawn since the page was cached) are dropped.
    static func merge(_ entries: [Entry], info: Data) throws -> [CatalogItem] {
        struct Info: Decodable {
            let workName: String
            let workImage: String
            let price: Int?
            let officialPrice: Int?
            let discountRate: Int?
            let isDiscount: Bool?
            let dlCount: Int?
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let infos = try decoder.decode([String: Info].self, from: info)
        return entries.compactMap { entry in
            guard let info = infos[entry.productId] else { return nil }
            return CatalogItem(
                productId: entry.productId,
                title: info.workName,
                circle: entry.circle,
                voiceActors: entry.voiceActors,
                coverURL: URL(string: "https:" + info.workImage)!,
                price: info.price,
                officialPrice: info.officialPrice,
                discountRate: info.isDiscount == true ? info.discountRate : nil,
                sales: info.dlCount
            )
        }
    }

    // MARK: - URLs

    static func searchURL(_ query: CatalogQuery, floor: DLsiteFloor, page: Int) -> URL {
        var path = "work_type_category%5B0%5D/audio"
        switch query {
        case .ranking: preconditionFailure("Rankings are not a search")
        case .newReleases: path += "/order/release_d"
        case .onSale: path += "/campaign/campaign/order/trend"
        case .creator(let name): path += "/keyword_creater/\(quoted(name))/order/trend"
        case .circle(let name): path += "/keyword_maker_name/\(escape(name))/order/trend"
        case .genre(let id, _): path += "/genre%5B0%5D/\(id)/order/trend"
        case .series(let id, _): path += "/title_id/\(id)/order/release_d"
        }
        return URL(string: "https://www.dlsite.com/\(floor.rawValue)/fsr/ajax/=/\(path)/per_page/\(pageSize)/page/\(page)")!
    }

    static func infoURL(_ ids: [String], floor: DLsiteFloor) -> URL {
        URL(string: "https://www.dlsite.com/\(floor.rawValue)/product/info/ajax?product_id=\(ids.joined(separator: ","))")!
    }

    /// Search path segments are percent-encoded, slashes included.
    private static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }

    /// A creator matches exactly only in quotes, as DLsite's own links do.
    private static func quoted(_ name: String) -> String {
        escape("\"\(name)\"")
    }
}

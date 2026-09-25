import Foundation
import Testing
@testable import TonariCore

private func fixture(_ name: String) throws -> Data {
    try Data(contentsOf: Bundle.module.url(forResource: "Fixtures/dlsite/\(name)", withExtension: nil)!)
}

struct DLsiteCatalogTests {
    @Test func rankingRowsKeepOrderCircleAndVoiceActors() throws {
        let entries = try DLsiteCatalog.parseRanking(String(decoding: try fixture("ranking.html"), as: UTF8.self))
        #expect(entries.map(\.productId) == ["RJ01589926", "RJ01726233", "RJ01693003"])
        #expect(entries[0].circle == "ししどラボ")
        #expect(entries[0].voiceActors == ["天知遥", "逢坂成美", "佐京柚音", "みもりあいの"])
    }

    @Test func searchResultsCarryTheTotal() throws {
        let (entries, total) = try DLsiteCatalog.parseSearch(try fixture("search.json"))
        #expect(entries.map(\.productId) == ["RJ01727535", "RJ01727496", "RJ01726957"])
        #expect(entries[0].circle == "调教之声")
        #expect(total == 93579)
    }

    @Test func infoFillsTitleCoverAndPrice() throws {
        let entries = try DLsiteCatalog.parseRanking(String(decoding: try fixture("ranking.html"), as: UTF8.self))
            + [DLsiteCatalog.Entry(productId: "RJ00000000", circle: nil, voiceActors: [])]
        let items = try DLsiteCatalog.merge(entries, info: try fixture("info.json"))
        #expect(items.count == 3)
        let first = items[0]
        #expect(first.title.hasPrefix("【5時間半×4姉妹乱交♡】"))
        #expect(first.coverURL.absoluteString == "https://img.dlsite.jp/modpub/images2/work/doujin/RJ01590000/RJ01589926_img_main.jpg")
        #expect(first.price == 1848 && first.officialPrice == 3080 && first.discountRate == 40)
        #expect(first.sales != nil)
    }

    @Test func searchURLsFilterVoiceWorks() {
        #expect(DLsiteCatalog.searchURL(.onSale, floor: .maniax, page: 2).absoluteString
            == "https://www.dlsite.com/maniax/fsr/ajax/=/work_type_category%5B0%5D/audio/campaign/campaign/order/trend/per_page/30/page/2")
        #expect(DLsiteCatalog.searchURL(.creator("天知遥"), floor: .home, page: 1).absoluteString
            == "https://www.dlsite.com/home/fsr/ajax/=/work_type_category%5B0%5D/audio/keyword_creater/%22%E5%A4%A9%E7%9F%A5%E9%81%A5%22/order/trend/per_page/30/page/1")
    }

    @Test func pagesJoinListAndInfo() async throws {
        let catalog = DLsiteCatalog(transport: .init(get: { url in
            url.path().contains("product/info") ? try fixture("info.json") : try fixture("search.json")
        }))
        let page = try await catalog.page(.newReleases, floor: .maniax, page: 1)
        #expect(page.items.map(\.productId) == ["RJ01727535", "RJ01727496", "RJ01726957"])
        #expect(page.total == 93579)
    }
}

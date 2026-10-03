import XCTest

// Runs against a freshly installed app with an empty library and no accounts,
// so every check here works offline and on a clean CI simulator.
@MainActor
final class TonariUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
    }

    func testTabBarShowsAllSections() {
        for tab in ["Tonari", "发现", "资料库", "浏览", "搜索"] {
            XCTAssertTrue(app.tabBars.buttons[tab].waitForExistence(timeout: 5), "missing tab \(tab)")
        }
    }

    func testHomeShowsEmptyLibraryHint() {
        XCTAssertTrue(app.staticTexts["还没有作品"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["到「资料库」点 ＋ 导入包含 RJ 编号的文件夹"].exists)
    }

    func testSwitchingTabsShowsMatchingScreens() {
        app.tabBars.buttons["资料库"].tap()
        XCTAssertTrue(app.navigationBars["资料库"].waitForExistence(timeout: 5))

        app.tabBars.buttons["浏览"].tap()
        XCTAssertTrue(app.navigationBars["浏览"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本机文件夹"].exists)

        app.tabBars.buttons["Tonari"].tap()
        XCTAssertTrue(app.navigationBars["Tonari"].waitForExistence(timeout: 5))
    }

    func testSettingsOpensAndCloses() {
        app.navigationBars["Tonari"].buttons["设置"].tap()
        let settings = app.navigationBars["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        // Lists only load rows on screen, so stick to the first section.
        for row in ["外观", "播放", "隐私"] {
            XCTAssertTrue(app.staticTexts[row].exists, "missing settings row \(row)")
        }

        settings.buttons["完成"].tap()
        XCTAssertTrue(settings.waitForNonExistence(timeout: 5))
    }

    func testAppearanceChoiceShowsInSettings() {
        app.navigationBars["Tonari"].buttons["设置"].tap()
        app.staticTexts["外观"].tap()
        XCTAssertTrue(app.navigationBars["外观"].waitForExistence(timeout: 5))

        app.buttons["深色"].tap()
        app.navigationBars["外观"].buttons.firstMatch.tap()

        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["深色"].exists)
    }

    func testSearchWithoutMatchesShowsEmptyResult() {
        app.tabBars.buttons["搜索"].tap()
        let field = app.searchFields["作品、声优、社团、#标签"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["分类浏览"].exists)

        field.tap()
        field.typeText("RJ999999999")

        let empty = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "RJ999999999")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
    }
}

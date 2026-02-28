import XCTest

final class MovieSwiftUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-smoke-tests"]
        app.launch()
        return app
    }

    func testLaunchShowsMainTabs() {
        let app = launchApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Movies"].exists)
        XCTAssertTrue(tabBar.buttons["Discover"].exists)
        XCTAssertTrue(tabBar.buttons["Fan Club"].exists)
        XCTAssertTrue(tabBar.buttons["My Lists"].exists)
    }

    func testSelectingFirstMovieOpensDetailScreen() {
        let app = launchApp()

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: 5))
        firstCell.tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }
}

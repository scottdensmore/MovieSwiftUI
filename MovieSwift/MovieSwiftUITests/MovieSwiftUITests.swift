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

    private func openTab(_ title: String, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[title]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
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

    func testFanClubTabShowsExpectedScreenElements() {
        let app = launchApp()
        openTab("Fan Club", in: app)

        XCTAssertTrue(app.navigationBars["Fan Club"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Popular people to add to your Fan Club"].exists)
    }

    func testMyListsTabShowsCreateAndSortControls() {
        let app = launchApp()
        openTab("My Lists", in: app)

        XCTAssertTrue(app.navigationBars["My Lists"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Create custom list"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Wishlist"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Seenlist"].exists)
    }

    func testMoviesSearchShowsCancelAndFilterControls() {
        let app = launchApp()

        let searchField = app.textFields["Search any movies or person"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("matrix")

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Movies"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["People"].exists)
    }
}

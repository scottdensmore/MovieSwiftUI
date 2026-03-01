import XCTest

final class MovieSwiftUITests: XCTestCase {
    private static let primaryDestinations = ["Movies", "Discover", "Fan Club", "My Lists"]
    private let uiWaitTimeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--ui-smoke-tests"]
        app.launchEnvironment["UI_SMOKE_TESTS"] = "1"
        app.launch()
        return app
    }

    private func navigationButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let tabBarButton = app.tabBars.buttons[title]
        if tabBarButton.waitForExistence(timeout: 0.5) {
            return tabBarButton
        }

        return app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func openTab(_ title: String, in app: XCUIApplication) {
        let tabButton = navigationButton(title, in: app)
        XCTAssertTrue(tabButton.waitForExistence(timeout: uiWaitTimeout), "Expected tab '\(title)' to exist")
        tabButton.tap()
    }

    func testLaunchShowsMainTabs() {
        let app = launchApp()

        for destination in Self.primaryDestinations {
            XCTAssertTrue(
                navigationButton(destination, in: app).waitForExistence(timeout: uiWaitTimeout),
                "Expected to find primary navigation item '\(destination)'"
            )
        }
    }

    func testSelectingFirstMovieOpensDetailScreen() {
        let app = launchApp()
        openTab("Movies", in: app)

        let firstCell = app.cells.firstMatch
        XCTAssertTrue(firstCell.waitForExistence(timeout: uiWaitTimeout))
        firstCell.tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: uiWaitTimeout))
    }

    func testFanClubTabShowsExpectedScreenElements() {
        let app = launchApp()
        openTab("Fan Club", in: app)

        XCTAssertTrue(app.navigationBars["Fan Club"].waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(app.staticTexts["Popular people to add to your Fan Club"].exists)
    }

    func testMyListsTabShowsCreateAndSortControls() {
        let app = launchApp()
        openTab("My Lists", in: app)

        XCTAssertTrue(app.navigationBars["My Lists"].waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(app.buttons["Create custom list"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Wishlist"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Seenlist"].exists)
    }

    func testMoviesSearchShowsCancelAndFilterControls() {
        let app = launchApp()
        openTab("Movies", in: app)

        let searchField = app.textFields["Search any movies or person"]
        XCTAssertTrue(searchField.waitForExistence(timeout: uiWaitTimeout))
        searchField.tap()
        searchField.typeText("matrix")

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(app.segmentedControls.buttons["Movies"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["People"].exists)
    }
}

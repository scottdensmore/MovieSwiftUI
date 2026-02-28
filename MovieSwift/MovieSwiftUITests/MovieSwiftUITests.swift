import XCTest

final class MovieSwiftUITests: XCTestCase {
    private static let primaryDestinations = ["Movies", "Discover", "Fan Club", "My Lists"]

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

    private func navigationButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let tabBarButton = app.tabBars.buttons[title]
        if tabBarButton.exists {
            return tabBarButton
        }

        return app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func openTab(_ title: String, in app: XCUIApplication) {
        let tabButton = navigationButton(title, in: app)
        XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
        tabButton.tap()
    }

    func testLaunchShowsMainTabs() {
        let app = launchApp()

        for destination in Self.primaryDestinations {
            XCTAssertTrue(
                navigationButton(destination, in: app).waitForExistence(timeout: 5),
                "Expected to find primary navigation item '\(destination)'"
            )
        }
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

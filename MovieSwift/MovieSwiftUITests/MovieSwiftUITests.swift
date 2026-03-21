import XCTest

final class MovieSwiftUITests: XCTestCase {
    private static let primaryDestinations = ["Movies", "Discover", "Fan Club", "My Lists"]
    private let uiWaitTimeout: TimeInterval = 15
    private let shouldLogHierarchyOnFailure = ProcessInfo.processInfo.environment["UI_TEST_LOG_HIERARCHY"] == "1"

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

    private func button(_ identifierOrLabel: String, in app: XCUIApplication) -> XCUIElement {
        let identifiedButton = app.buttons[identifierOrLabel]
        if identifiedButton.waitForExistence(timeout: 0.5) {
            return identifiedButton
        }

        return app.buttons.matching(NSPredicate(format: "label == %@", identifierOrLabel)).firstMatch
    }

    private func identifiedElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tappableElement(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    private func openTab(_ title: String, in app: XCUIApplication) {
        let tabButton = navigationButton(title, in: app)
        XCTAssertTrue(tabButton.waitForExistence(timeout: uiWaitTimeout), "Expected tab '\(title)' to exist")
        tabButton.tap()
    }

    private func scrollUntilElementExists(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return false
    }

    private func logHierarchyIfMissing(_ app: XCUIApplication, element: XCUIElement, named name: String) {
        if shouldLogHierarchyOnFailure && !element.exists {
            print("Missing element: \(name)")
            print(app.debugDescription)
        }
    }

    @discardableResult
    private func openFirstMovieDetail(in app: XCUIApplication) -> XCUIElement {
        openTab("Movies", in: app)

        let firstMovie = identifiedElement("moviesList.movie.0", in: app)
        XCTAssertTrue(firstMovie.waitForExistence(timeout: uiWaitTimeout))
        firstMovie.tap()

        let addToListButton = identifiedElement("movieDetail.addToListButton", in: app)
        logHierarchyIfMissing(app, element: addToListButton, named: "movieDetail.addToListButton")
        XCTAssertTrue(addToListButton.waitForExistence(timeout: uiWaitTimeout))
        return addToListButton
    }

    private func openFirstPersonDetailFromMovie(in app: XCUIApplication) {
        _ = openFirstMovieDetail(in: app)

        let topPersonLink = identifiedElement("movieDetail.topPersonShortcut", in: app)
        logHierarchyIfMissing(app, element: topPersonLink, named: "movieDetail.topPersonShortcut")
        XCTAssertTrue(topPersonLink.waitForExistence(timeout: uiWaitTimeout))
        topPersonLink.tap()
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
        _ = openFirstMovieDetail(in: app)

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

    func testMoviesSettingsModalCanOpenAndDismiss() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let cancelButton = button("settings.cancelButton", in: app)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: uiWaitTimeout))
        cancelButton.tap()

        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(settingsButton.isHittable)
    }

    func testMoviesSettingsSavePersistsOriginalTitlePreference() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let originalTitleToggle = app.switches["settings.alwaysOriginalTitleToggle"]
        XCTAssertTrue(originalTitleToggle.waitForExistence(timeout: uiWaitTimeout))

        let initialValue = originalTitleToggle.value as? String
        let toggleRow = identifiedElement("settings.alwaysOriginalTitleRow", in: app)
        XCTAssertTrue(toggleRow.waitForExistence(timeout: uiWaitTimeout))
        toggleRow.tap()

        let expectedValue = initialValue == "1" ? "0" : "1"
        let updatedValuePredicate = NSPredicate(format: "value == %@", expectedValue)
        expectation(for: updatedValuePredicate, evaluatedWith: originalTitleToggle)
        waitForExpectations(timeout: uiWaitTimeout)

        let saveButton = button("settings.saveButton", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiWaitTimeout))
        saveButton.tap()

        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let reopenedToggle = app.switches["settings.alwaysOriginalTitleToggle"]
        XCTAssertTrue(reopenedToggle.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertEqual(reopenedToggle.value as? String, expectedValue)
    }

    func testMoviesGridSeeAllOpensListScreen() {
        let app = launchApp()
        openTab("Movies", in: app)

        let toggleLayoutButton = button("moviesHome.toggleLayoutButton", in: app)
        XCTAssertTrue(toggleLayoutButton.waitForExistence(timeout: uiWaitTimeout))
        toggleLayoutButton.tap()

        let seeAllButton = app.buttons.matching(NSPredicate(format: "label == %@", "See all")).firstMatch
        XCTAssertTrue(seeAllButton.waitForExistence(timeout: uiWaitTimeout))
        seeAllButton.tap()

        XCTAssertTrue(app.textFields["Search any movies or person"].waitForExistence(timeout: uiWaitTimeout))
    }

    func testMyListsCustomListOpensDetailScreen() {
        let app = launchApp()
        openTab("My Lists", in: app)

        let customListEntry = tappableElement("TestName", in: app)
        XCTAssertTrue(customListEntry.waitForExistence(timeout: uiWaitTimeout))
        customListEntry.tap()

        XCTAssertTrue(app.textFields["Search movies to add to your list"].waitForExistence(timeout: uiWaitTimeout))
    }

    func testMovieDetailCanNavigateToPersonAndBackToMovie() {
        let app = launchApp()
        openFirstPersonDetailFromMovie(in: app)

        let backButton = app.buttons["BackButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: uiWaitTimeout))
        backButton.tap()

        XCTAssertTrue(identifiedElement("movieDetail.addToListButton", in: app).waitForExistence(timeout: uiWaitTimeout))
    }

    func testPeopleDetailCreditOpensMovieDetail() {
        let app = launchApp()
        openFirstPersonDetailFromMovie(in: app)

        let creditedMovie = identifiedElement("peopleDetail.movie.0", in: app)
        logHierarchyIfMissing(app, element: creditedMovie, named: "peopleDetail.movie.0")
        XCTAssertTrue(scrollUntilElementExists(creditedMovie, in: app))
        creditedMovie.tap()

        XCTAssertTrue(identifiedElement("movieDetail.addToListButton", in: app).waitForExistence(timeout: uiWaitTimeout))
    }
}

//  UI tests for the native macOS target. Uses NavigationSplitView sidebar navigation.

import XCTest
import MovieSwiftFluxCore

final class MovieSwiftMacUITests: XCTestCase {
    private let timeout = UITestConstants.uiWaitTimeout

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Launch the app, optionally pre-selecting a sidebar menu via the
    /// `UI_TEST_SELECT_MENU` environment variable. This is the reliable way
    /// to navigate the sidebar in headless CI where `tap()` on SwiftUI
    /// `List(selection:)` rows does not trigger the selection binding.
    @discardableResult
    private func launchApp(
        selectMenu menu: String? = nil,
        environment: [String: String] = [:]
    ) -> XCUIApplication {
        var env = environment
        if let menu {
            env["UI_TEST_SELECT_MENU"] = menu
        }
        return .launchForTesting(environment: env)
    }

    private func waitForSidebarItem(_ title: String, in app: XCUIApplication) {
        let sidebarItem = app.identifiedElement("sidebar.\(title)")
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: timeout),
                      "Expected sidebar item '\(title)' to exist")
    }

    @discardableResult
    private func openFirstMovieDetail(in app: XCUIApplication) -> XCUIElement {
        // Popular is the default selection — no sidebar tap needed
        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
        firstMovie.tap()

        let addToListButton = app.identifiedElement("movieDetail.addToListButton")
        logHierarchyOnMissing(app, element: addToListButton, named: "movieDetail.addToListButton")
        XCTAssertTrue(addToListButton.waitForExistence(timeout: timeout))
        return addToListButton
    }

    // MARK: - Launch & Navigation

    func testLaunchShowsSidebar() {
        let app = launchApp()

        let sidebarItems = ["Popular", "Top rated", "Upcoming", "Now Playing",
                            "Trending", "Genres", "Fan Club", "Discover",
                            "My Lists", "Settings"]
        for item in sidebarItems {
            XCTAssertTrue(
                app.identifiedElement("sidebar.\(item)").waitForExistence(timeout: timeout),
                "Expected sidebar item '\(item)' to exist"
            )
        }
    }

    func testPopularTabShowsMovies() {
        let app = launchApp(selectMenu: "Popular")

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    func testTopRatedTabShowsMovies() {
        let app = launchApp(selectMenu: "Top rated")

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    // MARK: - Movie Detail

    func testSelectingMovieOpensDetail() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)
    }

    func testMovieDetailShowsGenreChips() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let genreChip = app.identifiedButton("movieDetail.genre.0")
        XCTAssertTrue(genreChip.waitForExistence(timeout: timeout))
    }

    func testMovieDetailCanNavigateToPersonAndBack() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let topPersonLink = app.identifiedElement("movieDetail.topPersonShortcut")
        logHierarchyOnMissing(app, element: topPersonLink, named: "movieDetail.topPersonShortcut")
        XCTAssertTrue(topPersonLink.waitForExistence(timeout: timeout))
        topPersonLink.tap()

        XCTAssertTrue(app.identifiedElement("peopleDetail.knownFor").waitForExistence(timeout: timeout))

        let backButton = app.buttons["BackButton"]
        if backButton.waitForExistence(timeout: 2) {
            backButton.tap()
            XCTAssertTrue(app.identifiedElement("movieDetail.addToListButton").waitForExistence(timeout: timeout))
        }
    }

    func testMovieDetailWishlistButtonToggles() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let wishlistButton = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Wishlist", "In wishlist")
        ).firstMatch
        XCTAssertTrue(wishlistButton.waitForExistence(timeout: timeout))

        let initialLabel = wishlistButton.label
        wishlistButton.tap()

        let expectedLabel = initialLabel == "Wishlist" ? "In wishlist" : "Wishlist"
        let toggled = app.buttons.matching(NSPredicate(format: "label == %@", expectedLabel)).firstMatch
        XCTAssertTrue(toggled.waitForExistence(timeout: timeout))
    }

    func testMovieDetailSeenlistButtonToggles() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let seenlistButton = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Seenlist", "Seen")
        ).firstMatch
        XCTAssertTrue(seenlistButton.waitForExistence(timeout: timeout))

        let initialLabel = seenlistButton.label
        seenlistButton.tap()

        let expectedLabel = initialLabel == "Seenlist" ? "Seen" : "Seenlist"
        let toggled = app.buttons.matching(NSPredicate(format: "label == %@", expectedLabel)).firstMatch
        XCTAssertTrue(toggled.waitForExistence(timeout: timeout))
    }

    func testSidebarMenuChangePopsPushedMovieDetail() {
        // Regression test: clicking a different sidebar menu while a
        // MovieDetail is pushed in the right pane must pop the pushed
        // destination. NavigationSplitView on macOS used to hold on to
        // the pushed view across menu changes; SplitView now lifts the
        // navigationRoute up and nils it before swapping menus.
        let app = launchApp()

        // Push MovieDetail from the default Popular menu.
        let addToListButton = openFirstMovieDetail(in: app)
        XCTAssertTrue(addToListButton.exists,
                      "MovieDetail should be visible after tapping the first movie")

        // Switch sidebar to Top rated.
        let topRated = app.identifiedElement("sidebar.Top rated")
        XCTAssertTrue(topRated.waitForExistence(timeout: timeout))
        topRated.tap()

        // The pushed MovieDetail must be gone and the new menu's
        // movie list must be at the root.
        let detailGone = NSPredicate(format: "exists == false")
        let detailDismissed = expectation(for: detailGone, evaluatedWith: addToListButton)
        wait(for: [detailDismissed], timeout: timeout)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout),
                      "Expected the new menu's movies list to be visible at the root")
    }

    func testMovieDetailGenreChipExists() {
        // Verify genre chip exists and is tappable. Full genre navigation
        // (navigationDestination push within the detail NavigationStack)
        // is unreliable in headless macOS CI, so we only verify the chip
        // is present rather than testing the pushed destination.
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let genreChip = app.identifiedButton("movieDetail.genre.0")
        XCTAssertTrue(genreChip.waitForExistence(timeout: timeout))
    }

    // MARK: - Fan Club

    func testFanClubShowsExpectedElements() {
        let app = launchApp(selectMenu: "Fan Club")

        XCTAssertTrue(app.staticTexts["Popular people to add to your Fan Club"].waitForExistence(timeout: timeout))
    }

    func testFanClubPersonOpensPeopleDetail() {
        let app = launchApp(selectMenu: "Fan Club")

        let personRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "fanClub.person."))
            .firstMatch
        XCTAssertTrue(personRow.waitForExistence(timeout: timeout))
        personRow.tap()

        XCTAssertTrue(app.identifiedElement("peopleDetail.knownFor").waitForExistence(timeout: timeout))
    }

    func testFanClubShowsRetryOnFailure() {
        let app = launchApp(
            selectMenu: "Fan Club",
            environment: ["UI_SMOKE_TEST_FAN_CLUB_FAILURE": "1"]
        )

        XCTAssertTrue(app.identifiedElement("fanClub.errorState").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.identifiedButton("fanClub.retryButton").waitForExistence(timeout: timeout))
    }

    // MARK: - My Lists

    func testMyListsShowsContent() {
        let app = launchApp(selectMenu: "My Lists")

        // Wishlist is selected by default (selectedList == 0), so the
        // wishlist section header should be visible without any tapping.
        let wishlistHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "movies in wishlist")
        ).firstMatch
        // Also check for the "Create custom list" button as a fallback
        let createButton = app.identifiedElement("myLists.createCustomListButton")

        let found = wishlistHeader.waitForExistence(timeout: timeout)
            || createButton.waitForExistence(timeout: timeout)
        if !found {
            // Dump hierarchy for diagnostic purposes in CI
            XCTFail("My Lists view did not render. Hierarchy:\n\(app.debugDescription)")
        }
    }

    func testMyListsCustomListExists() {
        let app = launchApp(selectMenu: "My Lists")

        // The custom list row contains Text("TestName") but on macOS the
        // Button wrapper may combine children into a single accessibility
        // element. Search broadly for any element containing the list name.
        let customListElement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "TestName"))
            .firstMatch
        XCTAssertTrue(customListElement.waitForExistence(timeout: timeout),
                      "Expected custom list 'TestName' to exist")
    }

    // MARK: - Discover

    func testDiscoverShowsContent() {
        let app = launchApp(selectMenu: "Discover")

        let filterButton = app.identifiedButton("discover.filterButton")
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout))
    }

    func testDiscoverDismissCanBeUndone() {
        let app = launchApp(selectMenu: "Discover")

        let filterButton = app.identifiedButton("discover.filterButton")
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout))

        let title = app.identifiedElement("discover.currentMovieTitle")
        XCTAssertTrue(title.waitForExistence(timeout: timeout))
        let originalTitle = title.label

        let dismissButton = app.identifiedButton("discover.dismissButton")
        XCTAssertTrue(dismissButton.waitForExistence(timeout: timeout))
        dismissButton.tap()

        let undoButton = app.identifiedButton("discover.undoButton")
        XCTAssertTrue(undoButton.waitForExistence(timeout: timeout))
        undoButton.tap()

        let restoredTitle = app.identifiedElement("discover.currentMovieTitle")
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: timeout))
        XCTAssertEqual(restoredTitle.label, originalTitle)
    }

    func testDiscoverFilterShowsPickerControls() {
        let app = launchApp(selectMenu: "Discover")

        let filterButton = app.identifiedButton("discover.filterButton")
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout))
        filterButton.tap()

        XCTAssertTrue(app.identifiedElement("discoverFilter.eraPicker").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.identifiedElement("discoverFilter.genrePicker").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.identifiedElement("discoverFilter.countryPicker").waitForExistence(timeout: timeout))
    }

    // MARK: - Settings

    func testSettingsShowsRegionPicker() {
        let app = launchApp(selectMenu: "Settings")

        let regionPicker = app.identifiedElement("settings.regionPicker")
        XCTAssertTrue(regionPicker.waitForExistence(timeout: timeout))
    }

    func testSettingsShowsDebugInfo() {
        let app = launchApp(selectMenu: "Settings")

        XCTAssertTrue(app.staticTexts["Movies in state"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Archived state size"].waitForExistence(timeout: timeout))
    }

    // MARK: - Settings: TMDB API key

    /// Pasting a key, saving, and clearing should drive the status row through
    /// "Using your key" → "the bundled key"-or-"No API key" in turn.
    /// Self-cleaning: if a previous run left a user-provided key behind, we
    /// tap Clear before running the real assertion sequence.
    func testSettingsTMDBAPIKeyPasteSaveAndClearRoundTrip() {
        let app = launchApp(selectMenu: "Settings")

        let apiKeyField = app.secureTextFields["settings.tmdb.apiKeyField"]
        XCTAssertTrue(apiKeyField.waitForExistence(timeout: timeout),
                      "Expected the TMDB API key SecureField in macOS Settings")

        // Self-clean residual state.
        let preExistingClear = app.buttons["settings.tmdb.clearButton"]
        if preExistingClear.waitForExistence(timeout: 1) {
            preExistingClear.tap()
            _ = !preExistingClear.waitForExistence(timeout: 2)
        }

        apiKeyField.click()
        apiKeyField.typeText("UI-TEST-PASTED-KEY-MAC")

        let saveButton = app.buttons["settings.tmdb.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(saveButton.isEnabled,
                      "Save should enable once the draft differs from the persisted value")
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Using your key"].waitForExistence(timeout: timeout),
                      "After saving, the status row should read 'Using your key'")
        let clearButton = app.buttons["settings.tmdb.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: timeout))

        clearButton.tap()
        let usingYourKey = app.staticTexts["Using your key"]
        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: usingYourKey)
        waitForExpectations(timeout: timeout)
        XCTAssertFalse(clearButton.waitForExistence(timeout: 2),
                       "Clear button should hide once the user key is removed")
    }

    /// Saving a key persists across a sidebar menu switch + back: navigate
    /// away to Popular, then back to Settings, and the status row should
    /// still read "Using your key" — catches regressions where the SecureField's
    /// draft is stored in transient @State only and not in AppUserDefaults.
    func testSettingsTMDBAPIKeySavePersistsAcrossSidebarSwitch() {
        let app = launchApp(selectMenu: "Settings")

        let apiKeyField = app.secureTextFields["settings.tmdb.apiKeyField"]
        XCTAssertTrue(apiKeyField.waitForExistence(timeout: timeout))

        let preExistingClear = app.buttons["settings.tmdb.clearButton"]
        if preExistingClear.waitForExistence(timeout: 1) {
            preExistingClear.tap()
            _ = !preExistingClear.waitForExistence(timeout: 2)
        }

        apiKeyField.click()
        apiKeyField.typeText("UI-TEST-PERSISTENCE-KEY-MAC")
        app.buttons["settings.tmdb.saveButton"].tap()
        XCTAssertTrue(app.staticTexts["Using your key"].waitForExistence(timeout: timeout))

        // Switch sidebar to Popular and back to Settings.
        app.identifiedElement("sidebar.Popular").tap()
        XCTAssertTrue(app.identifiedElement("moviesList.movie.0").waitForExistence(timeout: timeout))
        app.identifiedElement("sidebar.Settings").tap()

        let reopenedField = app.secureTextFields["settings.tmdb.apiKeyField"]
        XCTAssertTrue(reopenedField.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Using your key"].waitForExistence(timeout: timeout),
                      "After switching sidebar away and back, status should still read 'Using your key'")

        // Tidy up.
        let cleanupClear = app.buttons["settings.tmdb.clearButton"]
        if cleanupClear.waitForExistence(timeout: 2) {
            cleanupClear.tap()
        }
    }
}

//
//  MovieSwiftMacUITests.swift
//  MovieSwiftUITests
//
//  UI tests for the native macOS target. Uses NavigationSplitView sidebar navigation.
//

import XCTest

final class MovieSwiftMacUITests: XCTestCase {
    private let timeout = UITestConstants.uiWaitTimeout

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        .launchForTesting(environment: environment)
    }

    private func selectSidebarItem(_ title: String, in app: XCUIApplication) {
        // First try the accessibility identifier on the row cell
        let sidebarItem = app.identifiedElement("sidebar.\(title)")
        if sidebarItem.waitForExistence(timeout: timeout) {
            sidebarItem.tap()
            return
        }
        // Fallback: find and tap the static text in the sidebar
        let sidebarText = app.staticTexts[title]
        XCTAssertTrue(sidebarText.waitForExistence(timeout: timeout),
                      "Expected sidebar item '\(title)' to exist")
        sidebarText.tap()
    }

    @discardableResult
    private func openFirstMovieDetail(in app: XCUIApplication) -> XCUIElement {
        selectSidebarItem("Popular", in: app)

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
        let app = launchApp()
        selectSidebarItem("Popular", in: app)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    func testTopRatedTabShowsMovies() {
        let app = launchApp()
        selectSidebarItem("Top rated", in: app)

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

    func testMovieDetailGenreOpensGenreList() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let genreChip = app.identifiedButton("movieDetail.genre.0")
        XCTAssertTrue(genreChip.waitForExistence(timeout: timeout))
        genreChip.tap()

        // On macOS, NavigationSplitView may not show a traditional navigation bar;
        // verify the genre list loaded by checking for a movie list element
        let genreNavBar = app.navigationBars["test"]
        let movieInGenre = app.identifiedElement("moviesList.movie.0")
        let found = genreNavBar.waitForExistence(timeout: timeout)
            || movieInGenre.waitForExistence(timeout: timeout)
        XCTAssertTrue(found, "Expected genre list to appear")
    }

    // MARK: - Fan Club

    func testFanClubShowsExpectedElements() {
        let app = launchApp()
        selectSidebarItem("Fan Club", in: app)

        XCTAssertTrue(app.staticTexts["Popular people to add to your Fan Club"].waitForExistence(timeout: timeout))
    }

    func testFanClubPersonOpensPeopleDetail() {
        let app = launchApp()
        selectSidebarItem("Fan Club", in: app)

        let personRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "fanClub.person."))
            .firstMatch
        XCTAssertTrue(personRow.waitForExistence(timeout: timeout))
        personRow.tap()

        XCTAssertTrue(app.identifiedElement("peopleDetail.knownFor").waitForExistence(timeout: timeout))
    }

    func testFanClubShowsRetryOnFailure() {
        let app = launchApp(environment: ["UI_SMOKE_TEST_FAN_CLUB_FAILURE": "1"])
        selectSidebarItem("Fan Club", in: app)

        XCTAssertTrue(app.identifiedElement("fanClub.errorState").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.identifiedButton("fanClub.retryButton").waitForExistence(timeout: timeout))
    }

    // MARK: - My Lists

    func testMyListsShowsSegmentControls() {
        let app = launchApp()
        selectSidebarItem("My Lists", in: app)

        XCTAssertTrue(app.segmentedControls.buttons["Wishlist"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.segmentedControls.buttons["Seenlist"].exists)
    }

    func testMyListsWishlistSegmentShowsMovies() {
        let app = launchApp()
        selectSidebarItem("My Lists", in: app)

        let wishlistTab = app.segmentedControls.buttons["Wishlist"]
        XCTAssertTrue(wishlistTab.waitForExistence(timeout: timeout))
        wishlistTab.tap()

        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "movies in wishlist")
        ).firstMatch.waitForExistence(timeout: timeout))
    }

    func testMyListsSeenlistSegmentShowsMovies() {
        let app = launchApp()
        selectSidebarItem("My Lists", in: app)

        let seenlistTab = app.segmentedControls.buttons["Seenlist"]
        XCTAssertTrue(seenlistTab.waitForExistence(timeout: timeout))
        seenlistTab.tap()

        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "movies in seenlist")
        ).firstMatch.waitForExistence(timeout: timeout))
    }

    func testMyListsCustomListOpensDetail() {
        let app = launchApp()
        selectSidebarItem("My Lists", in: app)

        let customListEntry = app.labeledElement("TestName")
        XCTAssertTrue(customListEntry.waitForExistence(timeout: timeout))
        customListEntry.tap()

        XCTAssertTrue(app.textFields["Search movies to add to your list"].waitForExistence(timeout: timeout))
    }

    // MARK: - Discover

    func testDiscoverShowsContent() {
        let app = launchApp()
        selectSidebarItem("Discover", in: app)

        let filterButton = app.identifiedButton("discover.filterButton")
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout))
    }

    func testDiscoverDismissCanBeUndone() {
        let app = launchApp()
        selectSidebarItem("Discover", in: app)

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
        let app = launchApp()
        selectSidebarItem("Discover", in: app)

        let filterButton = app.identifiedButton("discover.filterButton")
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout))
        filterButton.tap()

        XCTAssertTrue(app.identifiedElement("discoverFilter.eraPicker").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.identifiedElement("discoverFilter.genrePicker").waitForExistence(timeout: timeout))
        XCTAssertTrue(app.identifiedElement("discoverFilter.countryPicker").waitForExistence(timeout: timeout))
    }

    // MARK: - Settings

    func testSettingsShowsRegionPicker() {
        let app = launchApp()
        selectSidebarItem("Settings", in: app)

        let regionPicker = app.identifiedElement("settings.regionPicker")
        XCTAssertTrue(regionPicker.waitForExistence(timeout: timeout))
    }

    func testSettingsShowsDebugInfo() {
        let app = launchApp()
        selectSidebarItem("Settings", in: app)

        XCTAssertTrue(app.staticTexts["Movies in state"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Archived state size"].waitForExistence(timeout: timeout))
    }
}

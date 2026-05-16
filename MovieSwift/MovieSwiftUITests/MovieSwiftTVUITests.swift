//  UI tests for the tvOS target. Uses focus-based navigation with Siri Remote.

import XCTest
import MovieSwiftFluxCore

final class MovieSwiftTVUITests: XCTestCase {
    private let timeout = UITestConstants.uiWaitTimeout

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        .launchForTesting(environment: environment)
    }

    /// Navigate to a tab by using the remote. Focus moves to the tab bar first,
    /// then right/left to the desired tab, then select.
    private func selectTab(_ title: String, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[title]
        XCTAssertTrue(tabButton.waitForExistence(timeout: timeout),
                      "Expected tab '\(title)' to exist")
        // Focus the tab bar (move up repeatedly to ensure we're at the top)
        for _ in 0..<5 {
            XCUIRemote.shared.press(.up)
        }
        // Navigate horizontally to the desired tab
        // Try pressing right until we find the focused tab matching our title
        for _ in 0..<10 {
            if tabButton.hasFocus {
                break
            }
            XCUIRemote.shared.press(.right)
        }
        // If we overshot, try left
        for _ in 0..<10 {
            if tabButton.hasFocus {
                break
            }
            XCUIRemote.shared.press(.left)
        }
        XCUIRemote.shared.press(.select)
    }

    @discardableResult
    private func openFirstMovieDetail(in app: XCUIApplication) -> XCUIElement {
        selectTab("Popular", in: app)

        // Navigate down from tab bar to content
        XCUIRemote.shared.press(.down)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
        XCUIRemote.shared.press(.select)

        let movieDetail = app.identifiedElement("movieDetail")
        logHierarchyOnMissing(app, element: movieDetail, named: "movieDetail")
        XCTAssertTrue(movieDetail.waitForExistence(timeout: timeout))
        return movieDetail
    }

    // MARK: - Launch & Tab Navigation

    func testLaunchShowsTabs() {
        let app = launchApp()

        let expectedTabs = ["Popular", "Top Rated", "Upcoming", "Now Playing", "Trending", "Search"]
        for tab in expectedTabs {
            XCTAssertTrue(
                app.tabBars.buttons[tab].waitForExistence(timeout: timeout),
                "Expected tab '\(tab)' to exist"
            )
        }
    }

    func testPopularTabShowsMovies() {
        let app = launchApp()
        selectTab("Popular", in: app)

        // Navigate down from tab bar to content
        XCUIRemote.shared.press(.down)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    func testTopRatedTabShowsMovies() {
        let app = launchApp()
        selectTab("Top Rated", in: app)

        XCUIRemote.shared.press(.down)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    func testUpcomingTabShowsMovies() {
        let app = launchApp()
        selectTab("Upcoming", in: app)

        XCUIRemote.shared.press(.down)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    func testNowPlayingTabShowsMovies() {
        let app = launchApp()
        selectTab("Now Playing", in: app)

        XCUIRemote.shared.press(.down)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    func testTrendingTabShowsMovies() {
        let app = launchApp()
        selectTab("Trending", in: app)

        XCUIRemote.shared.press(.down)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    // MARK: - Movie Detail

    func testSelectingMovieOpensDetail() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)
    }

    func testMovieDetailShowsTitle() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let titleElement = app.identifiedElement("movieDetail.title")
        XCTAssertTrue(titleElement.waitForExistence(timeout: timeout))
    }

    func testMovieDetailShowsCastSection() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let castHeader = app.identifiedElement("movieDetail.castHeader")
        // On tvOS, scroll down with remote to find cast section
        for _ in 0..<6 {
            if castHeader.waitForExistence(timeout: 1) { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(castHeader.exists)
    }

    func testMovieDetailShowsRecommendedSection() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let recommendedHeader = app.identifiedElement("movieDetail.recommendedHeader")
        for _ in 0..<8 {
            if recommendedHeader.waitForExistence(timeout: 1) { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(recommendedHeader.exists)
    }

    func testMovieDetailCanNavigateBackToList() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        // Press Menu to go back
        XCUIRemote.shared.press(.menu)

        let firstMovie = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout))
    }

    /// The Recommended row is a horizontal carousel of NavigationLink cards.
    /// Focusing one with the remote and pressing Select should push another
    /// TVMovieDetail onto the stack — this is the "browse related films
    /// without ever leaving the detail flow" journey, and it's the only
    /// deep-link target inside TVMovieDetail (cast cards have empty actions).
    ///
    /// Verifies:
    ///   1. The recommended card is reachable via remote `down` presses.
    ///   2. Pressing `select` on a focused recommended card replaces the
    ///      visible title with a different movie's title (confirming the
    ///      navigation stack pushed, not that focus merely moved).
    ///   3. Pressing `menu` pops back to the first detail (one level up,
    ///      not all the way to the tab's list), proving the nav-stack depth
    ///      is exactly 2.
    func testRecommendedMovieSelectionPushesNewDetail() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        // Capture the originating movie's title so we can detect that the
        // visible detail actually changed when we tap into Recommended.
        let originalTitle = app.identifiedElement("movieDetail.title")
        XCTAssertTrue(originalTitle.waitForExistence(timeout: timeout))
        let originalLabel = originalTitle.label
        XCTAssertFalse(originalLabel.isEmpty,
                       "Expected the first movie's title to be loaded before navigating")

        // Scroll the Recommended section into view. The detail page has 3
        // focus sections (header → cast → recommended) so 8 down-presses is
        // a safe upper bound; the helper short-circuits as soon as the
        // header is visible.
        let recommendedHeader = app.identifiedElement("movieDetail.recommendedHeader")
        for _ in 0..<8 {
            if recommendedHeader.waitForExistence(timeout: 1) { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(recommendedHeader.exists,
                      "Expected Recommended section to scroll into view")

        // Press down one more time to move focus from the header label
        // onto the first focusable card in the carousel, then select it.
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.select)

        // A new TVMovieDetail should push with a different title. We can't
        // know the recommended movie's title up-front (the fixture order
        // depends on TMDb's recommended list), so we just assert that the
        // title element transitions to a non-empty *different* label.
        let titleChanged = NSPredicate(
            format: "label != %@ AND label.length > 0",
            originalLabel
        )
        let titleAfterPush = app.identifiedElement("movieDetail.title")
        expectation(for: titleChanged, evaluatedWith: titleAfterPush, handler: nil)
        waitForExpectations(timeout: timeout)

        // Menu should pop us back to the originating movie's detail (depth-2 → depth-1),
        // not all the way to the list. This proves the deep-link actually pushed
        // onto the existing NavigationStack instead of replacing the root.
        XCUIRemote.shared.press(.menu)
        let titleRestored = NSPredicate(format: "label == %@", originalLabel)
        let titleAfterMenu = app.identifiedElement("movieDetail.title")
        expectation(for: titleRestored, evaluatedWith: titleAfterMenu, handler: nil)
        waitForExpectations(timeout: timeout)
    }

    // MARK: - Search

    func testSearchTabShowsEmptyState() {
        let app = launchApp()
        selectTab("Search", in: app)

        let emptyState = app.identifiedElement("search.emptyState")
        XCTAssertTrue(emptyState.waitForExistence(timeout: timeout))
    }

    // MARK: - Tab Switching

    func testCanSwitchBetweenAllMovieTabs() {
        let app = launchApp()

        let movieTabs = ["Popular", "Top Rated", "Upcoming", "Now Playing", "Trending"]
        for tab in movieTabs {
            selectTab(tab, in: app)
            // Verify tab is selected by checking content loads
            XCUIRemote.shared.press(.down)
            let firstMovie = app.identifiedElement("moviesList.movie.0")
            XCTAssertTrue(firstMovie.waitForExistence(timeout: timeout),
                          "Expected movies to load for tab '\(tab)'")
        }
    }
}

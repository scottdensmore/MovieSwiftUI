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
    /// The assertion uses **navigation-depth signals** rather than
    /// "title changes after Select." The smoke fixture
    /// (`makeUISmokeTestState` in MovieSwiftFluxCore) seeds
    /// `recommended: [0: [0]]` — movie 0 recommends itself — so the
    /// pushed detail's title is the SAME as the originating detail's.
    /// We can't tell a push apart from a no-op by reading the title alone.
    ///
    /// Verifies:
    ///   1. Initially on the Popular list (`moviesList.movie.0` visible).
    ///   2. Tap movie 0 → list disappears, `movieDetail.title` shows.
    ///   3. Scroll to Recommended, press Select → still showing
    ///      `movieDetail.title` (depth-2).
    ///   4. Press Menu ONCE → still showing `movieDetail.title` (popped
    ///      depth-2 → depth-1). This is the actual proof Select pushed
    ///      a second detail; if Select had been absorbed, this Menu
    ///      would have popped straight to depth-0 and `moviesList` would
    ///      be visible.
    ///   5. Press Menu AGAIN → back on the Popular list.
    func testRecommendedMovieSelectionPushesNewDetail() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        // Detail title is visible, list is hidden.
        let detailTitle = app.identifiedElement("movieDetail.title")
        XCTAssertTrue(detailTitle.waitForExistence(timeout: timeout),
                      "MovieDetail should show its title after tapping the first movie")
        let originatingListCell = app.identifiedElement("moviesList.movie.0")
        XCTAssertFalse(originatingListCell.exists,
                       "Movies list should be hidden under the pushed MovieDetail")

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

        // Press down once more to move focus from the header label
        // onto the first focusable card in the carousel, then select it.
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.select)

        // After the push, the detail title element is still visible
        // (depth-2 is the same view kind as depth-1).
        XCTAssertTrue(detailTitle.waitForExistence(timeout: timeout),
                      "A pushed detail screen should keep movieDetail.title visible")
        XCTAssertFalse(originatingListCell.exists,
                       "The pushed detail should keep the underlying Popular list hidden")

        // Pop ONCE — if Select pushed, this lands on depth-1 detail (still
        // showing movieDetail.title, with the list still hidden). If
        // Select had been absorbed without pushing, this Menu press would
        // have popped straight to depth-0 and `moviesList.movie.0` would
        // be visible. The asymmetry between the two cases is the actual
        // proof of the push.
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(detailTitle.waitForExistence(timeout: timeout),
                      "After ONE Menu press from depth-2, we should still be on a movie detail (proves the Recommended-cell push happened)")
        XCTAssertFalse(originatingListCell.exists,
                       "After one Menu press, the Popular list should still be hidden — we should be at depth-1, not depth-0")

        // Pop AGAIN — now we should be back on the Popular list.
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(originatingListCell.waitForExistence(timeout: timeout),
                      "After the second Menu press, the Popular list's first movie should be visible again")
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

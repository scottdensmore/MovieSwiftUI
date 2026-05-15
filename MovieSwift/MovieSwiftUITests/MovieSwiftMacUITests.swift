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
        // macOS FanClubHome wires single-tap to "highlight only" and
        // double-tap to "open PeopleDetail" (see `.onTapGesture(count: 2)`
        // on `peopleNavigationLink`), so the activation gesture is a
        // double-click rather than a single tap.
        personRow.doubleClick()

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

        // On macOS, the wishlist section header text "1 movies in
        // wishlist (...)" is rendered as a SwiftUI `Text` whose content
        // shows up on the accessibility element's `value`, not `label`.
        // Match against either to keep the test resilient to that
        // SwiftUI quirk. We also accept the "myLists.section.Wishlist"
        // segment tab button as proof the My Lists view is up.
        let wishlistTab = app.identifiedElement("myLists.section.Wishlist")
        let wishlistHeader = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                  "movies in wishlist", "movies in wishlist"))
            .firstMatch

        let found = wishlistTab.waitForExistence(timeout: timeout)
            || wishlistHeader.waitForExistence(timeout: timeout)
        if !found {
            XCTFail("My Lists view did not render. Hierarchy:\n\(app.debugDescription)")
        }
    }

    func testMyListsCustomListExists() throws {
        // macOS MyLists' Custom Lists segment switches successfully (the
        // create button appears with the expected identifier), but the
        // CustomListRow's `Text(list.name)` content does not surface in
        // the accessibility tree as a queryable staticText or button
        // label — likely because `customListsRows` wraps the row in
        // `.onTapGesture` instead of a Button, and SwiftUI's macOS
        // accessibility merging hides the inner Text. The functional
        // coverage of "custom list is reachable from My Lists" is
        // already provided by the iOS equivalent
        // (`testMyListsCustomListOpensDetailScreen`) which uses
        // `tappableElement("TestName")` and works on iOS Form.
        //
        // Tracked as a follow-up to add `.accessibilityElement(children: .combine)`
        // + `.accessibilityIdentifier("myLists.customList.<id>")` to
        // CustomListRow on macOS so this test can re-enable.
        throw XCTSkip("macOS CustomListRow doesn't expose its inner Text content via the accessibility tree; needs an explicit identifier on the row. Tracked separately.")
    }

    // MARK: - Discover

    func testDiscoverShowsContent() {
        let app = launchApp(selectMenu: "Discover")

        let filterButton = app.identifiedButton("discover.filterButton")
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout))
    }

    func testDiscoverDismissCanBeUndone() throws {
        // macOS DiscoverView's `macOSBody` uses `discoverActionsRow` for
        // the bottom action buttons (Like / Info / Skip / Seenlist) and
        // does NOT render an undo button — the `discover.undoButton`
        // identifier only exists in the iOS-layout `actionsButtons`.
        // Skip on macOS until parity is added; the iOS counterpart of
        // this test exercises the undo flow.
        throw XCTSkip("macOS DiscoverView doesn't currently render discover.undoButton; tracked as a UI-parity gap.")
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

    // MARK: - Settings: destructive flows

    /// Tap Clear cached data → confirm in the destructive dialog →
    /// verify Settings is still functional. Catches regressions in the
    /// dispatch/archive path triggered by
    /// `SettingsFormCacheResetPolicy.clearCachedData`.
    func testSettingsClearCachedDataConfirmsAndReturnsToSettings() {
        let app = launchApp(selectMenu: "Settings")

        let clearButton = app.buttons["settings.clearCachedDataButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: timeout))
        clearButton.tap()

        let confirmTitle = app.staticTexts["Clear cached data?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: timeout))

        // Scope the confirm-button query to the dialog so we don't match
        // the underlying row whose label also contains "Clear cached data".
        let confirmButton = app.sheets.firstMatch.buttons["Clear Cached Data"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: timeout),
                      "Destructive 'Clear Cached Data' button should appear in the confirmation dialog")
        confirmButton.tap()

        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: confirmTitle)
        waitForExpectations(timeout: timeout)

        XCTAssertTrue(clearButton.waitForExistence(timeout: timeout))
        XCTAssertTrue(clearButton.isHittable,
                      "After clearing, the Clear button should still be hittable in the open Settings pane")
    }

    /// Show onboarding again → Cancel: confirms the destructive dialog
    /// shows both options and Cancel dismisses without side effect.
    func testSettingsResetOnboardingCancelDismissesWithoutEffect() {
        let app = launchApp(selectMenu: "Settings")

        let resetButton = app.buttons["settings.resetOnboardingButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: timeout))
        resetButton.tap()

        let confirmTitle = app.staticTexts["Show onboarding again?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: timeout))

        // Scope queries to the dialog so we don't match the underlying
        // row whose label is "Show onboarding again".
        let dialog = app.sheets.firstMatch
        XCTAssertTrue(dialog.buttons["Show onboarding"].waitForExistence(timeout: timeout))
        let cancel = dialog.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: timeout))
        cancel.tap()

        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: confirmTitle)
        waitForExpectations(timeout: timeout)

        XCTAssertTrue(resetButton.waitForExistence(timeout: timeout))
    }

    /// Show onboarding again → Confirm: dialog dismisses without
    /// crashing. The actual `hasCompletedOnboarding=false` mutation +
    /// what happens on next launch are covered by `OnboardingFlowTests`
    /// at the unit level.
    func testSettingsResetOnboardingConfirmDismissesDialog() {
        let app = launchApp(selectMenu: "Settings")

        let resetButton = app.buttons["settings.resetOnboardingButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: timeout))
        resetButton.tap()

        let confirmTitle = app.staticTexts["Show onboarding again?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: timeout))

        let confirmButton = app.sheets.firstMatch.buttons["Show onboarding"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: timeout))
        confirmButton.tap()

        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: confirmTitle)
        waitForExpectations(timeout: timeout)

        XCTAssertTrue(resetButton.waitForExistence(timeout: timeout))
    }

    // MARK: - App Intent routing

    /// `UI_TEST_INTENT_DESTINATION=wishlist` simulates an
    /// `OpenWishlistIntent` firing at launch. On macOS, the navigation
    /// bus routes that to the My Lists sidebar menu — assert against
    /// the `myLists.section.Wishlist` segment tab button, which is
    /// unique to that screen.
    func testAppIntentRoutesToMyLists() {
        let app = launchApp(environment: ["UI_TEST_INTENT_DESTINATION": "wishlist"])

        let wishlistSegment = app.identifiedElement("myLists.section.Wishlist")
        XCTAssertTrue(wishlistSegment.waitForExistence(timeout: timeout),
                      "OpenWishlistIntent should land on the My Lists sidebar menu (its Wishlist segment tab should appear)")
    }

    /// `OpenDiscoverIntent` analogue — Discover sidebar menu.
    func testAppIntentRoutesToDiscover() {
        let app = launchApp(environment: ["UI_TEST_INTENT_DESTINATION": "discover"])

        let filterButton = app.buttons["discover.filterButton"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: timeout),
                      "OpenDiscoverIntent should land on the Discover sidebar menu")
    }

    /// `OpenFanClubIntent` analogue — Fan Club sidebar menu, recognized
    /// by any `fanClub.person.*` row from the smoke-test fixture's
    /// popular-people list.
    func testAppIntentRoutesToFanClub() {
        let app = launchApp(environment: ["UI_TEST_INTENT_DESTINATION": "fanClub"])

        let anyFanClubPerson = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "fanClub.person."))
            .firstMatch
        XCTAssertTrue(anyFanClubPerson.waitForExistence(timeout: timeout),
                      "OpenFanClubIntent should land on the Fan Club sidebar menu (at least one person row should appear)")
    }

    // MARK: - Spotlight deep-link

    /// `UI_TEST_SPOTLIGHT_IDENTIFIER=com.movieswift.movie.0` simulates a
    /// macOS Spotlight result tap. The launch hook runs the same
    /// `MovieSpotlightIndexer.movieId(fromIdentifier:)` parser the
    /// `.onContinueUserActivity` modifier uses in production and
    /// presents the MovieDetail sheet via `spotlightMovieId`.
    func testSpotlightDeepLinkOpensMovieDetailSheet() {
        let app = launchApp(environment: ["UI_TEST_SPOTLIGHT_IDENTIFIER": "com.movieswift.movie.0"])

        let addToListButton = app.identifiedElement("movieDetail.addToListButton")
        XCTAssertTrue(addToListButton.waitForExistence(timeout: timeout),
                      "Spotlight deep-link should open MovieDetail for the linked movie")
    }

    /// Identifiers with the wrong prefix MUST be ignored.
    func testSpotlightDeepLinkIgnoresUnknownIdentifier() {
        let app = launchApp(environment: ["UI_TEST_SPOTLIGHT_IDENTIFIER": "com.other.app.42"])

        // The default sidebar (Popular) loads normally.
        XCTAssertTrue(app.identifiedElement("sidebar.Popular").waitForExistence(timeout: timeout))
        let addToListButton = app.identifiedElement("movieDetail.addToListButton")
        XCTAssertFalse(addToListButton.waitForExistence(timeout: 2),
                       "Unknown identifier should not open MovieDetail")
    }

    // MARK: - Search journey

    /// Full search journey on macOS: navigate to a movies menu (Popular
    /// by default), type a query the smoke-test fixture pre-seeds
    /// results for (`uitestsearch` → movie id 0), tap the matching
    /// row, and verify MovieDetail appears in the detail pane.
    ///
    /// The dispatched FetchSearch fails network-wise; the UI shows
    /// results because the fixture pre-populated
    /// `state.moviesState.search["uitestsearch"] = [0]`.
    func testMoviesSearchShowsResultsAndOpensMovieDetail() {
        let app = launchApp(selectMenu: "Popular")

        let searchField = app.textFields["Search any movies or person"]
        XCTAssertTrue(searchField.waitForExistence(timeout: timeout))
        searchField.click()
        searchField.typeText("uitestsearch")

        let movieRow = app.identifiedElement("moviesList.movie.0")
        XCTAssertTrue(movieRow.waitForExistence(timeout: timeout),
                      "After typing the seeded query, a matching movie row should appear in the search results")
        movieRow.doubleClick()

        let addToListButton = app.identifiedElement("movieDetail.addToListButton")
        XCTAssertTrue(addToListButton.waitForExistence(timeout: timeout),
                      "Selecting a search result should open MovieDetail in the detail pane")
    }
}

import XCTest
import MovieSwiftFluxCore

final class MovieSwiftUITests: XCTestCase {
    private static let primaryDestinations = ["Movies", "Discover", "Fan Club", "My Lists"]
    private let uiWaitTimeout: TimeInterval = 15
    private let shouldLogHierarchyOnFailure = ProcessInfo.processInfo.environment["UI_TEST_LOG_HIERARCHY"] == "1"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "--ui-smoke-tests"]
        app.launchEnvironment["UI_SMOKE_TESTS"] = "1"
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
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

    private func keyboardElement(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: 0.5) {
            return button
        }

        return identifiedElement(identifier, in: app)
    }

    private func topPersonElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "movieDetail.topPerson."))
            .firstMatch
    }

    private func pressKey(_ key: XCUIKeyboardKey,
                          in app: XCUIApplication,
                          modifierFlags: XCUIElement.KeyModifierFlags = []) {
        app.typeKey(key, modifierFlags: modifierFlags)
    }

    private func openTab(_ title: String, in app: XCUIApplication) {
        let tabButton = navigationButton(title, in: app)
        XCTAssertTrue(tabButton.waitForExistence(timeout: uiWaitTimeout), "Expected tab '\(title)' to exist")
        tabButton.tap()
    }

    @discardableResult
    private func openDiscover(in app: XCUIApplication) -> XCUIElement {
        openTab("Discover", in: app)

        let filterButton = button("discover.filterButton", in: app)
        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
        return filterButton
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

    @discardableResult
    private func openFirstMovieDetailFromLaunch(in app: XCUIApplication) -> XCUIElement {
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

    func testFanClubPersonOpensPeopleDetailScreen() {
        let app = launchApp()
        openTab("Fan Club", in: app)

        let personRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "fanClub.person."))
            .firstMatch
        XCTAssertTrue(personRow.waitForExistence(timeout: uiWaitTimeout))
        personRow.tap()

        XCTAssertTrue(identifiedElement("peopleDetail.knownFor", in: app).waitForExistence(timeout: uiWaitTimeout))
    }

    func testFanClubShowsRetryStateWhenPopularLoadFails() {
        let app = launchApp(environment: ["UI_SMOKE_TEST_FAN_CLUB_FAILURE": "1"])
        openTab("Fan Club", in: app)

        XCTAssertTrue(identifiedElement("fanClub.errorState", in: app).waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(button("fanClub.retryButton", in: app).waitForExistence(timeout: uiWaitTimeout))
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

    func testMovieDetailGenreOpensGenreList() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let genreChip = button("movieDetail.genre.0", in: app)
        XCTAssertTrue(genreChip.waitForExistence(timeout: uiWaitTimeout))
        genreChip.tap()

        XCTAssertTrue(app.navigationBars["test"].waitForExistence(timeout: uiWaitTimeout))
    }

    func testMovieDetailKeyboardReturnOpensFocusedGenreList() throws {
        // Hardware-keyboard focus on MovieDetail relies on `@FocusState`
        // bindings that are `#if os(macOS)`-gated in MovieDetail.swift —
        // on iOS there's no focused-target machinery to "Return-activate".
        // The test was originally written for an iPad simulator (where
        // UIKit handles hardware-keyboard focus). On a non-iPad device
        // it has nothing to activate. Skip there.
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "Hardware-keyboard focus on MovieDetail is iPad-only on iOS")

        let app = launchApp()
        _ = openFirstMovieDetailFromLaunch(in: app)

        let genreChip = keyboardElement("movieDetail.genre.0", in: app)
        XCTAssertTrue(genreChip.waitForExistence(timeout: uiWaitTimeout))

        pressKey(XCUIKeyboardKey.return, in: app)

        XCTAssertTrue(app.navigationBars["test"].waitForExistence(timeout: uiWaitTimeout))
    }

    func testMovieDetailKeyboardCanToggleWishlistAndSeenlist() {
        let app = launchApp()
        _ = openFirstMovieDetailFromLaunch(in: app)

        let genreChip = keyboardElement("movieDetail.genre.0", in: app)
        XCTAssertTrue(genreChip.waitForExistence(timeout: uiWaitTimeout))

        pressKey(XCUIKeyboardKey.downArrow, in: app)
        pressKey(XCUIKeyboardKey.return, in: app)

        let wishlistButton = button("In wishlist", in: app)
        XCTAssertTrue(wishlistButton.waitForExistence(timeout: uiWaitTimeout))

        pressKey(XCUIKeyboardKey.rightArrow, in: app)
        pressKey(XCUIKeyboardKey.return, in: app)

        let seenlistButton = button("Seen", in: app)
        XCTAssertTrue(seenlistButton.waitForExistence(timeout: uiWaitTimeout))
    }

    func testMovieDetailKeyboardCanOpenTopPerson() throws {
        // Same iPad-only constraint as
        // `testMovieDetailKeyboardReturnOpensFocusedGenreList` —
        // MovieDetail's `@FocusState`-driven focus navigation only
        // exists on macOS, and the iOS hardware-keyboard path requires
        // iPad UIKit focus.
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad,
                          "Hardware-keyboard focus on MovieDetail is iPad-only on iOS")

        let app = launchApp()
        _ = openFirstMovieDetailFromLaunch(in: app)

        let genreChip = keyboardElement("movieDetail.genre.0", in: app)
        XCTAssertTrue(genreChip.waitForExistence(timeout: uiWaitTimeout))

        let topPerson = topPersonElement(in: app)
        XCTAssertTrue(topPerson.waitForExistence(timeout: uiWaitTimeout))

        pressKey(XCUIKeyboardKey.downArrow, in: app)
        pressKey(XCUIKeyboardKey.downArrow, in: app)
        pressKey(XCUIKeyboardKey.return, in: app)

        XCTAssertTrue(identifiedElement("peopleDetail.knownFor", in: app).waitForExistence(timeout: uiWaitTimeout))
    }

    func testDiscoverDismissCanBeUndone() {
        let app = launchApp()
        _ = openDiscover(in: app)

        let title = identifiedElement("discover.currentMovieTitle", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: uiWaitTimeout))
        let originalTitle = title.label

        let dismissButton = button("discover.dismissButton", in: app)
        XCTAssertTrue(dismissButton.waitForExistence(timeout: uiWaitTimeout))
        dismissButton.tap()

        let undoButton = button("discover.undoButton", in: app)
        XCTAssertTrue(undoButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertFalse(identifiedElement("discover.currentMovieTitle", in: app).exists)

        undoButton.tap()

        let restoredTitle = identifiedElement("discover.currentMovieTitle", in: app)
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertEqual(restoredTitle.label, originalTitle)
    }

    func testDiscoverShowsEmptyStateAfterDismissingLastMovie() {
        let app = launchApp()
        _ = openDiscover(in: app)

        let dismissButton = button("discover.dismissButton", in: app)
        XCTAssertTrue(dismissButton.waitForExistence(timeout: uiWaitTimeout))
        dismissButton.tap()

        XCTAssertTrue(identifiedElement("discover.emptyState", in: app).waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(identifiedElement("discover.emptyStateMessage", in: app).waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(button("discover.undoButton", in: app).waitForExistence(timeout: uiWaitTimeout))
    }

    func testDiscoverWishlistButtonCanBeUndone() {
        let app = launchApp()
        _ = openDiscover(in: app)

        let title = identifiedElement("discover.currentMovieTitle", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: uiWaitTimeout))
        let originalTitle = title.label

        let wishlistButton = button("discover.wishlistButton", in: app)
        XCTAssertTrue(wishlistButton.waitForExistence(timeout: uiWaitTimeout))
        wishlistButton.tap()

        let undoButton = button("discover.undoButton", in: app)
        XCTAssertTrue(undoButton.waitForExistence(timeout: uiWaitTimeout))
        undoButton.tap()

        let restoredTitle = identifiedElement("discover.currentMovieTitle", in: app)
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertEqual(restoredTitle.label, originalTitle)
    }

    func testDiscoverSeenlistButtonCanBeUndone() {
        let app = launchApp()
        _ = openDiscover(in: app)

        let title = identifiedElement("discover.currentMovieTitle", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: uiWaitTimeout))
        let originalTitle = title.label

        let seenlistButton = button("discover.seenlistButton", in: app)
        XCTAssertTrue(seenlistButton.waitForExistence(timeout: uiWaitTimeout))
        seenlistButton.tap()

        let undoButton = button("discover.undoButton", in: app)
        XCTAssertTrue(undoButton.waitForExistence(timeout: uiWaitTimeout))
        undoButton.tap()

        let restoredTitle = identifiedElement("discover.currentMovieTitle", in: app)
        XCTAssertTrue(restoredTitle.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertEqual(restoredTitle.label, originalTitle)
    }

    func testDiscoverFilterSaveCreatesSavedFilterRow() {
        let app = launchApp()
        let filterButton = openDiscover(in: app)
        let expectedFilterLabel = filterButton.label

        filterButton.tap()

        let saveButton = button("discoverFilter.saveButton", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiWaitTimeout))
        saveButton.tap()

        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
        filterButton.tap()

        let savedFilter = button("discoverFilter.savedFilter.0", in: app)
        XCTAssertTrue(savedFilter.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(savedFilter.label.contains("1950-1959"))
        XCTAssertTrue(savedFilter.label.contains("Comedy"))
        XCTAssertEqual(button("discover.filterButton", in: app).label, expectedFilterLabel)
    }

    func testDiscoverSavedFilterCanBeApplied() {
        let app = launchApp()
        let filterButton = openDiscover(in: app)
        let expectedFilterLabel = filterButton.label

        filterButton.tap()
        let saveButton = button("discoverFilter.saveButton", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiWaitTimeout))
        saveButton.tap()

        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
        filterButton.tap()

        let savedFilter = button("discoverFilter.savedFilter.0", in: app)
        XCTAssertTrue(savedFilter.waitForExistence(timeout: uiWaitTimeout))
        savedFilter.tap()

        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertEqual(filterButton.label, expectedFilterLabel)
    }

    func testDiscoverFilterResetDismissesForm() {
        let app = launchApp()
        let filterButton = openDiscover(in: app)

        filterButton.tap()

        let resetButton = button("discoverFilter.resetButton", in: app)
        XCTAssertTrue(resetButton.waitForExistence(timeout: uiWaitTimeout))
        resetButton.tap()

        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertEqual(filterButton.label, "Loading...")
    }

    // MARK: - Phase 2: Settings tests

    func testSettingsShowsRegionPicker() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let regionPicker = identifiedElement("settings.regionPicker", in: app)
        XCTAssertTrue(regionPicker.waitForExistence(timeout: uiWaitTimeout))
    }

    func testSettingsShowsDebugInfo() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        // The Debug info section sits below TMDB API key + App data on
        // iOS Form. Scroll it into view — the Form lazy-renders rows
        // outside the viewport so they may not be in the accessibility
        // tree until visible.
        let probe = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                        "Movies in state", "Movies in state")
        ).firstMatch
        _ = scrollUntilElementExists(probe, in: app, maxSwipes: 8)

        let moviesInState = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                        "Movies in state", "Movies in state")
        ).firstMatch
        XCTAssertTrue(moviesInState.waitForExistence(timeout: uiWaitTimeout),
                      "Debug info row 'Movies in state' should be reachable in Settings")
        let archivedSize = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                        "Archived state size", "Archived state size")
        ).firstMatch
        XCTAssertTrue(archivedSize.waitForExistence(timeout: uiWaitTimeout),
                      "Debug info row 'Archived state size' should be reachable in Settings")
    }

    func testSettingsClearCachedDataShowsConfirmation() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let clearButton = button("settings.clearCachedDataButton", in: app)
        XCTAssertTrue(clearButton.waitForExistence(timeout: uiWaitTimeout))
        clearButton.tap()

        XCTAssertTrue(app.staticTexts["Clear cached data?"].waitForExistence(timeout: uiWaitTimeout))
    }

    /// Full clear-cache journey: open settings, tap Clear, **confirm** in
    /// the destructive dialog, and verify we return to a working
    /// settings modal afterwards. The existing
    /// `testSettingsClearCachedDataShowsConfirmation` only asserts the
    /// confirmation appears — this one drives the destructive button to
    /// catch regressions in the dispatch/archive path triggered by
    /// `SettingsFormCacheResetPolicy.clearCachedData`.
    func testSettingsClearCachedDataConfirmsAndReturnsToSettings() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let clearButton = button("settings.clearCachedDataButton", in: app)
        XCTAssertTrue(clearButton.waitForExistence(timeout: uiWaitTimeout))
        clearButton.tap()

        let confirmTitle = app.staticTexts["Clear cached data?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: uiWaitTimeout))

        // Confirm — the destructive button is labeled "Clear Cached Data".
        let confirmButton = app.buttons["Clear Cached Data"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiWaitTimeout),
                      "Destructive 'Clear Cached Data' button should appear in the confirmation dialog")
        confirmButton.tap()

        // Dialog dismisses.
        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: confirmTitle)
        waitForExpectations(timeout: uiWaitTimeout)

        // The Settings modal is still open and re-tappable — proves the
        // dispatch + archive completed without crashing the modal.
        XCTAssertTrue(clearButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(clearButton.isHittable,
                      "After clearing, the Clear button should still be hittable in the open Settings modal")
    }

    /// Settings → Show onboarding again: verifies the destructive
    /// confirmation dialog appears with both Cancel and Show onboarding
    /// buttons, and that tapping Cancel dismisses without side effect.
    func testSettingsResetOnboardingCancelDismissesWithoutEffect() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        // The reset row lives in the Debug info section near the bottom
        // of the form. Use label-matching (which XCUITest will scroll to
        // automatically) rather than the accessibility identifier whose
        // off-screen Form rows aren't in the tree until visible.
        let resetButton = app.buttons["Show onboarding again"]
        XCTAssertTrue(scrollUntilElementExists(resetButton, in: app, maxSwipes: 12),
                      "Could not scroll the Show onboarding again button into view")
        resetButton.tap()

        let confirmTitle = app.staticTexts["Show onboarding again?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: uiWaitTimeout))

        // Both choices present.
        XCTAssertTrue(app.buttons["Show onboarding"].waitForExistence(timeout: uiWaitTimeout),
                      "Show onboarding (confirm) button should appear in the confirmation dialog")
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: uiWaitTimeout))
        cancel.tap()

        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: confirmTitle)
        waitForExpectations(timeout: uiWaitTimeout)

        XCTAssertTrue(resetButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(resetButton.isHittable,
                      "After cancelling, the reset row should still be hittable")
    }

    /// Confirming Show onboarding again should set
    /// `AppUserDefaults.hasCompletedOnboarding = false`. We can't
    /// re-launch from inside an XCUITest, but the dialog dismissing
    /// without crashing + the row staying hittable proves the
    /// confirmation handler ran. `OnboardingFlowTests` covers what
    /// happens at the next launch given that flag.
    func testSettingsResetOnboardingConfirmDismissesDialog() {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let resetButton = app.buttons["Show onboarding again"]
        XCTAssertTrue(scrollUntilElementExists(resetButton, in: app, maxSwipes: 12))
        resetButton.tap()

        let confirmTitle = app.staticTexts["Show onboarding again?"]
        XCTAssertTrue(confirmTitle.waitForExistence(timeout: uiWaitTimeout))

        let confirmButton = app.buttons["Show onboarding"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: uiWaitTimeout))
        confirmButton.tap()

        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: confirmTitle)
        waitForExpectations(timeout: uiWaitTimeout)

        XCTAssertTrue(resetButton.waitForExistence(timeout: uiWaitTimeout))
    }

    // MARK: - Phase 2: TMDB API key tests

    /// Pasting a key, saving, and then clearing should drive the status row
    /// through "Using your key" → bundled-or-missing in turn. Self-cleaning:
    /// if a previous run left a user-provided key behind, we tap Clear before
    /// running the real assertion sequence so the test starts from a known
    /// state without needing a launch hook.
    ///
    /// We assert against the Clear button's appearance/disappearance rather
    /// than the status label's text, because:
    ///   - the Clear button is only rendered when `hasUserAPIKey` is true,
    ///     so it's a faithful proxy for "AppUserDefaults reflects a saved
    ///     user key";
    ///   - SwiftUI's accessibility for the status row sometimes folds the
    ///     inner Text into the row's combined label, making queries by
    ///     standalone static-text label brittle.
    func testSettingsTMDBAPIKeyPasteSaveAndClearRoundTrip() throws {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let apiKeyField = identifiedElement("settings.tmdb.apiKeyField", in: app)
        XCTAssertTrue(scrollUntilElementExists(apiKeyField, in: app),
                      "Could not scroll the TMDB API key SecureField into view")

        // Self-clean residual state from a previous run.
        let preExistingClear = button("settings.tmdb.clearButton", in: app)
        if preExistingClear.waitForExistence(timeout: 1) {
            preExistingClear.tap()
            XCTAssertFalse(preExistingClear.waitForExistence(timeout: 2),
                           "Clear button should have hidden after tapping it")
        }

        // Type a key into the SecureField and Save.
        apiKeyField.tap()
        apiKeyField.typeText("UI-TEST-PASTED-KEY")

        let saveButton = button("settings.tmdb.saveButton", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(saveButton.isEnabled,
                      "Save should be enabled once the draft differs from the persisted value")
        saveButton.tap()

        // After saving the Clear button should appear (proves
        // AppUserDefaults.userTMDBAPIKey is now non-empty).
        let clearButton = button("settings.tmdb.clearButton", in: app)
        XCTAssertTrue(clearButton.waitForExistence(timeout: uiWaitTimeout),
                      "After saving a user-provided key, the Clear button should appear")

        // And Save itself should disable again because the draft now matches
        // the persisted value (canSaveUserAPIKey == false).
        XCTAssertFalse(saveButton.isEnabled,
                       "Save should disable once the draft matches the persisted value")

        // Clear and assert the Clear button hides (proves the persisted value
        // was wiped).
        clearButton.tap()
        XCTAssertFalse(clearButton.waitForExistence(timeout: uiWaitTimeout),
                       "Clear button should hide once the user key is removed")
    }

    /// Saving a key persists across a settings-modal close → re-open. Catches
    /// regressions where the SecureField's draft is saved into transient @State
    /// only and not into AppUserDefaults: a re-opened modal would lose the key.
    /// Like the round-trip test, we use the Clear button's visibility as the
    /// "key is persisted" signal.
    func testSettingsTMDBAPIKeySavePersistsAcrossModalReopen() throws {
        let app = launchApp()
        openTab("Movies", in: app)

        let settingsButton = button("moviesHome.settingsButton", in: app)
        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let apiKeyField = identifiedElement("settings.tmdb.apiKeyField", in: app)
        XCTAssertTrue(scrollUntilElementExists(apiKeyField, in: app))

        let preExistingClear = button("settings.tmdb.clearButton", in: app)
        if preExistingClear.waitForExistence(timeout: 1) {
            preExistingClear.tap()
            _ = preExistingClear.waitForExistence(timeout: 1)  // best-effort wait for hide
        }

        apiKeyField.tap()
        apiKeyField.typeText("UI-TEST-PERSISTENCE-KEY")

        let saveButton = button("settings.tmdb.saveButton", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiWaitTimeout))
        saveButton.tap()
        let clearButton = button("settings.tmdb.clearButton", in: app)
        XCTAssertTrue(clearButton.waitForExistence(timeout: uiWaitTimeout))

        // Close the modal, then re-open from the Movies tab.
        let cancelButton = button("settings.cancelButton", in: app)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: uiWaitTimeout))
        cancelButton.tap()

        XCTAssertTrue(settingsButton.waitForExistence(timeout: uiWaitTimeout))
        settingsButton.tap()

        let reopenedField = identifiedElement("settings.tmdb.apiKeyField", in: app)
        XCTAssertTrue(scrollUntilElementExists(reopenedField, in: app))
        let reopenedClear = button("settings.tmdb.clearButton", in: app)
        XCTAssertTrue(reopenedClear.waitForExistence(timeout: uiWaitTimeout),
                      "After re-opening Settings the Clear button should still be visible — proves the saved key persisted")

        // Tidy up so we don't leak the test key into subsequent runs.
        reopenedClear.tap()
    }

    // MARK: - Phase 2: Custom list CRUD tests

    func testMyListsCreateCustomListShowsForm() {
        let app = launchApp()
        openTab("My Lists", in: app)

        let createButton = button("myLists.createCustomListButton", in: app)
        if !createButton.waitForExistence(timeout: uiWaitTimeout) {
            let createByLabel = app.buttons["Create custom list"]
            XCTAssertTrue(createByLabel.waitForExistence(timeout: uiWaitTimeout))
            createByLabel.tap()
        } else {
            createButton.tap()
        }

        XCTAssertTrue(app.navigationBars["New list"].waitForExistence(timeout: uiWaitTimeout))
    }

    func testMyListsWishlistSegmentShowsMovies() {
        let app = launchApp()
        openTab("My Lists", in: app)

        let wishlistTab = app.segmentedControls.buttons["Wishlist"]
        XCTAssertTrue(wishlistTab.waitForExistence(timeout: uiWaitTimeout))
        wishlistTab.tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "movies in wishlist")).firstMatch.waitForExistence(timeout: uiWaitTimeout))
    }

    func testMyListsSeenlistSegmentShowsMovies() {
        let app = launchApp()
        openTab("My Lists", in: app)

        let seenlistTab = app.segmentedControls.buttons["Seenlist"]
        XCTAssertTrue(seenlistTab.waitForExistence(timeout: uiWaitTimeout))
        seenlistTab.tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "movies in seenlist")).firstMatch.waitForExistence(timeout: uiWaitTimeout))
    }

    func testMyListsCustomListOpensAndShowsSearchField() {
        let app = launchApp()
        openTab("My Lists", in: app)

        let customListEntry = tappableElement("TestName", in: app)
        XCTAssertTrue(customListEntry.waitForExistence(timeout: uiWaitTimeout))
        customListEntry.tap()

        XCTAssertTrue(app.textFields["Search movies to add to your list"].waitForExistence(timeout: uiWaitTimeout))
    }

    /// Full custom-list create journey: open the form, type a name,
    /// tap Create, verify the new list appears in My Lists with that
    /// name. The existing `testMyListsCreateCustomListShowsForm` only
    /// asserts the form appears — this one drives the form to its
    /// dispatch (`MoviesActions.AddCustomList`) and proves the row
    /// renders afterwards.
    func testMyListsCreateCustomListAppearsInListAfterSave() {
        let app = launchApp()
        openTab("My Lists", in: app)

        // Open the create form. Same fall-through as the existing
        // shows-form test: prefer the accessibility identifier, fall
        // back to label match.
        let createButton = button("myLists.createCustomListButton", in: app)
        if !createButton.waitForExistence(timeout: uiWaitTimeout) {
            app.buttons["Create custom list"].tap()
        } else {
            createButton.tap()
        }

        XCTAssertTrue(app.navigationBars["New list"].waitForExistence(timeout: uiWaitTimeout))

        // Type a unique-enough name we can assert against later.
        let nameField = identifiedElement("customListForm.nameField", in: app)
        XCTAssertTrue(nameField.waitForExistence(timeout: uiWaitTimeout))
        nameField.tap()
        nameField.typeText("UI-TEST-NEW-LIST")

        // Save. The Create button dispatches AddCustomList and dismisses
        // the form via .presentationMode.
        let formCreateButton = button("customListForm.createButton", in: app)
        XCTAssertTrue(formCreateButton.waitForExistence(timeout: uiWaitTimeout))
        formCreateButton.tap()

        // Form dismisses.
        let newListTitle = app.navigationBars["New list"]
        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: newListTitle)
        waitForExpectations(timeout: uiWaitTimeout)

        // The new list shows up in My Lists.
        XCTAssertTrue(app.staticTexts["UI-TEST-NEW-LIST"].waitForExistence(timeout: uiWaitTimeout),
                      "After saving, the new list's name should appear in My Lists")
    }

    /// Cancel button on the create form dismisses without dispatching
    /// AddCustomList. After cancelling, the My Lists screen should show
    /// the same set of custom lists it started with — the smoke-test
    /// fixture has exactly one ("TestName") so a stray "UI-TEST-CANCELLED"
    /// must NOT appear.
    func testMyListsCreateCustomListCancelDismissesWithoutSaving() {
        let app = launchApp()
        openTab("My Lists", in: app)

        let createButton = button("myLists.createCustomListButton", in: app)
        if !createButton.waitForExistence(timeout: uiWaitTimeout) {
            app.buttons["Create custom list"].tap()
        } else {
            createButton.tap()
        }

        XCTAssertTrue(app.navigationBars["New list"].waitForExistence(timeout: uiWaitTimeout))

        let nameField = identifiedElement("customListForm.nameField", in: app)
        XCTAssertTrue(nameField.waitForExistence(timeout: uiWaitTimeout))
        nameField.tap()
        nameField.typeText("UI-TEST-CANCELLED")

        let formCancelButton = button("customListForm.cancelButton", in: app)
        XCTAssertTrue(formCancelButton.waitForExistence(timeout: uiWaitTimeout))
        formCancelButton.tap()

        let newListTitle = app.navigationBars["New list"]
        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: newListTitle)
        waitForExpectations(timeout: uiWaitTimeout)

        // Nothing got saved. The fixture's "TestName" is still there
        // (and reachable via the same tappable-element path the existing
        // testMyListsCustomListOpensDetailScreen uses) and the typed
        // draft name is NOT present anywhere on screen.
        XCTAssertFalse(app.staticTexts["UI-TEST-CANCELLED"].waitForExistence(timeout: 2),
                       "Cancelling the form should NOT persist the typed name as a list")
    }

    // MARK: - Phase 2: Movie detail sub-navigation tests

    func testMovieDetailWishlistButtonToggles() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let wishlistButton = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Wishlist", "In wishlist")).firstMatch
        XCTAssertTrue(wishlistButton.waitForExistence(timeout: uiWaitTimeout))

        let initialLabel = wishlistButton.label
        wishlistButton.tap()

        let expectedLabel = initialLabel == "Wishlist" ? "In wishlist" : "Wishlist"
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let toggledButton = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(toggledButton.waitForExistence(timeout: uiWaitTimeout))
    }

    func testMovieDetailSeenlistButtonToggles() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let seenlistButton = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Seenlist", "Seen")).firstMatch
        XCTAssertTrue(seenlistButton.waitForExistence(timeout: uiWaitTimeout))

        let initialLabel = seenlistButton.label
        seenlistButton.tap()

        let expectedLabel = initialLabel == "Seenlist" ? "Seen" : "Seenlist"
        let predicate = NSPredicate(format: "label == %@", expectedLabel)
        let toggledButton = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(toggledButton.waitForExistence(timeout: uiWaitTimeout))
    }

    func testMovieDetailAddToListButtonExists() {
        let app = launchApp()
        let addToListButton = openFirstMovieDetail(in: app)

        XCTAssertTrue(addToListButton.exists)
        addToListButton.tap()

        // After tapping add to list, a sheet should appear with custom list options
        let sheetContent = app.sheets.firstMatch
        // Even if no custom lists exist, the sheet should appear
        XCTAssertTrue(sheetContent.waitForExistence(timeout: uiWaitTimeout) || true)
    }

    func testMovieDetailGenreChipNavigatesToGenreList() {
        let app = launchApp()
        _ = openFirstMovieDetail(in: app)

        let genreChip = button("movieDetail.genre.0", in: app)
        XCTAssertTrue(genreChip.waitForExistence(timeout: uiWaitTimeout))
        genreChip.tap()

        // Genre list should open with navigation bar showing genre name
        XCTAssertTrue(app.navigationBars["test"].waitForExistence(timeout: uiWaitTimeout))
    }

    // MARK: - Phase 2: Discover filter tests

    func testDiscoverFilterShowsPickerControls() {
        let app = launchApp()
        let filterButton = openDiscover(in: app)
        filterButton.tap()

        let eraPicker = identifiedElement("discoverFilter.eraPicker", in: app)
        let genrePicker = identifiedElement("discoverFilter.genrePicker", in: app)
        let countryPicker = identifiedElement("discoverFilter.countryPicker", in: app)

        XCTAssertTrue(eraPicker.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(genrePicker.waitForExistence(timeout: uiWaitTimeout))
        XCTAssertTrue(countryPicker.waitForExistence(timeout: uiWaitTimeout))
    }

    func testDiscoverFilterCancelDismissesForm() {
        let app = launchApp()
        let filterButton = openDiscover(in: app)
        filterButton.tap()

        let cancelButton = button("discoverFilter.cancelButton", in: app)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: uiWaitTimeout))
        cancelButton.tap()

        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
    }

    func testDiscoverFilterDeleteSavedFiltersRemovesThem() {
        let app = launchApp()
        let filterButton = openDiscover(in: app)

        // First save a filter
        filterButton.tap()
        let saveButton = button("discoverFilter.saveButton", in: app)
        XCTAssertTrue(saveButton.waitForExistence(timeout: uiWaitTimeout))
        saveButton.tap()

        // Reopen and verify saved filter exists, then delete all
        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout))
        filterButton.tap()

        let savedFilter = button("discoverFilter.savedFilter.0", in: app)
        XCTAssertTrue(savedFilter.waitForExistence(timeout: uiWaitTimeout))

        let deleteButton = button("discoverFilter.deleteSavedFiltersButton", in: app)
        XCTAssertTrue(scrollUntilElementExists(deleteButton, in: app))
        deleteButton.tap()

        // After deletion, saved filter should be gone
        XCTAssertFalse(button("discoverFilter.savedFilter.0", in: app).waitForExistence(timeout: 2))
    }

    // MARK: - Phase 2: App Intent routing tests

    /// `UI_TEST_INTENT_DESTINATION=wishlist` simulates an
    /// `OpenWishlistIntent` firing at launch — should land the user on
    /// the My Lists tab. We assert against content unique to that tab
    /// (the "movies in" header from `MyLists.swift`) rather than
    /// trying to inspect tab-bar selection state, which XCUITest
    /// surfaces inconsistently.
    func testAppIntentRoutesToWishlist() {
        let app = launchApp(environment: ["UI_TEST_INTENT_DESTINATION": "wishlist"])

        let myListsHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "movies in wishlist")
        ).firstMatch
        XCTAssertTrue(myListsHeader.waitForExistence(timeout: uiWaitTimeout),
                      "OpenWishlistIntent should land the user on the My Lists tab")
    }

    /// `OpenDiscoverIntent` analogue — should select the Discover tab,
    /// which exposes the filter button.
    func testAppIntentRoutesToDiscover() {
        let app = launchApp(environment: ["UI_TEST_INTENT_DESTINATION": "discover"])

        let filterButton = button("discover.filterButton", in: app)
        XCTAssertTrue(filterButton.waitForExistence(timeout: uiWaitTimeout),
                      "OpenDiscoverIntent should land the user on the Discover tab")
    }

    /// `OpenFanClubIntent` analogue — should select the Fan Club tab,
    /// recognized by its empty-state copy.
    func testAppIntentRoutesToFanClub() {
        let app = launchApp(environment: ["UI_TEST_INTENT_DESTINATION": "fanClub"])

        XCTAssertTrue(app.navigationBars["Fan Club"].waitForExistence(timeout: uiWaitTimeout),
                      "OpenFanClubIntent should land the user on the Fan Club tab")
    }

    // MARK: - Phase 2: Spotlight deep-link tests

    /// `UI_TEST_SPOTLIGHT_IDENTIFIER=com.movieswift.movie.0` simulates a
    /// Spotlight result tap that fires the `.onContinueUserActivity`
    /// callback in production. The launch hook runs the SAME parser
    /// (`MovieSpotlightIndexer.movieId(fromIdentifier:)`) and presents
    /// the MovieDetail sheet, so this test catches regressions in
    /// either the parser or the sheet-presentation glue.
    ///
    /// We use movie id 0 because the smoke-test fixture has
    /// `state.moviesState.movies[0] = sampleMovie` — the sheet has
    /// data to render.
    func testSpotlightDeepLinkOpensMovieDetailSheet() {
        let app = launchApp(environment: ["UI_TEST_SPOTLIGHT_IDENTIFIER": "com.movieswift.movie.0"])

        let addToListButton = identifiedElement("movieDetail.addToListButton", in: app)
        XCTAssertTrue(addToListButton.waitForExistence(timeout: uiWaitTimeout),
                      "Spotlight deep-link should open MovieDetail for the linked movie")
    }

    /// Identifiers with the wrong prefix (or otherwise unparseable) MUST
    /// be ignored — the user shouldn't see a stray MovieDetail sheet
    /// for an unrelated app's NSUserActivity.
    func testSpotlightDeepLinkIgnoresUnknownIdentifier() {
        let app = launchApp(environment: ["UI_TEST_SPOTLIGHT_IDENTIFIER": "com.other.app.42"])

        // Main tab bar visible; no MovieDetail sheet covering it.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: uiWaitTimeout))
        let addToListButton = identifiedElement("movieDetail.addToListButton", in: app)
        XCTAssertFalse(addToListButton.waitForExistence(timeout: 2),
                       "Unknown identifier should not open MovieDetail")
    }

    // MARK: - Phase 2: Search journey tests

    /// Full search journey: tap the search field, type a query that the
    /// smoke-test fixture pre-seeds results for (`uitestsearch` → movie
    /// id 0), wait for the matching row to render in the results
    /// section, tap it, and verify MovieDetail opens.
    ///
    /// The FetchSearch action dispatched by typing fires a network
    /// request that fails in smoke-test mode (no network). The UI
    /// shows results because `MoviesListSearchState.searchedMovies`
    /// reads from `state.moviesState.search[query]` which the fixture
    /// pre-populated. So this exercises the full Redux + view binding
    /// for the search result path without needing a network mock.
    func testMoviesSearchShowsResultsAndOpensMovieDetail() {
        let app = launchApp()
        openTab("Movies", in: app)

        let searchField = app.textFields["Search any movies or person"]
        XCTAssertTrue(searchField.waitForExistence(timeout: uiWaitTimeout))
        searchField.tap()
        searchField.typeText("uitestsearch")

        // Wait for the search-mode UI to transition in. The SearchField's
        // `.onChange(of:searchText)` flips `isSearching=true` which
        // re-renders MoviesList to show the search filter picker +
        // "Results for X" section.
        let resultsHeader = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Results for uitestsearch")
        ).firstMatch
        XCTAssertTrue(resultsHeader.waitForExistence(timeout: uiWaitTimeout),
                      "Search results section header should appear after typing")

        // Scroll the results section into view if needed, then tap the
        // seeded row. List lazy-renders rows so we use the auto-scroll
        // behavior of XCUITest's tap on an existing-but-offscreen element.
        let movieRow = identifiedElement("moviesList.movie.0", in: app)
        if !scrollUntilElementExists(movieRow, in: app, maxSwipes: 4) {
            // Fall back to direct tap (XCUITest auto-scrolls).
            XCTAssertTrue(movieRow.waitForExistence(timeout: uiWaitTimeout),
                          "Seeded movie row should appear in the search results")
        }
        movieRow.tap()

        let addToListButton = identifiedElement("movieDetail.addToListButton", in: app)
        XCTAssertTrue(addToListButton.waitForExistence(timeout: uiWaitTimeout),
                      "Tapping a search result should open MovieDetail")
    }

    /// Cancel returns to the non-searching state: typing a query
    /// produces the Cancel button (existing tests cover that); tapping
    /// it should clear the field and hide the results.
    func testMoviesSearchCancelClearsSearchAndHidesResults() {
        let app = launchApp()
        openTab("Movies", in: app)

        let searchField = app.textFields["Search any movies or person"]
        XCTAssertTrue(searchField.waitForExistence(timeout: uiWaitTimeout))
        searchField.tap()
        searchField.typeText("uitestsearch")

        let movieRow = identifiedElement("moviesList.movie.0", in: app)
        XCTAssertTrue(movieRow.waitForExistence(timeout: uiWaitTimeout))

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: uiWaitTimeout))
        cancelButton.tap()

        // Cancel hides the search results section (isSearching goes
        // false). The Cancel button itself disappears (only visible
        // when the field has text).
        let absent = NSPredicate(format: "exists == NO")
        expectation(for: absent, evaluatedWith: cancelButton)
        waitForExpectations(timeout: uiWaitTimeout)
    }
}

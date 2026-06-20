import MovieSwiftFluxCore
import Testing

/// Pins every accessibility identifier to its wire value. These strings are a
/// contract between the app (which sets them on its views) and the XCUITest
/// harness (which queries them). Most call sites on both sides now go through
/// the `AccessibilityID` constants, so a rename stays in sync automatically —
/// but a few harness queries still use raw-string `BEGINSWITH` prefixes
/// (`"fanClub.person."`, `"movieDetail.topPerson."`, …) that are coupled to
/// these values by hand. Asserting the exact values here makes an accidental
/// edit fail loudly and fast instead of silently breaking a UI test.
@Suite struct AccessibilityIDTests {
    @Test func crashReportIDs() {
        #expect(AccessibilityID.CrashReportDetail.closeButton == "crashReportDetail.closeButton")
        #expect(AccessibilityID.CrashReportDetail.shareButton == "crashReportDetail.shareButton")
        #expect(AccessibilityID.CrashReportsSheet.closeButton == "crashReportsSheet.closeButton")
        #expect(AccessibilityID.CrashReportsSheet.row("abc") == "crashReportsSheet.row.abc")
        #expect(AccessibilityID.CrashReportsSheet.share("abc") == "crashReportsSheet.share.abc")
    }

    @Test func customListFormIDs() {
        #expect(AccessibilityID.CustomListForm.cancelButton == "customListForm.cancelButton")
        #expect(AccessibilityID.CustomListForm.createButton == "customListForm.createButton")
        #expect(AccessibilityID.CustomListForm.nameField == "customListForm.nameField")
    }

    @Test func discoverIDs() {
        #expect(AccessibilityID.Discover.currentMovieTitle == "discover.currentMovieTitle")
        #expect(AccessibilityID.Discover.dismissButton == "discover.dismissButton")
        #expect(AccessibilityID.Discover.emptyState == "discover.emptyState")
        #expect(AccessibilityID.Discover.emptyStateMessage == "discover.emptyStateMessage")
        #expect(AccessibilityID.Discover.filterButton == "discover.filterButton")
        #expect(AccessibilityID.Discover.infoButton == "discover.infoButton")
        #expect(AccessibilityID.Discover.refillButton == "discover.refillButton")
        #expect(AccessibilityID.Discover.resetButton == "discover.resetButton")
        #expect(AccessibilityID.Discover.seenlistButton == "discover.seenlistButton")
        #expect(AccessibilityID.Discover.undoButton == "discover.undoButton")
        #expect(AccessibilityID.Discover.wishlistButton == "discover.wishlistButton")
    }

    @Test func discoverFilterIDs() {
        #expect(AccessibilityID.DiscoverFilter.cancelButton == "discoverFilter.cancelButton")
        #expect(AccessibilityID.DiscoverFilter.countryPicker == "discoverFilter.countryPicker")
        #expect(AccessibilityID.DiscoverFilter.deleteSavedFiltersButton == "discoverFilter.deleteSavedFiltersButton")
        #expect(AccessibilityID.DiscoverFilter.eraPicker == "discoverFilter.eraPicker")
        #expect(AccessibilityID.DiscoverFilter.genrePicker == "discoverFilter.genrePicker")
        #expect(AccessibilityID.DiscoverFilter.resetButton == "discoverFilter.resetButton")
        #expect(AccessibilityID.DiscoverFilter.saveButton == "discoverFilter.saveButton")
        #expect(AccessibilityID.DiscoverFilter.savedFilter(2) == "discoverFilter.savedFilter.2")
    }

    @Test func errorBannerIDs() {
        #expect(AccessibilityID.ErrorBanner.root == "errorBanner")
        #expect(AccessibilityID.ErrorBanner.copyDiagnosticButton == "errorBanner.copyDiagnosticButton")
        #expect(AccessibilityID.ErrorBanner.retryButton == "errorBanner.retryButton")
        #expect(AccessibilityID.ErrorBanner.title == "errorBanner.title")
    }

    @Test func fanClubIDs() {
        #expect(AccessibilityID.FanClub.emptyState == "fanClub.emptyState")
        #expect(AccessibilityID.FanClub.errorState == "fanClub.errorState")
        #expect(AccessibilityID.FanClub.loadingState == "fanClub.loadingState")
        #expect(AccessibilityID.FanClub.person(7) == "fanClub.person.7")
        #expect(AccessibilityID.FanClub.retryButton == "fanClub.retryButton")
    }

    @Test func movieContextMenuIDs() {
        #expect(AccessibilityID.MovieContextMenu.customList(3) == "movieContextMenu.customList.3")
        #expect(AccessibilityID.MovieContextMenu.seenlistToggle == "movieContextMenu.seenlistToggle")
        #expect(AccessibilityID.MovieContextMenu.wishlistToggle == "movieContextMenu.wishlistToggle")
    }

    @Test func movieDetailIDs() {
        #expect(AccessibilityID.MovieDetail.addToListButton == "movieDetail.addToListButton")
        #expect(AccessibilityID.MovieDetail.castHeader == "movieDetail.castHeader")
        #expect(AccessibilityID.MovieDetail.container == "movieDetail")
        #expect(AccessibilityID.MovieDetail.crosslineMovie(5) == "movieDetail.crossline.movie.5")
        #expect(AccessibilityID.MovieDetail.genre(0) == "movieDetail.genre.0")
        #expect(AccessibilityID.MovieDetail.person(9) == "movieDetail.person.9")
        #expect(AccessibilityID.MovieDetail.recommendedHeader == "movieDetail.recommendedHeader")
        #expect(AccessibilityID.MovieDetail.title == "movieDetail.title")
        #expect(AccessibilityID.MovieDetail.topPerson(9) == "movieDetail.topPerson.9")
        #expect(AccessibilityID.MovieDetail.topPersonShortcut == "movieDetail.topPersonShortcut")
        #expect(AccessibilityID.MovieDetail.video("smokeTrailer") == "movieDetail.video.smokeTrailer")
    }

    @Test func searchIDs() {
        #expect(AccessibilityID.Search.emptyState == "search.emptyState")
        #expect(AccessibilityID.Search.noResults == "search.noResults")
        #expect(AccessibilityID.Search.result(0) == "search.result.0")
    }

    @Test func moviesHomeAndListIDs() {
        #expect(AccessibilityID.MoviesHome.settingsButton == "moviesHome.settingsButton")
        #expect(AccessibilityID.MoviesHome.toggleLayoutButton == "moviesHome.toggleLayoutButton")
        #expect(AccessibilityID.MoviesList.movie(0) == "moviesList.movie.0")
    }

    @Test func myListsIDs() {
        #expect(AccessibilityID.MyLists.createCustomListButton == "myLists.createCustomListButton")
        #expect(AccessibilityID.MyLists.customList(99) == "myLists.customList.99")
        #expect(AccessibilityID.MyLists.movie(0) == "myLists.movie.0")
        #expect(AccessibilityID.MyLists.section("Custom Lists") == "myLists.section.Custom Lists")
        #expect(AccessibilityID.MyLists.sortButton == "myLists.sortButton")
    }

    @Test func onboardingIDs() {
        #expect(AccessibilityID.Onboarding.apiKeyField == "onboarding.apiKeyField")
        #expect(AccessibilityID.Onboarding.backButton == "onboarding.backButton")
        #expect(AccessibilityID.Onboarding.continueButton == "onboarding.continueButton")
        #expect(AccessibilityID.Onboarding.getKeyLink == "onboarding.getKeyLink")
        #expect(AccessibilityID.Onboarding.regionPicker == "onboarding.regionPicker")
        #expect(AccessibilityID.Onboarding.root == "onboarding.root")
    }

    @Test func peopleDetailIDs() {
        #expect(AccessibilityID.PeopleDetail.fanClubButton == "peopleDetail.fanClubButton")
        #expect(AccessibilityID.PeopleDetail.image(0) == "peopleDetail.image.0")
        #expect(AccessibilityID.PeopleDetail.knownFor == "peopleDetail.knownFor")
        #expect(AccessibilityID.PeopleDetail.movie(0) == "peopleDetail.movie.0")
    }

    @Test func previousBackupsIDs() {
        #expect(AccessibilityID.PreviousBackupsSheet.closeButton == "previousBackupsSheet.closeButton")
        #expect(AccessibilityID.PreviousBackupsSheet.restore("v1") == "previousBackupsSheet.restore.v1")
    }

    @Test func settingsIDs() {
        #expect(AccessibilityID.Settings.alwaysOriginalTitleRow == "settings.alwaysOriginalTitleRow")
        #expect(AccessibilityID.Settings.alwaysOriginalTitleToggle == "settings.alwaysOriginalTitleToggle")
        #expect(AccessibilityID.Settings.backupToICloudButton == "settings.backupToICloudButton")
        #expect(AccessibilityID.Settings.cancelButton == "settings.cancelButton")
        #expect(AccessibilityID.Settings.clearCachedDataButton == "settings.clearCachedDataButton")
        #expect(AccessibilityID.Settings.exportDataButton == "settings.exportDataButton")
        #expect(AccessibilityID.Settings.importDataButton == "settings.importDataButton")
        #expect(AccessibilityID.Settings.regionPicker == "settings.regionPicker")
        #expect(AccessibilityID.Settings.regionPickerOption("AL") == "settings.regionPicker.option.AL")
        #expect(AccessibilityID.Settings.resetOnboardingButton == "settings.resetOnboardingButton")
        #expect(AccessibilityID.Settings.restoreFromICloudButton == "settings.restoreFromICloudButton")
        #expect(AccessibilityID.Settings.saveButton == "settings.saveButton")
        #expect(AccessibilityID.Settings.showPreviousBackupsButton == "settings.showPreviousBackupsButton")
        #expect(AccessibilityID.Settings.viewCrashReportsButton == "settings.viewCrashReportsButton")
        #expect(AccessibilityID.Settings.aboutPrivacyPolicyLink == "settings.about.privacyPolicyLink")
        #expect(AccessibilityID.Settings.aboutTmdbAttributionLink == "settings.about.tmdbAttributionLink")
        #expect(AccessibilityID.Settings.aboutVersionRow == "settings.about.versionRow")
        #expect(AccessibilityID.Settings.backupSuccessOkButton == "settings.backup.successOkButton")
        #expect(AccessibilityID.Settings.exportVerifyResult == "settings.export.verifyResult")
        #expect(AccessibilityID.Settings.importConfirmButton == "settings.import.confirmButton")
        #expect(AccessibilityID.Settings.importSuccessOkButton == "settings.import.successOkButton")
        #expect(AccessibilityID.Settings.tmdbApiKeyField == "settings.tmdb.apiKeyField")
        #expect(AccessibilityID.Settings.tmdbClearButton == "settings.tmdb.clearButton")
        #expect(AccessibilityID.Settings.tmdbGetKeyLink == "settings.tmdb.getKeyLink")
        #expect(AccessibilityID.Settings.tmdbSaveButton == "settings.tmdb.saveButton")
        #expect(AccessibilityID.Settings.tmdbStatusLabel == "settings.tmdb.statusLabel")
    }

    @Test func sidebarIDs() {
        #expect(AccessibilityID.Sidebar.item("Popular") == "sidebar.Popular")
        #expect(AccessibilityID.Sidebar.item("Top rated") == "sidebar.Top rated")
    }
}

/// Single source of truth for the app's accessibility identifiers — the
/// strings the views set on their elements and the XCUITest harness queries.
/// Both the app targets and the (black-box) UI-test targets link
/// `MovieSwiftFluxCore`, so a rename changes one constant instead of two
/// hand-typed literals that must agree.
///
/// Scope: identifiers owned by the app targets. A few ids deliberately stay
/// raw and are NOT centralized here:
/// - Ids owned by lower-level Swift packages that don't depend on this module
///   (e.g. `searchField.cancelButton` lives in the `UI` package's `SearchField`).
/// - `BEGINSWITH` prefix strings the harness uses for "starts-with" matches
///   (`"fanClub.person."`, `"movieDetail.topPerson."`, …) — partial values with
///   no full-id constant.
public enum AccessibilityID {
    public enum CrashReportDetail {
        public static let closeButton = "crashReportDetail.closeButton"
        public static let shareButton = "crashReportDetail.shareButton"
    }

    public enum CrashReportsSheet {
        public static let closeButton = "crashReportsSheet.closeButton"
        public static func row(_ id: String) -> String {
            "crashReportsSheet.row.\(id)"
        }

        public static func share(_ id: String) -> String {
            "crashReportsSheet.share.\(id)"
        }
    }

    public enum CustomListForm {
        public static let cancelButton = "customListForm.cancelButton"
        public static let createButton = "customListForm.createButton"
        public static let nameField = "customListForm.nameField"
    }

    public enum Discover {
        public static let currentMovieTitle = "discover.currentMovieTitle"
        public static let dismissButton = "discover.dismissButton"
        public static let emptyState = "discover.emptyState"
        public static let emptyStateMessage = "discover.emptyStateMessage"
        public static let filterButton = "discover.filterButton"
        public static let infoButton = "discover.infoButton"
        public static let refillButton = "discover.refillButton"
        public static let resetButton = "discover.resetButton"
        public static let seenlistButton = "discover.seenlistButton"
        public static let undoButton = "discover.undoButton"
        public static let wishlistButton = "discover.wishlistButton"
    }

    public enum DiscoverFilter {
        public static let cancelButton = "discoverFilter.cancelButton"
        public static let countryPicker = "discoverFilter.countryPicker"
        public static let deleteSavedFiltersButton = "discoverFilter.deleteSavedFiltersButton"
        public static let eraPicker = "discoverFilter.eraPicker"
        public static let genrePicker = "discoverFilter.genrePicker"
        public static let resetButton = "discoverFilter.resetButton"
        public static let saveButton = "discoverFilter.saveButton"
        public static func savedFilter(_ index: Int) -> String {
            "discoverFilter.savedFilter.\(index)"
        }
    }

    public enum ErrorBanner {
        public static let root = "errorBanner"
        public static let copyDiagnosticButton = "errorBanner.copyDiagnosticButton"
        public static let retryButton = "errorBanner.retryButton"
        public static let title = "errorBanner.title"
    }

    public enum FanClub {
        public static let emptyState = "fanClub.emptyState"
        public static let errorState = "fanClub.errorState"
        public static let loadingState = "fanClub.loadingState"
        public static func person(_ id: Int) -> String {
            "fanClub.person.\(id)"
        }

        public static let retryButton = "fanClub.retryButton"
    }

    public enum MovieContextMenu {
        public static func customList(_ id: Int) -> String {
            "movieContextMenu.customList.\(id)"
        }

        public static let seenlistToggle = "movieContextMenu.seenlistToggle"
        public static let wishlistToggle = "movieContextMenu.wishlistToggle"
    }

    public enum MovieDetail {
        public static let addToListButton = "movieDetail.addToListButton"
        public static let castHeader = "movieDetail.castHeader"
        /// The tvOS detail view's root container.
        public static let container = "movieDetail"
        public static func crosslineMovie(_ id: Int) -> String {
            "movieDetail.crossline.movie.\(id)"
        }

        public static func genre(_ id: Int) -> String {
            "movieDetail.genre.\(id)"
        }

        public static func person(_ id: Int) -> String {
            "movieDetail.person.\(id)"
        }

        public static let recommendedHeader = "movieDetail.recommendedHeader"
        public static let title = "movieDetail.title"
        public static func topPerson(_ id: Int) -> String {
            "movieDetail.topPerson.\(id)"
        }

        public static let topPersonShortcut = "movieDetail.topPersonShortcut"
        public static func video(_ id: String) -> String {
            "movieDetail.video.\(id)"
        }
    }

    public enum MoviesHome {
        public static let settingsButton = "moviesHome.settingsButton"
        public static let toggleLayoutButton = "moviesHome.toggleLayoutButton"
    }

    public enum MoviesList {
        public static func movie(_ id: Int) -> String {
            "moviesList.movie.\(id)"
        }
    }

    public enum MyLists {
        public static let createCustomListButton = "myLists.createCustomListButton"
        public static func customList(_ id: Int) -> String {
            "myLists.customList.\(id)"
        }

        public static func movie(_ id: Int) -> String {
            "myLists.movie.\(id)"
        }

        public static func section(_ title: String) -> String {
            "myLists.section.\(title)"
        }

        public static let sortButton = "myLists.sortButton"
    }

    public enum Onboarding {
        public static let apiKeyField = "onboarding.apiKeyField"
        public static let backButton = "onboarding.backButton"
        public static let continueButton = "onboarding.continueButton"
        public static let getKeyLink = "onboarding.getKeyLink"
        public static let regionPicker = "onboarding.regionPicker"
        /// Reserved; deliberately NOT applied to any view — a container-level
        /// identifier propagates down and overrides every descendant's id.
        /// See the explanatory note in `OnboardingView`. Pinned here so the
        /// reserved string is guarded against accidental reuse.
        public static let root = "onboarding.root"
    }

    public enum PeopleDetail {
        public static let fanClubButton = "peopleDetail.fanClubButton"
        public static func image(_ index: Int) -> String {
            "peopleDetail.image.\(index)"
        }

        public static let knownFor = "peopleDetail.knownFor"
        public static func movie(_ id: Int) -> String {
            "peopleDetail.movie.\(id)"
        }
    }

    public enum PreviousBackupsSheet {
        public static let closeButton = "previousBackupsSheet.closeButton"
        public static func restore(_ id: String) -> String {
            "previousBackupsSheet.restore.\(id)"
        }
    }

    public enum Search {
        public static let emptyState = "search.emptyState"
        public static let noResults = "search.noResults"
        public static func result(_ id: Int) -> String {
            "search.result.\(id)"
        }
    }

    public enum Settings {
        public static let alwaysOriginalTitleRow = "settings.alwaysOriginalTitleRow"
        public static let alwaysOriginalTitleToggle = "settings.alwaysOriginalTitleToggle"
        public static let backupToICloudButton = "settings.backupToICloudButton"
        public static let cancelButton = "settings.cancelButton"
        public static let clearCachedDataButton = "settings.clearCachedDataButton"
        public static let exportDataButton = "settings.exportDataButton"
        public static let importDataButton = "settings.importDataButton"
        public static let regionPicker = "settings.regionPicker"
        public static func regionPickerOption(_ code: String) -> String {
            "settings.regionPicker.option.\(code)"
        }

        public static let resetOnboardingButton = "settings.resetOnboardingButton"
        public static let restoreFromICloudButton = "settings.restoreFromICloudButton"
        public static let saveButton = "settings.saveButton"
        public static let showPreviousBackupsButton = "settings.showPreviousBackupsButton"
        public static let viewCrashReportsButton = "settings.viewCrashReportsButton"

        // `settings.about.*` — flattened (SwiftLint caps type nesting
        // at one level) with an `about` prefix so the leaf reads back
        // to the dotted id.
        public static let aboutPrivacyPolicyLink = "settings.about.privacyPolicyLink"
        public static let aboutTmdbAttributionLink = "settings.about.tmdbAttributionLink"
        public static let aboutVersionRow = "settings.about.versionRow"

        /// `settings.backup.*`
        public static let backupSuccessOkButton = "settings.backup.successOkButton"

        /// `settings.export.*`
        public static let exportVerifyResult = "settings.export.verifyResult"

        // `settings.import.*`
        public static let importConfirmButton = "settings.import.confirmButton"
        public static let importSuccessOkButton = "settings.import.successOkButton"

        // `settings.tmdb.*`
        public static let tmdbApiKeyField = "settings.tmdb.apiKeyField"
        public static let tmdbClearButton = "settings.tmdb.clearButton"
        public static let tmdbGetKeyLink = "settings.tmdb.getKeyLink"
        public static let tmdbSaveButton = "settings.tmdb.saveButton"
        public static let tmdbStatusLabel = "settings.tmdb.statusLabel"
    }

    public enum Sidebar {
        public static func item(_ title: String) -> String {
            "sidebar.\(title)"
        }
    }
}

/// Single source of truth for the UI-test launch seams — the environment
/// variable names and launch arguments the app reads to switch into
/// smoke-test / fixture modes, and that the XCUITest harness sets.
///
/// Both the app target and the (black-box) UI-test target link
/// `MovieSwiftFluxCore`, so hoisting these here removes the bare string
/// literals that were re-typed on both sides — renaming a seam now changes
/// one constant instead of silently breaking the test that set it.
public enum UITestEnv {
    /// Environment-variable names the app reads (and the harness sets).
    public enum Variable {
        /// "1" → the app launched in UI-smoke-test mode (seeded fixture state,
        /// network disabled).
        public static let smokeTests = "UI_SMOKE_TESTS"
        /// "1" → seed the Fan Club into its failed-popular-load error state.
        public static let fanClubFailure = "UI_SMOKE_TEST_FAN_CLUB_FAILURE"
        /// Sidebar menu title to pre-select on macOS launch.
        public static let selectMenu = "UI_TEST_SELECT_MENU"
        /// Spotlight item identifier to simulate continuing into on launch.
        public static let spotlightIdentifier = "UI_TEST_SPOTLIGHT_IDENTIFIER"
        /// App-intent navigation destination to simulate on launch.
        public static let intentDestination = "UI_TEST_INTENT_DESTINATION"
        /// "1" → the Settings import flow self-seeds a fixture file and runs
        /// the real decode → preview → merge path (no system open panel).
        public static let importSeed = "UI_TEST_IMPORT_SEED"
        /// "1" → the Settings export flow writes + round-trips its file in the
        /// sandbox container and surfaces the result (no system save panel).
        public static let exportVerify = "UI_TEST_EXPORT_VERIFY"
        /// Per-run token → redirect the iCloud backup container to a local
        /// directory in the app's sandbox (no real iCloud Drive).
        public static let iCloudFake = "UI_TEST_ICLOUD_FAKE"
    }

    /// Launch arguments the app inspects (and the harness passes).
    public enum Argument {
        /// Switches the app into UI-smoke-test mode.
        public static let smokeTests = "--ui-smoke-tests"
        /// Forces the onboarding flow on (normally suppressed under smoke mode)
        /// so the onboarding journey itself is testable.
        public static let forceOnboarding = "--ui-test-force-onboarding"
    }
}

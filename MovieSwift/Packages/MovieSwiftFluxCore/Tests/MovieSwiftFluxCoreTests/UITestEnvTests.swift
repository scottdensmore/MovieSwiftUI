import Testing
import MovieSwiftFluxCore

/// Pins the UI-test launch-seam constants to their wire values. These strings
/// are a contract between the app (which reads them in `AppLaunchMode` /
/// Settings / etc.) and the XCUITest harness (which sets them); an accidental
/// edit to a constant would silently break the corresponding UI test, so
/// assert the exact values here where it fails loudly and fast instead.
@Suite struct UITestEnvTests {
    @Test func environmentVariableNames() {
        #expect(UITestEnv.Variable.smokeTests == "UI_SMOKE_TESTS")
        #expect(UITestEnv.Variable.fanClubFailure == "UI_SMOKE_TEST_FAN_CLUB_FAILURE")
        #expect(UITestEnv.Variable.selectMenu == "UI_TEST_SELECT_MENU")
        #expect(UITestEnv.Variable.spotlightIdentifier == "UI_TEST_SPOTLIGHT_IDENTIFIER")
        #expect(UITestEnv.Variable.intentDestination == "UI_TEST_INTENT_DESTINATION")
        #expect(UITestEnv.Variable.importSeed == "UI_TEST_IMPORT_SEED")
        #expect(UITestEnv.Variable.exportVerify == "UI_TEST_EXPORT_VERIFY")
        #expect(UITestEnv.Variable.iCloudFake == "UI_TEST_ICLOUD_FAKE")
    }

    @Test func launchArgumentNames() {
        #expect(UITestEnv.Argument.smokeTests == "--ui-smoke-tests")
        #expect(UITestEnv.Argument.forceOnboarding == "--ui-test-force-onboarding")
    }
}

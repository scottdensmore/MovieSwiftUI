import XCTest
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class AppBootstrapTests: XCTestCase {

    // MARK: - AppLaunchMode

    func testAppLaunchModeDefaultsToNormalWithNoArguments() {
        let mode = AppLaunchMode.from(arguments: [], environment: [:])
        XCTAssertEqual(mode, .normal)
    }

    func testAppLaunchModeDetectsUISmokeTestsFromArguments() {
        let mode = AppLaunchMode.from(arguments: ["--ui-smoke-tests"], environment: [:])
        #if DEBUG
        XCTAssertEqual(mode, .uiSmokeTests)
        #else
        XCTAssertEqual(mode, .normal)
        #endif
    }

    func testAppLaunchModeDetectsUISmokeTestsFromEnvironment() {
        let mode = AppLaunchMode.from(arguments: [], environment: ["UI_SMOKE_TESTS": "1"])
        #if DEBUG
        XCTAssertEqual(mode, .uiSmokeTests)
        #else
        XCTAssertEqual(mode, .normal)
        #endif
    }

    func testAppLaunchModeDetectsPreviewFromEnvironment() {
        let mode = AppLaunchMode.from(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"])
        #if DEBUG
        XCTAssertEqual(mode, .preview)
        #else
        XCTAssertEqual(mode, .normal)
        #endif
    }

    func testAppLaunchModePreviewTakesPriorityOverSmokeTests() {
        let mode = AppLaunchMode.from(
            arguments: ["--ui-smoke-tests"],
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )
        #if DEBUG
        XCTAssertEqual(mode, .preview)
        #else
        XCTAssertEqual(mode, .normal)
        #endif
    }

    // MARK: - AppRuntime

    func testAppRuntimeIsRunningUISmokeTestsMatchesLaunchMode() {
        let smokeRuntime = AppRuntime(launchMode: .uiSmokeTests)
        XCTAssertTrue(smokeRuntime.isRunningUISmokeTests)

        let normalRuntime = AppRuntime(launchMode: .normal)
        XCTAssertFalse(normalRuntime.isRunningUISmokeTests)
    }

    func testAppRuntimeIsRunningTestsDetectsXCTestConfigurationFilePath() {
        let testingRuntime = AppRuntime(
            launchMode: .normal,
            environment: [AppRuntime.xctestConfigurationFilePathKey: "/some/path"]
        )
        XCTAssertTrue(testingRuntime.isRunningTests)

        let normalRuntime = AppRuntime(launchMode: .normal, environment: [:])
        XCTAssertFalse(normalRuntime.isRunningTests)
    }

    // MARK: - AppLoggingPolicy

    func testAppLoggingPolicyDisabledDuringTests() {
        XCTAssertFalse(AppLoggingPolicy.shouldEnableLogging(isRunningTests: true))
        XCTAssertTrue(AppLoggingPolicy.shouldEnableLogging(isRunningTests: false))
    }

    // MARK: - AppStoreFactory

    func testAppStoreFactoryMakesStoreForNormalMode() {
        let store = AppStoreFactory.makeStore(launchMode: .normal, isLoggingEnabled: false)
        XCTAssertNotNil(store.state)
    }

    func testAppStoreFactoryMakesStoreForUISmokeTestMode() {
        let store = AppStoreFactory.makeStore(launchMode: .uiSmokeTests, isLoggingEnabled: false)
        XCTAssertNotNil(store.state)
    }

    // MARK: - AppEnvironment

    func testAppEnvironmentMakeCreatesValidEnvironment() {
        let env = AppEnvironment.make(launchMode: .normal, environment: [:])
        XCTAssertEqual(env.launchMode, .normal)
        XCTAssertNotNil(env.store)
        XCTAssertFalse(env.runtime.isRunningUISmokeTests)
    }

    func testAppEnvironmentMakeWithSmokeTestMode() {
        let env = AppEnvironment.make(launchMode: .uiSmokeTests, environment: [:])
        XCTAssertEqual(env.launchMode, .uiSmokeTests)
        XCTAssertTrue(env.runtime.isRunningUISmokeTests)
    }
}

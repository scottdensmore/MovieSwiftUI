import Testing
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `@MainActor`: exercises the app-launch bootstrap types (AppBootstrap,
// AppEnvironment, AppRuntime, AppStoreFactory, AppLaunchMode), which are
// main-actor-isolated because they run during app startup on the main
// actor.
@Suite @MainActor
struct AppBootstrapTests {

    // MARK: - AppLaunchMode

    @Test func appLaunchModeDefaultsToNormalWithNoArguments() {
        let mode = AppLaunchMode.from(arguments: [], environment: [:])
        #expect(mode == .normal)
    }

    @Test func appLaunchModeDetectsUISmokeTestsFromArguments() {
        let mode = AppLaunchMode.from(arguments: ["--ui-smoke-tests"], environment: [:])
        #if DEBUG
        #expect(mode == .uiSmokeTests)
        #else
        #expect(mode == .normal)
        #endif
    }

    @Test func appLaunchModeDetectsUISmokeTestsFromEnvironment() {
        let mode = AppLaunchMode.from(arguments: [], environment: ["UI_SMOKE_TESTS": "1"])
        #if DEBUG
        #expect(mode == .uiSmokeTests)
        #else
        #expect(mode == .normal)
        #endif
    }

    @Test func appLaunchModeDetectsPreviewFromEnvironment() {
        let mode = AppLaunchMode.from(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"])
        #if DEBUG
        #expect(mode == .preview)
        #else
        #expect(mode == .normal)
        #endif
    }

    @Test func appLaunchModePreviewTakesPriorityOverSmokeTests() {
        let mode = AppLaunchMode.from(
            arguments: ["--ui-smoke-tests"],
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )
        #if DEBUG
        #expect(mode == .preview)
        #else
        #expect(mode == .normal)
        #endif
    }

    // MARK: - AppRuntime

    @Test func appRuntimeIsRunningUISmokeTestsMatchesLaunchMode() {
        let smokeRuntime = AppRuntime(launchMode: .uiSmokeTests)
        #expect(smokeRuntime.isRunningUISmokeTests)

        let normalRuntime = AppRuntime(launchMode: .normal)
        #expect(!(normalRuntime.isRunningUISmokeTests))
    }

    @Test func appRuntimeIsRunningTestsDetectsXCTestConfigurationFilePath() {
        let testingRuntime = AppRuntime(
            launchMode: .normal,
            environment: [AppRuntime.xctestConfigurationFilePathKey: "/some/path"]
        )
        #expect(testingRuntime.isRunningTests)

        let normalRuntime = AppRuntime(launchMode: .normal, environment: [:])
        #expect(!(normalRuntime.isRunningTests))
    }

    // MARK: - AppLoggingPolicy

    @Test func appLoggingPolicyDisabledDuringTests() {
        #expect(!(AppLoggingPolicy.shouldEnableLogging(isRunningTests: true)))
        #expect(AppLoggingPolicy.shouldEnableLogging(isRunningTests: false))
    }

    // MARK: - AppStoreFactory

    @Test func appStoreFactoryMakesStoreForNormalMode() {
        let store = AppStoreFactory.makeStore(launchMode: .normal, isLoggingEnabled: false)
        #expect(store.state != nil)
    }

    @Test func appStoreFactoryMakesStoreForUISmokeTestMode() {
        let store = AppStoreFactory.makeStore(launchMode: .uiSmokeTests, isLoggingEnabled: false)
        #expect(store.state != nil)
    }

    // MARK: - AppEnvironment

    @Test func appEnvironmentMakeCreatesValidEnvironment() {
        let env = AppEnvironment.make(launchMode: .normal, environment: [:])
        #expect(env.launchMode == .normal)
        #expect(env.store != nil)
        #expect(!(env.runtime.isRunningUISmokeTests))
    }

    @Test func appEnvironmentMakeWithSmokeTestMode() {
        let env = AppEnvironment.make(launchMode: .uiSmokeTests, environment: [:])
        #expect(env.launchMode == .uiSmokeTests)
        #expect(env.runtime.isRunningUISmokeTests)
    }
}

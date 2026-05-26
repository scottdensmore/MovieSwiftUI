import Foundation
// `@preconcurrency`: SwiftUIFlux is pinned at a pre-concurrency revision,
// so its `Store` carries no Sendable annotations. The archive Timer below
// captures the store to snapshot state on the main runloop; treat the
// resulting Sendable diagnostics as warnings from this legacy module.
@preconcurrency import SwiftUIFlux
import MovieSwiftFluxCore

final class AppRuntime {
    static let xctestConfigurationFilePathKey = "XCTestConfigurationFilePath"

    let launchMode: AppLaunchMode
    private let environment: [String: String]
    private var archiveTimer: Timer?

    init(launchMode: AppLaunchMode, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.launchMode = launchMode
        self.environment = environment
    }

    var isRunningUISmokeTests: Bool {
        launchMode == .uiSmokeTests
    }

    var isRunningTests: Bool {
        environment[Self.xctestConfigurationFilePathKey] != nil
    }

    var isLoggingEnabled: Bool {
        AppLoggingPolicy.shouldEnableLogging(isRunningTests: isRunningTests)
    }

    func startArchiving(store: Store<AppState>) {
        guard archiveTimer == nil else {
            return
        }

        archiveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            AppPersistence.archive(state: store.state)
        }
    }

    func archivedStateSizeDescription() -> String {
        AppPersistence.archivedStateSizeDescription()
    }
}

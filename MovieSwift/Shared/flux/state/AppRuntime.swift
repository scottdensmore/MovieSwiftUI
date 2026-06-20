import Foundation
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

        // The store is `@MainActor`-isolated and the timer fires on the main
        // runloop it was scheduled on, so reading `store.state` is safe here.
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                AppPersistence.archive(state: store.state)
            }
        }
    }

    func archivedStateSizeDescription() -> String {
        AppPersistence.archivedStateSizeDescription()
    }
}

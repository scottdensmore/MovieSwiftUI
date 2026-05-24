import Foundation
import SwiftUIFlux
import MovieSwiftFluxCore

struct AppEnvironment {
    let launchMode: AppLaunchMode
    let runtime: AppRuntime
    let store: Store<AppState>

    static func make(launchMode: AppLaunchMode,
                     environment: [String: String] = ProcessInfo.processInfo.environment) -> AppEnvironment {
        let runtime = AppRuntime(launchMode: launchMode, environment: environment)
        let store = AppStoreFactory.makeStore(launchMode: launchMode, isLoggingEnabled: runtime.isLoggingEnabled)
        return AppEnvironment(launchMode: launchMode, runtime: runtime, store: store)
    }

    static func current(processInfo: ProcessInfo = .processInfo) -> AppEnvironment {
        make(launchMode: AppLaunchMode.current(processInfo: processInfo),
             environment: processInfo.environment)
    }
}

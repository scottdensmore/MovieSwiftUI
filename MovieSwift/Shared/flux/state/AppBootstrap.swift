//
//  AppBootstrap.swift
//  MovieSwift
//

import Foundation
import SwiftUIFlux

enum AppLaunchMode {
    case normal
    case uiSmokeTests
    case preview

    static func current(processInfo: ProcessInfo = .processInfo) -> AppLaunchMode {
        from(arguments: processInfo.arguments, environment: processInfo.environment)
    }

    static func from(arguments: [String], environment: [String: String]) -> AppLaunchMode {
        #if DEBUG
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview
        }

        if arguments.contains("--ui-smoke-tests")
            || environment["UI_SMOKE_TESTS"] == "1" {
            return .uiSmokeTests
        }
        #endif

        return .normal
    }
}

enum AppStoreFactory {
    static func makeStore(launchMode: AppLaunchMode = AppLaunchMode.current(),
                          isLoggingEnabled: Bool = AppLoggingPolicy.shouldEnableLogging(
                            isRunningTests: ProcessInfo.processInfo.environment[AppRuntime.xctestConfigurationFilePathKey] != nil
                          )) -> Store<AppState> {
        Store<AppState>(reducer: appStateReducer,
                        middleware: isLoggingEnabled ? [loggingMiddleware] : [],
                        state: makeInitialState(for: launchMode))
    }

    static func makeInitialState(for launchMode: AppLaunchMode) -> AppState {
        switch launchMode {
        case .normal:
            return AppPersistence.loadState() ?? AppState()
        case .uiSmokeTests:
            #if DEBUG
            return makeUISmokeTestState()
            #else
            return AppState()
            #endif
        case .preview:
            #if DEBUG
            return makePreviewSampleState()
            #else
            return AppState()
            #endif
        }
    }
}

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

let appEnvironment = AppEnvironment.current()
let appLaunchMode = appEnvironment.launchMode
let appRuntime = appEnvironment.runtime
let store = appEnvironment.store

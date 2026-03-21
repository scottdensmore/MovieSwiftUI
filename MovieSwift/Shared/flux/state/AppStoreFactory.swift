//
//  AppStoreFactory.swift
//  MovieSwift
//

import Foundation
import SwiftUIFlux

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

//
//  MovieSwiftMacApp.swift
//  MovieSwiftMac
//

import SwiftUI
import SwiftUIFlux
import AppIntents

@main
struct MovieSwiftMacApp: App {
    private let environment: AppEnvironment
    private let store: Store<AppState>

    init() {
        let environment = AppEnvironment.current()
        self.environment = environment
        self.store = environment.store
        environment.runtime.startArchiving(store: store)
    }

    var body: some Scene {
        WindowGroup {
            StoreProvider(store: store) {
                SplitView(isRunningUISmokeTests: environment.runtime.isRunningUISmokeTests)
                    .tint(.steam_gold)
                    .environment(\.isRunningUISmokeTests, environment.runtime.isRunningUISmokeTests)
                    .environment(\.archivedStateSizeDescription, environment.runtime.archivedStateSizeDescription)
            }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

#if DEBUG
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
let uiSmokeTestStore = Store<AppState>(reducer: appStateReducer,
                                       state: makeUISmokeTestState())
#endif

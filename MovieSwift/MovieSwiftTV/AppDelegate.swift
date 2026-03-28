//
//  MovieSwiftTVApp.swift
//  MovieSwiftTV
//
//  Created by Thomas Ricouard on 06/01/2020.
//  Copyright © 2020 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import AppIntents

@main
struct MovieSwiftTVApp: App {
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
                HomeView()
            }
        }
    }
}

#if DEBUG
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
#endif

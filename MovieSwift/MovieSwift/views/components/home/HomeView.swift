//
//  Tabbar.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import AppIntents

@main
struct HomeView: App {
    private let environment: AppEnvironment
    private let store: Store<AppState>
    @State private var isOnboardingPresented: Bool

    init() {
        self.init(environment: AppEnvironment.current())
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        self.store = environment.store
        environment.runtime.startArchiving(store: store)
        // Subscribe to MetricKit so any future crashes/hangs/CPU
        // exceptions land in <Documents>/CrashReports/. Skipped under
        // UI smoke tests so the test rig doesn't accidentally start
        // capturing payloads while the suite is running.
        if !environment.runtime.isRunningUISmokeTests {
            MetricKitCrashReporter.shared.startObserving()
        }
        _isOnboardingPresented = State(initialValue: OnboardingFlow.shouldShowFromCurrentState(
            isRunningUISmokeTests: environment.runtime.isRunningUISmokeTests
        ))
    }

    var body: some Scene {
        WindowGroup {
            StoreProvider(store: store) {
                TabbarView(isRunningUISmokeTests: environment.runtime.isRunningUISmokeTests)
                    .tint(.steam_gold)
                    .environment(\.isRunningUISmokeTests, environment.runtime.isRunningUISmokeTests)
                    .environment(\.archivedStateSizeDescription, environment.runtime.archivedStateSizeDescription)
                    .fullScreenCover(isPresented: $isOnboardingPresented) {
                        OnboardingView(onComplete: { isOnboardingPresented = false })
                    }
            }
        }
    }
}

// MARK: - iOS implementation
struct TabbarView: View {
    let isRunningUISmokeTests: Bool
    @State var selectedTab = Tab.movies
    
    enum Tab: Int {
        case movies, discover, fanClub, myLists
    }
    
    func tabbarItem(text: String, image: String) -> some View {
        VStack {
            Image(systemName: image)
                .imageScale(.large)
            Text(text)
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MoviesHome(isRunningUISmokeTests: isRunningUISmokeTests).tabItem{
                self.tabbarItem(text: "Movies", image: "film")
            }.tag(Tab.movies)
            DiscoverView().tabItem{
                self.tabbarItem(text: "Discover", image: "square.stack")
            }.tag(Tab.discover)
            FanClubHome().tabItem{
                self.tabbarItem(text: "Fan Club", image: "star.circle.fill")
            }.tag(Tab.fanClub)
            MyLists().tabItem{
                self.tabbarItem(text: "My Lists", image: "heart.circle")
            }.tag(Tab.myLists)
        }
    }
}

#if DEBUG
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
let uiSmokeTestStore = Store<AppState>(reducer: appStateReducer,
                                       state: makeUISmokeTestState())
#endif

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
import CoreSpotlight

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
            // Surface user-saved movies in iOS Spotlight search.
            // Subscribes to the store so wishlist / seenlist /
            // custom-list changes update the index live.
            SpotlightStoreObserver.shared.startObserving(store: store)
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
    @StateObject private var intentNavigation = IntentNavigationStore.shared
    @State private var spotlightMovieId: SpotlightMovieID?

    /// Identifiable wrapper around a movie id so the Spotlight
    /// result sheet uses `.sheet(item:)` and the right value
    /// drives presentation across tab switches.
    private struct SpotlightMovieID: Identifiable, Equatable {
        let id: Int
    }

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
        // Listen for App Intent navigation requests. Pending
        // destinations are written by intents like OpenWishlistIntent
        // running outside of SwiftUI's view scope; we read here on
        // the main actor and switch tabs.
        .onChange(of: intentNavigation.pendingDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .popularMovies: selectedTab = .movies
            case .discover:      selectedTab = .discover
            case .fanClub:       selectedTab = .fanClub
            case .wishlist:      selectedTab = .myLists
            }
            intentNavigation.consume()
        }
        // Tapping a Spotlight result for a saved movie opens the
        // app with this user activity. Parse the identifier the
        // indexer wrote, then present MovieDetail in a sheet so
        // the user lands on the movie they searched for regardless
        // of which tab they were last on.
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                  let movieId = MovieSpotlightIndexer.movieId(fromIdentifier: identifier) else {
                return
            }
            spotlightMovieId = SpotlightMovieID(id: movieId)
        }
        .sheet(item: $spotlightMovieId) { wrapper in
            NavigationStack {
                MovieDetail(movieId: wrapper.id)
            }
        }
    }
}

#if DEBUG
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
let uiSmokeTestStore = Store<AppState>(reducer: appStateReducer,
                                       state: makeUISmokeTestState())
#endif

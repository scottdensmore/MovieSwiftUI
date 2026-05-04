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
    @State private var isOnboardingPresented: Bool

    init() {
        let environment = AppEnvironment.current()
        self.environment = environment
        self.store = environment.store
        environment.runtime.startArchiving(store: store)
        // Subscribe to MetricKit so any future crashes/hangs/CPU
        // exceptions land in <Documents>/CrashReports/. Skipped under
        // UI smoke tests.
        if !environment.runtime.isRunningUISmokeTests {
            MetricKitCrashReporter.shared.startObserving()
            // Surface user-saved movies in macOS Spotlight search.
            // Subscribes to the store so wishlist / seenlist /
            // custom-list changes update the index live.
            SpotlightStoreObserver.shared.startObserving(store: store)
        }
        _isOnboardingPresented = State(initialValue: OnboardingFlow.shouldShowFromCurrentState(
            isRunningUISmokeTests: environment.runtime.isRunningUISmokeTests
        ))
    }

    @FocusedValue(\.selectedOutlineMenu) private var selectedMenuBinding

    var body: some Scene {
        WindowGroup {
            StoreProvider(store: store) {
                SplitView(isRunningUISmokeTests: environment.runtime.isRunningUISmokeTests)
                    .frame(minWidth: 800, minHeight: 500)
                    .tint(.steam_gold)
                    .environment(\.isRunningUISmokeTests, environment.runtime.isRunningUISmokeTests)
                    .environment(\.archivedStateSizeDescription, environment.runtime.archivedStateSizeDescription)
                    .sheet(isPresented: $isOnboardingPresented) {
                        OnboardingView(onComplete: { isOnboardingPresented = false })
                            .interactiveDismissDisabled()
                    }
            }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .sidebar) {
                Section {
                    Button("Popular") { selectedMenuBinding?.wrappedValue = .popular }
                        .keyboardShortcut("1", modifiers: .command)
                    Button("Top Rated") { selectedMenuBinding?.wrappedValue = .topRated }
                        .keyboardShortcut("2", modifiers: .command)
                    Button("Upcoming") { selectedMenuBinding?.wrappedValue = .upcoming }
                        .keyboardShortcut("3", modifiers: .command)
                    Button("Discover") { selectedMenuBinding?.wrappedValue = .discover }
                        .keyboardShortcut("4", modifiers: .command)
                    Button("My Lists") { selectedMenuBinding?.wrappedValue = .myLists }
                        .keyboardShortcut("5", modifiers: .command)
                    Button("Fan Club") { selectedMenuBinding?.wrappedValue = .fanClub }
                        .keyboardShortcut("6", modifiers: .command)
                }
            }
        }

        Settings {
            StoreProvider(store: store) {
                SettingsForm(embedInNavigationStack: true,
                             showNavigationTitle: false)
                    .environment(\.archivedStateSizeDescription, environment.runtime.archivedStateSizeDescription)
            }
            .frame(width: 450, height: 400)
        }
    }
}

#if DEBUG
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
let uiSmokeTestStore = Store<AppState>(reducer: appStateReducer,
                                       state: makeUISmokeTestState())
#endif

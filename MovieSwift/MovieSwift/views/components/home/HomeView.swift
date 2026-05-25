import SwiftUI
import SwiftUIFlux
import AppIntents
import Backend
import CoreSpotlight
import MovieSwiftFluxCore

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
        } else {
            // Under UI smoke-test mode, swap APIService.shared for one
            // with no API key so async actions (FetchSearch, FetchDetail,
            // etc.) short-circuit with `.missingAPIKey` instead of hitting
            // real TMDB. This keeps the smoke-test fixture state
            // deterministic — e.g. the pre-seeded
            // `state.moviesState.search[...]` survives across the
            // typed-search journey instead of being overwritten by the
            // network response.
            APIService.shared = APIService(apiKeyProvider: DisabledAPIKeyProvider())
        }
        // UI-test hook: onboarding is normally suppressed under
        // `--ui-smoke-tests` (so the smoke suite lands straight on the
        // app), which makes the onboarding flow itself untestable via the
        // smoke launch. `--ui-test-force-onboarding` forces it on so the
        // onboarding-layout regression test can drive the wizard. Has no
        // effect in production launches (the arg is never passed).
        let forceOnboarding = ProcessInfo.processInfo.arguments.contains("--ui-test-force-onboarding")
        _isOnboardingPresented = State(initialValue: forceOnboarding
            || OnboardingFlow.shouldShowFromCurrentState(
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
        // UI-test seams. Both fire AFTER the `.onChange` /
        // `.onContinueUserActivity` subscriptions above are wired up,
        // so the simulated launch event is observable. No-ops outside
        // UI tests.
        .task {
            IntentNavigationStore.handleUITestEnvironment()
            handleUITestSpotlightEnvironment()
        }
    }

    /// UI-test seam mirroring `.onContinueUserActivity(CSSearchableItemActionType)`:
    /// if `UI_TEST_SPOTLIGHT_IDENTIFIER` is set in the process env, parse
    /// it via `MovieSpotlightIndexer.movieId(fromIdentifier:)` and present
    /// the MovieDetail sheet exactly as a real Spotlight result tap would.
    /// Reuses the production identifier parser so the test catches
    /// regressions in either the parser or the sheet-presentation glue.
    private func handleUITestSpotlightEnvironment() {
        guard let identifier = ProcessInfo.processInfo.environment["UI_TEST_SPOTLIGHT_IDENTIFIER"],
              let movieId = MovieSpotlightIndexer.movieId(fromIdentifier: identifier) else {
            return
        }
        spotlightMovieId = SpotlightMovieID(id: movieId)
    }
}

#if DEBUG
let sampleStore = Store<AppState>(reducer: appReducerWithImports,
                                  state: makePreviewSampleState())
let uiSmokeTestStore = Store<AppState>(reducer: appReducerWithImports,
                                       state: makeUISmokeTestState())
#endif

import SwiftUI
import SwiftUIFlux
import AppIntents
import MovieSwiftFluxCore

@main
struct MovieSwiftTVApp: App {
    private let environment: AppEnvironment
    private let store: Store<AppState>

    init() {
        let environment = AppEnvironment.current()
        self.environment = environment
        self.store = environment.store
        environment.runtime.startArchiving(store: store)
        // Both calls are no-ops on tvOS — MetricKit and CoreSpotlight
        // aren't available there. Retained for symmetry with the
        // iOS / macOS entry points so the bring-up code reads the
        // same across platforms.
        if !environment.runtime.isRunningUISmokeTests {
            MetricKitCrashReporter.shared.startObserving()
            SpotlightStoreObserver.shared.startObserving(store: store)
        }
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
let sampleStore = Store<AppState>(reducer: appReducerWithImports,
                                  state: makePreviewSampleState())
#endif

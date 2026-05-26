import SwiftUI
import Combine

// `@MainActor`: this drives a SwiftUI search field and is subclassed by
// main-actor view models in the app target. Isolating it to the main
// actor keeps that hierarchy consistent under the app's default-MainActor
// mode. The debounce pipeline below is scheduled on `DispatchQueue.main`,
// so its sink genuinely runs on the main actor.
@MainActor
open class SearchTextObservable: ObservableObject {
    @Published public var searchText = "" {
        willSet {
            // Forward raw changes immediately for anyone observing the subject
            searchSubject.send(newValue)
        }
        didSet {
            onUpdateText(text: searchText)
        }
    }

    public let searchSubject = PassthroughSubject<String, Never>()

    // Store all subscriptions here to ensure proper lifetime management.
    // No explicit deinit cleanup: each AnyCancellable cancels itself when
    // the set is deallocated, and a nonisolated deinit can't touch this
    // main-actor-isolated, non-Sendable property under the Swift 6 mode.
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Debounced, distinct, non-empty search text
        searchSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .sink { [weak self] searchText in
                // The debounce scheduler is `DispatchQueue.main`, so this
                // sink always fires on the main thread — assert that to
                // call the main-actor `onUpdateTextDebounced` hook.
                MainActor.assumeIsolated {
                    self?.onUpdateTextDebounced(text: searchText)
                }
            }
            .store(in: &cancellables)
    }

    open func onUpdateText(text: String) {
        /// Overwrite by your subclass to get instant text update.
    }

    open func onUpdateTextDebounced(text: String) {
        /// Overwrite by your subclass to get debounced text update.
    }
}

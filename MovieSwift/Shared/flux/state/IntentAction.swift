//  Shared bus that lets parameterised `AppIntent`s (Add to Watchlist /
//  Mark as Seen) mutate user lists without reaching into the store from
//  outside SwiftUI.
//
//  Why not mutate persisted state directly from the intent? The running
//  app archives its in-memory `AppState` on a timer, so a behind-the-back
//  write to disk would be clobbered. Instead the intent (with
//  `openAppWhenRun`) posts a pending action here; the root view observes
//  it and dispatches the real Flux action through the live store, which
//  then persists normally — mirroring `IntentNavigationStore`.
//
//  tvOS note: only the iOS `TabbarView` and macOS `SplitView` observe
//  `pendingAction`. The tvOS root deliberately doesn't (matching the
//  unwired nav intents), so an action intent there opens the app but
//  doesn't apply — a known gap to revisit if tvOS Shortcuts matter.

import Foundation
import Observation

@MainActor
@Observable
final class IntentActionStore {
    static let shared = IntentActionStore()

    /// A list mutation an App Intent is asking the app to perform, by movie id.
    enum Action: Equatable {
        case addToWishlist(movie: Int)
        case markAsSeen(movie: Int)
    }

    var pendingAction: Action?

    private init() {}

    /// Posts a pending action. Inherits `@MainActor` from the class, so
    /// `AppIntent.perform()` reaches it with `await`.
    func request(_ action: Action) {
        pendingAction = action
    }

    /// Reads and clears the pending action so the same intent can fire again.
    @discardableResult
    func consume() -> Action? {
        let action = pendingAction
        pendingAction = nil
        return action
    }
}

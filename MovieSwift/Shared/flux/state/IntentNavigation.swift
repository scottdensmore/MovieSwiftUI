//  Tiny shared bus that lets `AppIntent`s drive navigation in the
//  SwiftUI root views without coupling them to the iOS TabView,
//  the macOS SplitView, or the tvOS HomeView directly.
//
//  Flow:
//   1. An intent's `perform()` calls `IntentNavigationStore.shared
//      .request(.wishlist)`.
//   2. The root view subscribes to `pendingDestination` via a
//      `@StateObject` / `.onChange` and switches its selected tab /
//      sidebar menu when a destination appears.
//   3. The view calls `consume()` (or sets `pendingDestination =
//      nil`) once it has navigated, so a second invocation of the
//      same intent re-fires.
//
//  The store is a singleton because AppIntent runs outside SwiftUI
//  view scope. We can't pass an EnvironmentObject in, so the
//  AppIntent and the view both reach for `.shared`.

import Foundation
import Combine

final class IntentNavigationStore: ObservableObject {
    static let shared = IntentNavigationStore()

    /// Where an App Intent is asking the app to navigate. Each
    /// case maps to one of the iOS tabs or the macOS sidebar menus.
    enum Destination: Equatable {
        case popularMovies
        case discover
        case fanClub
        case wishlist
    }

    @Published var pendingDestination: Destination?

    private init() {}

    /// Posts a destination request from any thread. Hopped to
    /// main so SwiftUI's `@Published` observation fires on the
    /// main actor. Safe to call from
    /// `AppIntent.perform()` which runs on a background queue.
    func request(_ destination: Destination) {
        if Thread.isMainThread {
            pendingDestination = destination
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.pendingDestination = destination
            }
        }
    }

    /// Reads and clears the pending destination. Views call this
    /// after acting on a request so the intent can be invoked
    /// again later with the same destination.
    @discardableResult
    func consume() -> Destination? {
        let destination = pendingDestination
        pendingDestination = nil
        return destination
    }
}

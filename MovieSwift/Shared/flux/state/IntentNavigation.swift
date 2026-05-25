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
import Observation

@Observable
final class IntentNavigationStore {
    static let shared = IntentNavigationStore()

    /// Where an App Intent is asking the app to navigate. Each
    /// case maps to one of the iOS tabs or the macOS sidebar menus.
    enum Destination: Equatable {
        case popularMovies
        case discover
        case fanClub
        case wishlist
    }

    var pendingDestination: Destination?

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

    /// UI-test seam: when `UI_TEST_INTENT_DESTINATION` is set in the
    /// process environment, post the matching destination to the
    /// navigation bus. Called from a `.task` modifier on the iOS
    /// TabbarView and macOS SplitView so the value lands AFTER the
    /// `.onChange` subscription is in place — otherwise the change
    /// would happen before observation starts and the view wouldn't
    /// react.
    ///
    /// This is how `MovieSwiftUITests` simulates an App Intent firing
    /// at launch (`OpenWishlistIntent`, `OpenDiscoverIntent`, etc.)
    /// without invoking the AppIntent runtime, which can't be driven
    /// from XCUITest.
    static func handleUITestEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let raw = environment["UI_TEST_INTENT_DESTINATION"] else { return }
        let destination: Destination?
        switch raw {
        case "popularMovies": destination = .popularMovies
        case "discover":      destination = .discover
        case "fanClub":       destination = .fanClub
        case "wishlist":      destination = .wishlist
        default:              destination = nil
        }
        guard let destination else { return }
        shared.request(destination)
    }
}

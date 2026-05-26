import Foundation

class MoviesPagesListener {
    var currentPage: Int = 1 {
        didSet {
            loadPage()
        }
    }

    // Explicit (rather than synthesized) initializer: under the app
    // target's default-MainActor isolation a synthesized `init()` is
    // nonisolated, which clashes with the main-actor-isolated `init`s of
    // the `@MainActor` subclasses. Declaring it explicitly makes it
    // main-actor-isolated to match.
    init() {}

    func loadPage() {

    }
}

//  AppIntent definitions that surface MovieSwift in Siri,
//  Spotlight search, and the Shortcuts app. Each intent opens the
//  app and (where applicable) writes a destination to
//  `IntentNavigationStore.shared` for the root view to read on its
//  next layout pass.
//
//  AppShortcut registration lives in `MovieSwiftAppShortcuts.swift`
//  — the provider must be in the same target as the intents and
//  the @main App entry point so the system can discover the
//  shortcuts when it indexes the app.

import Foundation
import AppIntents

/// "Open MovieSwift" — generic launcher. Useful as the system
/// fallback shortcut and as a foundation for future parameterised
/// intents (e.g. "Open MovieSwift to Popular").
struct OpenMovieSwiftIntent: AppIntent {
    static let title: LocalizedStringResource = "Open MovieSwift"

    static let description = IntentDescription(
        "Opens MovieSwift to whatever section you were last viewing.",
        categoryName: "Navigation"
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // No specific destination — opening the app is the action.
        // The system brings the app to the foreground because of
        // openAppWhenRun.
        return .result()
    }
}

struct OpenWishlistIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Wishlist"

    static let description = IntentDescription(
        "Opens MovieSwift to your wishlist.",
        categoryName: "Navigation"
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await IntentNavigationStore.shared.request(.wishlist)
        return .result()
    }
}

struct OpenDiscoverIntent: AppIntent {
    static let title: LocalizedStringResource = "Discover Movies"

    static let description = IntentDescription(
        "Opens MovieSwift to the Discover view for swipe-through movie suggestions.",
        categoryName: "Navigation"
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await IntentNavigationStore.shared.request(.discover)
        return .result()
    }
}

struct OpenFanClubIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Fan Club"

    static let description = IntentDescription(
        "Opens MovieSwift to your Fan Club — actors and people you've added.",
        categoryName: "Navigation"
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await IntentNavigationStore.shared.request(.fanClub)
        return .result()
    }
}

struct OpenPopularMoviesIntent: AppIntent {
    static let title: LocalizedStringResource = "Browse Popular Movies"

    static let description = IntentDescription(
        "Opens MovieSwift to the Popular movies list.",
        categoryName: "Navigation"
    )

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await IntentNavigationStore.shared.request(.popularMovies)
        return .result()
    }
}

/// "Add <Movie> to Watchlist" — parameterised over a `MovieEntity` the user
/// picks (from their saved movies). Posts the action to `IntentActionStore`;
/// the app applies it through the live store on its next layout so the change
/// persists normally.
struct AddToWatchlistIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Movie to Watchlist"

    static let description = IntentDescription(
        "Adds a movie to your MovieSwift wishlist.",
        categoryName: "Lists"
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Movie")
    var movie: MovieEntity

    func perform() async throws -> some IntentResult {
        await IntentActionStore.shared.request(.addToWishlist(movie: movie.id))
        return .result()
    }
}

/// "Mark <Movie> as Seen" — parameterised companion to `AddToWatchlistIntent`.
struct MarkAsSeenIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Movie as Seen"

    static let description = IntentDescription(
        "Adds a movie to your MovieSwift seenlist.",
        categoryName: "Lists"
    )

    static let openAppWhenRun: Bool = true

    @Parameter(title: "Movie")
    var movie: MovieEntity

    func perform() async throws -> some IntentResult {
        await IntentActionStore.shared.request(.markAsSeen(movie: movie.id))
        return .result()
    }
}

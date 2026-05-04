//
//  MovieSwiftAppIntents.swift
//  MovieSwift
//
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
//

import Foundation
import AppIntents

/// "Open MovieSwift" — generic launcher. Useful as the system
/// fallback shortcut and as a foundation for future parameterised
/// intents (e.g. "Open MovieSwift to Popular").
struct OpenMovieSwiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Open MovieSwift"

    static var description = IntentDescription(
        "Opens MovieSwift to whatever section you were last viewing.",
        categoryName: "Navigation"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // No specific destination — opening the app is the action.
        // The system brings the app to the foreground because of
        // openAppWhenRun.
        return .result()
    }
}

struct OpenWishlistIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Wishlist"

    static var description = IntentDescription(
        "Opens MovieSwift to your wishlist.",
        categoryName: "Navigation"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        IntentNavigationStore.shared.request(.wishlist)
        return .result()
    }
}

struct OpenDiscoverIntent: AppIntent {
    static var title: LocalizedStringResource = "Discover Movies"

    static var description = IntentDescription(
        "Opens MovieSwift to the Discover view for swipe-through movie suggestions.",
        categoryName: "Navigation"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        IntentNavigationStore.shared.request(.discover)
        return .result()
    }
}

struct OpenFanClubIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Fan Club"

    static var description = IntentDescription(
        "Opens MovieSwift to your Fan Club — actors and people you've added.",
        categoryName: "Navigation"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        IntentNavigationStore.shared.request(.fanClub)
        return .result()
    }
}

struct OpenPopularMoviesIntent: AppIntent {
    static var title: LocalizedStringResource = "Browse Popular Movies"

    static var description = IntentDescription(
        "Opens MovieSwift to the Popular movies list.",
        categoryName: "Navigation"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        IntentNavigationStore.shared.request(.popularMovies)
        return .result()
    }
}

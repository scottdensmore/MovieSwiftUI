//  Registers the app's intents with the system so they appear in:
//   - Spotlight search ("wishlist" / "discover" / "movieswift")
//   - The Shortcuts app gallery
//   - Siri ("open my wishlist in MovieSwift")
//
//  The provider must compile into the app target alongside the
//  @main entry point. It's discovered automatically by Xcode's
//  appintentsmetadataprocessor build step (visible in the build
//  log around the app target's late phases).

import Foundation
import AppIntents

struct MovieSwiftAppShortcuts: AppShortcutsProvider {

    /// Tint applied to every shortcut row in the Shortcuts app.
    /// Matches the steam_gold accent used throughout the UI.
    static let shortcutTileColor: ShortcutTileColor = .yellow

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenMovieSwiftIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Launch \(.applicationName)",
            ],
            shortTitle: "Open MovieSwift",
            systemImageName: "film.stack"
        )
        AppShortcut(
            intent: OpenWishlistIntent(),
            phrases: [
                "Open my wishlist in \(.applicationName)",
                "Show my wishlist in \(.applicationName)",
                "Open \(.applicationName) wishlist",
            ],
            shortTitle: "Wishlist",
            systemImageName: "heart.circle"
        )
        AppShortcut(
            intent: OpenDiscoverIntent(),
            phrases: [
                "Discover movies in \(.applicationName)",
                "Open Discover in \(.applicationName)",
                "Find movies in \(.applicationName)",
            ],
            shortTitle: "Discover",
            systemImageName: "square.stack"
        )
        AppShortcut(
            intent: OpenFanClubIntent(),
            phrases: [
                "Open Fan Club in \(.applicationName)",
                "Show my Fan Club in \(.applicationName)",
            ],
            shortTitle: "Fan Club",
            systemImageName: "star.circle.fill"
        )
        AppShortcut(
            intent: OpenPopularMoviesIntent(),
            phrases: [
                "Browse popular movies in \(.applicationName)",
                "Show popular movies in \(.applicationName)",
            ],
            shortTitle: "Popular",
            systemImageName: "film.fill"
        )
        AppShortcut(
            intent: AddToWatchlistIntent(),
            phrases: [
                "Add \(\.$movie) to my watchlist in \(.applicationName)",
                "Add \(\.$movie) to my \(.applicationName) watchlist",
            ],
            shortTitle: "Add to Watchlist",
            systemImageName: "heart.circle"
        )
        AppShortcut(
            intent: MarkAsSeenIntent(),
            phrases: [
                "Mark \(\.$movie) as seen in \(.applicationName)",
                "Mark \(\.$movie) as watched in \(.applicationName)",
            ],
            shortTitle: "Mark as Seen",
            systemImageName: "eye"
        )
    }
}

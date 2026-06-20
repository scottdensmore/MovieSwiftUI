import Foundation

/// Pure helpers that back the `MovieEntity` App Intent query: which movies
/// to suggest when the user picks one in Shortcuts/Siri, and how to resolve
/// a set of ids back to movies. Kept free of the AppIntents framework so it
/// is unit-testable; the `AppEntity`/`EntityQuery` wrapper lives in the app
/// target and reads state via `AppPersistence`.
public enum MovieEntitySource {
    /// The user's saved movies (wishlist ∪ seenlist) resolved from the movie
    /// cache, deduped and ordered by id for a stable suggestion list. Ids not
    /// present in the cache are skipped (nothing to display for them).
    public static func suggested(from state: AppState, limit: Int = 20) -> [Movie] {
        let saved = state.moviesState.wishlist.union(state.moviesState.seenlist)
        return Array(saved
            .sorted()
            .compactMap { state.moviesState.movies[$0] }
            .prefix(limit))
    }

    /// Resolves the given ids to cached movies, preserving the input order
    /// and dropping any id that isn't cached.
    public static func movies(for ids: [Int], from state: AppState) -> [Movie] {
        ids.compactMap { state.moviesState.movies[$0] }
    }
}

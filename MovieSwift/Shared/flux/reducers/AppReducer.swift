import Foundation
import SwiftUIFlux
import MovieSwiftFluxCore

enum AppActions {
    struct ClearCachedData: Action { }

    /// Merges the provided import envelope into the current state.
    /// See `AppDataImport.merge(envelope:into:)` for the merge rules.
    struct ImportAppData: Action {
        let envelope: AppDataExportEnvelope
    }
}

// `nonisolated`: pure state transformations invoked synchronously during
// reducer dispatch (and from the background archive queue). They must not
// inherit the app target's default main-actor isolation.
nonisolated enum AppStateCacheReset {
    static func persistentSnapshot(from state: AppState) -> AppState {
        var snapshot = AppState()
        let preservedMovieIds = preservedMovieIds(from: state)

        snapshot.moviesState.movies = state.moviesState.movies.filter { preservedMovieIds.contains($0.key) }
        snapshot.moviesState.wishlist = state.moviesState.wishlist
        snapshot.moviesState.seenlist = state.moviesState.seenlist
        snapshot.moviesState.moviesUserMeta = state.moviesState.moviesUserMeta.filter {
            preservedMovieIds.contains($0.key)
        }
        snapshot.moviesState.savedDiscoverFilters = state.moviesState.savedDiscoverFilters
        snapshot.moviesState.discoverFilter = state.moviesState.discoverFilter
        snapshot.moviesState.customLists = state.moviesState.customLists

        snapshot.peoplesState.peoples = state.peoplesState.peoples.filter {
            state.peoplesState.fanClub.contains($0.key)
        }
        snapshot.peoplesState.fanClub = state.peoplesState.fanClub

        return snapshot
    }

    private static func preservedMovieIds(from state: AppState) -> Set<Int> {
        var ids = state.moviesState.wishlist
        ids.formUnion(state.moviesState.seenlist)

        for list in state.moviesState.customLists.values {
            ids.formUnion(list.movies)
            if let cover = list.cover {
                ids.insert(cover)
            }
        }

        return ids
    }
}

/// App-shell wrapper around `MovieSwiftFluxCore.appStateReducer` that adds two
/// app-only actions:
///   - `AppActions.ClearCachedData`: drops every cached TMDB movie/person except
///     ones the user has saved (wishlist, seenlist, custom lists, fan club).
///   - `AppActions.ImportAppData`: merges a previously-exported state envelope.
/// Both depend on app-target types (`AppDataImport`, `AppDataExportEnvelope`)
/// that aren't available inside the package.
// `nonisolated`: this is the SwiftUIFlux store's reducer, a pure
// (State, Action) -> State function. It must stay off the main actor so it
// satisfies the nonisolated `Reducer` type the Store initializer expects.
nonisolated func appReducerWithImports(state: AppState, action: Action) -> AppState {
    if action is AppActions.ClearCachedData {
        return AppStateCacheReset.persistentSnapshot(from: state)
    }
    if let importAction = action as? AppActions.ImportAppData {
        return AppDataImport.merge(envelope: importAction.envelope, into: state)
    }
    return appStateReducer(state: state, action: action)
}

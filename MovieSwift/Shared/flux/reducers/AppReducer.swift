import Foundation
import SwiftUIFlux

enum AppActions {
    struct ClearCachedData: Action { }

    /// Merges the provided import envelope into the current state.
    /// See `AppDataImport.merge(envelope:into:)` for the merge rules.
    struct ImportAppData: Action {
        let envelope: AppDataExportEnvelope
    }
}

enum AppStateCacheReset {
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

func appStateReducer(state: AppState, action: Action) -> AppState {
    if action is AppActions.ClearCachedData {
        return AppStateCacheReset.persistentSnapshot(from: state)
    }
    if let importAction = action as? AppActions.ImportAppData {
        return AppDataImport.merge(envelope: importAction.envelope, into: state)
    }

    var state = state
    state.moviesState = moviesStateReducer(state: state.moviesState, action: action)
    state.peoplesState = peoplesStateReducer(state: state.peoplesState, action: action)
    return state
}

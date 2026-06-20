import Foundation
import Backend
import MovieSwiftFluxCore

enum SettingsFormRefreshPolicy {
    static func shouldRefreshMovieMenus(previousRegion: String, selectedRegion: String) -> Bool {
        previousRegion != selectedRegion
    }

    static func menusToRefresh(previousRegion: String, selectedRegion: String) -> [MoviesMenu] {
        guard shouldRefreshMovieMenus(previousRegion: previousRegion,
                                      selectedRegion: selectedRegion) else {
            return []
        }

        return MoviesMenu.allCases
    }
}

enum SettingsFormDebugState {
    static func moviesCount(from movies: [Int: Movie]) -> Int {
        movies.count
    }
}

enum SettingsFormState {
    static func moviesCount(in state: AppState) -> Int {
        SettingsFormDebugState.moviesCount(from: state.moviesState.movies)
    }
}

enum SettingsFormCacheResetPolicy {
    static func clearCachedData(state: AppState,
                                dispatch: @escaping DispatchFunction,
                                clearImageCache: () -> Void = {
                                    ImageLoaderCache.shared.clear()
                                },
                                clearURLCache: () -> Void = {
                                    URLCache.shared.removeAllCachedResponses()
                                },
                                archiveState: (AppState) -> Void = { state in
                                    AppPersistence.archiveNow(state: state)
                                }) {
        let cachedState = AppStateCacheReset.persistentSnapshot(from: state)
        clearImageCache()
        clearURLCache()
        dispatch(AppActions.ClearCachedData())
        archiveState(cachedState)
    }
}

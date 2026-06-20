import Testing
import Foundation
import MovieSwiftFluxCore
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `@MainActor`: exercises main-actor app code (state query helpers,
// reducers via the store, presentation builders), so the suite runs on
// the main actor.
@Suite @MainActor
struct SettingsGenresActionSheetTests {
    private func makeMovie(id: Int,
                           keywords: Movie.Keywords? = nil,
                           images: Movie.MovieImages? = nil) -> Movie {
        Movie(id: id,
              originalTitle: "Movie \(id)",
              title: "Movie \(id)",
              overview: "Overview",
              posterPath: nil,
              backdropPath: nil,
              popularity: 0,
              voteAverage: 0,
              voteCount: 0,
              releaseDateString: nil,
              genres: nil,
              runtime: nil,
              status: nil,
              video: false,
              keywords: keywords,
              images: images,
              productionCountries: nil,
              character: nil,
              department: nil)
    }

    private func makePerson(id: Int, character: String? = nil, department: String? = nil) -> People {
        People(id: id,
               name: "Person \(id)",
               character: character,
               department: department,
               profilePath: nil,
               knownForDepartment: nil,
               knownFor: nil,
               alsoKnownAs: nil,
               birthDay: nil,
               deathDay: nil,
               placeOfBirth: nil,
               biography: nil,
               popularity: nil,
               images: nil)
    }

    @Test func genresListFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(GenresListFetchPolicy.shouldFetchGenres(isRunningUISmokeTests: false))
    }

    @Test func genresListFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(GenresListFetchPolicy.shouldFetchGenres(isRunningUISmokeTests: true)))
    }

    @Test func genresListFetchPolicyReturnsFetchGenresActionOutsideUISmokeTests() {
        let actions = GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: false)

        #expect(actions.count == 1)
        #expect(actions.first is MoviesActions.FetchGenres)
    }

    @Test func genresListFetchPolicyReturnsNoActionsDuringUISmokeTests() {
        #expect(GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: true).isEmpty)
    }

    @Test func genresListStateReturnsGenresFromState() {
        var state = AppState()
        state.moviesState.genres = [Genre(id: 1, name: "Comedy"),
                                    Genre(id: 2, name: "Drama"), ]

        #expect(GenresListState.genres(from: state).map(\.id) == [1, 2])
    }

    @Test func settingsFormRefreshPolicyRefreshesWhenRegionChanges() {
        #expect(SettingsFormRefreshPolicy.shouldRefreshMovieMenus(previousRegion: "US",
                                                                       selectedRegion: "FR"))
    }

    @Test func settingsFormRefreshPolicySkipsWhenRegionMatches() {
        #expect(!(SettingsFormRefreshPolicy.shouldRefreshMovieMenus(previousRegion: "US",
                                                                        selectedRegion: "US")))
    }

    @Test func settingsFormRefreshPolicyReturnsAllMenusWhenRegionChanges() {
        #expect(SettingsFormRefreshPolicy.menusToRefresh(previousRegion: "US",
                                                                selectedRegion: "FR") ==
                       MoviesMenu.allCases)
    }

    @Test func settingsFormRefreshPolicyReturnsNoMenusWhenRegionMatches() {
        #expect(SettingsFormRefreshPolicy.menusToRefresh(previousRegion: "US",
                                                              selectedRegion: "US").isEmpty)
    }

    @Test func settingsFormCacheResetPolicyClearsCachesDispatchesResetAndArchivesTrimmedState() {
        var state = AppState()
        state.moviesState.movies[11] = makeMovie(id: 11)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist = [11]
        state.moviesState.moviesList[.popular] = [99]
        state.peoplesState.fanClub = [7]
        state.peoplesState.peoples[7] = makePerson(id: 7)
        state.peoplesState.peoples[8] = makePerson(id: 8)

        var clearedImageCache = false
        var clearedURLCache = false
        var didDispatchClearCachedData = false
        var archivedState: AppState?

        SettingsFormCacheResetPolicy.clearCachedData(
            state: state,
            dispatch: { action in
                didDispatchClearCachedData = action is AppActions.ClearCachedData
            },
            clearImageCache: {
                clearedImageCache = true
            },
            clearURLCache: {
                clearedURLCache = true
            },
            archiveState: { state in
                archivedState = state
            }
        )

        #expect(clearedImageCache)
        #expect(clearedURLCache)
        #expect(didDispatchClearCachedData)
        #expect(archivedState?.moviesState.wishlist == Set([11]))
        #expect(archivedState?.moviesState.movies[11] != nil)
        #expect(archivedState?.moviesState.movies[99] == nil)
        #expect(archivedState?.peoplesState.fanClub == Set([7]))
        #expect(archivedState?.peoplesState.peoples[7] != nil)
        #expect(archivedState?.peoplesState.peoples[8] == nil)
    }

    @Test func settingsFormDebugStateCountsMovies() {
        #expect(SettingsFormDebugState.moviesCount(from: [0: sampleMovie, 1: sampleMovie]) == 2)
    }

    @Test func settingsFormStateCountsMoviesFromAppState() {
        var state = AppState()
        state.moviesState.movies = [0: sampleMovie, 1: sampleMovie]

        #expect(SettingsFormState.moviesCount(in: state) == 2)
    }

#if !os(macOS)

    @Test func actionSheetMovieListActionAddsMovieToWishlistWhenMissing() {
        #expect(ActionSheetMovieListAction.wishlist(movie: 12, isInWishlist: false) ==
                       .addToWishlist(movie: 12))
    }

    @Test func actionSheetMovieListActionRemovesMovieFromWishlistWhenPresent() {
        #expect(ActionSheetMovieListAction.wishlist(movie: 12, isInWishlist: true) ==
                       .removeFromWishlist(movie: 12))
    }

    @Test func actionSheetMovieListActionAddsMovieToSeenlistWhenMissing() {
        #expect(ActionSheetMovieListAction.seenlist(movie: 12, isInSeenlist: false) ==
                       .addToSeenlist(movie: 12))
    }

    @Test func actionSheetMovieListActionRemovesMovieFromSeenlistWhenPresent() {
        #expect(ActionSheetMovieListAction.seenlist(movie: 12, isInSeenlist: true) ==
                       .removeFromSeenlist(movie: 12))
    }

    @Test func actionSheetMovieListActionAddsMovieToCustomListWhenMissing() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        #expect(ActionSheetMovieListAction.customList(list: list, movie: 12) ==
                       .addToCustomList(list: 7, movie: 12))
    }

    @Test func actionSheetMovieListActionRemovesMovieFromCustomListWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [12])

        #expect(ActionSheetMovieListAction.customList(list: list, movie: 12) ==
                       .removeFromCustomList(list: 7, movie: 12))
    }

#endif
}

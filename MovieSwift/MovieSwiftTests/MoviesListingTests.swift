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
struct MoviesListingTests {
    @Test func moviesStateReducerMarksMovieDetailSlicesLoaded() {
        let movie = Movie(id: 9,
                          original_title: "Movie",
                          title: "Movie",
                          overview: "",
                          poster_path: nil,
                          backdrop_path: nil,
                          popularity: 0,
                          vote_average: 0,
                          vote_count: 0,
                          release_date: nil,
                          genres: nil,
                          runtime: nil,
                          status: nil,
                          video: false,
                          character: nil,
                          department: nil)

        var state = moviesStateReducer(state: MoviesState(),
                                       action: MoviesActions.SetDetail(movie: 9, response: movie))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetRecommended(movie: 9,
                                                                        response: PaginatedResponse(page: 1,
                                                                                                    total_results: 0,
                                                                                                    total_pages: 1,
                                                                                                    results: [])))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetSimilar(movie: 9,
                                                                    response: PaginatedResponse(page: 1,
                                                                                                total_results: 0,
                                                                                                total_pages: 1,
                                                                                                results: [])))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetVideos(movie: 9,
                                                                   response: PaginatedResponse(page: 1,
                                                                                               total_results: 0,
                                                                                               total_pages: 1,
                                                                                               results: [])))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetMovieReviews(movie: 9,
                                                                         response: PaginatedResponse(page: 1,
                                                                                                     total_results: 0,
                                                                                                     total_pages: 1,
                                                                                                     results: [])))

        #expect(state.detailed.contains(9))
        #expect(state.recommendedLoaded.contains(9))
        #expect(state.similarLoaded.contains(9))
        #expect(state.videosLoaded.contains(9))
        #expect(state.reviewsLoaded.contains(9))
    }

    @Test func moviesStateCodableRoundTripPreservesLoadedMovieDetailFlags() throws {
        var state = MoviesState()
        state.detailed.insert(1)
        state.recommendedLoaded.insert(2)
        state.similarLoaded.insert(3)
        state.videosLoaded.insert(4)
        state.reviewsLoaded.insert(5)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MoviesState.self, from: data)

        #expect(decoded.detailed.contains(1))
        #expect(decoded.recommendedLoaded.contains(2))
        #expect(decoded.similarLoaded.contains(3))
        #expect(decoded.videosLoaded.contains(4))
        #expect(decoded.reviewsLoaded.contains(5))
    }

    @Test func uISmokeInitialStateSeedsExpectedNavigationData() {
        let state = AppStoreFactory.makeInitialState(for: .uiSmokeTests)

        #expect(state.moviesState.movies[0]?.id == 0)
        #expect(state.moviesState.customLists[0]?.name == "TestName")
        #expect(state.peoplesState.crews[1]?[0] == "Director 1")
    }

    @Test func previewInitialStateSeedsExpectedNavigationData() {
        let state = AppStoreFactory.makeInitialState(for: .preview)

        #expect(state.moviesState.movies[0]?.id == 0)
        #expect(state.peoplesState.casts[0]?[0] == "Character 1")
    }

    @Test func moviesMenuListPageListenerDispatchesInjectedPageLoad() {
        var loadedMenu: MoviesMenu?
        var loadedPage: Int?
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { true },
                                                  dispatchPage: { menu, page in
            loadedMenu = menu
            loadedPage = page
        })

        listener.currentPage = 3

        #expect(loadedMenu == .popular)
        #expect(loadedPage == 3)
    }

    @Test func moviesMenuListPageListenerSkipsDispatchWhenSuppressed() {
        var dispatchCount = 0
        let listener = MoviesMenuListPageListener(menu: .trending,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { false },
                                                  dispatchPage: { _, _ in
            dispatchCount += 1
        })

        listener.loadPage()

        #expect(dispatchCount == 0)
    }

    @Test func moviesMenuListPageListenerSkipsDispatchWithoutLoadPolicy() {
        var dispatchCount = 0
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  dispatchPage: { _, _ in
            dispatchCount += 1
        })

        listener.loadPage()

        #expect(dispatchCount == 0)
    }

    @Test func moviesMenuListPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { true })

        listener.loadPage()

        #expect(true)
    }

    @Test func moviesSelectedMenuStoreSynchronizesInitialMenuToListener() {
        let listener = MoviesMenuListPageListener(menu: .trending, loadOnInit: false)
        let store = MoviesSelectedMenuStore(selectedMenu: .popular, pageListener: listener)

        #expect(store.menu == .popular)
        #expect(listener.menu == .popular)
    }

    @Test func moviesSelectedMenuStoreUpdatesListenerWhenMenuChanges() {
        let listener = MoviesMenuListPageListener(menu: .popular, loadOnInit: false)
        let store = MoviesSelectedMenuStore(selectedMenu: .popular, pageListener: listener)

        store.menu = .topRated

        #expect(listener.menu == .topRated)
    }

    @Test func keywordPageListenerDispatchesInjectedPageLoad() {
        var loadedKeyword: Int?
        var loadedPage: Int?
        let listener = KeywordPageListener(dispatchPage: { keyword, page in
            loadedKeyword = keyword
            loadedPage = page
        })
        listener.keyword = 17
        listener.currentPage = 2

        #expect(loadedKeyword == 17)
        #expect(loadedPage == 2)
    }

    @Test func keywordPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = KeywordPageListener()
        listener.keyword = 17

        listener.loadPage()

        #expect(true)
    }

    @Test func moviesSearchPageListenerDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let listener = MoviesSearchPageListener(dispatchSearches: { text, page in
            loadedText = text
            loadedPage = page
        })
        listener.text = "matrix"
        listener.currentPage = 2

        #expect(loadedText == "matrix")
        #expect(loadedPage == 2)
    }

    @Test func moviesSearchPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = MoviesSearchPageListener()
        listener.text = "matrix"

        listener.loadPage()

        #expect(true)
    }

    @Test func moviesSearchTextWrapperBindsInjectedSearchDispatch() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = MoviesSearchTextWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")
        wrapper.searchPageListener.loadPage()

        #expect(loadedText == "matrix")
        #expect(loadedPage == 1)
    }

    @Test func moviesListSearchStateReturnsSearchResultsAndRecentSearches() {
        var state = AppState()
        let keywords = (1...6).map { Keyword(id: $0, name: "Keyword \($0)") }
        state.moviesState.search["matrix"] = [1, 2, 3]
        state.moviesState.searchKeywords["matrix"] = keywords
        state.peoplesState.search["matrix"] = [9, 10]
        state.moviesState.recentSearches = ["matrix", "alien"]

        #expect(MoviesListSearchState.searchedMovies(query: "matrix", from: state) == [1, 2, 3])
        #expect(MoviesListSearchState.searchedKeywords(query: "matrix", from: state)?.map(\.id) == [1, 2, 3, 4, 5])
        #expect(MoviesListSearchState.searchedPeoples(query: "matrix", from: state) == [9, 10])
        #expect(Set(MoviesListSearchState.recentSearches(from: state)) == Set(["matrix", "alien"]))
    }

    @Test func moviesListPaginationPolicyAdvancesSearchPageOnlyWithSearchResults() {
        #expect(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: true, searchedMovies: [1]))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: true, searchedMovies: [])))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: false, searchedMovies: [1])))
    }

    @Test func moviesListPaginationPolicyAdvancesListPageOnlyWhenBrowsingMovies() {
        #expect(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                      pageListenerExists: true,
                                                                      movies: [1]))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: true,
                                                                       pageListenerExists: true,
                                                                       movies: [1])))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                       pageListenerExists: false,
                                                                       movies: [1])))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                       pageListenerExists: true,
                                                                       movies: [])))
    }

    @Test func moviesHomeGridFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(MoviesHomeGridFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: false))
    }

    @Test func moviesHomeGridFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(MoviesHomeGridFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: true)))
    }

    @Test func moviesHomeGridFetchPolicyFetchesMenuPagesOutsideUISmokeTests() {
        #expect(MoviesHomeGridFetchPolicy.shouldFetchMenuPage(isRunningUISmokeTests: false))
    }

    @Test func moviesHomeGridFetchPolicySkipsGenreFetchDuringUISmokeTests() {
        #expect(!(MoviesHomeGridFetchPolicy.shouldFetchGenresOnAppear(isRunningUISmokeTests: true)))
    }

    @Test func moviesHomeGridStateReturnsMoviesAndDropsFirstGenre() {
        var state = AppState()
        state.moviesState.moviesList[.popular] = [1, 2]
        state.moviesState.genres = [Genre(id: 0, name: "Random"),
                                    Genre(id: 1, name: "Comedy"),
                                    Genre(id: 2, name: "Drama"), ]

        #expect(MoviesHomeGridState.movies(from: state)[.popular] == [1, 2])
        #expect(MoviesHomeGridState.genres(from: state).map(\.id) == [1, 2])
    }

    @Test func moviesHomeListStateReturnsMoviesForMenuWhenPresent() {
        var state = AppState()
        state.moviesState.moviesList[.popular] = [1, 2, 3]

        #expect(MoviesHomeListState.movies(for: .popular, from: state) == [1, 2, 3])
    }

    @Test func moviesHomeListStateReturnsPlaceholderMoviesWhenMissing() {
        #expect(MoviesHomeListState.movies(for: .popular, from: AppState()) == [0, 0, 0, 0])
    }

    @Test func moviesHomeStateTogglesBetweenListAndGrid() {
        #expect(MoviesHomeState.toggledMode(from: .list) == .grid)
        #expect(MoviesHomeState.toggledMode(from: .grid) == .list)
    }

    @Test func moviesHomeStateSkipsPageLoadDuringUISmokeTests() {
        #expect(!(MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: true)))
        #expect(MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: false))
    }

    @Test func moviesGenreListStateReturnsGenreMoviesWhenPresent() {
        var state = AppState()
        let genre = Genre(id: 9, name: "Adventure")
        state.moviesState.withGenre[9] = [1, 4, 7]

        #expect(MoviesGenreListState.movies(for: genre, from: state) == [1, 4, 7])
    }

    @Test func moviesGenreListStateReturnsEmptyWhenMissing() {
        let state = AppState()
        let genre = Genre(id: 9, name: "Adventure")

        #expect(MoviesGenreListState.movies(for: genre, from: state) == [])
    }

    @Test func moviesCrewListStateReturnsCrewMoviesWhenPresent() {
        var state = AppState()
        let crew = People(id: 9,
                          name: "Test Director",
                          character: nil,
                          department: "Directing",
                          profile_path: nil,
                          known_for_department: nil,
                          known_for: nil,
                          also_known_as: nil,
                          birthDay: nil,
                          deathDay: nil,
                          place_of_birth: nil,
                          biography: nil,
                          popularity: nil,
                          images: nil)
        state.moviesState.withCrew[9] = [1, 4, 7]

        #expect(MoviesCrewListState.movies(for: crew, from: state) == [1, 4, 7])
    }

    @Test func moviesCrewListStateReturnsEmptyWhenMissing() {
        let state = AppState()
        let crew = People(id: 9,
                          name: "Test Director",
                          character: nil,
                          department: "Directing",
                          profile_path: nil,
                          known_for_department: nil,
                          known_for: nil,
                          also_known_as: nil,
                          birthDay: nil,
                          deathDay: nil,
                          place_of_birth: nil,
                          biography: nil,
                          popularity: nil,
                          images: nil)

        #expect(MoviesCrewListState.movies(for: crew, from: state) == [])
    }

    @Test func outlineMoviesMenuListFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: false))
    }

    @Test func outlineMoviesMenuListFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: true)))
    }

    @Test func moviesSortAPIMapping() {
        #expect(MoviesSort.byReleaseDate.sortByAPI() == "release_date.desc")
        #expect(MoviesSort.byAddedDate.sortByAPI() == "primary_release_date.desc")
        #expect(MoviesSort.byScore.sortByAPI() == "vote_average.desc")
        #expect(MoviesSort.byPopularity.sortByAPI() == "popularity.desc")
    }

#if !os(macOS)

    @Test func moviesHomeStateUsesInlineTitleInListMode() {
        #expect(MoviesHomeState.navigationBarTitleDisplayMode(for: .list) == .inline)
        #expect(MoviesHomeState.navigationBarTitleDisplayMode(for: .grid) == .automatic)
    }

#endif
}

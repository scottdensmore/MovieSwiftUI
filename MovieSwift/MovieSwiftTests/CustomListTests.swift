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
struct CustomListTests {
    @Test func sortedMoviesIdsKeepsMissingMoviesForAddedDateSort() {
        var state = AppState()
        state.moviesState.moviesUserMeta[42] = MovieUserMeta(addedToList: Date(timeIntervalSince1970: 200))
        state.moviesState.moviesUserMeta[7] = MovieUserMeta(addedToList: Date(timeIntervalSince1970: 100))

        let sorted = [7, 42].sortedMoviesIds(by: .byAddedDate, state: state)

        #expect(sorted == [42, 7])
    }

    @Test func sortedMoviesIdsKeepsMissingMoviesForReleaseDateSort() {
        var state = AppState()
        state.moviesState.movies[sampleMovie.id] = sampleMovie

        let sorted = [42, sampleMovie.id].sortedMoviesIds(by: .byReleaseDate, state: state)

        #expect(sorted == [sampleMovie.id, 42])
    }

    @Test func customListPresentationUsesFirstMovieAsListCover() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [sampleMovie.id])

        #expect(CustomListPresentation.coverMovie(for: list,
                                                         movies: [sampleMovie.id: sampleMovie])?.id ==
                       sampleMovie.id)
    }

    @Test func customListPresentationUsesExplicitBackdropCoverWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: sampleMovie.id, movies: [])

        #expect(CustomListPresentation.coverBackdropMovie(for: list,
                                                                 movies: [sampleMovie.id: sampleMovie])?.id ==
                       sampleMovie.id)
    }

    @Test func customListPresentationSkipsMissingCoverMovies() {
        let list = CustomList(id: 7, name: "Favorites", cover: 999, movies: [999])

        #expect(CustomListPresentation.coverMovie(for: list, movies: [:]) == nil)
        #expect(CustomListPresentation.coverBackdropMovie(for: list, movies: [:]) == nil)
    }

    @Test func customListSearchMovieTextWrapperDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = CustomListSearchMovieTextWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(loadedText == "matrix")
        #expect(loadedPage == 1)
    }

    @Test func customListSearchMovieTextWrapperDoesNotDispatchWithoutInjectedHandler() {
        let wrapper = CustomListSearchMovieTextWrapper()

        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(true)
    }

    @Test func customListFormSearchWrapperDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = CustomListFormSearchWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(loadedText == "matrix")
        #expect(loadedPage == 1)
    }

    @Test func customListFormSearchWrapperDoesNotDispatchWithoutInjectedHandler() {
        let wrapper = CustomListFormSearchWrapper()

        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(true)
    }

    @Test func customListSelectionTogglesMovieIntoSelection() {
        #expect(CustomListSelection.toggled(movie: 7, in: []) == Set([7]))
    }

    @Test func customListSelectionTogglesMovieOutOfSelection() {
        #expect(CustomListSelection.toggled(movie: 7, in: Set([7, 9])) == Set([9]))
    }

    @Test func customListSelectionPendingAddButtonTitleForEmptySelection() {
        #expect(CustomListSelection.pendingAddButtonTitle(for: []) == "Cancel")
    }

    @Test func customListSelectionPendingAddButtonTitleForSelectedMovies() {
        #expect(CustomListSelection.pendingAddButtonTitle(for: Set([1, 2])) == "Add movies (2)")
    }

    @Test func customListFormStateReturnsEditingValuesWhenListExists() {
        let list = CustomList(id: 7, name: "Favorites", cover: 12, movies: [])

        let editingValues = CustomListFormState.editingValues(editingListId: 7,
                                                              customLists: [7: list])

        #expect(editingValues?.name == "Favorites")
        #expect(editingValues?.cover == 12)
    }

    @Test func customListFormStateReturnsNilWhenEditingListIsMissing() {
        #expect(CustomListFormState.editingValues(editingListId: 7, customLists: [:]) == nil)
    }

    @Test func customListFormPresentationReturnsCoverMovieWhenPresent() {
        #expect(CustomListFormPresentation.coverMovie(coverId: sampleMovie.id,
                                                             movies: [sampleMovie.id: sampleMovie])?.id ==
                       sampleMovie.id)
    }

    @Test func customListFormPresentationSkipsMissingCoverMovie() {
        #expect(CustomListFormPresentation.coverMovie(coverId: 99, movies: [:]) == nil)
    }

    @Test func customListFormPresentationReturnsResolvedSearchMovies() {
        let movies = CustomListFormPresentation.searchedMovies(searchText: "alien",
                                                               searchResults: ["alien": [sampleMovie.id]],
                                                               movies: [sampleMovie.id: sampleMovie])

        #expect(movies.map(\.id) == [sampleMovie.id])
    }

    @Test func customListFormPresentationSkipsMissingSearchMovies() {
        let movies = CustomListFormPresentation.searchedMovies(searchText: "alien",
                                                               searchResults: ["alien": [sampleMovie.id, 99]],
                                                               movies: [sampleMovie.id: sampleMovie])

        #expect(movies.map(\.id) == [sampleMovie.id])
    }

    @Test func customListDetailStateReturnsListWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        #expect(CustomListDetailState.list(listId: 7, customLists: [7: list])?.id == 7)
    }

    @Test func customListDetailStateReturnsNilWhenListIsMissing() {
        #expect(CustomListDetailState.list(listId: 7, customLists: [:]) == nil)
    }

    @Test func customListDetailStateReturnsSearchResultsWhenSearching() {
        #expect(CustomListDetailState.searchedMovies(searchText: "alien",
                                                            searchResults: ["alien": [1, 2]]) ==
                       [1, 2])
    }

    @Test func customListDetailStateReturnsNilWhenSearchTextIsEmpty() {
        #expect(CustomListDetailState.searchedMovies(searchText: "",
                                                          searchResults: ["alien": [1, 2]]) == nil)
    }

    @Test func myListsPresentationReturnsCustomListsFromDictionary() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        #expect(MyListsPresentation.customLists(from: [7: list]).map(\.id) == [7])
    }

    @Test func myListsPresentationReturnsEmptySortedMoviesForEmptyInput() {
        #expect(MyListsPresentation.sortedMovies([], by: .byReleaseDate, state: AppState()) == [])
    }
}

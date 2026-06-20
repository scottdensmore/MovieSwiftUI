import Testing
@testable import MovieSwiftFluxCore

@Suite struct MovieEntitySourceTests {
    private func makeMovie(id: Int, title: String) -> Movie {
        Movie(id: id, originalTitle: title, title: title, overview: "",
              popularity: 0, voteAverage: 0, voteCount: 0, video: false)
    }

    private func makeState() -> AppState {
        var state = AppState()
        state.moviesState.movies = [
            1: makeMovie(id: 1, title: "Alpha"),
            2: makeMovie(id: 2, title: "Beta"),
            3: makeMovie(id: 3, title: "Gamma"),
            9: makeMovie(id: 9, title: "Cached but unlisted"), // not in any list → never suggested
        ]
        state.moviesState.wishlist = [2, 1]
        state.moviesState.seenlist = [3, 1] // 1 also in wishlist → deduped
        return state
    }

    @Test func suggestedReturnsSavedMoviesDedupedAndSortedById() {
        let suggested = MovieEntitySource.suggested(from: makeState())

        // wishlist(1,2) ∪ seenlist(1,3) = {1,2,3}, sorted by id, resolved
        // from the cache.
        #expect(suggested.map(\.id) == [1, 2, 3])
        #expect(suggested.map(\.title) == ["Alpha", "Beta", "Gamma"])
    }

    @Test func suggestedSkipsSavedIdsMissingFromTheMovieCache() {
        var state = makeState()
        state.moviesState.wishlist = [2, 404] // 404 isn't in `movies`

        let suggested = MovieEntitySource.suggested(from: state)

        #expect(suggested.map(\.id) == [1, 2, 3]) // 404 dropped, seenlist still contributes 1,3
    }

    @Test func suggestedRespectsTheLimit() {
        let suggested = MovieEntitySource.suggested(from: makeState(), limit: 2)

        #expect(suggested.map(\.id) == [1, 2])
    }

    @Test func moviesForIdsResolvesFromCacheAndDropsUnknowns() {
        let resolved = MovieEntitySource.movies(for: [3, 999, 1], from: makeState())

        #expect(resolved.map(\.id) == [3, 1]) // order preserved, 999 dropped
    }
}

import Testing
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

@Suite struct MovieSpotlightIndexerTests {

    private func makeMovie(id: Int) -> Movie {
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
              keywords: nil,
              images: nil,
              productionCountries: nil,
              character: nil,
              department: nil)
    }

    // MARK: - Identifier round-trip

    @Test func identifierRoundTrip() {
        for id in [1, 42, 999, 12345] {
            let identifier = MovieSpotlightIndexer.identifier(forMovieId: id)
            #expect(MovieSpotlightIndexer.movieId(fromIdentifier: identifier) == id)
        }
    }

    @Test func movieIdFromIdentifierReturnsNilForUnknownPrefix() {
        #expect(MovieSpotlightIndexer.movieId(fromIdentifier: "com.other.app.42") == nil)
        #expect(MovieSpotlightIndexer.movieId(fromIdentifier: "com.movieswift.person.42") == nil)
        #expect(MovieSpotlightIndexer.movieId(fromIdentifier: "42") == nil)
    }

    @Test func movieIdFromIdentifierReturnsNilForNonNumericSuffix() {
        #expect(MovieSpotlightIndexer.movieId(fromIdentifier: "com.movieswift.movie.abc") == nil)
        #expect(MovieSpotlightIndexer.movieId(fromIdentifier: "com.movieswift.movie.") == nil)
    }

    // MARK: - indexableMovieIds

    @Test func indexableMovieIdsUnionsWishlistSeenlistAndCustomLists() {
        var state = AppState()
        state.moviesState.wishlist.insert(1)
        state.moviesState.wishlist.insert(2)
        state.moviesState.seenlist.insert(3)
        state.moviesState.seenlist.insert(2)  // overlap with wishlist
        state.moviesState.customLists[10] = CustomList(id: 10,
                                                       name: "Favs",
                                                       cover: nil,
                                                       movies: [4, 5])
        state.moviesState.customLists[20] = CustomList(id: 20,
                                                       name: "Re-watch",
                                                       cover: nil,
                                                       movies: [3, 6])  // 3 also in seenlist

        let ids = MovieSpotlightIndexer.indexableMovieIds(in: state)

        #expect(ids == [1, 2, 3, 4, 5, 6],
                "Indexable set should union all three sources, deduplicated")
    }

    @Test func indexableMovieIdsExcludesUnsavedCachedMovies() {
        // Movies in the state's cache that aren't in any list
        // (e.g. results of a TMDB Popular query) should NOT be
        // indexed — we don't want every TMDB title appearing
        // in Spotlight, only items the user explicitly saved.
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist.insert(1)
        // 2 and 99 are cached but not in any list.

        let ids = MovieSpotlightIndexer.indexableMovieIds(in: state)
        #expect(ids == [1])
    }

    @Test func indexableMovieIdsIsEmptyForFreshState() {
        let state = AppState()
        #expect(MovieSpotlightIndexer.indexableMovieIds(in: state).isEmpty,
                "A fresh AppState shouldn't index anything except the placeholder data")
    }

    @Test func indexableMovieIdsIncludesEmptyCustomLists() {
        // An empty custom list contributes nothing to the
        // indexable set — confirmed by union behaviour rather
        // than special-casing.
        var state = AppState()
        state.moviesState.customLists[1] = CustomList(id: 1,
                                                      name: "Empty",
                                                      cover: nil,
                                                      movies: [])
        #expect(MovieSpotlightIndexer.indexableMovieIds(in: state).isEmpty)
    }
}

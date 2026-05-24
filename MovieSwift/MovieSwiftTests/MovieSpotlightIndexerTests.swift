import XCTest
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class MovieSpotlightIndexerTests: XCTestCase {

    private func makeMovie(id: Int) -> Movie {
        Movie(id: id,
              original_title: "Movie \(id)",
              title: "Movie \(id)",
              overview: "Overview",
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
              keywords: nil,
              images: nil,
              production_countries: nil,
              character: nil,
              department: nil)
    }

    // MARK: - Identifier round-trip

    func testIdentifierRoundTrip() {
        for id in [1, 42, 999, 12345] {
            let identifier = MovieSpotlightIndexer.identifier(forMovieId: id)
            XCTAssertEqual(MovieSpotlightIndexer.movieId(fromIdentifier: identifier), id)
        }
    }

    func testMovieIdFromIdentifierReturnsNilForUnknownPrefix() {
        XCTAssertNil(MovieSpotlightIndexer.movieId(fromIdentifier: "com.other.app.42"))
        XCTAssertNil(MovieSpotlightIndexer.movieId(fromIdentifier: "com.movieswift.person.42"))
        XCTAssertNil(MovieSpotlightIndexer.movieId(fromIdentifier: "42"))
    }

    func testMovieIdFromIdentifierReturnsNilForNonNumericSuffix() {
        XCTAssertNil(MovieSpotlightIndexer.movieId(fromIdentifier: "com.movieswift.movie.abc"))
        XCTAssertNil(MovieSpotlightIndexer.movieId(fromIdentifier: "com.movieswift.movie."))
    }

    // MARK: - indexableMovieIds

    func testIndexableMovieIdsUnionsWishlistSeenlistAndCustomLists() {
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

        XCTAssertEqual(ids, [1, 2, 3, 4, 5, 6],
                       "Indexable set should union all three sources, deduplicated")
    }

    func testIndexableMovieIdsExcludesUnsavedCachedMovies() {
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
        XCTAssertEqual(ids, [1])
    }

    func testIndexableMovieIdsIsEmptyForFreshState() {
        let state = AppState()
        XCTAssertTrue(MovieSpotlightIndexer.indexableMovieIds(in: state).isEmpty,
                      "A fresh AppState shouldn't index anything except the placeholder data")
    }

    func testIndexableMovieIdsIncludesEmptyCustomLists() {
        // An empty custom list contributes nothing to the
        // indexable set — confirmed by union behaviour rather
        // than special-casing.
        var state = AppState()
        state.moviesState.customLists[1] = CustomList(id: 1,
                                                      name: "Empty",
                                                      cover: nil,
                                                      movies: [])
        XCTAssertTrue(MovieSpotlightIndexer.indexableMovieIds(in: state).isEmpty)
    }
}

import XCTest
@testable import MovieSwift

final class AppPersistenceTests: XCTestCase {

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

    private func makePeople(id: Int) -> People {
        People(id: id,
               name: "Person \(id)",
               character: nil,
               department: nil,
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
    }

    // MARK: - AppStateCacheReset

    func testPersistentSnapshotPreservesWishlistSeenlistAndCustomLists() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.movies[3] = makeMovie(id: 3)
        state.moviesState.wishlist.insert(1)
        state.moviesState.seenlist.insert(2)
        state.moviesState.customLists[10] = CustomList(id: 10, name: "Favs", cover: 3, movies: [3])

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        XCTAssertTrue(snapshot.moviesState.wishlist.contains(1))
        XCTAssertTrue(snapshot.moviesState.seenlist.contains(2))
        XCTAssertEqual(snapshot.moviesState.customLists[10]?.name, "Favs")
        XCTAssertNotNil(snapshot.moviesState.movies[1])
        XCTAssertNotNil(snapshot.moviesState.movies[2])
        XCTAssertNotNil(snapshot.moviesState.movies[3])
    }

    func testPersistentSnapshotStripsTransientCaches() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist.insert(1)
        state.moviesState.moviesList[.popular] = [1, 99]
        state.moviesState.search["test"] = [99]
        state.moviesState.recommended[1] = [99]

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        XCTAssertNotNil(snapshot.moviesState.movies[1])
        XCTAssertNil(snapshot.moviesState.movies[99])
        XCTAssertTrue(snapshot.moviesState.moviesList.isEmpty)
        XCTAssertTrue(snapshot.moviesState.search.isEmpty)
        XCTAssertTrue(snapshot.moviesState.recommended.isEmpty)
    }

    func testPersistentSnapshotPreservesFanClubPeople() {
        var state = AppState()
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.peoples[6] = makePeople(id: 6)
        state.peoplesState.fanClub.insert(5)

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        XCTAssertNotNil(snapshot.peoplesState.peoples[5])
        XCTAssertNil(snapshot.peoplesState.peoples[6])
        XCTAssertTrue(snapshot.peoplesState.fanClub.contains(5))
    }

    func testPersistentSnapshotPreservesMovieUserMeta() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist.insert(1)

        var meta1 = MovieUserMeta()
        meta1.addedToList = Date()
        state.moviesState.moviesUserMeta[1] = meta1

        var meta99 = MovieUserMeta()
        meta99.addedToList = Date()
        state.moviesState.moviesUserMeta[99] = meta99

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        XCTAssertNotNil(snapshot.moviesState.moviesUserMeta[1])
        XCTAssertNil(snapshot.moviesState.moviesUserMeta[99])
    }

    func testPersistentSnapshotPreservesDiscoverFilter() {
        var state = AppState()
        state.moviesState.discoverFilter = DiscoverFilter(
            year: 2000, startYear: nil, endYear: nil,
            sort: "popularity.desc", genre: nil, region: nil
        )
        let filter = DiscoverFilter(
            year: 2010, startYear: nil, endYear: nil,
            sort: "vote_average.desc", genre: 28, region: "US"
        )
        state.moviesState.savedDiscoverFilters = [filter]

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        XCTAssertEqual(snapshot.moviesState.discoverFilter?.year, 2000)
        XCTAssertEqual(snapshot.moviesState.savedDiscoverFilters.count, 1)
        XCTAssertEqual(snapshot.moviesState.savedDiscoverFilters.first?.genre, 28)
    }

    func testPersistentSnapshotPreservesCustomListCoverMovie() {
        var state = AppState()
        state.moviesState.movies[50] = makeMovie(id: 50)
        state.moviesState.customLists[1] = CustomList(id: 1, name: "Test", cover: 50, movies: [])

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        XCTAssertNotNil(snapshot.moviesState.movies[50])
    }
}

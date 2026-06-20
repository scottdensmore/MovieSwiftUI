import Testing
import Foundation
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

@Suite struct AppPersistenceTests {

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

    private func makePeople(id: Int) -> People {
        People(id: id,
               name: "Person \(id)",
               character: nil,
               department: nil,
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

    // MARK: - AppStateCacheReset

    @Test func persistentSnapshotPreservesWishlistSeenlistAndCustomLists() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.movies[3] = makeMovie(id: 3)
        state.moviesState.wishlist.insert(1)
        state.moviesState.seenlist.insert(2)
        state.moviesState.customLists[10] = CustomList(id: 10, name: "Favs", cover: 3, movies: [3])

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        #expect(snapshot.moviesState.wishlist.contains(1))
        #expect(snapshot.moviesState.seenlist.contains(2))
        #expect(snapshot.moviesState.customLists[10]?.name == "Favs")
        #expect(snapshot.moviesState.movies[1] != nil)
        #expect(snapshot.moviesState.movies[2] != nil)
        #expect(snapshot.moviesState.movies[3] != nil)
    }

    @Test func persistentSnapshotStripsTransientCaches() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist.insert(1)
        state.moviesState.moviesList[.popular] = [1, 99]
        state.moviesState.search["test"] = [99]
        state.moviesState.recommended[1] = [99]

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        #expect(snapshot.moviesState.movies[1] != nil)
        #expect(snapshot.moviesState.movies[99] == nil)
        #expect(snapshot.moviesState.moviesList.isEmpty)
        #expect(snapshot.moviesState.search.isEmpty)
        #expect(snapshot.moviesState.recommended.isEmpty)
    }

    @Test func persistentSnapshotPreservesFanClubPeople() {
        var state = AppState()
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.peoples[6] = makePeople(id: 6)
        state.peoplesState.fanClub.insert(5)

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        #expect(snapshot.peoplesState.peoples[5] != nil)
        #expect(snapshot.peoplesState.peoples[6] == nil)
        #expect(snapshot.peoplesState.fanClub.contains(5))
    }

    @Test func persistentSnapshotPreservesMovieUserMeta() {
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

        #expect(snapshot.moviesState.moviesUserMeta[1] != nil)
        #expect(snapshot.moviesState.moviesUserMeta[99] == nil)
    }

    @Test func persistentSnapshotPreservesDiscoverFilter() {
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

        #expect(snapshot.moviesState.discoverFilter?.year == 2000)
        #expect(snapshot.moviesState.savedDiscoverFilters.count == 1)
        #expect(snapshot.moviesState.savedDiscoverFilters.first?.genre == 28)
    }

    @Test func persistentSnapshotPreservesCustomListCoverMovie() {
        var state = AppState()
        state.moviesState.movies[50] = makeMovie(id: 50)
        state.moviesState.customLists[1] = CustomList(id: 1, name: "Test", cover: 50, movies: [])

        let snapshot = AppStateCacheReset.persistentSnapshot(from: state)

        #expect(snapshot.moviesState.movies[50] != nil)
    }
}

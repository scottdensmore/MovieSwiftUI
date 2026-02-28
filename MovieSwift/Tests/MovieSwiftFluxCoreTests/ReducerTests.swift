import XCTest
@testable import MovieSwiftFluxCore

final class ReducerTests: XCTestCase {
    func testMoviesReducerSetMovieMenuListPageOneReplacesList() {
        var state = MoviesState()
        state.moviesList[.popular] = [999]

        let response = paginated([makeMovie(id: 1), makeMovie(id: 2)])
        let action = MoviesActions.SetMovieMenuList(page: 1, list: .popular, response: response)

        let reduced = moviesStateReducer(state: state, action: action)

        XCTAssertEqual(reduced.moviesList[.popular] ?? [], [1, 2])
        XCTAssertEqual(reduced.movies[1]?.id, 1)
        XCTAssertEqual(reduced.movies[2]?.id, 2)
    }

    func testMoviesReducerSetMovieMenuListPageTwoAppendsList() {
        var state = MoviesState()
        state.moviesList[.trending] = [1]

        let response = paginated([makeMovie(id: 2), makeMovie(id: 3)])
        let action = MoviesActions.SetMovieMenuList(page: 2, list: .trending, response: response)

        let reduced = moviesStateReducer(state: state, action: action)

        XCTAssertEqual(reduced.moviesList[.trending] ?? [], [1, 2, 3])
    }

    func testMoviesReducerAddToWishlistMovesMovieAndAddsMetaTimestamp() {
        var state = MoviesState()
        state.seenlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddToWishlist(movie: 42))

        XCTAssertTrue(reduced.wishlist.contains(42))
        XCTAssertFalse(reduced.seenlist.contains(42))
        XCTAssertNotNil(reduced.moviesUserMeta[42]?.addedToList)
    }

    func testMoviesReducerSetRandomDiscoverPrependsWhenBelowLimit() {
        var state = MoviesState()
        state.discover = [100, 101]
        let filter = DiscoverFilter(year: 1990, startYear: nil, endYear: nil, sort: "popularity.desc", genre: 12, region: "US")
        let response = paginated([makeMovie(id: 1), makeMovie(id: 2)])

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetRandomDiscover(filter: filter, response: response)
        )

        XCTAssertEqual(reduced.discover, [1, 2, 100, 101])
        XCTAssertEqual(reduced.movies[1]?.id, 1)
        XCTAssertEqual(reduced.movies[2]?.id, 2)
        XCTAssertEqual(reduced.discoverFilter?.year, filter.year)
        XCTAssertEqual(reduced.discoverFilter?.sort, filter.sort)
        XCTAssertEqual(reduced.discoverFilter?.genre, filter.genre)
        XCTAssertEqual(reduced.discoverFilter?.region, filter.region)
    }

    func testMoviesReducerSetGenresInsertsRandomGenreFirst() {
        let genres = [Genre(id: 7, name: "Drama"), Genre(id: 8, name: "Comedy")]

        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetGenres(genres: genres))

        XCTAssertEqual(reduced.genres.first?.id, -1)
        XCTAssertEqual(reduced.genres.first?.name, "Random")
        XCTAssertEqual(reduced.genres.dropFirst().map(\.id), [7, 8])
    }

    func testPeopleReducerSetDetailPreservesExistingMetadataFields() {
        let knownFor = [People.KnownFor(id: 90, original_title: "Old", poster_path: "/old.jpg")]
        let images = [ImageData(aspect_ratio: 1.0, file_path: "/img.jpg", height: 10, width: 10)]

        var state = PeoplesState()
        state.peoples[5] = makePeople(id: 5, name: "Old Name", character: "Old Char", department: "Directing", knownFor: knownFor, images: images)

        let incoming = makePeople(id: 5, name: "New Name", character: nil, department: nil, knownFor: nil, images: nil)
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetDetail(person: incoming))

        XCTAssertEqual(reduced.peoples[5]?.name, "New Name")
        XCTAssertEqual(reduced.peoples[5]?.character, "Old Char")
        XCTAssertEqual(reduced.peoples[5]?.department, "Directing")
        XCTAssertEqual(reduced.peoples[5]?.known_for?.first?.id, 90)
        XCTAssertEqual(reduced.peoples[5]?.images?.first?.file_path, "/img.jpg")
    }

    func testPeopleReducerSetMovieCastsMergesPeopleAndIndexesMovie() {
        let cast = makePeople(id: 1, name: "Cast Member")
        let crew = makePeople(id: 2, name: "Crew Member")
        let response = CastResponse(id: 100, cast: [cast], crew: [crew])

        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetMovieCasts(movie: 99, response: response))

        XCTAssertEqual(reduced.peoples[1]?.name, "Cast Member")
        XCTAssertEqual(reduced.peoples[2]?.name, "Crew Member")
        XCTAssertEqual(reduced.peoplesMovies[99], Set([1, 2]))
    }

    func testPeopleReducerSetPeopleCreditsStoresCharacterAndDepartmentMaps() {
        let castMovie = makeMovie(id: 10, character: "Hero", department: nil)
        let castMovieWithoutCharacter = makeMovie(id: 11, character: nil, department: nil)
        let crewMovie = makeMovie(id: 20, character: nil, department: "Directing")
        let crewMovieWithoutDepartment = makeMovie(id: 21, character: nil, department: nil)

        let response = PeopleActions.PeopleCreditsResponse(
            cast: [castMovie, castMovieWithoutCharacter],
            crew: [crewMovie, crewMovieWithoutDepartment]
        )

        let reduced = peoplesStateReducer(
            state: PeoplesState(),
            action: PeopleActions.SetPeopleCredits(people: 7, response: response)
        )

        XCTAssertEqual(reduced.casts[7]?[10], "Hero")
        XCTAssertNil(reduced.casts[7]?[11])
        XCTAssertEqual(reduced.crews[7]?[20], "Directing")
        XCTAssertNil(reduced.crews[7]?[21])
    }

    func testAppReducerRoutesMovieActionToMoviesState() {
        var state = AppState()
        state.moviesState.seenlist.insert(5)

        let reduced = appStateReducer(state: state, action: MoviesActions.AddToWishlist(movie: 5))

        XCTAssertTrue(reduced.moviesState.wishlist.contains(5))
        XCTAssertFalse(reduced.moviesState.seenlist.contains(5))
    }

    func testAppReducerRoutesPeopleActionToPeoplesState() {
        let reduced = appStateReducer(state: AppState(), action: PeopleActions.AddToFanClub(people: 55))

        XCTAssertTrue(reduced.peoplesState.fanClub.contains(55))
    }

    private func paginated<T: Codable>(_ values: [T]) -> PaginatedResponse<T> {
        PaginatedResponse(page: 1, total_results: values.count, total_pages: 1, results: values)
    }

    private func makeMovie(id: Int, character: String? = nil, department: String? = nil) -> Movie {
        Movie(
            id: id,
            original_title: "Original \(id)",
            title: "Title \(id)",
            overview: "Overview \(id)",
            poster_path: nil,
            backdrop_path: nil,
            popularity: 1.0,
            vote_average: 2.0,
            vote_count: 3,
            release_date: "2020-01-01",
            genres: nil,
            runtime: nil,
            status: nil,
            video: false,
            keywords: nil,
            images: nil,
            production_countries: nil,
            character: character,
            department: department
        )
    }

    private func makePeople(
        id: Int,
        name: String,
        character: String? = nil,
        department: String? = nil,
        knownFor: [People.KnownFor]? = nil,
        images: [ImageData]? = nil
    ) -> People {
        People(
            id: id,
            name: name,
            character: character,
            department: department,
            profile_path: nil,
            known_for_department: nil,
            known_for: knownFor,
            also_known_as: nil,
            birthDay: nil,
            deathDay: nil,
            place_of_birth: nil,
            biography: nil,
            popularity: nil,
            images: images
        )
    }
}

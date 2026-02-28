import XCTest
import Backend
@testable import MovieSwiftFluxCore

final class ModelUtilityTests: XCTestCase {
    func testPeopleKnownForTextFiltersNilTitlesAndJoins() {
        let people = People(
            id: 1,
            name: "Person",
            character: nil,
            department: nil,
            profile_path: nil,
            known_for_department: nil,
            known_for: [
                People.KnownFor(id: 100, original_title: "Movie A", poster_path: nil),
                People.KnownFor(id: 101, original_title: nil, poster_path: nil),
                People.KnownFor(id: 102, original_title: "Movie B", poster_path: nil)
            ],
            also_known_as: nil,
            birthDay: nil,
            deathDay: nil,
            place_of_birth: nil,
            biography: nil,
            popularity: nil,
            images: nil
        )

        XCTAssertEqual(people.knownForText, "Movie A, Movie B")
    }

    func testDiscoverFilterToParamsUsesYearWhenRangeMissing() {
        let filter = DiscoverFilter(
            year: 2001,
            startYear: nil,
            endYear: nil,
            sort: "popularity.desc",
            genre: 28,
            region: "US"
        )

        let params = filter.toParams()

        XCTAssertEqual(params["year"], "2001")
        XCTAssertNil(params["primary_release_date.gte"])
        XCTAssertNil(params["primary_release_date.lte"])
        XCTAssertEqual(params["with_genres"], "28")
        XCTAssertEqual(params["region"], "US")
        XCTAssertEqual(params["sort_by"], "popularity.desc")
        XCTAssertEqual(params["language"], "en-US")
        XCTAssertNotNil(params["page"])
    }

    func testDiscoverFilterToParamsUsesRangeWhenProvided() {
        let filter = DiscoverFilter(
            year: 2020,
            startYear: 1990,
            endYear: 1999,
            sort: "vote_average.desc",
            genre: nil,
            region: nil
        )

        let params = filter.toParams()

        XCTAssertEqual(params["primary_release_date.gte"], "1990")
        XCTAssertEqual(params["primary_release_date.lte"], "1999")
        XCTAssertNil(params["year"])
        XCTAssertEqual(params["sort_by"], "vote_average.desc")
    }

    func testDiscoverFilterToTextBuildsExpectedLabel() {
        let filter = DiscoverFilter(
            year: 2005,
            startYear: 1990,
            endYear: 1995,
            sort: "popularity.desc",
            genre: 12,
            region: "FR"
        )
        let genres = [Genre(id: 12, name: "Adventure")]

        XCTAssertEqual(filter.toText(genres: genres), "1990-1995 · Adventure · FR")
    }

    func testMovieUserTitleRespectsAlwaysOriginalTitlePreference() {
        let original = AppUserDefaults.alwaysOriginalTitle
        defer { AppUserDefaults.alwaysOriginalTitle = original }

        let movie = makeMovie(id: 10, title: "Localized", originalTitle: "Original")

        AppUserDefaults.alwaysOriginalTitle = false
        XCTAssertEqual(movie.userTitle, "Localized")

        AppUserDefaults.alwaysOriginalTitle = true
        XCTAssertEqual(movie.userTitle, "Original")
    }

    func testMovieReleaseDateFallsBackToCurrentDateWhenSourceMissing() {
        let movie = makeMovie(id: 11, releaseDate: nil)

        let now = Date()
        let releaseDate = try? XCTUnwrap(movie.releaseDate)
        XCTAssertNotNil(releaseDate)
        XCTAssertLessThan(abs((releaseDate ?? now).timeIntervalSince(now)), 2.0)
    }

    func testMoviesSortSortByAPIValues() {
        XCTAssertEqual(MoviesSort.byReleaseDate.sortByAPI(), "release_date.desc")
        XCTAssertEqual(MoviesSort.byAddedDate.sortByAPI(), "primary_release_date.desc")
        XCTAssertEqual(MoviesSort.byScore.sortByAPI(), "vote_average.desc")
        XCTAssertEqual(MoviesSort.byPopularity.sortByAPI(), "popularity.desc")
    }

    func testSortedMoviesIdsSortsByScoreAndPopularity() {
        let movieA = makeMovie(id: 1, voteAverage: 7.0, popularity: 20.0)
        let movieB = makeMovie(id: 2, voteAverage: 9.0, popularity: 10.0)
        let movieC = makeMovie(id: 3, voteAverage: 8.0, popularity: 30.0)

        var state = AppState()
        state.moviesState.movies = [1: movieA, 2: movieB, 3: movieC]

        let ids = [1, 2, 3]

        XCTAssertEqual(ids.sortedMoviesIds(by: .byScore, state: state), [2, 3, 1])
        XCTAssertEqual(ids.sortedMoviesIds(by: .byPopularity, state: state), [3, 1, 2])
    }

    func testSortedMoviesIdsSortsByReleaseDateAndAddedDate() {
        let movieA = makeMovie(id: 1, releaseDate: "2020-01-01")
        let movieB = makeMovie(id: 2, releaseDate: "2023-01-01")
        let movieC = makeMovie(id: 3, releaseDate: "2021-01-01")

        var state = AppState()
        state.moviesState.movies = [1: movieA, 2: movieB, 3: movieC]
        state.moviesState.moviesUserMeta = [
            1: MovieUserMeta(addedToList: Date(timeIntervalSince1970: 100)),
            2: MovieUserMeta(addedToList: Date(timeIntervalSince1970: 300)),
            3: MovieUserMeta(addedToList: Date(timeIntervalSince1970: 200))
        ]

        let ids = [1, 2, 3]

        XCTAssertEqual(ids.sortedMoviesIds(by: .byReleaseDate, state: state), [2, 3, 1])
        XCTAssertEqual(ids.sortedMoviesIds(by: .byAddedDate, state: state), [2, 3, 1])
    }

    func testPaginatedResponseDecodingRegression() throws {
        let json = #"{"page":1,"total_results":1,"total_pages":1,"results":[{"id":7,"name":"Drama"}]}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(PaginatedResponse<Genre>.self, from: data)

        XCTAssertEqual(decoded.page, 1)
        XCTAssertEqual(decoded.total_results, 1)
        XCTAssertEqual(decoded.total_pages, 1)
        XCTAssertEqual(decoded.results.first?.id, 7)
        XCTAssertEqual(decoded.results.first?.name, "Drama")
    }

    func testDiscoverFilterRandomHelpersStayInExpectedDomain() {
        let year = DiscoverFilter.randomYear()
        let currentYear = Calendar.current.component(.year, from: Date())
        XCTAssertGreaterThanOrEqual(year, 1950)
        XCTAssertLessThan(year, currentYear)

        let sort = DiscoverFilter.randomSort()
        XCTAssertTrue([
            "popularity.desc",
            "popularity.asc",
            "vote_average.asc",
            "vote_average.desc"
        ].contains(sort))

        let page = DiscoverFilter.randomPage()
        XCTAssertTrue((1..<20).contains(page))
    }

    private func makeMovie(
        id: Int,
        title: String = "Title",
        originalTitle: String = "Original",
        voteAverage: Float = 7.0,
        popularity: Float = 10.0,
        releaseDate: String? = "2020-01-01"
    ) -> Movie {
        Movie(
            id: id,
            original_title: originalTitle,
            title: title,
            overview: "Overview",
            poster_path: nil,
            backdrop_path: nil,
            popularity: popularity,
            vote_average: voteAverage,
            vote_count: 1,
            release_date: releaseDate,
            genres: nil,
            runtime: nil,
            status: nil,
            video: false,
            keywords: nil,
            images: nil,
            production_countries: nil,
            character: nil,
            department: nil
        )
    }
}

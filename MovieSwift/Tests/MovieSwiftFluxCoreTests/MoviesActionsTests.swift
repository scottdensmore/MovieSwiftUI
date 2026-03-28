import XCTest
import Backend
@testable import MovieSwiftFluxCore

final class MoviesActionsTests: XCTestCase {
    private final class StubAPIKeyProvider: APIKeyProviding {
        private let value: String?

        init(_ value: String?) {
            self.value = value
        }

        func apiKey() -> String? {
            value
        }
    }

    private final class MockDataTask: NetworkDataTask {
        private(set) var resumeCalls = 0

        func resume() {
            resumeCalls += 1
        }
    }

    private final class MockNetworkSession: NetworkSession {
        var lastRequest: URLRequest?
        var nextData: Data?
        var nextResponse: URLResponse?
        var nextError: Error?

        let task = MockDataTask()

        func dataTask(
            with request: URLRequest,
            completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
        ) -> NetworkDataTask {
            lastRequest = request
            completionHandler(nextData, nextResponse, nextError)
            return task
        }
    }

    private enum StubError: Error {
        case failed
    }

    private var originalAPIService: APIService!

    override func setUp() {
        super.setUp()
        originalAPIService = APIService.shared
    }

    override func tearDown() {
        APIService.shared = originalAPIService
        super.tearDown()
    }

    func testFetchMoviesMenuListDispatchesSetMovieMenuListOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 20)])
        )

        let callbackQueue = DispatchQueue(label: "MoviesActionsTests.fetchList")
        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: callbackQueue
        )

        let expectation = expectation(description: "Dispatch SetMovieMenuList")
        var dispatchedAction: MoviesActions.SetMovieMenuList?

        MoviesActions.FetchMoviesMenuList(list: .popular, page: 2).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetMovieMenuList
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.page, 2)
        XCTAssertEqual(dispatchedAction?.list, .popular)
        XCTAssertEqual(dispatchedAction?.response.results.map(\.id), [20])
        XCTAssertEqual(session.task.resumeCalls, 1)

        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(session.lastRequest?.url), resolvingAgainstBaseURL: false)
        )
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertTrue(components.path.contains("/movie/popular"))
        XCTAssertEqual(queryItems["api_key"], "test-key")
        XCTAssertEqual(queryItems["page"], "2")
        XCTAssertEqual(queryItems["region"], AppUserDefaults.region)
    }

    func testFetchMoviesMenuListDoesNotDispatchWhenAPIKeyMissing() {
        let session = MockNetworkSession()
        let callbackQueue = DispatchQueue(label: "MoviesActionsTests.missingAPIKey")

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider(nil),
            session: session,
            callbackQueue: callbackQueue
        )

        let expectation = expectation(description: "No dispatch")
        expectation.isInverted = true

        MoviesActions.FetchMoviesMenuList(list: .popular, page: 1).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        XCTAssertNil(session.lastRequest)
        XCTAssertEqual(session.task.resumeCalls, 0)
    }

    func testFetchMoviesMenuListDoesNotDispatchOnNetworkError() {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.networkFailure")
        )

        let expectation = expectation(description: "No dispatch on network error")
        expectation.isInverted = true

        MoviesActions.FetchMoviesMenuList(list: .upcoming, page: 1).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        XCTAssertEqual(session.task.resumeCalls, 1)
    }

    func testFetchMoviesMenuListDoesNotDispatchOnDecodingError() {
        let session = MockNetworkSession()
        session.nextData = Data("not-json".utf8)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.decodingFailure")
        )

        let expectation = expectation(description: "No dispatch on decode error")
        expectation.isInverted = true

        MoviesActions.FetchMoviesMenuList(list: .nowPlaying, page: 1).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        XCTAssertEqual(session.task.resumeCalls, 1)
    }

    func testFetchGenresDispatchesSetGenresOnSuccess() throws {
        let session = MockNetworkSession()
        let payload = #"{"genres":[{"id":12,"name":"Adventure"},{"id":18,"name":"Drama"}]}"#
        session.nextData = Data(payload.utf8)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchGenres")
        )

        let expectation = expectation(description: "Dispatch SetGenres")
        var dispatchedAction: MoviesActions.SetGenres?

        MoviesActions.FetchGenres().execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetGenres
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.genres.map(\.id), [12, 18])
        XCTAssertEqual(dispatchedAction?.genres.map(\.name), ["Adventure", "Drama"])
        XCTAssertEqual(session.task.resumeCalls, 1)

        let requestURL = try XCTUnwrap(session.lastRequest?.url)
        XCTAssertTrue(requestURL.path.contains("/genre/movie/list"))
    }

    func testFetchGenresDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextData = nil
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.genresFailure")
        )

        let expectation = expectation(description: "No dispatch on genres failure")
        expectation.isInverted = true

        MoviesActions.FetchGenres().execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        XCTAssertEqual(session.task.resumeCalls, 1)
    }

    // MARK: - FetchDetail

    func testFetchDetailDispatchesSetDetailOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(makeMovie(id: 42))

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchDetail")
        )

        let expectation = expectation(description: "Dispatch SetDetail")
        var dispatchedAction: MoviesActions.SetDetail?

        MoviesActions.FetchDetail(movie: 42).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetDetail
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.movie, 42)
        XCTAssertEqual(dispatchedAction?.response.id, 42)

        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(session.lastRequest?.url), resolvingAgainstBaseURL: false)
        )
        XCTAssertTrue(components.path.contains("/movie/42"))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryItems["append_to_response"], "keywords,images")
    }

    func testFetchDetailDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchDetailFailure")
        )

        let expectation = expectation(description: "No dispatch on detail failure")
        expectation.isInverted = true

        MoviesActions.FetchDetail(movie: 42).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
    }

    // MARK: - FetchRecommended

    func testFetchRecommendedDispatchesSetRecommendedOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 10)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRecommended")
        )

        let expectation = expectation(description: "Dispatch SetRecommended")
        var dispatchedAction: MoviesActions.SetRecommended?

        MoviesActions.FetchRecommended(movie: 5).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetRecommended
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.movie, 5)
        XCTAssertEqual(dispatchedAction?.response.results.map(\.id), [10])
    }

    // MARK: - FetchSimilar

    func testFetchSimilarDispatchesSetSimilarOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 11)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchSimilar")
        )

        let expectation = expectation(description: "Dispatch SetSimilar")
        var dispatchedAction: MoviesActions.SetSimilar?

        MoviesActions.FetchSimilar(movie: 6).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetSimilar
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.movie, 6)
        XCTAssertEqual(dispatchedAction?.response.results.map(\.id), [11])
    }

    // MARK: - FetchVideos

    func testFetchVideosDispatchesSetVideosOnSuccess() throws {
        let session = MockNetworkSession()
        let video = Video(id: "v1", name: "Trailer", site: "YouTube", key: "abc", type: "Trailer")
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [video])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchVideos")
        )

        let expectation = expectation(description: "Dispatch SetVideos")
        var dispatchedAction: MoviesActions.SetVideos?

        MoviesActions.FetchVideos(movie: 7).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetVideos
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.movie, 7)
        XCTAssertEqual(dispatchedAction?.response.results.first?.key, "abc")
    }

    // MARK: - FetchSearch

    func testFetchSearchDispatchesSetSearchOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 2, total_results: 1, total_pages: 2, results: [makeMovie(id: 30)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchSearch")
        )

        let expectation = expectation(description: "Dispatch SetSearch")
        var dispatchedAction: MoviesActions.SetSearch?

        MoviesActions.FetchSearch(query: "test", page: 2).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetSearch
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.query, "test")
        XCTAssertEqual(dispatchedAction?.page, 2)
        XCTAssertEqual(dispatchedAction?.response.results.first?.id, 30)
    }

    // MARK: - FetchSearchKeyword

    func testFetchSearchKeywordDispatchesSetSearchKeywordOnSuccess() throws {
        let session = MockNetworkSession()
        let keyword = Keyword(id: 50, name: "neo-noir")
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [keyword])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchSearchKeyword")
        )

        let expectation = expectation(description: "Dispatch SetSearchKeyword")
        var dispatchedAction: MoviesActions.SetSearchKeyword?

        MoviesActions.FetchSearchKeyword(query: "noir").execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetSearchKeyword
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.query, "noir")
        XCTAssertEqual(dispatchedAction?.response.results.first?.name, "neo-noir")
    }

    // MARK: - FetchMoviesGenre

    func testFetchMoviesGenreDispatchesSetMovieForGenreOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 40)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchMoviesGenre")
        )

        let expectation = expectation(description: "Dispatch SetMovieForGenre")
        var dispatchedAction: MoviesActions.SetMovieForGenre?
        let genre = Genre(id: 28, name: "Action")

        MoviesActions.FetchMoviesGenre(genre: genre, page: 1, sortBy: .byPopularity).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetMovieForGenre
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.genre.id, 28)
        XCTAssertEqual(dispatchedAction?.page, 1)
        XCTAssertEqual(dispatchedAction?.response.results.first?.id, 40)
    }

    // MARK: - FetchMovieReviews

    func testFetchMovieReviewsDispatchesSetMovieReviewsOnSuccess() throws {
        let session = MockNetworkSession()
        let review = Review(id: "r1", author: "Critic", content: "Great movie")
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [review])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchReviews")
        )

        let expectation = expectation(description: "Dispatch SetMovieReviews")
        var dispatchedAction: MoviesActions.SetMovieReviews?

        MoviesActions.FetchMovieReviews(movie: 8).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetMovieReviews
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.movie, 8)
        XCTAssertEqual(dispatchedAction?.response.results.first?.author, "Critic")
    }

    // MARK: - FetchMovieWithCrew

    func testFetchMovieWithCrewDispatchesSetMovieWithCrewOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 50)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchMovieWithCrew")
        )

        let expectation = expectation(description: "Dispatch SetMovieWithCrew")
        var dispatchedAction: MoviesActions.SetMovieWithCrew?

        MoviesActions.FetchMovieWithCrew(crew: 15).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetMovieWithCrew
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.crew, 15)
        XCTAssertEqual(dispatchedAction?.response.results.first?.id, 50)
    }

    // MARK: - FetchMovieWithKeywords

    func testFetchMovieWithKeywordsDispatchesSetMovieWithKeywordOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 2, total_results: 1, total_pages: 2, results: [makeMovie(id: 60)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchMovieWithKeywords")
        )

        let expectation = expectation(description: "Dispatch SetMovieWithKeyword")
        var dispatchedAction: MoviesActions.SetMovieWithKeyword?

        MoviesActions.FetchMovieWithKeywords(keyword: 99, page: 2).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetMovieWithKeyword
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.keyword, 99)
        XCTAssertEqual(dispatchedAction?.page, 2)
        XCTAssertEqual(dispatchedAction?.response.results.first?.id, 60)
    }

    // MARK: - FetchRandomDiscover

    func testFetchRandomDiscoverDispatchesSetRandomDiscoverOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 70)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRandomDiscover")
        )

        let expectation = expectation(description: "Dispatch SetRandomDiscover")
        var dispatchedAction: MoviesActions.SetRandomDiscover?
        let filter = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)

        MoviesActions.FetchRandomDiscover(filter: filter).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetRandomDiscover
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.filter.year, 2000)
        XCTAssertEqual(dispatchedAction?.response.results.first?.id, 70)
    }

    func testFetchRandomDiscoverUsesRandomFilterWhenNilProvided() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 80)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRandomDiscoverNilFilter")
        )

        let expectation = expectation(description: "Dispatch SetRandomDiscover with random filter")
        var dispatchedAction: MoviesActions.SetRandomDiscover?

        MoviesActions.FetchRandomDiscover(filter: nil).execute(state: nil) { action in
            dispatchedAction = action as? MoviesActions.SetRandomDiscover
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertNotNil(dispatchedAction?.filter)
        XCTAssertGreaterThanOrEqual(dispatchedAction?.filter.year ?? 0, 1950)
    }

    // MARK: - Helpers

    private func makeMovie(id: Int) -> Movie {
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
            character: nil,
            department: nil
        )
    }
}

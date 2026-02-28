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

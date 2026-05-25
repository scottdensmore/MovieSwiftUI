import XCTest
import Backend
import SwiftUIFlux
@testable import MovieSwiftFluxCore

/// Tests for the `MoviesActions` AsyncAction execute paths.
///
/// **Dispatch contract.** Every action that hits the network funnels through
/// `MoviesActions.makeTrackedHandler(...)`, which dispatches:
///   1. `SetLoadingState(key:, state: .loading)` — synchronously, before
///      the GET fires.
///   2a. on success — `SetLoadingState(key:, state: nil)` (clears the
///       loading entry), then the data action (e.g. `SetMovieMenuList`).
///   2b. on failure — `SetLoadingState(key:, state: .failed(translated))`.
///       No data action is dispatched on failure.
///
/// So success-path tests have to look at three dispatches and pick out the
/// data action; failure-path tests have to look at two dispatches and assert
/// the second is a `.failed` SetLoadingState.
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

    private final class MockNetworkSession: NetworkSession, @unchecked Sendable {
        var lastRequest: URLRequest?

        /// All requests issued, in order. Used by multi-phase tests (e.g.
        /// `FetchRandomDiscover` probe → fetch) to inspect both URLs.
        var allRequests: [URLRequest] = []

        var nextData: Data?
        var nextResponse: URLResponse?
        var nextError: Error?

        /// FIFO queue of `(Data?, URLResponse?, Error?)` triples — when
        /// non-empty, each `data(for:)` call pops the front element and
        /// returns/throws it. Falls back to `(nextData, nextResponse,
        /// nextError)` once the queue drains, so existing tests that only
        /// set `nextData` keep working.
        var responseQueue: [(Data?, URLResponse?, Error?)] = []

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            lastRequest = request
            allRequests.append(request)
            // Pop the queued triple if present, else fall back to the
            // single `next*` values. Choosing the tuple first, then
            // destructuring, keeps this a single clear expression.
            let (data, response, error) = responseQueue.isEmpty
                ? (nextData, nextResponse, nextError)
                : responseQueue.removeFirst()
            if let error { throw error }
            // Default to 200 when a test only sets data (matches the prior
            // "nil response → skip status check → decode" behaviour).
            let resolvedResponse = response
                ?? HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
            return (data ?? Data(), resolvedResponse)
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

    // MARK: - Dispatch capture helper

    /// Run an AsyncAction against a synchronous mock session and collect every
    /// action it dispatches into an array. The expectation fulfills as soon as
    /// `trigger` returns true for one of the dispatched actions; the wait then
    /// returns and the caller asserts on the captured array.
    ///
    /// `assertForOverFulfill` is set to false so a slightly noisy success path
    /// (e.g. SetLoadingState clear → data action where both qualify under
    /// `trigger`) doesn't crash the test before it can make its real
    /// assertions.
    private func captureDispatches(
        waitingFor description: String,
        until trigger: @escaping (Action) -> Bool,
        timeout: TimeInterval = 1.0,
        when execute: (@escaping DispatchFunction) -> Void
    ) -> [Action] {
        // `dispatched` is mutated from two threads:
        //   - the test thread, which receives the synchronous
        //     SetLoadingState(.loading) dispatch fired immediately by
        //     `makeTrackedHandler` before APIService.GET returns
        //   - the APIService's `callbackQueue` thread, which fires
        //     the subsequent .failed / .success+data dispatches
        //
        // `Array<any Action>` stores existential containers (5
        // machine-words per element). Concurrent writes corrupt the
        // storage and cause downcasts (`$0 as? SetMovieMenuList`) to
        // succeed on garbage that wasn't actually a SetMovieMenuList,
        // which surfaces as "Failure path unexpectedly dispatched a
        // SetMovieMenuList data action" with the value's description
        // rendered as "(Function)". The race is data-loss-prone on
        // any ARM machine; macos-26 CI runners hit it deterministically
        // while local M-series Macs tend to slip past it.
        //
        // Serialize all reads/writes through an NSLock so the array
        // stays consistent regardless of which thread dispatches.
        let lock = NSLock()
        var dispatched: [Action] = []
        let exp = expectation(description: description)
        exp.assertForOverFulfill = false
        execute { action in
            lock.lock()
            dispatched.append(action)
            let shouldFulfill = trigger(action)
            lock.unlock()
            if shouldFulfill { exp.fulfill() }
        }
        waitForExpectations(timeout: timeout)
        lock.lock()
        defer { lock.unlock() }
        return dispatched
    }

    /// Find the first dispatched action of the given type, or fail the test if
    /// none was dispatched.
    private func unwrapDispatched<T>(
        _ type: T.Type,
        in dispatched: [Action],
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let matches = dispatched.compactMap { $0 as? T }
        return try XCTUnwrap(matches.first,
                             "Expected one \(T.self) in dispatched actions, got: \(dispatched)",
                             file: file, line: line)
    }

    /// Assert that the dispatch trace ends in a `SetLoadingState(.failed)`
    /// for `key`, with no data action of `dataType` ever dispatched. Returns
    /// the failure for further assertion.
    ///
    /// Takes a `noDataActionMatching` closure rather than a generic `T.Type`.
    /// The generic-T form (`$0 as? T`) was triggering a Swift 6 compiler
    /// quirk on the macos-26 GitHub runner where the cast returned a value
    /// whose dynamic type rendered as `(Function)` — even though no Action
    /// passed to dispatch was a closure. Inlining the type check at the
    /// call site (via the closure) bypasses the generic-existential cast
    /// path and produces consistent results locally and on CI.
    private func assertFailureDispatch(
        in dispatched: [Action],
        for key: LoadingKey,
        noDataActionMatching matches: (Action) -> Bool,
        dataActionDescription: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> MoviesListLoadFailure {
        let unwantedDataAction = dispatched.first(where: matches)
        XCTAssertNil(unwantedDataAction,
                     "Failure path unexpectedly dispatched a \(dataActionDescription) data action.",
                     file: file, line: line)
        let loadingStates = dispatched.compactMap { $0 as? MoviesActions.SetLoadingState }
        let lastForKey = loadingStates.last { $0.key == key }
        let unwrapped = try XCTUnwrap(lastForKey,
                                      "No SetLoadingState dispatched for key \(key); got: \(loadingStates)",
                                      file: file, line: line)
        guard case let .failed(failure) = unwrapped.state else {
            XCTFail("Last SetLoadingState for \(key) was \(String(describing: unwrapped.state)), not .failed",
                    file: file, line: line)
            throw StubError.failed
        }
        return failure
    }

    // MARK: - FetchMoviesMenuList

    func testFetchMoviesMenuListDispatchesSetMovieMenuListOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 20)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchList")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetMovieMenuList dispatched",
            until: { $0 is MoviesActions.SetMovieMenuList }
        ) { dispatch in
            MoviesActions.FetchMoviesMenuList(list: .popular, page: 2)
                .execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieMenuList.self, in: dispatched)
        XCTAssertEqual(action.page, 2)
        XCTAssertEqual(action.list, .popular)
        XCTAssertEqual(action.response.results.map(\.id), [20])
        XCTAssertNotNil(session.lastRequest, "expected the request to be issued")

        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(session.lastRequest?.url), resolvingAgainstBaseURL: false)
        )
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertTrue(components.path.contains("/movie/popular"))
        XCTAssertEqual(queryItems["api_key"], "test-key")
        XCTAssertEqual(queryItems["page"], "2")
        XCTAssertEqual(queryItems["region"], AppUserDefaults.region)
    }

    func testFetchMoviesMenuListDispatchesFailureWhenAPIKeyMissing() throws {
        let session = MockNetworkSession()

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider(nil),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.missingAPIKey")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetLoadingState(.failed) for .homeMenu(.popular)",
            until: { isFailedSetLoading($0, for: .homeMenu(.popular)) }
        ) { dispatch in
            MoviesActions.FetchMoviesMenuList(list: .popular, page: 1)
                .execute(state: nil, dispatch: dispatch)
        }

        let failure = try assertFailureDispatch(
            in: dispatched,
            for: .homeMenu(.popular),
            noDataActionMatching: { $0 is MoviesActions.SetMovieMenuList },
            dataActionDescription: "SetMovieMenuList"
        )
        XCTAssertEqual(failure.kind, .missingAPIKey)
        // Missing API key short-circuits in APIService.GET — no network call.
        XCTAssertNil(session.lastRequest)
    }

    func testFetchMoviesMenuListDispatchesFailureOnNetworkError() throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.networkFailure")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetLoadingState(.failed) for .homeMenu(.upcoming)",
            until: { isFailedSetLoading($0, for: .homeMenu(.upcoming)) }
        ) { dispatch in
            MoviesActions.FetchMoviesMenuList(list: .upcoming, page: 1)
                .execute(state: nil, dispatch: dispatch)
        }

        _ = try assertFailureDispatch(
            in: dispatched,
            for: .homeMenu(.upcoming),
            noDataActionMatching: { $0 is MoviesActions.SetMovieMenuList },
            dataActionDescription: "SetMovieMenuList"
        )
        XCTAssertNotNil(session.lastRequest, "expected the request to be issued")
    }

    func testFetchMoviesMenuListDispatchesFailureOnDecodingError() throws {
        let session = MockNetworkSession()
        session.nextData = Data("not-json".utf8)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.decodingFailure")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetLoadingState(.failed) for .homeMenu(.nowPlaying)",
            until: { isFailedSetLoading($0, for: .homeMenu(.nowPlaying)) }
        ) { dispatch in
            MoviesActions.FetchMoviesMenuList(list: .nowPlaying, page: 1)
                .execute(state: nil, dispatch: dispatch)
        }

        let failure = try assertFailureDispatch(
            in: dispatched,
            for: .homeMenu(.nowPlaying),
            noDataActionMatching: { $0 is MoviesActions.SetMovieMenuList },
            dataActionDescription: "SetMovieMenuList"
        )
        XCTAssertEqual(failure.kind, .decode)
        XCTAssertNotNil(session.lastRequest, "expected the request to be issued")
    }

    // MARK: - FetchGenres

    func testFetchGenresDispatchesSetGenresOnSuccess() throws {
        let session = MockNetworkSession()
        let payload = #"{"genres":[{"id":12,"name":"Adventure"},{"id":18,"name":"Drama"}]}"#
        session.nextData = Data(payload.utf8)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchGenres")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetGenres dispatched",
            until: { $0 is MoviesActions.SetGenres }
        ) { dispatch in
            MoviesActions.FetchGenres().execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetGenres.self, in: dispatched)
        XCTAssertEqual(action.genres.map(\.id), [12, 18])
        XCTAssertEqual(action.genres.map(\.name), ["Adventure", "Drama"])
        XCTAssertNotNil(session.lastRequest, "expected the request to be issued")

        let requestURL = try XCTUnwrap(session.lastRequest?.url)
        XCTAssertTrue(requestURL.path.contains("/genre/movie/list"))
    }

    func testFetchGenresDispatchesFailureOnError() throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.genresFailure")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetLoadingState(.failed) for .genres",
            until: { isFailedSetLoading($0, for: .genres) }
        ) { dispatch in
            MoviesActions.FetchGenres().execute(state: nil, dispatch: dispatch)
        }

        _ = try assertFailureDispatch(
            in: dispatched,
            for: .genres,
            noDataActionMatching: { $0 is MoviesActions.SetGenres },
            dataActionDescription: "SetGenres"
        )
        XCTAssertNotNil(session.lastRequest, "expected the request to be issued")
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

        let dispatched = captureDispatches(
            waitingFor: "SetDetail dispatched",
            until: { $0 is MoviesActions.SetDetail }
        ) { dispatch in
            MoviesActions.FetchDetail(movie: 42).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetDetail.self, in: dispatched)
        XCTAssertEqual(action.movie, 42)
        XCTAssertEqual(action.response.id, 42)

        let components = try XCTUnwrap(
            URLComponents(url: try XCTUnwrap(session.lastRequest?.url), resolvingAgainstBaseURL: false)
        )
        XCTAssertTrue(components.path.contains("/movie/42"))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(queryItems["append_to_response"], "keywords,images")
    }

    func testFetchDetailDispatchesFailureOnError() throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchDetailFailure")
        )

        let dispatched = captureDispatches(
            waitingFor: "SetLoadingState(.failed) for .movieDetail(42)",
            until: { isFailedSetLoading($0, for: .movieDetail(42)) }
        ) { dispatch in
            MoviesActions.FetchDetail(movie: 42).execute(state: nil, dispatch: dispatch)
        }

        _ = try assertFailureDispatch(
            in: dispatched,
            for: .movieDetail(42),
            noDataActionMatching: { $0 is MoviesActions.SetDetail },
            dataActionDescription: "SetDetail"
        )
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

        let dispatched = captureDispatches(
            waitingFor: "SetRecommended dispatched",
            until: { $0 is MoviesActions.SetRecommended }
        ) { dispatch in
            MoviesActions.FetchRecommended(movie: 5).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRecommended.self, in: dispatched)
        XCTAssertEqual(action.movie, 5)
        XCTAssertEqual(action.response.results.map(\.id), [10])
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

        let dispatched = captureDispatches(
            waitingFor: "SetSimilar dispatched",
            until: { $0 is MoviesActions.SetSimilar }
        ) { dispatch in
            MoviesActions.FetchSimilar(movie: 6).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetSimilar.self, in: dispatched)
        XCTAssertEqual(action.movie, 6)
        XCTAssertEqual(action.response.results.map(\.id), [11])
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

        let dispatched = captureDispatches(
            waitingFor: "SetVideos dispatched",
            until: { $0 is MoviesActions.SetVideos }
        ) { dispatch in
            MoviesActions.FetchVideos(movie: 7).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetVideos.self, in: dispatched)
        XCTAssertEqual(action.movie, 7)
        XCTAssertEqual(action.response.results.first?.key, "abc")
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

        let dispatched = captureDispatches(
            waitingFor: "SetSearch dispatched",
            until: { $0 is MoviesActions.SetSearch }
        ) { dispatch in
            MoviesActions.FetchSearch(query: "test", page: 2).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetSearch.self, in: dispatched)
        XCTAssertEqual(action.query, "test")
        XCTAssertEqual(action.page, 2)
        XCTAssertEqual(action.response.results.first?.id, 30)
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

        let dispatched = captureDispatches(
            waitingFor: "SetSearchKeyword dispatched",
            until: { $0 is MoviesActions.SetSearchKeyword }
        ) { dispatch in
            MoviesActions.FetchSearchKeyword(query: "noir").execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetSearchKeyword.self, in: dispatched)
        XCTAssertEqual(action.query, "noir")
        XCTAssertEqual(action.response.results.first?.name, "neo-noir")
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

        let genre = Genre(id: 28, name: "Action")
        let dispatched = captureDispatches(
            waitingFor: "SetMovieForGenre dispatched",
            until: { $0 is MoviesActions.SetMovieForGenre }
        ) { dispatch in
            MoviesActions.FetchMoviesGenre(genre: genre, page: 1, sortBy: .byPopularity)
                .execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieForGenre.self, in: dispatched)
        XCTAssertEqual(action.genre.id, 28)
        XCTAssertEqual(action.page, 1)
        XCTAssertEqual(action.response.results.first?.id, 40)
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

        let dispatched = captureDispatches(
            waitingFor: "SetMovieReviews dispatched",
            until: { $0 is MoviesActions.SetMovieReviews }
        ) { dispatch in
            MoviesActions.FetchMovieReviews(movie: 8).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieReviews.self, in: dispatched)
        XCTAssertEqual(action.movie, 8)
        XCTAssertEqual(action.response.results.first?.author, "Critic")
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

        let dispatched = captureDispatches(
            waitingFor: "SetMovieWithCrew dispatched",
            until: { $0 is MoviesActions.SetMovieWithCrew }
        ) { dispatch in
            MoviesActions.FetchMovieWithCrew(crew: 15).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieWithCrew.self, in: dispatched)
        XCTAssertEqual(action.crew, 15)
        XCTAssertEqual(action.response.results.first?.id, 50)
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

        let dispatched = captureDispatches(
            waitingFor: "SetMovieWithKeyword dispatched",
            until: { $0 is MoviesActions.SetMovieWithKeyword }
        ) { dispatch in
            MoviesActions.FetchMovieWithKeywords(keyword: 99, page: 2)
                .execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieWithKeyword.self, in: dispatched)
        XCTAssertEqual(action.keyword, 99)
        XCTAssertEqual(action.page, 2)
        XCTAssertEqual(action.response.results.first?.id, 60)
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

        let filter = DiscoverFilter(
            year: 2000, startYear: nil, endYear: nil,
            sort: "popularity.desc", genre: nil, region: nil
        )
        let dispatched = captureDispatches(
            waitingFor: "SetRandomDiscover dispatched",
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(filter: filter).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        XCTAssertEqual(action.filter.year, 2000)
        XCTAssertEqual(action.response.results.first?.id, 70)
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

        let dispatched = captureDispatches(
            waitingFor: "SetRandomDiscover with random filter dispatched",
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(filter: nil).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        XCTAssertGreaterThanOrEqual(action.filter.year, 1950)
    }

    // MARK: - FetchRandomDiscover: two-phase logic
    //
    // Background: TMDB's `/discover/movie` returns **HTTP 400** when the
    // requested `page` exceeds the query's `total_pages`. The old
    // implementation picked a random page in [1, 19] without knowing the
    // real ceiling and hit 400s on obscure filters. The new flow probes
    // page 1, reads `total_pages` from the response, then picks a random
    // page in [1, min(total_pages, randomPageCeiling)].

    /// Pure-helper tests for `resolveTargetPage`.

    func testResolveTargetPageClampsToTotalPages() {
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 3,
            randomSource: { range in range.upperBound }
        )
        XCTAssertEqual(page, 3,
                       "When total_pages is below randomPageCeiling, the random pick must not exceed total_pages")
    }

    func testResolveTargetPageClampsToRandomPageCeiling() {
        // total_pages > ceiling — random pick should saturate at the ceiling.
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 500,
            randomSource: { range in range.upperBound }
        )
        XCTAssertEqual(page, DiscoverFilter.randomPageCeiling,
                       "When total_pages exceeds the ceiling, the random pick must not exceed the ceiling")
    }

    func testResolveTargetPageHandlesZeroTotalPages() {
        // TMDB returns total_pages=0 for completely empty queries.
        // The action should still request page=1 (which returns an empty
        // result), not page=0 (which is invalid and would 400).
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 0,
            randomSource: { range in range.lowerBound }
        )
        XCTAssertEqual(page, 1,
                       "total_pages=0 must still produce a page>=1 request")
    }

    func testResolveTargetPageRespectsInjectedRandomSource() {
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 10,
            randomSource: { _ in 7 }
        )
        XCTAssertEqual(page, 7)
    }

    /// Integration test: when the probe returns `total_pages == 1`, the
    /// action must NOT fire a second network request — it should dispatch
    /// `SetRandomDiscover` with the probe's response directly. This saves
    /// a request and matches the old single-fetch behavior for queries
    /// with only one page of results.
    func testFetchRandomDiscoverSinglePageProbeDispatchesWithoutSecondFetch() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makeMovie(id: 90)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRandomDiscoverSinglePage")
        )

        let filter = DiscoverFilter(
            year: 2000, startYear: nil, endYear: nil,
            sort: "popularity.desc", genre: nil, region: nil
        )
        let dispatched = captureDispatches(
            waitingFor: "SetRandomDiscover dispatched",
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(
                filter: filter,
                randomSource: { _ in 1 }  // doesn't matter — total_pages=1 short-circuits
            ).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        XCTAssertEqual(action.response.results.first?.id, 90)
        XCTAssertEqual(session.allRequests.count, 1,
                       "Single-page probe must not trigger a second fetch")
    }

    /// Integration test: when the probe returns `total_pages > 1` AND the
    /// injected `randomSource` picks page != 1, the action must fire a
    /// SECOND network request with the new page, and dispatch
    /// `SetRandomDiscover` carrying the second response (not the probe).
    /// This is the core two-phase behavior that fixes the 400 bug.
    func testFetchRandomDiscoverMultiPageProbeFiresSecondFetch() throws {
        let session = MockNetworkSession()
        let probeData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 50, total_pages: 5, results: [makeMovie(id: 100)])
        )
        let phase2Data = try JSONEncoder().encode(
            PaginatedResponse(page: 3, total_results: 50, total_pages: 5, results: [makeMovie(id: 200)])
        )
        session.responseQueue = [
            (probeData, nil, nil),
            (phase2Data, nil, nil)
        ]

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRandomDiscoverMultiPage")
        )

        let filter = DiscoverFilter(
            year: 2000, startYear: nil, endYear: nil,
            sort: "popularity.desc", genre: nil, region: nil
        )
        let dispatched = captureDispatches(
            waitingFor: "SetRandomDiscover dispatched",
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(
                filter: filter,
                randomSource: { _ in 3 }  // force page 3 → triggers phase-2 fetch
            ).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        XCTAssertEqual(action.response.results.first?.id, 200,
                       "SetRandomDiscover should carry the SECOND fetch's response, not the probe")
        XCTAssertEqual(session.allRequests.count, 2,
                       "Multi-page probe must trigger a second fetch")

        // Verify the two requests asked for different pages.
        let pages = session.allRequests.compactMap { request -> String? in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "page" })?.value
        }
        XCTAssertEqual(pages, ["1", "3"],
                       "Probe should request page=1, then phase 2 should request the random page (3)")
    }

    /// If the probe itself fails (network error, 401, etc.), the action
    /// must dispatch `SetLoadingState(.failed)` and NOT fire a phase-2
    /// request. This is the existing failure contract — the two-phase
    /// rewrite must not regress it.
    func testFetchRandomDiscoverProbeFailureDispatchesFailureAndSkipsSecondFetch() throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRandomDiscoverProbeFailure")
        )

        let filter = DiscoverFilter(
            year: 2000, startYear: nil, endYear: nil,
            sort: "popularity.desc", genre: nil, region: nil
        )
        let dispatched = captureDispatches(
            waitingFor: "SetLoadingState(.failed) for randomDiscover",
            until: { isFailedSetLoading($0, for: .randomDiscover) }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(filter: filter)
                .execute(state: nil, dispatch: dispatch)
        }

        let _ = try assertFailureDispatch(
            in: dispatched,
            for: .randomDiscover,
            noDataActionMatching: { $0 is MoviesActions.SetRandomDiscover },
            dataActionDescription: "SetRandomDiscover"
        )
        XCTAssertEqual(session.allRequests.count, 1,
                       "Probe failure must not trigger a second fetch")
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

/// Free-function predicate so the trigger closures stay readable. Returns
/// true iff `action` is a `SetLoadingState(.failed)` for the given key.
private func isFailedSetLoading(_ action: Action, for key: LoadingKey) -> Bool {
    guard let setLoading = action as? MoviesActions.SetLoadingState,
          setLoading.key == key,
          case .failed = setLoading.state else { return false }
    return true
}

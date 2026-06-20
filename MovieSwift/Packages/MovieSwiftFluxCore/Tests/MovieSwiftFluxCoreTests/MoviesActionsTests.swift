import Testing
import Foundation
import Backend
@testable import MovieSwiftFluxCore

// `.serialized`: every test mutates the shared global `APIService.shared`,
// and Swift Testing runs tests in parallel by default. Serializing keeps the
// snapshot/restore in init/deinit consistent across tests.

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
@Suite(.serialized)
final class MoviesActionsTests {
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
        var responseQueue: [(Data?, URLResponse?, Error?)] = [] // swiftlint:disable:this large_tuple

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
            // Test stub: request.url is set by the SUT, and a 200 status with
            // valid args always yields a non-nil HTTPURLResponse.
            // swiftlint:disable force_unwrapping
            let resolvedResponse = response
                ?? HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
            // swiftlint:enable force_unwrapping
            return (data ?? Data(), resolvedResponse)
        }
    }

    private enum StubError: Error {
        case failed
    }

    private let originalAPIService: APIService

    init() {
        originalAPIService = APIService.shared
    }

    deinit {
        APIService.shared = originalAPIService
    }

    // MARK: - Dispatch capture helper

    /// Runs an AsyncAction against the synchronous mock session and collects
    /// every action it dispatches, returning once `trigger` matches one of
    /// them (or after a 2s safety timeout). Bridges the completion-handler
    /// dispatch flow to async/await; a lock guards the cross-thread mutation
    /// and a class box carries the non-Sendable `[Action]` across the
    /// continuation.
    private func captureDispatches(
        until trigger: @escaping (Action) -> Bool,
        when execute: (@escaping DispatchFunction) -> Void
    ) async -> [Action] {
        final class Collector: @unchecked Sendable {
            let lock = NSLock()
            var dispatched: [Action] = []
            var didResume = false
        }
        struct Box: @unchecked Sendable { let actions: [Action] }
        let collector = Collector()
        return await withCheckedContinuation { (continuation: CheckedContinuation<Box, Never>) in
            execute { action in
                collector.lock.lock()
                collector.dispatched.append(action)
                let shouldResume = trigger(action) && !collector.didResume
                if shouldResume { collector.didResume = true }
                let snapshot = collector.dispatched
                collector.lock.unlock()
                if shouldResume { continuation.resume(returning: Box(actions: snapshot)) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                collector.lock.lock()
                let shouldResume = !collector.didResume
                if shouldResume { collector.didResume = true }
                let snapshot = collector.dispatched
                collector.lock.unlock()
                if shouldResume { continuation.resume(returning: Box(actions: snapshot)) }
            }
        }.actions
    }

    /// Find the first dispatched action of the given type, or fail the test if
    /// none was dispatched.
    private func unwrapDispatched<T>(
        _ type: T.Type,
        in dispatched: [Action],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> T {
        let matches = dispatched.compactMap { $0 as? T }
        return try #require(matches.first,
                            "Expected one \(T.self) in dispatched actions, got: \(dispatched)",
                            sourceLocation: sourceLocation)
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
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> MoviesListLoadFailure {
        let unwantedDataAction = dispatched.first(where: matches)
        #expect(unwantedDataAction == nil,
                "Failure path unexpectedly dispatched a \(dataActionDescription) data action.",
                sourceLocation: sourceLocation)
        let loadingStates = dispatched.compactMap { $0 as? MoviesActions.SetLoadingState }
        let lastForKey = loadingStates.last { $0.key == key }
        let unwrapped = try #require(lastForKey,
                                     "No SetLoadingState dispatched for key \(key); got: \(loadingStates)",
                                     sourceLocation: sourceLocation)
        guard case let .failed(failure) = unwrapped.state else {
            Issue.record("Last SetLoadingState for \(key) was \(String(describing: unwrapped.state)), not .failed",
                         sourceLocation: sourceLocation)
            throw StubError.failed
        }
        return failure
    }

    // MARK: - FetchMoviesMenuList

    @Test func fetchMoviesMenuListDispatchesSetMovieMenuListOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 20)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchList")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetMovieMenuList }
        ) { dispatch in
            MoviesActions.FetchMoviesMenuList(list: .popular, page: 2)
                .execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieMenuList.self, in: dispatched)
        #expect(action.page == 2)
        #expect(action.list == .popular)
        #expect(action.response.results.map(\.id) == [20])
        #expect(session.lastRequest != nil, "expected the request to be issued")

        let requestURL = try #require(session.lastRequest?.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(components.path.contains("/movie/popular"))
        #expect(queryItems["api_key"] == "test-key")
        #expect(queryItems["page"] == "2")
        #expect(queryItems["region"] == AppUserDefaults.region)
    }

    @Test func fetchMoviesMenuListDispatchesFailureWhenAPIKeyMissing() async throws {
        let session = MockNetworkSession()

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider(nil),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.missingAPIKey")
        )

        let dispatched = await captureDispatches(
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
        #expect(failure.kind == .missingAPIKey)
        // Missing API key short-circuits in APIService.GET — no network call.
        #expect(session.lastRequest == nil)
    }

    @Test func fetchMoviesMenuListDispatchesFailureOnNetworkError() async throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.networkFailure")
        )

        let dispatched = await captureDispatches(
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
        #expect(session.lastRequest != nil, "expected the request to be issued")
    }

    @Test func fetchMoviesMenuListDispatchesFailureOnDecodingError() async throws {
        let session = MockNetworkSession()
        session.nextData = Data("not-json".utf8)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.decodingFailure")
        )

        let dispatched = await captureDispatches(
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
        #expect(failure.kind == .decode)
        #expect(session.lastRequest != nil, "expected the request to be issued")
    }

    // MARK: - FetchGenres

    @Test func fetchGenresDispatchesSetGenresOnSuccess() async throws {
        let session = MockNetworkSession()
        let payload = #"{"genres":[{"id":12,"name":"Adventure"},{"id":18,"name":"Drama"}]}"#
        session.nextData = Data(payload.utf8)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchGenres")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetGenres }
        ) { dispatch in
            MoviesActions.FetchGenres().execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetGenres.self, in: dispatched)
        #expect(action.genres.map(\.id) == [12, 18])
        #expect(action.genres.map(\.name) == ["Adventure", "Drama"])
        #expect(session.lastRequest != nil, "expected the request to be issued")

        let requestURL = try #require(session.lastRequest?.url)
        #expect(requestURL.path.contains("/genre/movie/list"))
    }

    @Test func fetchGenresDispatchesFailureOnError() async throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.genresFailure")
        )

        let dispatched = await captureDispatches(
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
        #expect(session.lastRequest != nil, "expected the request to be issued")
    }

    // MARK: - FetchDetail

    @Test func fetchDetailDispatchesSetDetailOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(makeMovie(id: 42))

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchDetail")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetDetail }
        ) { dispatch in
            MoviesActions.FetchDetail(movie: 42).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetDetail.self, in: dispatched)
        #expect(action.movie == 42)
        #expect(action.response.id == 42)

        let requestURL = try #require(session.lastRequest?.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        #expect(components.path.contains("/movie/42"))
        let queryItems = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(queryItems["append_to_response"] == "keywords,images")
    }

    @Test func fetchDetailDispatchesFailureOnError() async throws {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchDetailFailure")
        )

        let dispatched = await captureDispatches(
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

    @Test func fetchRecommendedDispatchesSetRecommendedOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 10)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRecommended")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetRecommended }
        ) { dispatch in
            MoviesActions.FetchRecommended(movie: 5).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRecommended.self, in: dispatched)
        #expect(action.movie == 5)
        #expect(action.response.results.map(\.id) == [10])
    }

    // MARK: - FetchSimilar

    @Test func fetchSimilarDispatchesSetSimilarOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 11)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchSimilar")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetSimilar }
        ) { dispatch in
            MoviesActions.FetchSimilar(movie: 6).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetSimilar.self, in: dispatched)
        #expect(action.movie == 6)
        #expect(action.response.results.map(\.id) == [11])
    }

    // MARK: - FetchVideos

    @Test func fetchVideosDispatchesSetVideosOnSuccess() async throws {
        let session = MockNetworkSession()
        let video = Video(id: "v1", name: "Trailer", site: "YouTube", key: "abc", type: "Trailer")
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [video])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchVideos")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetVideos }
        ) { dispatch in
            MoviesActions.FetchVideos(movie: 7).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetVideos.self, in: dispatched)
        #expect(action.movie == 7)
        #expect(action.response.results.first?.key == "abc")
    }

    // MARK: - FetchSearch

    @Test func fetchSearchDispatchesSetSearchOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 2, totalResults: 1, totalPages: 2, results: [makeMovie(id: 30)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchSearch")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetSearch }
        ) { dispatch in
            MoviesActions.FetchSearch(query: "test", page: 2).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetSearch.self, in: dispatched)
        #expect(action.query == "test")
        #expect(action.page == 2)
        #expect(action.response.results.first?.id == 30)
    }

    // MARK: - FetchSearchKeyword

    @Test func fetchSearchKeywordDispatchesSetSearchKeywordOnSuccess() async throws {
        let session = MockNetworkSession()
        let keyword = Keyword(id: 50, name: "neo-noir")
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [keyword])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchSearchKeyword")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetSearchKeyword }
        ) { dispatch in
            MoviesActions.FetchSearchKeyword(query: "noir").execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetSearchKeyword.self, in: dispatched)
        #expect(action.query == "noir")
        #expect(action.response.results.first?.name == "neo-noir")
    }

    // MARK: - FetchMoviesGenre

    @Test func fetchMoviesGenreDispatchesSetMovieForGenreOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 40)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchMoviesGenre")
        )

        let genre = Genre(id: 28, name: "Action")
        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetMovieForGenre }
        ) { dispatch in
            MoviesActions.FetchMoviesGenre(genre: genre, page: 1, sortBy: .byPopularity)
                .execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieForGenre.self, in: dispatched)
        #expect(action.genre.id == 28)
        #expect(action.page == 1)
        #expect(action.response.results.first?.id == 40)
    }

    // MARK: - FetchMovieReviews

    @Test func fetchMovieReviewsDispatchesSetMovieReviewsOnSuccess() async throws {
        let session = MockNetworkSession()
        let review = Review(id: "r1", author: "Critic", content: "Great movie")
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [review])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchReviews")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetMovieReviews }
        ) { dispatch in
            MoviesActions.FetchMovieReviews(movie: 8).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieReviews.self, in: dispatched)
        #expect(action.movie == 8)
        #expect(action.response.results.first?.author == "Critic")
    }

    // MARK: - FetchMovieWithCrew

    @Test func fetchMovieWithCrewDispatchesSetMovieWithCrewOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 50)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchMovieWithCrew")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetMovieWithCrew }
        ) { dispatch in
            MoviesActions.FetchMovieWithCrew(crew: 15).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieWithCrew.self, in: dispatched)
        #expect(action.crew == 15)
        #expect(action.response.results.first?.id == 50)
    }

    // MARK: - FetchMovieWithKeywords

    @Test func fetchMovieWithKeywordsDispatchesSetMovieWithKeywordOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 2, totalResults: 1, totalPages: 2, results: [makeMovie(id: 60)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchMovieWithKeywords")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetMovieWithKeyword }
        ) { dispatch in
            MoviesActions.FetchMovieWithKeywords(keyword: 99, page: 2)
                .execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetMovieWithKeyword.self, in: dispatched)
        #expect(action.keyword == 99)
        #expect(action.page == 2)
        #expect(action.response.results.first?.id == 60)
    }

    // MARK: - FetchRandomDiscover

    @Test func fetchRandomDiscoverDispatchesSetRandomDiscoverOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 70)])
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
        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(filter: filter).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        #expect(action.filter.year == 2000)
        #expect(action.response.results.first?.id == 70)
    }

    @Test func fetchRandomDiscoverUsesRandomFilterWhenNilProvided() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 80)])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "MoviesActionsTests.fetchRandomDiscoverNilFilter")
        )

        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(filter: nil).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        #expect(action.filter.year >= 1950)
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

    @Test func resolveTargetPageClampsToTotalPages() async throws {
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 3,
            randomSource: { range in range.upperBound }
        )
        #expect(page == 3,
                "When total_pages is below randomPageCeiling, the random pick must not exceed total_pages")
    }

    @Test func resolveTargetPageClampsToRandomPageCeiling() async throws {
        // total_pages > ceiling — random pick should saturate at the ceiling.
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 500,
            randomSource: { range in range.upperBound }
        )
        #expect(page == DiscoverFilter.randomPageCeiling,
                "When total_pages exceeds the ceiling, the random pick must not exceed the ceiling")
    }

    @Test func resolveTargetPageHandlesZeroTotalPages() async throws {
        // TMDB returns total_pages=0 for completely empty queries.
        // The action should still request page=1 (which returns an empty
        // result), not page=0 (which is invalid and would 400).
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 0,
            randomSource: { range in range.lowerBound }
        )
        #expect(page == 1,
                "total_pages=0 must still produce a page>=1 request")
    }

    @Test func resolveTargetPageRespectsInjectedRandomSource() async throws {
        let page = MoviesActions.FetchRandomDiscover.resolveTargetPage(
            totalPages: 10,
            randomSource: { _ in 7 }
        )
        #expect(page == 7)
    }

    /// Integration test: when the probe returns `total_pages == 1`, the
    /// action must NOT fire a second network request — it should dispatch
    /// `SetRandomDiscover` with the probe's response directly. This saves
    /// a request and matches the old single-fetch behavior for queries
    /// with only one page of results.
    @Test func fetchRandomDiscoverSinglePageProbeDispatchesWithoutSecondFetch() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makeMovie(id: 90)])
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
        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(
                filter: filter,
                randomSource: { _ in 1 }  // doesn't matter — total_pages=1 short-circuits
            ).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        #expect(action.response.results.first?.id == 90)
        #expect(session.allRequests.count == 1,
                "Single-page probe must not trigger a second fetch")
    }

    /// Integration test: when the probe returns `total_pages > 1` AND the
    /// injected `randomSource` picks page != 1, the action must fire a
    /// SECOND network request with the new page, and dispatch
    /// `SetRandomDiscover` carrying the second response (not the probe).
    /// This is the core two-phase behavior that fixes the 400 bug.
    @Test func fetchRandomDiscoverMultiPageProbeFiresSecondFetch() async throws {
        let session = MockNetworkSession()
        let probeData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 50, totalPages: 5, results: [makeMovie(id: 100)])
        )
        let phase2Data = try JSONEncoder().encode(
            PaginatedResponse(page: 3, totalResults: 50, totalPages: 5, results: [makeMovie(id: 200)])
        )
        session.responseQueue = [
            (probeData, nil, nil),
            (phase2Data, nil, nil),
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
        let dispatched = await captureDispatches(
            until: { $0 is MoviesActions.SetRandomDiscover }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(
                filter: filter,
                randomSource: { _ in 3 }  // force page 3 → triggers phase-2 fetch
            ).execute(state: nil, dispatch: dispatch)
        }

        let action = try unwrapDispatched(MoviesActions.SetRandomDiscover.self, in: dispatched)
        #expect(action.response.results.first?.id == 200,
                "SetRandomDiscover should carry the SECOND fetch's response, not the probe")
        #expect(session.allRequests.count == 2,
                "Multi-page probe must trigger a second fetch")

        // Verify the two requests asked for different pages.
        let pages = session.allRequests.compactMap { request -> String? in
            guard let url = request.url else { return nil }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "page" })?.value
        }
        #expect(pages == ["1", "3"],
                "Probe should request page=1, then phase 2 should request the random page (3)")
    }

    /// If the probe itself fails (network error, 401, etc.), the action
    /// must dispatch `SetLoadingState(.failed)` and NOT fire a phase-2
    /// request. This is the existing failure contract — the two-phase
    /// rewrite must not regress it.
    @Test func fetchRandomDiscoverProbeFailureDispatchesFailureAndSkipsSecondFetch() async throws {
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
        let dispatched = await captureDispatches(
            until: { isFailedSetLoading($0, for: .randomDiscover) }
        ) { dispatch in
            MoviesActions.FetchRandomDiscover(filter: filter)
                .execute(state: nil, dispatch: dispatch)
        }

        _ = try assertFailureDispatch(
            in: dispatched,
            for: .randomDiscover,
            noDataActionMatching: { $0 is MoviesActions.SetRandomDiscover },
            dataActionDescription: "SetRandomDiscover"
        )
        #expect(session.allRequests.count == 1,
                "Probe failure must not trigger a second fetch")
    }

    // MARK: - Helpers

    private func makeMovie(id: Int) -> Movie {
        Movie(
            id: id,
            originalTitle: "Original \(id)",
            title: "Title \(id)",
            overview: "Overview \(id)",
            posterPath: nil,
            backdropPath: nil,
            popularity: 1.0,
            voteAverage: 2.0,
            voteCount: 3,
            releaseDateString: "2020-01-01",
            genres: nil,
            runtime: nil,
            status: nil,
            video: false,
            keywords: nil,
            images: nil,
            productionCountries: nil,
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

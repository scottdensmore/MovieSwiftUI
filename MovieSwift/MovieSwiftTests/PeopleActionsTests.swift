import Testing
import Foundation
import Backend
import MovieSwiftFluxCore
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `.serialized` + final class: every test swaps the shared global
// `APIService.shared`, so the suite can't run in parallel, and init/deinit
// snapshot & restore that value as per-test setup/teardown.
@Suite(.serialized)
final class PeopleActionsTests {
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
        var nextData: Data?
        var nextResponse: URLResponse?
        var nextError: Error?

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            lastRequest = request
            if let nextError { throw nextError }
            // Test stub: request.url is set by the SUT, and a 200 status with
            // valid args always yields a non-nil HTTPURLResponse.
            // swiftlint:disable force_unwrapping
            let response = nextResponse
                ?? HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
            // swiftlint:enable force_unwrapping
            return (nextData ?? Data(), response)
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

    // MARK: - Dispatch capture helpers
    //
    // The AsyncAction `execute(state:dispatch:)` flow funnels through
    // `APIService.GET`'s completion handler, which fires on a background
    // callback queue. These bridge that to async/await: a lock guards the
    // cross-thread mutation, and a class box carries the non-Sendable
    // `[Action]` across the continuation.

    private final class DispatchCollector: @unchecked Sendable {
        let lock = NSLock()
        var dispatched: [Action] = []
        var didResume = false
    }

    private struct ActionsBox: @unchecked Sendable {
        let actions: [Action]
    }

    /// Collects dispatched actions, returning once `trigger` matches one of
    /// them (or after a 2s safety timeout).
    private func collectDispatches(
        until trigger: @escaping (Action) -> Bool,
        when execute: (@escaping DispatchFunction) -> Void
    ) async -> [Action] {
        let collector = DispatchCollector()
        return await withCheckedContinuation { (continuation: CheckedContinuation<ActionsBox, Never>) in
            execute { action in
                collector.lock.lock()
                collector.dispatched.append(action)
                let shouldResume = trigger(action) && !collector.didResume
                if shouldResume { collector.didResume = true }
                let snapshot = collector.dispatched
                collector.lock.unlock()
                if shouldResume { continuation.resume(returning: ActionsBox(actions: snapshot)) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                collector.lock.lock()
                let shouldResume = !collector.didResume
                if shouldResume { collector.didResume = true }
                let snapshot = collector.dispatched
                collector.lock.unlock()
                if shouldResume { continuation.resume(returning: ActionsBox(actions: snapshot)) }
            }
        }.actions
    }

    /// Collects everything dispatched within `seconds` and returns it — the
    /// async equivalent of an inverted XCTestExpectation (used to assert a
    /// particular data action is NOT dispatched on a failure path).
    private func collectDispatches(
        forSeconds seconds: Double,
        when execute: (@escaping DispatchFunction) -> Void
    ) async -> [Action] {
        let collector = DispatchCollector()
        return await withCheckedContinuation { (continuation: CheckedContinuation<ActionsBox, Never>) in
            execute { action in
                collector.lock.lock()
                collector.dispatched.append(action)
                collector.lock.unlock()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                collector.lock.lock()
                let snapshot = collector.dispatched
                collector.lock.unlock()
                continuation.resume(returning: ActionsBox(actions: snapshot))
            }
        }.actions
    }

    // MARK: - Parameterized failure-path coverage
    //
    // All five "FetchX" AsyncActions share the same failure-side shape: on a
    // network error, the corresponding `SetX` data action must NOT be
    // dispatched (the success path is asserted per-action below, since each
    // verifies action-specific fields). Parameterizing over a `Sendable`
    // enum + instance-method switch (rather than a struct of @Sendable
    // closures) keeps `DispatchFunction` — a non-Sendable function type —
    // off the `@Test(arguments:)` boundary.
    private enum FailureFetchKind: String, Sendable, CaseIterable {
        case fetchDetail = "FetchDetail"
        case fetchImages = "FetchImages"
        case fetchPeopleCredits = "FetchPeopleCredits"
        case fetchMovieCasts = "FetchMovieCasts"
        case fetchSearch = "FetchSearch"
    }

    private func execute(_ kind: FailureFetchKind, dispatch: @escaping DispatchFunction) {
        switch kind {
        case .fetchDetail:
            PeopleActions.FetchDetail(people: 5).execute(state: nil, dispatch: dispatch)
        case .fetchImages:
            PeopleActions.FetchImages(people: 7).execute(state: nil, dispatch: dispatch)
        case .fetchPeopleCredits:
            PeopleActions.FetchPeopleCredits(people: 3).execute(state: nil, dispatch: dispatch)
        case .fetchMovieCasts:
            PeopleActions.FetchMovieCasts(movie: 99).execute(state: nil, dispatch: dispatch)
        case .fetchSearch:
            PeopleActions.FetchSearch(query: "bob", page: 1).execute(state: nil, dispatch: dispatch)
        }
    }

    private func isDataAction(_ kind: FailureFetchKind, _ action: Action) -> Bool {
        switch kind {
        case .fetchDetail: return action is PeopleActions.SetDetail
        case .fetchImages: return action is PeopleActions.SetImages
        case .fetchPeopleCredits: return action is PeopleActions.SetPeopleCredits
        case .fetchMovieCasts: return action is PeopleActions.SetMovieCasts
        case .fetchSearch: return action is PeopleActions.SetSearch
        }
    }

    /// Failure path coverage for every "fetch + dispatch SetX" action in
    /// the suite. On a network failure, the AsyncAction's data action
    /// (`SetDetail`, `SetImages`, `SetPeopleCredits`, `SetMovieCasts`,
    /// `SetSearch`) must NOT be dispatched. The corresponding success
    /// tests live as individual `@Test` methods further below because
    /// each verifies action-specific fields.
    @Test(arguments: FailureFetchKind.allCases)
    private func fetchActionDoesNotDispatchDataActionOnFailure(kind: FailureFetchKind) async {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.\(kind.rawValue)Failure")
        )

        let dispatched = await collectDispatches(forSeconds: 0.2) { dispatch in
            execute(kind, dispatch: dispatch)
        }

        #expect(!dispatched.contains { isDataAction(kind, $0) },
                "\(kind.rawValue): SetX data action should not be dispatched on failure")
    }

    // MARK: - FetchDetail

    @Test func fetchDetailDispatchesSetDetailOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(makePeople(id: 5, name: "Alice"))

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchDetail")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.SetDetail }) { dispatch in
            PeopleActions.FetchDetail(people: 5).execute(state: nil, dispatch: dispatch)
        }

        let dispatchedAction = dispatched.compactMap { $0 as? PeopleActions.SetDetail }.first
        #expect(dispatchedAction?.person.id == 5)
        #expect(dispatchedAction?.person.name == "Alice")
        #expect(session.lastRequest != nil, "expected the request to be issued")

        let requestURL = try #require(session.lastRequest?.url)
        #expect(requestURL.path.contains("/person/5"))
    }

    // MARK: - FetchImages

    @Test func fetchImagesDispatchesSetImagesOnSuccess() async throws {
        let session = MockNetworkSession()
        let payload = PeopleActions.ImagesResponse(
            id: 7,
            profiles: [ImageData(aspectRatio: 0.67, filePath: "/img.jpg", height: 300, width: 200)]
        )
        session.nextData = try JSONEncoder().encode(payload)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchImages")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.SetImages }) { dispatch in
            PeopleActions.FetchImages(people: 7).execute(state: nil, dispatch: dispatch)
        }

        let dispatchedAction = dispatched.compactMap { $0 as? PeopleActions.SetImages }.first
        #expect(dispatchedAction?.people == 7)
        #expect(dispatchedAction?.images.count == 1)
        #expect(dispatchedAction?.images.first?.filePath == "/img.jpg")
    }

    // MARK: - FetchPeopleCredits

    @Test func fetchPeopleCreditsDispatchesSetPeopleCreditsOnSuccess() async throws {
        let session = MockNetworkSession()
        let payload = PeopleActions.PeopleCreditsResponse(
            cast: [makeMovie(id: 10, character: "Hero")],
            crew: [makeMovie(id: 20, department: "Directing")]
        )
        session.nextData = try JSONEncoder().encode(payload)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchCredits")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.SetPeopleCredits }) { dispatch in
            PeopleActions.FetchPeopleCredits(people: 3).execute(state: nil, dispatch: dispatch)
        }

        let dispatchedAction = dispatched.compactMap { $0 as? PeopleActions.SetPeopleCredits }.first
        #expect(dispatchedAction?.people == 3)
        #expect(dispatchedAction?.response.cast?.first?.id == 10)
        #expect(dispatchedAction?.response.crew?.first?.id == 20)
    }

    // MARK: - FetchMovieCasts

    @Test func fetchMovieCastsDispatchesSetMovieCastsOnSuccess() async throws {
        let session = MockNetworkSession()
        let payload = CastResponse(
            id: 99,
            cast: [makePeople(id: 1, name: "Actor")],
            crew: [makePeople(id: 2, name: "Director")]
        )
        session.nextData = try JSONEncoder().encode(payload)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchMovieCasts")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.SetMovieCasts }) { dispatch in
            PeopleActions.FetchMovieCasts(movie: 99).execute(state: nil, dispatch: dispatch)
        }

        let dispatchedAction = dispatched.compactMap { $0 as? PeopleActions.SetMovieCasts }.first
        #expect(dispatchedAction?.movie == 99)
        #expect(dispatchedAction?.response.cast.first?.name == "Actor")
        #expect(dispatchedAction?.response.crew.first?.name == "Director")

        let requestURL = try #require(session.lastRequest?.url)
        #expect(requestURL.path.contains("/movie/99/credits"))
    }

    // MARK: - FetchSearch

    @Test func fetchSearchDispatchesSetSearchOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makePeople(id: 10, name: "Bob")])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchSearch")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.SetSearch }) { dispatch in
            PeopleActions.FetchSearch(query: "bob", page: 1).execute(state: nil, dispatch: dispatch)
        }

        let dispatchedAction = dispatched.compactMap { $0 as? PeopleActions.SetSearch }.first
        #expect(dispatchedAction?.query == "bob")
        #expect(dispatchedAction?.page == 1)
        #expect(dispatchedAction?.response.results.first?.name == "Bob")
    }

    // MARK: - FetchPopular

    @Test func fetchPopularDispatchesPopularRequestStartedThenSetPopularOnSuccess() async throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [makePeople(id: 20, name: "Star")])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchPopular")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.SetPopular }) { dispatch in
            PeopleActions.FetchPopular(page: 1).execute(state: nil, dispatch: dispatch)
        }

        #expect(dispatched.first is PeopleActions.PopularRequestStarted)
        let setPopular = dispatched.last as? PeopleActions.SetPopular
        #expect(setPopular?.page == 1)
        #expect(setPopular?.response.results.first?.name == "Star")
    }

    @Test func fetchPopularDispatchesPopularRequestFailedOnFailure() async {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchPopularFailure")
        )

        let dispatched = await collectDispatches(until: { $0 is PeopleActions.PopularRequestFailed }) { dispatch in
            PeopleActions.FetchPopular(page: 2).execute(state: nil, dispatch: dispatch)
        }

        // FetchPopular now also dispatches SetLoadingState transitions
        // through makeTrackedHandler in addition to its existing
        // PopularRequestStarted / PopularRequestFailed pair. The
        // existing pair remains the source of truth for paginated
        // retry — we just verify it still fires as before.
        #expect(dispatched.contains { $0 is PeopleActions.PopularRequestStarted })
        let failed = dispatched.compactMap { $0 as? PeopleActions.PopularRequestFailed }.last
        #expect(failed?.page == 2)
    }

    // MARK: - Helpers

    private func makePeople(id: Int, name: String) -> People {
        People(
            id: id,
            name: name,
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
            images: nil
        )
    }

    private func makeMovie(id: Int, character: String? = nil, department: String? = nil) -> Movie {
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
            character: character,
            department: department
        )
    }
}

import XCTest
import Backend
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class PeopleActionsTests: XCTestCase {
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

    // MARK: - FetchDetail

    func testFetchDetailDispatchesSetDetailOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(makePeople(id: 5, name: "Alice"))

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchDetail")
        )

        let expectation = expectation(description: "Dispatch SetDetail")
        var dispatchedAction: PeopleActions.SetDetail?

        PeopleActions.FetchDetail(people: 5).execute(state: nil) { action in
            dispatchedAction = action as? PeopleActions.SetDetail
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.person.id, 5)
        XCTAssertEqual(dispatchedAction?.person.name, "Alice")
        XCTAssertEqual(session.task.resumeCalls, 1)

        let requestURL = try XCTUnwrap(session.lastRequest?.url)
        XCTAssertTrue(requestURL.path.contains("/person/5"))
    }

    func testFetchDetailDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextData = nil
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchDetailFailure")
        )

        let expectation = expectation(description: "No dispatch on detail failure")
        expectation.isInverted = true

        PeopleActions.FetchDetail(people: 5).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
        XCTAssertEqual(session.task.resumeCalls, 1)
    }

    // MARK: - FetchImages

    func testFetchImagesDispatchesSetImagesOnSuccess() throws {
        let session = MockNetworkSession()
        let payload = PeopleActions.ImagesResponse(
            id: 7,
            profiles: [ImageData(aspect_ratio: 0.67, file_path: "/img.jpg", height: 300, width: 200)]
        )
        session.nextData = try JSONEncoder().encode(payload)

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchImages")
        )

        let expectation = expectation(description: "Dispatch SetImages")
        var dispatchedAction: PeopleActions.SetImages?

        PeopleActions.FetchImages(people: 7).execute(state: nil) { action in
            dispatchedAction = action as? PeopleActions.SetImages
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.people, 7)
        XCTAssertEqual(dispatchedAction?.images.count, 1)
        XCTAssertEqual(dispatchedAction?.images.first?.file_path, "/img.jpg")
    }

    func testFetchImagesDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchImagesFailure")
        )

        let expectation = expectation(description: "No dispatch on images failure")
        expectation.isInverted = true

        PeopleActions.FetchImages(people: 7).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
    }

    // MARK: - FetchPeopleCredits

    func testFetchPeopleCreditsDispatchesSetPeopleCreditsOnSuccess() throws {
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

        let expectation = expectation(description: "Dispatch SetPeopleCredits")
        var dispatchedAction: PeopleActions.SetPeopleCredits?

        PeopleActions.FetchPeopleCredits(people: 3).execute(state: nil) { action in
            dispatchedAction = action as? PeopleActions.SetPeopleCredits
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.people, 3)
        XCTAssertEqual(dispatchedAction?.response.cast?.first?.id, 10)
        XCTAssertEqual(dispatchedAction?.response.crew?.first?.id, 20)
    }

    func testFetchPeopleCreditsDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchCreditsFailure")
        )

        let expectation = expectation(description: "No dispatch on credits failure")
        expectation.isInverted = true

        PeopleActions.FetchPeopleCredits(people: 3).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
    }

    // MARK: - FetchMovieCasts

    func testFetchMovieCastsDispatchesSetMovieCastsOnSuccess() throws {
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

        let expectation = expectation(description: "Dispatch SetMovieCasts")
        var dispatchedAction: PeopleActions.SetMovieCasts?

        PeopleActions.FetchMovieCasts(movie: 99).execute(state: nil) { action in
            dispatchedAction = action as? PeopleActions.SetMovieCasts
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.movie, 99)
        XCTAssertEqual(dispatchedAction?.response.cast.first?.name, "Actor")
        XCTAssertEqual(dispatchedAction?.response.crew.first?.name, "Director")

        let requestURL = try XCTUnwrap(session.lastRequest?.url)
        XCTAssertTrue(requestURL.path.contains("/movie/99/credits"))
    }

    func testFetchMovieCastsDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchMovieCastsFailure")
        )

        let expectation = expectation(description: "No dispatch on movie casts failure")
        expectation.isInverted = true

        PeopleActions.FetchMovieCasts(movie: 99).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
    }

    // MARK: - FetchSearch

    func testFetchSearchDispatchesSetSearchOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makePeople(id: 10, name: "Bob")])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchSearch")
        )

        let expectation = expectation(description: "Dispatch SetSearch")
        var dispatchedAction: PeopleActions.SetSearch?

        PeopleActions.FetchSearch(query: "bob", page: 1).execute(state: nil) { action in
            dispatchedAction = action as? PeopleActions.SetSearch
            if dispatchedAction != nil { expectation.fulfill() }
        }

        waitForExpectations(timeout: 1)

        XCTAssertEqual(dispatchedAction?.query, "bob")
        XCTAssertEqual(dispatchedAction?.page, 1)
        XCTAssertEqual(dispatchedAction?.response.results.first?.name, "Bob")
    }

    func testFetchSearchDoesNotDispatchOnFailure() {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchSearchFailure")
        )

        let expectation = expectation(description: "No dispatch on search failure")
        expectation.isInverted = true

        PeopleActions.FetchSearch(query: "bob", page: 1).execute(state: nil) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
    }

    // MARK: - FetchPopular

    func testFetchPopularDispatchesPopularRequestStartedThenSetPopularOnSuccess() throws {
        let session = MockNetworkSession()
        session.nextData = try JSONEncoder().encode(
            PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makePeople(id: 20, name: "Star")])
        )

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchPopular")
        )

        let expectation = expectation(description: "Dispatch SetPopular")
        var actions: [Any] = []

        PeopleActions.FetchPopular(page: 1).execute(state: nil) { action in
            actions.append(action)
            if action is PeopleActions.SetPopular {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1)

        XCTAssertTrue(actions.first is PeopleActions.PopularRequestStarted)
        let setPopular = actions.last as? PeopleActions.SetPopular
        XCTAssertEqual(setPopular?.page, 1)
        XCTAssertEqual(setPopular?.response.results.first?.name, "Star")
    }

    func testFetchPopularDispatchesPopularRequestFailedOnFailure() {
        let session = MockNetworkSession()
        session.nextError = StubError.failed

        APIService.shared = APIService(
            apiKeyProvider: StubAPIKeyProvider("test-key"),
            session: session,
            callbackQueue: DispatchQueue(label: "PeopleActionsTests.fetchPopularFailure")
        )

        let expectation = expectation(description: "Dispatch PopularRequestFailed")
        var actions: [Any] = []

        PeopleActions.FetchPopular(page: 2).execute(state: nil) { action in
            actions.append(action)
            if action is PeopleActions.PopularRequestFailed {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 1)

        XCTAssertTrue(actions.first is PeopleActions.PopularRequestStarted)
        let failed = actions.last as? PeopleActions.PopularRequestFailed
        XCTAssertEqual(failed?.page, 2)
    }

    // MARK: - Helpers

    private func makePeople(id: Int, name: String) -> People {
        People(
            id: id,
            name: name,
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
            images: nil
        )
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
}

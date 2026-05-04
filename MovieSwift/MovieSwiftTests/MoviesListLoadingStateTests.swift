import XCTest
import Backend
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class MoviesListLoadingStateTests: XCTestCase {

    // MARK: - APIError → MoviesListLoadFailure presenter

    func testPresenterMapsMissingAPIKeyToOpenSettings() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .missingAPIKey)
        XCTAssertEqual(failure.kind, .missingAPIKey)
        XCTAssertEqual(failure.retryActionTitle, "Open Settings",
                       "missingAPIKey should send the user to fix their key, not retry")
        XCTAssertTrue(failure.message.contains("Settings"))
    }

    func testPresenterMapsOfflineToConnectionMessage() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .offline)
        XCTAssertEqual(failure.kind, .offline)
        XCTAssertEqual(failure.retryActionTitle, "Try again")
        XCTAssertTrue(failure.message.lowercased().contains("offline"))
    }

    func testPresenterMapsRateLimitedWithKnownRetryAfterToCountdownText() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: 8))
        XCTAssertEqual(failure.kind, .rateLimited(retryAfterSeconds: 8))
        XCTAssertTrue(failure.message.contains("8 seconds"),
                      "Expected message to surface the retry-after seconds, got \(failure.message)")
    }

    func testPresenterMapsRateLimitedWithSingleSecondToSingularText() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: 1))
        XCTAssertTrue(failure.message.contains("1 second"))
        XCTAssertFalse(failure.message.contains("1 seconds"),
                       "Singular grammar matters in user-facing copy")
    }

    func testPresenterMapsRateLimitedWithUnknownRetryAfterToVagueText() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: nil))
        XCTAssertTrue(failure.message.lowercased().contains("moment"),
                      "Without a known retry-after, fall back to a vague 'try again in a moment'")
    }

    func testPresenterMapsHTTP401ToUnauthorizedKey() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: 401))
        XCTAssertEqual(failure.kind, .unauthorized)
        XCTAssertEqual(failure.retryActionTitle, "Open Settings")
    }

    func testPresenterMapsHTTP403ToForbidden() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: 403))
        XCTAssertEqual(failure.kind, .forbidden)
    }

    func testPresenterMapsHTTP500RangeToServer() {
        for code in [500, 502, 503, 599] {
            let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: code))
            XCTAssertEqual(failure.kind, .server, "HTTP \(code) should be classified as server")
            XCTAssertTrue(failure.message.contains("\(code)"),
                          "Server error messages should include the status code for diagnosis")
        }
    }

    func testPresenterMapsOtherHTTPCodesToOther() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: 418))
        XCTAssertEqual(failure.kind, .other)
        XCTAssertTrue(failure.message.contains("418"))
    }

    func testPresenterMapsDecodeErrorToDecodeKind() {
        struct StubError: Error {}
        let failure = MoviesListLoadFailurePresenter.failure(from: .jsonDecodingError(error: StubError()))
        XCTAssertEqual(failure.kind, .decode)
    }

    func testPresenterMapsNoResponseToOtherWithRetry() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .noResponse)
        XCTAssertEqual(failure.kind, .other)
        XCTAssertEqual(failure.retryActionTitle, "Try again")
    }

    // MARK: - Reducer integration

    func testReducerSetsLoadingStateOnSetMoviesMenuListLoading() {
        let initial = MoviesState()
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetMoviesMenuListLoading(list: .popular)
        )
        XCTAssertEqual(result.moviesListLoadingState[.popular], .loading)
    }

    func testReducerSetsFailureStateOnSetMoviesMenuListFailure() {
        let initial = MoviesState()
        let failure = MoviesListLoadFailure(kind: .offline, message: "offline")
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetMoviesMenuListFailure(list: .topRated, failure: failure)
        )
        XCTAssertEqual(result.moviesListLoadingState[.topRated], .failed(failure))
    }

    func testReducerClearsFailureStateOnSuccessfulFetch() {
        // Arrange: a menu currently sitting in a failed state.
        var initial = MoviesState()
        initial.moviesListLoadingState[.popular] = .failed(
            MoviesListLoadFailure(kind: .offline, message: "offline")
        )

        // Act: a successful response lands.
        let response = PaginatedResponse<Movie>(
            page: 1,
            total_results: 0,
            total_pages: 1,
            results: []
        )
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetMovieMenuList(page: 1,
                                                   list: .popular,
                                                   response: response)
        )

        // Assert: the entry is gone — UI banner disappears.
        XCTAssertNil(result.moviesListLoadingState[.popular])
    }

    func testReducerKeepsLoadingStatePerMenu() {
        // Two menus shouldn't trample each other's loading state.
        var state = MoviesState()
        state = moviesStateReducer(
            state: state,
            action: MoviesActions.SetMoviesMenuListLoading(list: .popular)
        )
        let failure = MoviesListLoadFailure(kind: .server, message: "500")
        state = moviesStateReducer(
            state: state,
            action: MoviesActions.SetMoviesMenuListFailure(list: .topRated, failure: failure)
        )
        XCTAssertEqual(state.moviesListLoadingState[.popular], .loading)
        XCTAssertEqual(state.moviesListLoadingState[.topRated], .failed(failure))
    }
}

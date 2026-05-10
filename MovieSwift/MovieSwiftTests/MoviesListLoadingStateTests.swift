import XCTest
import Backend
import MovieSwiftFluxCore
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

    func testReducerSetsLoadingStateForKey() {
        let initial = MoviesState()
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.popular),
                                                   state: .loading)
        )
        XCTAssertEqual(result.loadingStates[.homeMenu(.popular)], .loading)
    }

    func testReducerSetsFailureStateForKey() {
        let initial = MoviesState()
        let failure = MoviesListLoadFailure(kind: .offline, message: "offline")
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.topRated),
                                                   state: .failed(failure))
        )
        XCTAssertEqual(result.loadingStates[.homeMenu(.topRated)], .failed(failure))
    }

    func testReducerClearsLoadingStateWhenStateIsNil() {
        // Arrange: a menu currently sitting in a failed state.
        var initial = MoviesState()
        initial.loadingStates[.homeMenu(.popular)] = .failed(
            MoviesListLoadFailure(kind: .offline, message: "offline")
        )

        // Act: nil-state clears the entry — used by the success path
        // in `makeTrackedHandler` so the banner disappears on retry
        // success.
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.popular),
                                                   state: nil)
        )

        XCTAssertNil(result.loadingStates[.homeMenu(.popular)])
    }

    func testReducerKeepsLoadingStatePerKey() {
        // Different keys shouldn't trample each other's state.
        var state = MoviesState()
        state = moviesStateReducer(
            state: state,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.popular),
                                                   state: .loading)
        )
        let failure = MoviesListLoadFailure(kind: .server, message: "500")
        state = moviesStateReducer(
            state: state,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.topRated),
                                                   state: .failed(failure))
        )
        XCTAssertEqual(state.loadingStates[.homeMenu(.popular)], .loading)
        XCTAssertEqual(state.loadingStates[.homeMenu(.topRated)], .failed(failure))
    }

    func testReducerHandlesPeopleAndMovieKeysInTheSameDict() {
        // The unified LoadingKey enum spans both Movies and People
        // fetchers. Verify entries don't collide.
        var state = MoviesState()
        state = moviesStateReducer(
            state: state,
            action: MoviesActions.SetLoadingState(key: .movieDetail(42),
                                                   state: .loading)
        )
        state = moviesStateReducer(
            state: state,
            action: MoviesActions.SetLoadingState(key: .personDetail(42),
                                                   state: .failed(MoviesListLoadFailure(kind: .server, message: "500")))
        )
        XCTAssertEqual(state.loadingStates[.movieDetail(42)], .loading)
        if case .failed = state.loadingStates[.personDetail(42)] {
            // ok
        } else {
            XCTFail("Expected personDetail(42) to be in failed state")
        }
    }
}

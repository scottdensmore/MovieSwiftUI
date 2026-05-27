import Testing
import Backend
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

@Suite struct MoviesListLoadingStateTests {

    // MARK: - APIError → MoviesListLoadFailure presenter

    @Test func presenterMapsMissingAPIKeyToOpenSettings() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .missingAPIKey)
        #expect(failure.kind == .missingAPIKey)
        #expect(failure.retryActionTitle == "Open Settings",
                "missingAPIKey should send the user to fix their key, not retry")
        #expect(failure.message.contains("Settings"))
    }

    @Test func presenterMapsOfflineToConnectionMessage() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .offline)
        #expect(failure.kind == .offline)
        #expect(failure.retryActionTitle == "Try again")
        #expect(failure.message.lowercased().contains("offline"))
    }

    @Test func presenterMapsRateLimitedWithKnownRetryAfterToCountdownText() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: 8))
        #expect(failure.kind == .rateLimited(retryAfterSeconds: 8))
        #expect(failure.message.contains("8 seconds"),
                "Expected message to surface the retry-after seconds, got \(failure.message)")
    }

    @Test func presenterMapsRateLimitedWithSingleSecondToSingularText() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: 1))
        #expect(failure.message.contains("1 second"))
        #expect(!(failure.message.contains("1 seconds")),
                "Singular grammar matters in user-facing copy")
    }

    @Test func presenterMapsRateLimitedWithUnknownRetryAfterToVagueText() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: nil))
        #expect(failure.message.lowercased().contains("moment"),
                "Without a known retry-after, fall back to a vague 'try again in a moment'")
    }

    @Test func presenterMapsHTTP401ToUnauthorizedKey() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: 401))
        #expect(failure.kind == .unauthorized)
        #expect(failure.retryActionTitle == "Open Settings")
    }

    @Test func presenterMapsHTTP403ToForbidden() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: 403))
        #expect(failure.kind == .forbidden)
    }

    @Test func presenterMapsHTTP500RangeToServer() {
        for code in [500, 502, 503, 599] {
            let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: code))
            #expect(failure.kind == .server, "HTTP \(code) should be classified as server")
            #expect(failure.message.contains("\(code)"),
                    "Server error messages should include the status code for diagnosis")
        }
    }

    @Test func presenterMapsOtherHTTPCodesToOther() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .httpStatus(code: 418))
        #expect(failure.kind == .other)
        #expect(failure.message.contains("418"))
    }

    @Test func presenterMapsDecodeErrorToDecodeKind() {
        struct StubError: Error {}
        let failure = MoviesListLoadFailurePresenter.failure(from: .jsonDecodingError(error: StubError()))
        #expect(failure.kind == .decode)
    }

    @Test func presenterMapsNoResponseToOtherWithRetry() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .noResponse)
        #expect(failure.kind == .other)
        #expect(failure.retryActionTitle == "Try again")
    }

    // MARK: - Reducer integration

    @Test func reducerSetsLoadingStateForKey() {
        let initial = MoviesState()
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.popular),
                                                   state: .loading)
        )
        #expect(result.loadingStates[.homeMenu(.popular)] == .loading)
    }

    @Test func reducerSetsFailureStateForKey() {
        let initial = MoviesState()
        let failure = MoviesListLoadFailure(kind: .offline, message: "offline")
        let result = moviesStateReducer(
            state: initial,
            action: MoviesActions.SetLoadingState(key: .homeMenu(.topRated),
                                                   state: .failed(failure))
        )
        #expect(result.loadingStates[.homeMenu(.topRated)] == .failed(failure))
    }

    @Test func reducerClearsLoadingStateWhenStateIsNil() {
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

        #expect(result.loadingStates[.homeMenu(.popular)] == nil)
    }

    @Test func reducerKeepsLoadingStatePerKey() {
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
        #expect(state.loadingStates[.homeMenu(.popular)] == .loading)
        #expect(state.loadingStates[.homeMenu(.topRated)] == .failed(failure))
    }

    @Test func reducerHandlesPeopleAndMovieKeysInTheSameDict() {
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
        #expect(state.loadingStates[.movieDetail(42)] == .loading)
        if case .failed = state.loadingStates[.personDetail(42)] {
            // ok
        } else {
            Issue.record("Expected personDetail(42) to be in failed state")
        }
    }
}

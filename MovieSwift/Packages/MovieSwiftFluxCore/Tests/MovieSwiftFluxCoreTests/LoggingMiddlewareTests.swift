import Testing
@testable import MovieSwiftFluxCore

@Suite struct LoggingMiddlewareTests {
    @Test func loggingMiddlewareForwardsActionToNext() {
        var forwardedMovie: Int?
        var nextCallCount = 0

        let middleware = loggingMiddleware({ _ in }, { AppState() })
        let dispatch = middleware { action in
            nextCallCount += 1
            if let forwarded = action as? MoviesActions.AddToWishlist {
                forwardedMovie = forwarded.movie
            }
        }

        dispatch(MoviesActions.AddToWishlist(movie: 42))

        #expect(nextCallCount == 1)
        #expect(forwardedMovie == 42)
    }
}

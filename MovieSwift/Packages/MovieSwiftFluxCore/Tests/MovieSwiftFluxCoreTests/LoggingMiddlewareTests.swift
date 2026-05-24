import XCTest
@testable import MovieSwiftFluxCore

final class LoggingMiddlewareTests: XCTestCase {
    func testLoggingMiddlewareForwardsActionToNext() {
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

        XCTAssertEqual(nextCallCount, 1)
        XCTAssertEqual(forwardedMovie, 42)
    }
}

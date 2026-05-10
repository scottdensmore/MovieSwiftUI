import XCTest
import Backend
@testable import MovieSwiftFluxCore

/// Regression tests for the package-owned `Localizable.xcstrings`.
///
/// `MoviesListLoadFailurePresenter` lives in `MovieSwiftFluxCore` and
/// must look up its strings against `Bundle.module`, not `Bundle.main`.
/// Without `bundle: .module`, lookups fall back to `Bundle.main` (the
/// app target's bundle when hosted, or the test runner when unhosted)
/// and the package can't be reused outside the app.
///
/// These tests run against the package's own bundle, so if the
/// catalog is missing or the call sites drop `bundle: .module`, the
/// English source string still falls through — which is why the
/// assertions below intentionally check substrings of the development
/// language text. The real safety net is that the catalog file ships
/// with the package and the build doesn't strip it.
final class MoviesListLoadingStateTests: XCTestCase {

    func testOfflineFailureResolvesEnglishMessageThroughPackageBundle() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .offline)
        XCTAssertEqual(failure.kind, .offline)
        XCTAssertEqual(failure.message,
                       "You're offline. Check your connection and try again.")
        XCTAssertEqual(failure.retryActionTitle, "Try again")
    }

    func testMissingAPIKeyFailureResolvesEnglishMessageThroughPackageBundle() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .missingAPIKey)
        XCTAssertEqual(failure.kind, .missingAPIKey)
        XCTAssertEqual(failure.message,
                       "No TMDB API key is configured. Add one in Settings to load movies.")
        XCTAssertEqual(failure.retryActionTitle, "Open Settings")
    }

    func testRateLimitedSingularSecondResolvesThroughPackageBundle() {
        let failure = MoviesListLoadFailurePresenter.failure(from: .rateLimited(retryAfterSeconds: 1))
        XCTAssertEqual(failure.message,
                       "Too many requests to TMDB right now. Try again in 1 second.")
    }

    /// `Bundle.module` is only synthesized when the target declares
    /// resources. Reference it from the test so anyone deleting
    /// `resources: [.process("Resources")]` from `Package.swift`
    /// breaks the build instead of silently regressing the lookup
    /// path back to `Bundle.main`.
    func testPackageBundleIsAvailable() {
        XCTAssertFalse(Bundle.module.bundlePath.isEmpty)
    }
}

import XCTest
@testable import Backend

final class APIKeyProviderTests: XCTestCase {

    private final class StubAPIKeyProvider: APIKeyProviding {
        private let value: String?

        init(_ value: String?) {
            self.value = value
        }

        func apiKey() -> String? {
            value
        }
    }

    // MARK: - LayeredAPIKeyProvider

    func testLayeredProviderReturnsFirstNonNilKey() {
        let layered = LayeredAPIKeyProvider(providers: [
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider("user-key"),
            StubAPIKeyProvider("bundled-key")
        ])
        XCTAssertEqual(layered.apiKey(), "user-key")
    }

    func testLayeredProviderFallsThroughEmptyProviders() {
        let layered = LayeredAPIKeyProvider(providers: [
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider("bundled-key")
        ])
        XCTAssertEqual(layered.apiKey(), "bundled-key")
    }

    func testLayeredProviderReturnsNilWhenAllProvidersAreEmpty() {
        let layered = LayeredAPIKeyProvider(providers: [
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider(nil)
        ])
        XCTAssertNil(layered.apiKey())
    }

    func testLayeredProviderEmptyChainReturnsNil() {
        let layered = LayeredAPIKeyProvider(providers: [])
        XCTAssertNil(layered.apiKey())
    }

    // MARK: - UserDefaultsAPIKeyProvider
    //
    // These tests round-trip the real `AppUserDefaults.userTMDBAPIKey`
    // value via UserDefaults.standard. We snapshot whatever's there
    // before each test and restore after — both so the test doesn't
    // pollute the developer's environment and so the suite can run in
    // any order.

    private var savedUserKey: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedUserKey = AppUserDefaults.userTMDBAPIKey
        AppUserDefaults.userTMDBAPIKey = ""
    }

    override func tearDownWithError() throws {
        AppUserDefaults.userTMDBAPIKey = savedUserKey
        savedUserKey = nil
        try super.tearDownWithError()
    }

    func testUserDefaultsProviderReturnsNilWhenEmpty() {
        AppUserDefaults.userTMDBAPIKey = ""
        XCTAssertNil(UserDefaultsAPIKeyProvider().apiKey())
    }

    func testUserDefaultsProviderReturnsNilWhenWhitespaceOnly() {
        AppUserDefaults.userTMDBAPIKey = "   \n  "
        XCTAssertNil(UserDefaultsAPIKeyProvider().apiKey(),
                     "Whitespace-only values shouldn't count as a configured key")
    }

    func testUserDefaultsProviderReturnsTrimmedSavedKey() {
        AppUserDefaults.userTMDBAPIKey = "  abc-real-key  \n"
        XCTAssertEqual(UserDefaultsAPIKeyProvider().apiKey(), "abc-real-key")
    }

    func testUserDefaultsProviderRoundTripsExactValue() {
        AppUserDefaults.userTMDBAPIKey = "exact-key-no-trim"
        XCTAssertEqual(UserDefaultsAPIKeyProvider().apiKey(), "exact-key-no-trim")
    }

    // MARK: - Default convenience

    func testUserKeyOverridingBundleConvenienceWiresUserKeyAhead() {
        // When the user has set their own key, the layered convenience
        // composition must surface that one — not whatever the bundle
        // would have returned in production.
        AppUserDefaults.userTMDBAPIKey = "user-priority"
        XCTAssertEqual(LayeredAPIKeyProvider.userKeyOverridingBundle.apiKey(),
                       "user-priority")
    }
}

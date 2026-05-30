import Testing
@testable import Backend

// `.serialized` + final class: several tests round-trip the shared
// `AppUserDefaults.userTMDBAPIKey` (backed by UserDefaults.standard), so
// they can't run in parallel, and the class's init/deinit act as
// per-test setup/teardown to snapshot and restore that value.
@Suite(.serialized)
final class APIKeyProviderTests {

    private final class StubAPIKeyProvider: APIKeyProviding {
        private let value: String?

        init(_ value: String?) {
            self.value = value
        }

        func apiKey() -> String? {
            value
        }
    }

    // Snapshot whatever's in the real defaults before each test and
    // restore it after — so tests don't pollute the developer's
    // environment and can run in any order.
    private let savedUserKey: String

    init() {
        savedUserKey = AppUserDefaults.userTMDBAPIKey
        AppUserDefaults.userTMDBAPIKey = ""
    }

    deinit {
        AppUserDefaults.userTMDBAPIKey = savedUserKey
    }

    // MARK: - LayeredAPIKeyProvider

    @Test func layeredProviderReturnsFirstNonNilKey() {
        let layered = LayeredAPIKeyProvider(providers: [
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider("user-key"),
            StubAPIKeyProvider("bundled-key"),
        ])
        #expect(layered.apiKey() == "user-key")
    }

    @Test func layeredProviderFallsThroughEmptyProviders() {
        let layered = LayeredAPIKeyProvider(providers: [
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider("bundled-key"),
        ])
        #expect(layered.apiKey() == "bundled-key")
    }

    @Test func layeredProviderReturnsNilWhenAllProvidersAreEmpty() {
        let layered = LayeredAPIKeyProvider(providers: [
            StubAPIKeyProvider(nil),
            StubAPIKeyProvider(nil),
        ])
        #expect(layered.apiKey() == nil)
    }

    @Test func layeredProviderEmptyChainReturnsNil() {
        let layered = LayeredAPIKeyProvider(providers: [])
        #expect(layered.apiKey() == nil)
    }

    // MARK: - UserDefaultsAPIKeyProvider

    @Test func userDefaultsProviderReturnsNilWhenEmpty() {
        AppUserDefaults.userTMDBAPIKey = ""
        #expect(UserDefaultsAPIKeyProvider().apiKey() == nil)
    }

    @Test func userDefaultsProviderReturnsNilWhenWhitespaceOnly() {
        AppUserDefaults.userTMDBAPIKey = "   \n  "
        #expect(UserDefaultsAPIKeyProvider().apiKey() == nil,
                "Whitespace-only values shouldn't count as a configured key")
    }

    @Test func userDefaultsProviderReturnsTrimmedSavedKey() {
        AppUserDefaults.userTMDBAPIKey = "  abc-real-key  \n"
        #expect(UserDefaultsAPIKeyProvider().apiKey() == "abc-real-key")
    }

    @Test func userDefaultsProviderRoundTripsExactValue() {
        AppUserDefaults.userTMDBAPIKey = "exact-key-no-trim"
        #expect(UserDefaultsAPIKeyProvider().apiKey() == "exact-key-no-trim")
    }

    // MARK: - Default convenience

    @Test func userKeyOverridingBundleConvenienceWiresUserKeyAhead() {
        // When the user has set their own key, the layered convenience
        // composition must surface that one — not whatever the bundle
        // would have returned in production.
        AppUserDefaults.userTMDBAPIKey = "user-priority"
        #expect(LayeredAPIKeyProvider.userKeyOverridingBundle.apiKey() == "user-priority")
    }
}

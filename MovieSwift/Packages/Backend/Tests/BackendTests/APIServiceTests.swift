import Testing
import Foundation
@testable import Backend

@Suite struct APIServiceTests {
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
        var nextData: Data = Data()
        var nextResponse: URLResponse?
        var nextError: Error?

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            lastRequest = request
            if let nextError { throw nextError }
            // Default to a 200 so tests that only set `nextData` exercise
            // the success/decode path (mirrors the old "nil response →
            // skip status check" behaviour).
            let response = nextResponse
                ?? HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: "HTTP/1.1", headerFields: nil)!
            return (nextData, response)
        }
    }

    private enum StubError: Error {
        case failed
    }

    private struct Payload: Codable, Equatable, Sendable {
        let value: String
    }

    /// Carries a (non-Sendable) `Result` across the continuation so the
    /// completion-handler `GET` can be awaited and asserted on in the
    /// test's async context. Safe: the handler fires exactly once.
    private struct ResultBox<T>: @unchecked Sendable {
        let result: Result<T, APIService.APIError>
    }

    private func makeService(
        apiKey: String?,
        session: MockNetworkSession,
        callbackQueue: DispatchQueue = DispatchQueue(label: "APIServiceTests.callbackQueue"),
        authMode: APIService.AuthMode = .queryParameter(name: "api_key")
    ) -> APIService {
        APIService(
            apiKeyProvider: StubAPIKeyProvider(apiKey),
            session: session,
            callbackQueue: callbackQueue,
            authMode: authMode
        )
    }

    /// Bridges `APIService.GET`'s completion handler to async/await.
    private func get<T: Codable & Sendable>(
        _ service: APIService,
        endpoint: APIService.Endpoint,
        params: [String: String]? = nil,
        as type: T.Type = T.self
    ) async -> Result<T, APIService.APIError> {
        await withCheckedContinuation { continuation in
            service.GET(endpoint: endpoint, params: params) { (result: Result<T, APIService.APIError>) in
                continuation.resume(returning: ResultBox(result: result))
            }
        }.result
    }

    @Test func endpointPathBuildsExpectedValues() {
        #expect(APIService.Endpoint.popular.path() == "movie/popular")
        #expect(APIService.Endpoint.movieDetail(movie: 42).path() == "movie/42")
        #expect(APIService.Endpoint.personImages(person: 99).path() == "person/99/images")
        #expect(APIService.Endpoint.discover.path() == "discover/movie")
    }

    @Test func getReturnsMissingAPIKeyWhenProviderIsEmpty() async {
        let session = MockNetworkSession()
        let service = makeService(apiKey: nil, session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case .failure(.missingAPIKey) = result else {
            Issue.record("Expected missing API key error")
            return
        }
        // Missing key short-circuits before any network call.
        #expect(session.lastRequest == nil)
    }

    @Test func getBuildsRequestAndDecodesOnSuccess() async {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(
            service, endpoint: .searchMovie, params: ["page": "2", "query": "batman"])
        guard case let .success(payload) = result else {
            Issue.record("Expected success")
            return
        }
        #expect(payload == Payload(value: "ok"))

        #expect(session.lastRequest?.httpMethod == "GET")

        let requestURL = try? #require(session.lastRequest?.url)
        let components = requestURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )

        #expect(requestURL?.absoluteString.contains("/search/movie") == true)
        #expect(queryItems["api_key"] == "abc123")
        #expect(queryItems["language"] == Locale.preferredLanguages[0])
        #expect(queryItems["page"] == "2")
        #expect(queryItems["query"] == "batman")
    }

    // (The former testGETReturnsNoResponseWhenDataIsMissing was removed:
    // URLSession.data(for:) always yields a non-nil Data, so the
    // "successful response with missing data" path is structurally
    // impossible under async/await. The `.noResponse` error remains for
    // the URL-construction-failure guard in GET.)

    @Test func getReturnsNetworkErrorWhenErrorExists() async {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = StubError.failed
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case let .failure(.networkError(error)) = result else {
            Issue.record("Expected network error")
            return
        }
        #expect(error is StubError)
    }

    @Test func getReturnsDecodingErrorForInvalidPayload() async {
        let session = MockNetworkSession()
        session.nextData = Data("not-json".utf8)
        session.nextError = nil
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case .failure(.jsonDecodingError) = result else {
            Issue.record("Expected jsonDecodingError")
            return
        }
    }

    // MARK: - HTTP status + offline error mapping
    //
    // Without these, a 401 from a bad API key would mis-report as
    // jsonDecodingError (because TMDB's error body shape doesn't
    // match the requested success type) and the UI would have no way
    // to distinguish "your key is bad" from "TMDB returned junk".

    private func httpResponse(statusCode: Int,
                              headers: [String: String] = [:]) -> HTTPURLResponse? {
        HTTPURLResponse(
            url: URL(string: "https://api.themoviedb.org/3/movie/popular")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
    }

    @Test func getReturnsHTTPStatusFor401() async {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"status_message":"Invalid API key"}"#.utf8)
        session.nextResponse = httpResponse(statusCode: 401)
        let service = makeService(apiKey: "bogus", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case let .failure(.httpStatus(code)) = result else {
            Issue.record("Expected httpStatus error, got \(result)")
            return
        }
        #expect(code == 401)
    }

    @Test func getReturnsHTTPStatusFor500() async {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextResponse = httpResponse(statusCode: 500)
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case let .failure(.httpStatus(code)) = result else {
            Issue.record("Expected httpStatus error, got \(result)")
            return
        }
        #expect(code == 500)
    }

    @Test func getReturnsRateLimitedWithRetryAfterFor429() async {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextResponse = httpResponse(statusCode: 429,
                                            headers: ["Retry-After": "12"])
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case let .failure(.rateLimited(retryAfter)) = result else {
            Issue.record("Expected rateLimited error, got \(result)")
            return
        }
        #expect(retryAfter == 12)
    }

    @Test func getReturnsRateLimitedWithoutRetryAfterWhenHeaderMissing() async {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextResponse = httpResponse(statusCode: 429)
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case let .failure(.rateLimited(retryAfter)) = result else {
            Issue.record("Expected rateLimited error, got \(result)")
            return
        }
        #expect(retryAfter == nil)
    }

    @Test func getReturnsOfflineForNotConnectedURLError() async {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = URLError(.notConnectedToInternet)
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case .failure(.offline) = result else {
            Issue.record("Expected offline error, got \(result)")
            return
        }
    }

    @Test func getStillReturnsNetworkErrorForNonOfflineURLError() async {
        // Domain-resolution-style failure shouldn't masquerade as
        // "you're offline" — the user has a network, the server is
        // just unreachable.
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = URLError(.cannotFindHost)
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case .failure(.networkError) = result else {
            Issue.record("Expected networkError, got \(result)")
            return
        }
    }

    @Test func getSucceedsWhen2xxStatusEvenWithHTTPResponse() async {
        // Regression guard: adding the HTTP status check shouldn't
        // change the success path. A 200 with valid JSON should still
        // decode normally.
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        session.nextResponse = httpResponse(statusCode: 200)
        let service = makeService(apiKey: "abc123", session: session)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case .success(let payload) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(payload == Payload(value: "ok"))
    }

    // MARK: - retryAfterSeconds(from:)

    @Test func retryAfterParsesIntegerSeconds() throws {
        let response = try #require(httpResponse(statusCode: 429, headers: ["Retry-After": "5"]))
        #expect(APIService.retryAfterSeconds(from: response) == 5)
    }

    @Test func retryAfterTrimsWhitespace() throws {
        // HTTPURLResponse rejects header values containing newlines
        // per HTTP spec, so the realistic case is leading/trailing
        // spaces (which a misbehaving proxy might emit).
        let response = try #require(httpResponse(statusCode: 429, headers: ["Retry-After": "  10  "]))
        #expect(APIService.retryAfterSeconds(from: response) == 10)
    }

    @Test func retryAfterReturnsNilWhenHeaderMissing() throws {
        let response = try #require(httpResponse(statusCode: 429))
        #expect(APIService.retryAfterSeconds(from: response) == nil)
    }

    @Test func retryAfterReturnsNilWhenHeaderUnparseable() throws {
        let response = try #require(httpResponse(statusCode: 429, headers: ["Retry-After": "Wed, 01 Jan 2025 00:00:00 GMT"]))
        // We don't currently support HTTP-date format, only seconds.
        // Returning nil keeps the UI's retry behaviour predictable
        // rather than silently waiting an arbitrarily long time.
        #expect(APIService.retryAfterSeconds(from: response) == nil)
    }

    // MARK: - AuthMode

    @Test func getWithQueryParameterAuthAppendsAPIKeyToURL() async throws {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        let service = makeService(apiKey: "secret-key",
                                   session: session,
                                   authMode: .queryParameter(name: "api_key"))

        let _: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)

        let request = try #require(session.lastRequest)
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let query = (components.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        #expect(query["api_key"] == "secret-key",
                "Default authMode should append api_key as query parameter")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil,
                "Query-parameter auth should NOT also send a Bearer header")
    }

    @Test func getWithBearerAuthSendsAuthorizationHeaderAndOmitsAPIKeyQuery() async throws {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        let service = makeService(apiKey: "v4-token",
                                   session: session,
                                   authMode: .bearer)

        let _: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)

        let request = try #require(session.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer v4-token",
                "Bearer auth should send the key in the Authorization header")
        let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let queryNames = (components.queryItems ?? []).map(\.name)
        #expect(!queryNames.contains("api_key"),
                "Bearer auth should NOT also pass the key as a query parameter")
        #expect(queryNames.contains("language"),
                "Bearer auth should still pass non-credential query params (e.g. language)")
    }

    @Test func getWithBearerAuthStillReturnsMissingAPIKeyWhenProviderIsEmpty() async {
        // The auth mode shouldn't change how a missing key is
        // surfaced — the failure path remains the same.
        let session = MockNetworkSession()
        let service = makeService(apiKey: nil,
                                   session: session,
                                   authMode: .bearer)

        let result: Result<Payload, APIService.APIError> = await get(service, endpoint: .popular)
        guard case .failure(.missingAPIKey) = result else {
            Issue.record("Expected missingAPIKey, got \(result)")
            return
        }
    }

    // MARK: - defaultBaseURL

    @Test func defaultBaseURLFallsBackToTMDBDirect() {
        // The Backend Swift Package test runner doesn't load the
        // app bundle's Info.plist, so TMDB_BASE_URL is unset and
        // the static accessor returns the literal fallback.
        #expect(APIService.defaultBaseURL.absoluteString == "https://api.themoviedb.org/3")
    }
}

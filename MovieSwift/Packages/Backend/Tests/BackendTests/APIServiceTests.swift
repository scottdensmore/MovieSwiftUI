import XCTest
@testable import Backend

final class APIServiceTests: XCTestCase {
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
    
    private struct Payload: Codable, Equatable {
        let value: String
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
    
    func testEndpointPathBuildsExpectedValues() {
        XCTAssertEqual(APIService.Endpoint.popular.path(), "movie/popular")
        XCTAssertEqual(APIService.Endpoint.movieDetail(movie: 42).path(), "movie/42")
        XCTAssertEqual(APIService.Endpoint.personImages(person: 99).path(), "person/99/images")
        XCTAssertEqual(APIService.Endpoint.discover.path(), "discover/movie")
    }
    
    func testGETReturnsMissingAPIKeyWhenProviderIsEmpty() {
        let session = MockNetworkSession()
        let service = makeService(apiKey: nil, session: session)
        let expectation = expectation(description: "Missing API key failure")
        
        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .failure(.missingAPIKey) = result else {
                XCTFail("Expected missing API key error")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertNil(session.lastRequest)
        // Missing key short-circuits before any network call.
        XCTAssertNil(session.lastRequest)
    }

    func testGETBuildsRequestAndDecodesOnSuccess() {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "Success result")
        
        service.GET(endpoint: .searchMovie, params: ["page": "2", "query": "batman"]) { (result: Result<Payload, APIService.APIError>) in
            switch result {
            case let .success(payload):
                XCTAssertEqual(payload, Payload(value: "ok"))
            default:
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)

        XCTAssertEqual(session.lastRequest?.httpMethod, "GET")
        
        guard let requestURL = session.lastRequest?.url,
              let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
            XCTFail("Expected URL on built request")
            return
        }
        
        let queryItems = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        
        XCTAssertTrue(requestURL.absoluteString.contains("/search/movie"))
        XCTAssertEqual(queryItems["api_key"], "abc123")
        XCTAssertEqual(queryItems["language"], Locale.preferredLanguages[0])
        XCTAssertEqual(queryItems["page"], "2")
        XCTAssertEqual(queryItems["query"], "batman")
    }
    
    // (The former testGETReturnsNoResponseWhenDataIsMissing was removed:
    // URLSession.data(for:) always yields a non-nil Data, so the
    // "successful response with missing data" path is structurally
    // impossible under async/await. The `.noResponse` error remains for
    // the URL-construction-failure guard in GET.)

    func testGETReturnsNetworkErrorWhenErrorExists() {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = StubError.failed
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "Network error failure")
        
        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case let .failure(.networkError(error)) = result else {
                XCTFail("Expected network error")
                expectation.fulfill()
                return
            }
            XCTAssertTrue(error is StubError)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
    }
    
    func testGETReturnsDecodingErrorForInvalidPayload() {
        let session = MockNetworkSession()
        session.nextData = Data("not-json".utf8)
        session.nextError = nil
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "Decoding error failure")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .failure(.jsonDecodingError) = result else {
                XCTFail("Expected jsonDecodingError")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
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

    func testGETReturnsHTTPStatusFor401() {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"status_message":"Invalid API key"}"#.utf8)
        session.nextResponse = httpResponse(statusCode: 401)
        let service = makeService(apiKey: "bogus", session: session)
        let expectation = expectation(description: "HTTP 401 surfaces as httpStatus")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case let .failure(.httpStatus(code)) = result else {
                XCTFail("Expected httpStatus error, got \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(code, 401)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGETReturnsHTTPStatusFor500() {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextResponse = httpResponse(statusCode: 500)
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "HTTP 500 surfaces as httpStatus")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case let .failure(.httpStatus(code)) = result else {
                XCTFail("Expected httpStatus error, got \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(code, 500)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGETReturnsRateLimitedWithRetryAfterFor429() {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextResponse = httpResponse(statusCode: 429,
                                            headers: ["Retry-After": "12"])
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "HTTP 429 surfaces as rateLimited with parsed Retry-After")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case let .failure(.rateLimited(retryAfter)) = result else {
                XCTFail("Expected rateLimited error, got \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(retryAfter, 12)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGETReturnsRateLimitedWithoutRetryAfterWhenHeaderMissing() {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextResponse = httpResponse(statusCode: 429)
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "HTTP 429 with no Retry-After header still surfaces as rateLimited")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case let .failure(.rateLimited(retryAfter)) = result else {
                XCTFail("Expected rateLimited error, got \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertNil(retryAfter)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGETReturnsOfflineForNotConnectedURLError() {
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = URLError(.notConnectedToInternet)
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "URLError.notConnectedToInternet surfaces as offline")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .failure(.offline) = result else {
                XCTFail("Expected offline error, got \(result)")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGETStillReturnsNetworkErrorForNonOfflineURLError() {
        // Domain-resolution-style failure shouldn't masquerade as
        // "you're offline" — the user has a network, the server is
        // just unreachable.
        let session = MockNetworkSession()
        session.nextData = Data()
        session.nextError = URLError(.cannotFindHost)
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "Other URLErrors stay as networkError")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .failure(.networkError) = result else {
                XCTFail("Expected networkError, got \(result)")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGETSucceedsWhen2xxStatusEvenWithHTTPResponse() {
        // Regression guard: adding the HTTP status check shouldn't
        // change the success path. A 200 with valid JSON should still
        // decode normally.
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        session.nextResponse = httpResponse(statusCode: 200)
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "200 + valid JSON still succeeds")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .success(let payload) = result else {
                XCTFail("Expected success, got \(result)")
                expectation.fulfill()
                return
            }
            XCTAssertEqual(payload, Payload(value: "ok"))
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - retryAfterSeconds(from:)

    func testRetryAfterParsesIntegerSeconds() {
        let response = httpResponse(statusCode: 429, headers: ["Retry-After": "5"])!
        XCTAssertEqual(APIService.retryAfterSeconds(from: response), 5)
    }

    func testRetryAfterTrimsWhitespace() {
        // HTTPURLResponse rejects header values containing newlines
        // per HTTP spec, so the realistic case is leading/trailing
        // spaces (which a misbehaving proxy might emit).
        let response = httpResponse(statusCode: 429, headers: ["Retry-After": "  10  "])!
        XCTAssertEqual(APIService.retryAfterSeconds(from: response), 10)
    }

    func testRetryAfterReturnsNilWhenHeaderMissing() {
        let response = httpResponse(statusCode: 429)!
        XCTAssertNil(APIService.retryAfterSeconds(from: response))
    }

    func testRetryAfterReturnsNilWhenHeaderUnparseable() {
        let response = httpResponse(statusCode: 429, headers: ["Retry-After": "Wed, 01 Jan 2025 00:00:00 GMT"])!
        // We don't currently support HTTP-date format, only seconds.
        // Returning nil keeps the UI's retry behaviour predictable
        // rather than silently waiting an arbitrarily long time.
        XCTAssertNil(APIService.retryAfterSeconds(from: response))
    }

    // MARK: - AuthMode

    func testGETWithQueryParameterAuthAppendsAPIKeyToURL() {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        let service = makeService(apiKey: "secret-key",
                                   session: session,
                                   authMode: .queryParameter(name: "api_key"))
        let expectation = expectation(description: "Request with api_key query")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            _ = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        let request = try! XCTUnwrap(session.lastRequest)
        let components = try! XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let query = (components.queryItems ?? []).reduce(into: [String: String]()) { acc, item in
            acc[item.name] = item.value
        }
        XCTAssertEqual(query["api_key"], "secret-key",
                       "Default authMode should append api_key as query parameter")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"),
                     "Query-parameter auth should NOT also send a Bearer header")
    }

    func testGETWithBearerAuthSendsAuthorizationHeaderAndOmitsAPIKeyQuery() {
        let session = MockNetworkSession()
        session.nextData = Data(#"{"value":"ok"}"#.utf8)
        let service = makeService(apiKey: "v4-token",
                                   session: session,
                                   authMode: .bearer)
        let expectation = expectation(description: "Bearer auth request")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            _ = result
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        let request = try! XCTUnwrap(session.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"),
                       "Bearer v4-token",
                       "Bearer auth should send the key in the Authorization header")
        let components = try! XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let queryNames = (components.queryItems ?? []).map(\.name)
        XCTAssertFalse(queryNames.contains("api_key"),
                       "Bearer auth should NOT also pass the key as a query parameter")
        XCTAssertTrue(queryNames.contains("language"),
                      "Bearer auth should still pass non-credential query params (e.g. language)")
    }

    func testGETWithBearerAuthStillReturnsMissingAPIKeyWhenProviderIsEmpty() {
        // The auth mode shouldn't change how a missing key is
        // surfaced — the failure path remains the same.
        let session = MockNetworkSession()
        let service = makeService(apiKey: nil,
                                   session: session,
                                   authMode: .bearer)
        let expectation = expectation(description: "Missing key, bearer mode")

        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .failure(.missingAPIKey) = result else {
                XCTFail("Expected missingAPIKey, got \(result)")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - defaultBaseURL

    func testDefaultBaseURLFallsBackToTMDBDirect() {
        // The Backend Swift Package test runner doesn't load the
        // app bundle's Info.plist, so TMDB_BASE_URL is unset and
        // the static accessor returns the literal fallback.
        XCTAssertEqual(APIService.defaultBaseURL.absoluteString,
                       "https://api.themoviedb.org/3")
    }
}

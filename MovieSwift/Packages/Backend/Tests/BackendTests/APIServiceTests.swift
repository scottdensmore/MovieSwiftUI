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
    
    private final class MockDataTask: NetworkDataTask {
        private(set) var resumeCalls = 0
        
        func resume() {
            resumeCalls += 1
        }
    }
    
    private final class MockNetworkSession: NetworkSession {
        var lastRequest: URLRequest?
        var nextData: Data?
        var nextResponse: URLResponse?
        var nextError: Error?
        
        let task = MockDataTask()
        
        func dataTask(
            with request: URLRequest,
            completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
        ) -> NetworkDataTask {
            lastRequest = request
            completionHandler(nextData, nextResponse, nextError)
            return task
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
        callbackQueue: DispatchQueue = DispatchQueue(label: "APIServiceTests.callbackQueue")
    ) -> APIService {
        APIService(
            apiKeyProvider: StubAPIKeyProvider(apiKey),
            session: session,
            callbackQueue: callbackQueue
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
        XCTAssertEqual(session.task.resumeCalls, 0)
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
        
        XCTAssertEqual(session.task.resumeCalls, 1)
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
    
    func testGETReturnsNoResponseWhenDataIsMissing() {
        let session = MockNetworkSession()
        session.nextData = nil
        session.nextError = nil
        let service = makeService(apiKey: "abc123", session: session)
        let expectation = expectation(description: "No response failure")
        
        service.GET(endpoint: .popular, params: nil) { (result: Result<Payload, APIService.APIError>) in
            guard case .failure(.noResponse) = result else {
                XCTFail("Expected noResponse error")
                expectation.fulfill()
                return
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1)
        XCTAssertEqual(session.task.resumeCalls, 1)
    }
    
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
}

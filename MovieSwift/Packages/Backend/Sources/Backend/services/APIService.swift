import Foundation

public protocol APIKeyProviding {
    func apiKey() -> String?
}

public struct BundleAPIKeyProvider: APIKeyProviding {
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func apiKey() -> String? {
        guard let rawAPIKey = bundle.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String else {
            return nil
        }
        let value = rawAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty && value != "$(TMDB_API_KEY)" else {
            return nil
        }
        return value
    }
}

/// Resolves the user-supplied TMDB key from `AppUserDefaults`.
///
/// Returns nil when the stored value is empty or only whitespace so a
/// chained `LayeredAPIKeyProvider` cleanly falls through to the
/// bundled key. The provider re-reads UserDefaults on every
/// `apiKey()` call, so changes the user makes in Settings are picked
/// up by the next API request without needing to reinitialize
/// `APIService.shared`.
public struct UserDefaultsAPIKeyProvider: APIKeyProviding {
    public init() {}

    public func apiKey() -> String? {
        let value = AppUserDefaults.userTMDBAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// Tries each child provider in order and returns the first non-nil
/// key. Used to layer "user-supplied" over "bundled-default" so a
/// user's own TMDB key takes precedence without removing the bundled
/// fallback when the user hasn't entered one.
public struct LayeredAPIKeyProvider: APIKeyProviding {
    private let providers: [APIKeyProviding]

    public init(providers: [APIKeyProviding]) {
        self.providers = providers
    }

    public func apiKey() -> String? {
        for provider in providers {
            if let key = provider.apiKey() {
                return key
            }
        }
        return nil
    }
}

extension APIKeyProviding where Self == LayeredAPIKeyProvider {
    /// Default production resolution: try the user's saved key from
    /// AppUserDefaults first, then fall back to the bundle-substituted
    /// `TMDB_API_KEY` Info.plist value.
    public static var userKeyOverridingBundle: LayeredAPIKeyProvider {
        LayeredAPIKeyProvider(providers: [
            UserDefaultsAPIKeyProvider(),
            BundleAPIKeyProvider()
        ])
    }
}

/// Always returns nil. Used to install a "no network" `APIService` in
/// UI smoke-test mode so dispatched async actions short-circuit with
/// `.missingAPIKey` before hitting the network. That preserves the
/// pre-seeded fixture state — without this, e.g. a typed search query
/// would fire a real TMDB request whose empty results would overwrite
/// the seeded `state.moviesState.search[query]` dictionary.
public struct DisabledAPIKeyProvider: APIKeyProviding {
    public init() {}
    public func apiKey() -> String? { nil }
}

/// Injection seam for networking. `URLSession` conforms directly via
/// its async `data(for:)`; tests provide a mock that returns canned
/// `(Data, URLResponse)` or throws.
public protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

public struct APIService {

    /// How the API key is presented to the upstream service.
    ///
    /// `.queryParameter` matches TMDB v3 direct usage today: append
    /// `api_key=<key>` to the URL. `.bearer` sends the key in an
    /// `Authorization: Bearer <key>` header instead — used for
    /// TMDB v4-style tokens AND for proxy deployments where the
    /// proxy forwards a static bearer to TMDB and rejects requests
    /// without it. New deployments can swap auth mode without
    /// touching call sites.
    public enum AuthMode: Equatable {
        case queryParameter(name: String)
        case bearer
    }

    /// Falls back to the bundled TMDB direct URL if the build hasn't
    /// substituted `TMDB_BASE_URL` from xcconfig. Production builds
    /// pick up the substituted value; tests that don't load the app
    /// bundle's Info.plist get the literal default.
    public static var defaultBaseURL: URL {
        let fallback = URL(string: "https://api.themoviedb.org/3")!
        let raw = (Bundle.main.object(forInfoDictionaryKey: "TMDB_BASE_URL") as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "$(TMDB_BASE_URL)",
              let url = URL(string: trimmed) else {
            return fallback
        }
        return url
    }

    // `nonisolated(unsafe)`: this is a configure-once-at-startup
    // singleton. It's reassigned only from the main actor during app
    // launch (HomeView / MovieSwiftMacApp install a no-network instance
    // in UI-test mode) and serially in test `setUp`. `APIService` is an
    // immutable value type, so concurrent reads each see a complete,
    // valid copy; there is no read-during-write race in practice. The
    // unsafe annotation documents that we own that invariant rather than
    // forcing main-actor isolation onto every dispatch-time read.
    nonisolated(unsafe) public static var shared = APIService()
    let baseURL: URL
    let decoder: JSONDecoder
    private let apiKeyProvider: APIKeyProviding
    private let session: NetworkSession
    private let callbackQueue: DispatchQueue
    private let authMode: AuthMode

    public init(
        baseURL: URL = APIService.defaultBaseURL,
        decoder: JSONDecoder = JSONDecoder(),
        apiKeyProvider: APIKeyProviding = LayeredAPIKeyProvider.userKeyOverridingBundle,
        session: NetworkSession = URLSession.shared,
        callbackQueue: DispatchQueue = .main,
        authMode: AuthMode = .queryParameter(name: "api_key")
    ) {
        self.baseURL = baseURL
        self.decoder = decoder
        self.apiKeyProvider = apiKeyProvider
        self.session = session
        self.callbackQueue = callbackQueue
        self.authMode = authMode
    }

    private var apiKey: String? {
        apiKeyProvider.apiKey()
    }
    
    public enum APIError: Error {
        /// No usable TMDB key from any provider in the chain.
        case missingAPIKey
        /// URLSession returned no data and no error — shouldn't happen
        /// in practice but kept as a safety net.
        case noResponse
        /// JSON returned by TMDB couldn't be decoded into the expected
        /// model. Often indicates a TMDB-side error response (which
        /// has a different shape) being decoded as a success type.
        case jsonDecodingError(error: Error)
        /// URLSession reported a transport-level error that wasn't a
        /// recognised offline condition (DNS issue, TLS failure, etc).
        case networkError(error: Error)
        /// Device is reported offline by URLSession's error code.
        /// Distinguished from `networkError` so the UI can show a
        /// "you're offline" message rather than a generic failure.
        case offline
        /// TMDB throttled the request. `retryAfterSeconds` is parsed
        /// from the HTTP `Retry-After` header when present.
        case rateLimited(retryAfterSeconds: TimeInterval?)
        /// Any other non-2xx HTTP response. The status code tells the
        /// UI whether it's worth retrying (5xx) vs whether something
        /// is misconfigured (4xx — most commonly 401 from a bad key).
        case httpStatus(code: Int)
    }
    
    public enum Endpoint {
        case popular, topRated, upcoming, nowPlaying, trending
        case movieDetail(movie: Int), recommended(movie: Int), similar(movie: Int), videos(movie: Int)
        case credits(movie: Int), review(movie: Int)
        case searchMovie, searchKeyword, searchPerson
        case popularPersons
        case personDetail(person: Int)
        case personMovieCredits(person: Int)
        case personImages(person: Int)
        case genres
        case discover
        
        func path() -> String {
            switch self {
            case .popular:
                return "movie/popular"
            case .popularPersons:
                return "person/popular"
            case .topRated:
                return "movie/top_rated"
            case .upcoming:
                return "movie/upcoming"
            case .nowPlaying:
                return "movie/now_playing"
            case .trending:
                return "trending/movie/day"
            case let .movieDetail(movie):
                return "movie/\(String(movie))"
            case let .videos(movie):
                return "movie/\(String(movie))/videos"
            case let .personDetail(person):
                return "person/\(String(person))"
            case let .credits(movie):
                return "movie/\(String(movie))/credits"
            case let .review(movie):
                return "movie/\(String(movie))/reviews"
            case let .recommended(movie):
                return "movie/\(String(movie))/recommendations"
            case let .similar(movie):
                return "movie/\(String(movie))/similar"
            case let .personMovieCredits(person):
                return "person/\(person)/movie_credits"
            case let .personImages(person):
                return "person/\(person)/images"
            case .searchMovie:
                return "search/movie"
            case .searchKeyword:
                return "search/keyword"
            case .searchPerson:
                return "search/person"
            case .genres:
                return "genre/movie/list"
            case .discover:
                return "discover/movie"
            }
        }
    }
    
    // `T: Sendable` and the `@Sendable` completion handler are required
    // because the decoded value and the callback both cross from the
    // networking `Task` back to `callbackQueue` — strict concurrency
    // makes that hand-off explicit rather than racy.
    public func GET<T: Codable & Sendable>(endpoint: Endpoint,
                         params: [String: String]?,
                         completionHandler: @escaping @Sendable (Result<T, APIError>) -> Void) {
        guard let apiKey = apiKey else {
            #if DEBUG
            print("Missing TMDB_API_KEY. Set it in DeveloperSettings.xcconfig.")
            #endif
            callbackQueue.async {
                completionHandler(.failure(.missingAPIKey))
            }
            return
        }
        
        let queryURL = baseURL.appendingPathComponent(endpoint.path())
        var components = URLComponents(url: queryURL, resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "language", value: Locale.preferredLanguages[0])
        ]
        // Auth path: query parameter for direct TMDB v3 usage,
        // header for TMDB v4 / proxy deployments. Both modes
        // ignore the credential's exact form; the apiKeyProvider
        // is the single source of truth.
        if case .queryParameter(let name) = authMode {
            queryItems.append(URLQueryItem(name: name, value: apiKey))
        }
        if let params {
            for (_, value) in params.enumerated() {
                queryItems.append(URLQueryItem(name: value.key, value: value.value))
            }
        }
        components.queryItems = queryItems
        // `components.url` is non-nil for all the well-formed
        // endpoint paths we construct above — but if it ever does
        // come back nil (e.g. a future caller passes a path with
        // characters that fail percent-encoding), surface that as a
        // structured failure instead of crashing the request.
        guard let composedURL = components.url else {
            callbackQueue.async {
                completionHandler(.failure(.noResponse))
            }
            return
        }
        var request = URLRequest(url: composedURL)
        request.httpMethod = "GET"
        if case .bearer = authMode {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        // Fire the request on an unstructured Task so GET keeps its
        // synchronous, completion-handler signature (the AsyncAction /
        // dispatch facade and all callers are unchanged) while the
        // networking itself uses structured async/await internally.
        let session = self.session
        let decoder = self.decoder
        let callbackQueue = self.callbackQueue
        Task {
            do {
                let (data, response) = try await session.data(for: request)

                // HTTP status first — without this, a 401 from a bad API
                // key gets mis-reported as `jsonDecodingError` because the
                // error body shape doesn't match the success type.
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    #if DEBUG
                    // Diagnostic for Discover-style 400s and other non-2xx
                    // responses: print the request URL (api_key stripped)
                    // and the response body so a user reporting "TMDB
                    // returned an unexpected response (400)" can tell which
                    // query parameter combination TMDB rejected. Visible in
                    // `xcrun simctl spawn booted log stream` / Console.app.
                    let sanitizedURL = APIService.sanitizeURLForLogging(request.url)
                    let body = String(data: data, encoding: .utf8) ?? ""
                    let bodyPreview = body.isEmpty
                        ? "<no body>"
                        : (body.count > 500 ? String(body.prefix(500)) + "…" : body)
                    print("APIService HTTP \(http.statusCode) for \(sanitizedURL ?? "<no url>")\n  body: \(bodyPreview)")
                    #endif
                    if http.statusCode == 429 {
                        let retryAfter = APIService.retryAfterSeconds(from: http)
                        callbackQueue.async {
                            completionHandler(.failure(.rateLimited(retryAfterSeconds: retryAfter)))
                        }
                    } else {
                        callbackQueue.async {
                            completionHandler(.failure(.httpStatus(code: http.statusCode)))
                        }
                    }
                    return
                }

                do {
                    let object = try decoder.decode(T.self, from: data)
                    callbackQueue.async {
                        completionHandler(.success(object))
                    }
                } catch let error {
                    callbackQueue.async {
                        #if DEBUG
                        print("JSON Decoding Error: \(error)")
                        #endif
                        completionHandler(.failure(.jsonDecodingError(error: error)))
                    }
                }
            } catch {
                // Transport-level error — distinguish "device is offline"
                // from other failures so the UI can tailor the message.
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain
                    && APIService.offlineURLErrorCodes.contains(nsError.code) {
                    callbackQueue.async {
                        completionHandler(.failure(.offline))
                    }
                } else {
                    callbackQueue.async {
                        completionHandler(.failure(.networkError(error: error)))
                    }
                }
            }
        }
    }

    /// URLError codes that indicate the device is offline rather than
    /// hitting a generic transport failure. Surfaced as
    /// `APIError.offline` so the UI can show "you're offline" instead
    /// of a generic networking message.
    static let offlineURLErrorCodes: Set<Int> = [
        URLError.notConnectedToInternet.rawValue,
        URLError.networkConnectionLost.rawValue,
        URLError.dataNotAllowed.rawValue,
        URLError.internationalRoamingOff.rawValue
    ]

    /// Parses the `Retry-After` header from a 429 response. TMDB
    /// returns it as a number-of-seconds. Returns nil when the header
    /// is missing or unparseable.
    static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return seconds
    }

    /// Strips `api_key` from a request URL so the URL can safely be
    /// printed to the device log without leaking the credential. Used
    /// by the DEBUG-only HTTP-error diagnostic in `GET`.
    static func sanitizeURLForLogging(_ url: URL?) -> String? {
        guard let url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url?.absoluteString
        }
        components.queryItems = (components.queryItems ?? []).filter { item in
            item.name != "api_key"
        }
        return components.url?.absoluteString
    }
}

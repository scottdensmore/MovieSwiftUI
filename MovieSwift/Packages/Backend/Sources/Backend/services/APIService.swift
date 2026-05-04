//
//  APIService.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

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

public protocol NetworkDataTask {
    func resume()
}

extension URLSessionDataTask: NetworkDataTask {}

public protocol NetworkSession {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkDataTask
}

public struct URLSessionNetworkSession: NetworkSession {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> NetworkDataTask {
        session.dataTask(with: request, completionHandler: completionHandler)
    }
}

public struct APIService {
    public static var shared = APIService()
    let baseURL: URL
    let decoder: JSONDecoder
    private let apiKeyProvider: APIKeyProviding
    private let session: NetworkSession
    private let callbackQueue: DispatchQueue
    
    public init(
        baseURL: URL = URL(string: "https://api.themoviedb.org/3")!,
        decoder: JSONDecoder = JSONDecoder(),
        apiKeyProvider: APIKeyProviding = LayeredAPIKeyProvider.userKeyOverridingBundle,
        session: NetworkSession = URLSessionNetworkSession(),
        callbackQueue: DispatchQueue = .main
    ) {
        self.baseURL = baseURL
        self.decoder = decoder
        self.apiKeyProvider = apiKeyProvider
        self.session = session
        self.callbackQueue = callbackQueue
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
    
    public func GET<T: Codable>(endpoint: Endpoint,
                         params: [String: String]?,
                         completionHandler: @escaping (Result<T, APIError>) -> Void) {
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
        components.queryItems = [
           URLQueryItem(name: "api_key", value: apiKey),
           URLQueryItem(name: "language", value: Locale.preferredLanguages[0])
        ]
        if let params = params {
            for (_, value) in params.enumerated() {
                components.queryItems?.append(URLQueryItem(name: value.key, value: value.value))
            }
        }
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
        let task = session.dataTask(with: request) { (data, response, error) in
            // Transport-level error first — distinguishes "device is
            // offline" from other failures so the UI can surface a
            // tailored message.
            if let error {
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
                return
            }

            // HTTP status next — without this, a 401 from a bad API
            // key gets mis-reported as `jsonDecodingError` because the
            // error body shape doesn't match the success type.
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
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

            guard let data = data else {
                callbackQueue.async {
                    completionHandler(.failure(.noResponse))
                }
                return
            }

            do {
                let object = try self.decoder.decode(T.self, from: data)
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
        }
        task.resume()
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
}

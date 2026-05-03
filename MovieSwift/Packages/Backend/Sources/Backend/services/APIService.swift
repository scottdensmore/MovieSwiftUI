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
        case missingAPIKey
        case noResponse
        case jsonDecodingError(error: Error)
        case networkError(error: Error)
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
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                callbackQueue.async {
                    completionHandler(.failure(.noResponse))
                }
                return
            }
            guard error == nil else {
                callbackQueue.async {
                    completionHandler(.failure(.networkError(error: error!)))
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
    
}

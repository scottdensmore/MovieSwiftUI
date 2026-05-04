//
//  MoviesListLoadingState.swift
//  MovieSwift
//
//  Per-menu loading state for the home movie lists (Popular, Top
//  Rated, Upcoming, Now Playing, Trending). Lets the UI show an
//  inline error + retry banner when a TMDB request fails instead of
//  silently leaving the list empty forever — the "case .failure(_):
//  break" path that used to swallow every error.
//
//  This file holds the pure-logic types and an APIError → presenter
//  translator. The reducer wires it into MoviesState.
//

import Foundation
import Backend

/// Where a per-menu list is in its load lifecycle. Only stored when
/// not idle/loaded — `nil` in the dict means "no in-flight request,
/// data (if any) is the latest known good".
enum MoviesListLoadingState: Equatable {
    case loading
    case failed(MoviesListLoadFailure)
}

/// Identifies a single in-flight (or recently-failed) request so the
/// UI can surface a per-context error banner. One enum covers both
/// Movies and People fetchers because they all funnel through a
/// single `loadingStates: [LoadingKey: MoviesListLoadingState]`
/// dictionary in `MoviesState` — keeping it unified avoids needing a
/// parallel state slot inside `PeoplesState`.
enum LoadingKey: Hashable {
    // Movies
    case homeMenu(MoviesMenu)
    case movieDetail(Int)
    case recommended(movie: Int)
    case similar(movie: Int)
    case videos(movie: Int)
    case search(query: String)
    case searchKeyword(query: String)
    case moviesGenre(genre: Int)
    case movieReviews(movie: Int)
    case moviesWithCrew(crew: Int)
    case moviesWithKeyword(keyword: Int)
    case randomDiscover
    case genres

    // People
    case personDetail(Int)
    case personImages(Int)
    case personMovieCredits(Int)
    case movieCasts(movie: Int)
    case peopleSearch(query: String)
    case popularPeople
}

/// User-facing description of a failed list load.
struct MoviesListLoadFailure: Equatable {

    /// What kind of failure happened. Drives the UI's icon/CTA
    /// choice — e.g. missingAPIKey shows "Open Settings" instead of
    /// "Try again".
    enum Kind: Equatable {
        case offline
        case rateLimited(retryAfterSeconds: TimeInterval?)
        case missingAPIKey
        case server          // 5xx
        case unauthorized    // 401
        case forbidden       // 403
        case decode
        case other
    }

    let kind: Kind
    let message: String
    let retryActionTitle: String

    init(kind: Kind, message: String, retryActionTitle: String = "Try again") {
        self.kind = kind
        self.message = message
        self.retryActionTitle = retryActionTitle
    }
}

/// Translates the network-layer `APIError` into a UI-friendly
/// `MoviesListLoadFailure`. Pure logic so it can be unit-tested
/// without spinning up a SwiftUI view tree.
enum MoviesListLoadFailurePresenter {

    static func failure(from error: APIService.APIError) -> MoviesListLoadFailure {
        switch error {
        case .missingAPIKey:
            return MoviesListLoadFailure(
                kind: .missingAPIKey,
                message: "No TMDB API key is configured. Add one in Settings to load movies.",
                retryActionTitle: "Open Settings"
            )
        case .offline:
            return MoviesListLoadFailure(
                kind: .offline,
                message: "You're offline. Check your connection and try again.",
                retryActionTitle: "Try again"
            )
        case .rateLimited(let retryAfter):
            let suffix: String
            if let retryAfter, retryAfter > 0 {
                let seconds = Int(retryAfter.rounded(.up))
                suffix = " Try again in \(seconds) second\(seconds == 1 ? "" : "s")."
            } else {
                suffix = " Try again in a moment."
            }
            return MoviesListLoadFailure(
                kind: .rateLimited(retryAfterSeconds: retryAfter),
                message: "Too many requests to TMDB right now." + suffix,
                retryActionTitle: "Try again"
            )
        case .httpStatus(let code):
            switch code {
            case 401:
                return MoviesListLoadFailure(
                    kind: .unauthorized,
                    message: "TMDB rejected the request — your API key may be invalid. Check it in Settings.",
                    retryActionTitle: "Open Settings"
                )
            case 403:
                return MoviesListLoadFailure(
                    kind: .forbidden,
                    message: "TMDB declined the request. Your API key may not have access to this resource.",
                    retryActionTitle: "Open Settings"
                )
            case 500...599:
                return MoviesListLoadFailure(
                    kind: .server,
                    message: "TMDB is having a problem (\(code)). Try again in a minute.",
                    retryActionTitle: "Try again"
                )
            default:
                return MoviesListLoadFailure(
                    kind: .other,
                    message: "TMDB returned an unexpected response (\(code)).",
                    retryActionTitle: "Try again"
                )
            }
        case .jsonDecodingError:
            return MoviesListLoadFailure(
                kind: .decode,
                message: "Got an unexpected response from TMDB. Try again.",
                retryActionTitle: "Try again"
            )
        case .networkError, .noResponse:
            return MoviesListLoadFailure(
                kind: .other,
                message: "Couldn't reach TMDB. Check your connection and try again.",
                retryActionTitle: "Try again"
            )
        }
    }
}

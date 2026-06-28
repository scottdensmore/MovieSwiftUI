import Backend
import Foundation

public enum MoviesMenu: Int, CaseIterable, Sendable {
    case nowPlaying
    case upcoming
    case trending
    case popular
    case topRated
    case genres

    public func title() -> String {
        // `bundle: .module` is required: this type lives in the
        // MovieSwiftFluxCore package, whose localized strings are in the
        // package's own Localizable.xcstrings (not the app's main bundle).
        switch self {
        case .popular:
            return String(localized: "Popular", bundle: .module,
                          comment: "Movies menu / nav title: most popular movies")
        case .topRated:
            return String(localized: "Top Rated", bundle: .module,
                          comment: "Movies menu / nav title: highest rated movies")
        case .upcoming:
            return String(localized: "Upcoming", bundle: .module,
                          comment: "Movies menu / nav title: upcoming releases")
        case .nowPlaying:
            return String(localized: "Now Playing", bundle: .module,
                          comment: "Movies menu / nav title: movies in theaters now")
        case .trending:
            return String(localized: "Trending", bundle: .module,
                          comment: "Movies menu / nav title: trending movies")
        case .genres:
            return String(localized: "Genres", bundle: .module,
                          comment: "Movies menu / nav title: browse by genre")
        }
    }

    public func endpoint() -> APIService.Endpoint {
        switch self {
        case .popular: return APIService.Endpoint.popular
        case .topRated: return APIService.Endpoint.topRated
        case .upcoming: return APIService.Endpoint.upcoming
        case .nowPlaying: return APIService.Endpoint.nowPlaying
        case .trending: return APIService.Endpoint.trending
        case .genres: return APIService.Endpoint.genres
        }
    }

    /// Whether TMDB filters this list by the user's region. Only `nowPlaying`
    /// and `upcoming` are region-scoped (theatrical schedules differ by
    /// country), so their result counts can look sparse for small markets;
    /// the other lists are global. Drives the region indicator in the UI.
    public var isRegionFiltered: Bool {
        switch self {
        case .nowPlaying, .upcoming: return true
        case .popular, .topRated, .trending, .genres: return false
        }
    }

    /// One-line caption for the region indicator shown on region-filtered
    /// lists, e.g. "In theaters in Albania". `regionName` is the localized
    /// country name (see `RegionPresentation.displayName(forRegionCode:)`).
    public func regionCaption(regionName: String) -> String {
        switch self {
        case .nowPlaying:
            return String(localized: "In theaters in \(regionName)", bundle: .module,
                          comment: "Region indicator on the Now Playing list; argument is the country name")
        case .upcoming:
            return String(localized: "Upcoming in \(regionName)", bundle: .module,
                          comment: "Region indicator on the Upcoming list; argument is the country name")
        case .popular, .topRated, .trending, .genres:
            return String(localized: "Results for \(regionName)", bundle: .module,
                          comment: "Generic region indicator; argument is the country name")
        }
    }
}

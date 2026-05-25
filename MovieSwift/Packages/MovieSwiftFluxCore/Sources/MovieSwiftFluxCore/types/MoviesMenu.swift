import Foundation
import Backend

public enum MoviesMenu: Int, CaseIterable {
    case nowPlaying, upcoming, trending, popular, topRated, genres
    
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
}

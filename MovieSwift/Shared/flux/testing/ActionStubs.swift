import Foundation
import SwiftUIFlux

struct MoviesActions {
    struct SetMovieMenuList: Action {
        let page: Int
        let list: MoviesMenu
        let response: PaginatedResponse<Movie>
    }

    struct SetDetail: Action {
        let movie: Int
        let response: Movie
    }

    struct SetRecommended: Action {
        let movie: Int
        let response: PaginatedResponse<Movie>
    }

    struct SetSimilar: Action {
        let movie: Int
        let response: PaginatedResponse<Movie>
    }

    struct SetVideos: Action {
        let movie: Int
        let response: PaginatedResponse<Video>
    }

    struct SetSearch: Action {
        let query: String
        let page: Int
        let response: PaginatedResponse<Movie>
    }

    struct SetSearchKeyword: Action {
        let query: String
        let response: PaginatedResponse<Keyword>
    }

    struct AddToWishlist: Action {
        let movie: Int
    }

    struct RemoveFromWishlist: Action {
        let movie: Int
    }

    struct AddToSeenList: Action {
        let movie: Int
    }

    struct RemoveFromSeenList: Action {
        let movie: Int
    }

    struct SetMovieForGenre: Action {
        let genre: Genre
        let page: Int
        let response: PaginatedResponse<Movie>
    }

    struct SetMovieWithCrew: Action {
        let crew: Int
        let response: PaginatedResponse<Movie>
    }

    struct SetMovieWithKeyword: Action {
        let keyword: Int
        let page: Int
        let response: PaginatedResponse<Movie>
    }

    struct ResetRandomDiscover: Action {}

    struct SetRandomDiscover: Action {
        let filter: DiscoverFilter
        let response: PaginatedResponse<Movie>
    }

    struct PushRandomDiscover: Action {
        let movie: Int
    }

    struct PopRandromDiscover: Action {}

    struct SetMovieReviews: Action {
        let movie: Int
        let response: PaginatedResponse<Review>
    }

    struct AddCustomList: Action {
        let list: CustomList
    }

    struct EditCustomList: Action {
        let list: Int
        let title: String?
        let cover: Int?
    }

    struct AddMovieToCustomList: Action {
        let list: Int
        let movie: Int
    }

    struct AddMoviesToCustomList: Action {
        let list: Int
        let movies: [Int]
    }

    struct RemoveMovieFromCustomList: Action {
        let list: Int
        let movie: Int
    }

    struct RemoveCustomList: Action {
        let list: Int
    }

    struct SetGenres: Action {
        let genres: [Genre]
    }

    struct SaveDiscoverFilter: Action {
        let filter: DiscoverFilter
    }

    struct ClearSavedDiscoverFilters: Action {}
}

struct PeopleActions {
    struct PeopleCreditsResponse: Codable {
        let cast: [Movie]?
        let crew: [Movie]?
    }

    struct SetDetail: Action {
        let person: People
    }

    struct SetImages: Action {
        let people: Int
        let images: [ImageData]
    }

    struct SetMovieCasts: Action {
        let movie: Int
        let response: CastResponse
    }

    struct SetSearch: Action {
        let query: String
        let page: Int
        let response: PaginatedResponse<People>
    }

    struct SetPopular: Action {
        let page: Int
        let response: PaginatedResponse<People>
    }

    struct SetPeopleCredits: Action {
        let people: Int
        let response: PeopleCreditsResponse
    }

    struct AddToFanClub: Action {
        let people: Int
    }

    struct RemoveFromFanClub: Action {
        let people: Int
    }
}

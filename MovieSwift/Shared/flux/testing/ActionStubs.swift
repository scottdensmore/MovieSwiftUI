import Foundation
import SwiftUIFlux

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

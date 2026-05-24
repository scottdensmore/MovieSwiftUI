import Foundation
import SwiftUIFlux
import Backend

public struct PeopleActions {

    public init() {}
    public struct FetchDetail: AsyncAction {
        public let people: Int

        public init(
            people: Int
        ) {
            self.people = people
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.personDetail(people)
            let handler: (Result<People, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetDetail(person: response))
                }
            APIService.shared.GET(endpoint: .personDetail(person: people),
                                  params: nil,
                                  completionHandler: handler)
        }
    }

    public struct ImagesResponse: Codable {
        public let id: Int
        public let profiles: [ImageData]

        public init(
            id: Int,
            profiles: [ImageData]
        ) {
            self.id = id
            self.profiles = profiles
        }
    }

    public struct FetchImages: AsyncAction {
        public let people: Int

        public init(
            people: Int
        ) {
            self.people = people
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.personImages(people)
            let handler: (Result<ImagesResponse, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetImages(people: self.people, images: response.profiles))
                }
            APIService.shared.GET(endpoint: .personImages(person: people),
                                  params: nil,
                                  completionHandler: handler)
        }
    }

    public struct PeopleCreditsResponse: Codable {
        public let cast: [Movie]?
        public let crew: [Movie]?

        public init(
            cast: [Movie]? = nil,
            crew: [Movie]? = nil
        ) {
            self.cast = cast
            self.crew = crew
        }
    }
    public struct FetchPeopleCredits: AsyncAction {
        public let people: Int

        public init(
            people: Int
        ) {
            self.people = people
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.personMovieCredits(people)
            let handler: (Result<PeopleCreditsResponse, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetPeopleCredits(people: self.people, response: response))
                }
            APIService.shared.GET(endpoint: .personMovieCredits(person: people),
                                  params: nil,
                                  completionHandler: handler)
        }
    }

    public struct FetchMovieCasts: AsyncAction {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.movieCasts(movie: movie)
            let handler: (Result<CastResponse, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieCasts(movie: self.movie, response: response))
                }
            APIService.shared.GET(endpoint: .credits(movie: movie),
                                  params: nil,
                                  completionHandler: handler)
        }
    }

    public struct FetchSearch: AsyncAction {
        public let query: String
        public let page: Int

        public init(
            query: String,
            page: Int
        ) {
            self.query = query
            self.page = page
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.peopleSearch(query: query)
            let handler: (Result<PaginatedResponse<People>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetSearch(query: self.query,
                                       page: self.page,
                                       response: response))
                }
            APIService.shared.GET(endpoint: .searchPerson,
                                  params: ["query": query, "page": "\(page)"],
                                  completionHandler: handler)
        }
    }

    public struct FetchPopular: AsyncAction {
        public let page: Int

        public init(
            page: Int
        ) {
            self.page = page
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            // FetchPopular keeps its existing PopularRequestStarted /
            // PopularRequestFailed actions because PeoplesState
            // already drives a per-page lifecycle UI from those
            // (paginated retry), but layers the generic loading-state
            // tracking on top so the Fan Club view can render the
            // shared error banner alongside its existing UI.
            dispatch(PopularRequestStarted(page: page))
            let handler: (Result<PaginatedResponse<People>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: .popularPeople, dispatch: dispatch) { response in
                    dispatch(SetPopular(page: self.page, response: response))
                }
            APIService.shared.GET(
                endpoint: .popularPersons,
                params: ["page": "\(page)",
                         "region": AppUserDefaults.region]
            ) { (result: Result<PaginatedResponse<People>, APIService.APIError>) in
                if case .failure = result {
                    dispatch(PopularRequestFailed(page: self.page))
                }
                handler(result)
            }
        }
    }

    public struct PopularRequestStarted: Action {
        public let page: Int

        public init(
            page: Int
        ) {
            self.page = page
        }
    }

    public struct PopularRequestFailed: Action {
        public let page: Int

        public init(
            page: Int
        ) {
            self.page = page
        }
    }
    
    public struct SetDetail: Action {
        public let person: People

        public init(
            person: People
        ) {
            self.person = person
        }
    }
    
    public struct SetImages: Action {
        public let people: Int
        public let images: [ImageData]

        public init(
            people: Int,
            images: [ImageData]
        ) {
            self.people = people
            self.images = images
        }
    }
    
    public struct SetMovieCasts: Action {
        public let movie: Int
        public let response: CastResponse

        public init(
            movie: Int,
            response: CastResponse
        ) {
            self.movie = movie
            self.response = response
        }
    }
    
    public struct SetSearch: Action {
        public let query: String
        public let page: Int
        public let response: PaginatedResponse<People>

        public init(
            query: String,
            page: Int,
            response: PaginatedResponse<People>
        ) {
            self.query = query
            self.page = page
            self.response = response
        }
    }
    
    public struct SetPopular: Action {
        public let page: Int
        public let response: PaginatedResponse<People>

        public init(
            page: Int,
            response: PaginatedResponse<People>
        ) {
            self.page = page
            self.response = response
        }
    }
    
    public struct SetPeopleCredits: Action {
        public let people: Int
        public let response: PeopleCreditsResponse

        public init(
            people: Int,
            response: PeopleCreditsResponse
        ) {
            self.people = people
            self.response = response
        }
    }
    
    public struct AddToFanClub: Action {
        public let people: Int

        public init(
            people: Int
        ) {
            self.people = people
        }
    }
    
    public struct RemoveFromFanClub: Action {
        public let people: Int

        public init(
            people: Int
        ) {
            self.people = people
        }
    }
}

//
//  CastsAction.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUIFlux
import Backend

struct PeopleActions {
    struct FetchDetail: AsyncAction {
        let people: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    struct ImagesResponse: Codable {
        let id: Int
        let profiles: [ImageData]
    }

    struct FetchImages: AsyncAction {
        let people: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    struct PeopleCreditsResponse: Codable {
        let cast: [Movie]?
        let crew: [Movie]?
    }
    struct FetchPeopleCredits: AsyncAction {
        let people: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    struct FetchMovieCasts: AsyncAction {
        let movie: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    struct FetchSearch: AsyncAction {
        let query: String
        let page: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    struct FetchPopular: AsyncAction {
        let page: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    struct PopularRequestStarted: Action {
        let page: Int
    }

    struct PopularRequestFailed: Action {
        let page: Int
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

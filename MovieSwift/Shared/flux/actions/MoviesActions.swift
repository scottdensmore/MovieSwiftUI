//
//  MoviesAction.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUIFlux
import Backend

struct MoviesActions {
    
    // MARK: - Requests
    
    struct FetchMoviesMenuList: AsyncAction {
        let list: MoviesMenu
        let page: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.homeMenu(list)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieMenuList(page: self.page,
                                              list: self.list,
                                              response: response))
                }
            APIService.shared.GET(
                endpoint: list.endpoint(),
                params: ["page": "\(page)",
                         "region": AppUserDefaults.region],
                completionHandler: handler
            )
        }
    }

    struct FetchDetail: AsyncAction {
        let movie: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
            let key = LoadingKey.movieDetail(movie)
            let handler: (Result<Movie, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetDetail(movie: self.movie, response: response))
                }
            APIService.shared.GET(
                endpoint: .movieDetail(movie: movie),
                params: ["append_to_response": "keywords,images",
                         "include_image_language": "\(languageCode),en,null"],
                completionHandler: handler
            )
        }
    }

    struct FetchRecommended: AsyncAction {
        let movie: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.recommended(movie: movie)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetRecommended(movie: self.movie, response: response))
                }
            APIService.shared.GET(endpoint: .recommended(movie: movie),
                                  params: nil,
                                  completionHandler: handler)
        }
    }


    struct FetchSimilar: AsyncAction {
        let movie: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.similar(movie: movie)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetSimilar(movie: self.movie, response: response))
                }
            APIService.shared.GET(endpoint: .similar(movie: movie),
                                  params: nil,
                                  completionHandler: handler)
        }
    }

    struct FetchVideos: AsyncAction {
        let movie: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.videos(movie: movie)
            let handler: (Result<PaginatedResponse<Video>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetVideos(movie: self.movie, response: response))
                }
            APIService.shared.GET(endpoint: .videos(movie: movie),
                                  params: nil,
                                  completionHandler: handler)
        }
    }


    struct FetchSearch: AsyncAction {
        let query: String
        let page: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.search(query: query)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetSearch(query: self.query,
                                       page: self.page,
                                       response: response))
                }
            APIService.shared.GET(endpoint: .searchMovie,
                                  params: ["query": query, "page": "\(page)"],
                                  completionHandler: handler)
        }
    }

    struct FetchSearchKeyword: AsyncAction {
        let query: String

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.searchKeyword(query: query)
            let handler: (Result<PaginatedResponse<Keyword>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetSearchKeyword(query: self.query, response: response))
                }
            APIService.shared.GET(endpoint: .searchKeyword,
                                  params: ["query": query],
                                  completionHandler: handler)
        }
    }

    struct FetchMoviesGenre: AsyncAction {
        let genre: Genre
        let page: Int
        let sortBy: MoviesSort

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.moviesGenre(genre: genre.id)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieForGenre(genre: self.genre,
                                              page: self.page,
                                              response: response))
                }
            APIService.shared.GET(
                endpoint: .discover,
                params: ["with_genres": "\(genre.id)",
                         "page": "\(page)",
                         "sort_by": sortBy.sortByAPI()],
                completionHandler: handler
            )
        }
    }

    struct FetchMovieReviews: AsyncAction {
        let movie: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.movieReviews(movie: movie)
            let handler: (Result<PaginatedResponse<Review>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieReviews(movie: self.movie, response: response))
                }
            APIService.shared.GET(endpoint: .review(movie: movie),
                                  params: ["language": "en-US"],
                                  completionHandler: handler)
        }
    }


    struct FetchMovieWithCrew: AsyncAction {
        let crew: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.moviesWithCrew(crew: crew)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieWithCrew(crew: self.crew, response: response))
                }
            APIService.shared.GET(endpoint: .discover,
                                  params: ["with_people": "\(crew)"],
                                  completionHandler: handler)
        }
    }



    struct FetchMovieWithKeywords: AsyncAction {
        let keyword: Int
        let page: Int

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.moviesWithKeyword(keyword: keyword)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieWithKeyword(keyword: self.keyword,
                                                 page: self.page,
                                                 response: response))
                }
            APIService.shared.GET(endpoint: .discover,
                                  params: ["page": "\(page)",
                                           "with_keywords": "\(keyword)"],
                                  completionHandler: handler)
        }
    }

    struct FetchRandomDiscover: AsyncAction {
        var filter: DiscoverFilter?

        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            var filter = self.filter
            if filter == nil {
                filter = DiscoverFilter.randomFilter()
            }
            let resolvedFilter = filter!
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: .randomDiscover, dispatch: dispatch) { response in
                    dispatch(SetRandomDiscover(filter: resolvedFilter, response: response))
                }
            APIService.shared.GET(endpoint: .discover,
                                  params: resolvedFilter.toParams(),
                                  completionHandler: handler)
        }
    }

    struct GenresResponse: Codable {
        let genres: [Genre]
    }

    struct FetchGenres: AsyncAction {
        func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let handler: (Result<GenresResponse, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: .genres, dispatch: dispatch) { response in
                    dispatch(SetGenres(genres: response.genres))
                }
            APIService.shared.GET(endpoint: .genres,
                                  params: nil,
                                  completionHandler: handler)
        }
    }
    
    struct SetMovieMenuList: Action {
        let page: Int
        let list: MoviesMenu
        let response: PaginatedResponse<Movie>
    }

    /// Generic per-fetcher loading-state transition. `state == nil`
    /// clears the entry — used on success to remove a stale
    /// `.loading` or `.failed` from the dict so any error banner the
    /// UI was showing disappears. Passing `.loading` marks the start
    /// of a request; `.failed(...)` records a translated APIError.
    ///
    /// Replaces the earlier per-fetcher `Set<X>Loading` /
    /// `Set<X>Failure` action pairs that were starting to multiply
    /// once the home-menu pattern was extended to every async
    /// fetcher in the app.
    struct SetLoadingState: Action {
        let key: LoadingKey
        let state: MoviesListLoadingState?
    }

    /// Wraps an APIService completion handler with the loading-state
    /// dispatches: marks `key` as `.loading` synchronously when
    /// called, then on the result either dispatches
    /// `.failed(translatedFailure)` or invokes `onSuccess`. Caller
    /// passes the returned closure as the completion handler to
    /// `APIService.shared.GET(...)`.
    ///
    /// On success the loading-state entry is cleared *before*
    /// `onSuccess` runs. Order is UX-equivalent (both dispatches run
    /// in the same callback tick) but matters for tests that capture
    /// the most-recently-dispatched action — those tests are about
    /// the data action, not the loading bookkeeping.
    static func makeTrackedHandler<T>(
        key: LoadingKey,
        dispatch: @escaping DispatchFunction,
        onSuccess: @escaping (T) -> Void
    ) -> (Result<T, APIService.APIError>) -> Void {
        dispatch(SetLoadingState(key: key, state: .loading))
        return { result in
            switch result {
            case let .success(value):
                dispatch(SetLoadingState(key: key, state: nil))
                onSuccess(value)
            case let .failure(error):
                let failure = MoviesListLoadFailurePresenter.failure(from: error)
                dispatch(SetLoadingState(key: key, state: .failed(failure)))
            }
        }
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
    
    struct KeywordResponse: Codable {
        let id: Int
        let keywords: [Keyword]
    }
    
    struct SetSearch: Action {
        let query: String
        let page: Int
        let response: PaginatedResponse<Movie>
    }
    
    struct SetGenres: Action {
        let genres: [Genre]
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
        
    struct ResetRandomDiscover: Action {
        
    }
    
    struct SetRandomDiscover: Action {
        let filter: DiscoverFilter
        let response: PaginatedResponse<Movie>
    }
    
    struct SetActiveDiscoverFilter: Action {
        let filter: DiscoverFilter
    }
    
    struct PushRandomDiscover: Action {
        let movie: Int
    }
    
    struct PopRandromDiscover: Action {
        
    }
    
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
    
    struct SaveDiscoverFilter: Action {
        let filter: DiscoverFilter
    }
    
    struct ClearSavedDiscoverFilters: Action { }
}

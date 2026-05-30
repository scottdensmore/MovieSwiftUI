import Foundation
import SwiftUIFlux
import Backend

public struct MoviesActions {

    public init() {}

    // MARK: - Requests

    public struct FetchMoviesMenuList: AsyncAction {
        public let list: MoviesMenu
        public let page: Int

        public init(
            list: MoviesMenu,
            page: Int
        ) {
            self.list = list
            self.page = page
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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
                         "region": AppUserDefaults.region, ],
                completionHandler: handler
            )
        }
    }

    public struct FetchDetail: AsyncAction {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
            let key = LoadingKey.movieDetail(movie)
            let handler: (Result<Movie, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetDetail(movie: self.movie, response: response))
                }
            APIService.shared.GET(
                endpoint: .movieDetail(movie: movie),
                params: ["append_to_response": "keywords,images",
                         "include_image_language": "\(languageCode),en,null", ],
                completionHandler: handler
            )
        }
    }

    public struct FetchRecommended: AsyncAction {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    public struct FetchSimilar: AsyncAction {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    public struct FetchVideos: AsyncAction {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    public struct FetchSearchKeyword: AsyncAction {
        public let query: String

        public init(
            query: String
        ) {
            self.query = query
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    public struct FetchMoviesGenre: AsyncAction {
        public let genre: Genre
        public let page: Int
        public let sortBy: MoviesSort

        public init(
            genre: Genre,
            page: Int,
            sortBy: MoviesSort
        ) {
            self.genre = genre
            self.page = page
            self.sortBy = sortBy
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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
                         "sort_by": sortBy.sortByAPI(), ],
                completionHandler: handler
            )
        }
    }

    public struct FetchMovieReviews: AsyncAction {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    public struct FetchMovieWithCrew: AsyncAction {
        public let crew: Int

        public init(
            crew: Int
        ) {
            self.crew = crew
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
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

    public struct FetchMovieWithKeywords: AsyncAction {
        public let keyword: Int
        public let page: Int

        public init(
            keyword: Int,
            page: Int
        ) {
            self.keyword = keyword
            self.page = page
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let key = LoadingKey.moviesWithKeyword(keyword: keyword)
            let handler: (Result<PaginatedResponse<Movie>, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: key, dispatch: dispatch) { response in
                    dispatch(SetMovieWithKeyword(keyword: self.keyword,
                                                 page: self.page,
                                                 response: response))
                }
            APIService.shared.GET(endpoint: .discover,
                                  params: ["page": "\(page)",
                                           "with_keywords": "\(keyword)", ],
                                  completionHandler: handler)
        }
    }

    public struct FetchRandomDiscover: AsyncAction {
        public var filter: DiscoverFilter?

        /// Picks the random page from a `ClosedRange<Int>` after probing
        /// `total_pages`. Optional override so unit tests can pin the
        /// pick to a known value; `nil` (default) uses
        /// `Int.random(in: range)`.
        public var randomSource: ((ClosedRange<Int>) -> Int)?

        public init(
            filter: DiscoverFilter? = nil,
            randomSource: ((ClosedRange<Int>) -> Int)? = nil
        ) {
            self.filter = filter
            self.randomSource = randomSource
        }

        /// Pure: given a TMDB `total_pages`, pick a random page in
        /// `[1, min(total_pages, DiscoverFilter.randomPageCeiling)]`.
        ///
        /// TMDB's `/discover/movie` returns **HTTP 400** when `page >
        /// total_pages` — the old `randomPage()` could pick page 15 for a
        /// query that only has 3 pages, which is exactly the failure mode
        /// `feature/native-macos-target` was hitting. The fix is to call
        /// this AFTER probing page 1 so we know the real ceiling.
        ///
        /// `randomSource` defaults to `Int.random(in:)`; the parameter
        /// exists so unit tests can pin the random pick to a known value.
        public static func resolveTargetPage(
            totalPages: Int,
            randomSource: (ClosedRange<Int>) -> Int = { Int.random(in: $0) }
        ) -> Int {
            // total_pages is sometimes 0 for completely-empty queries
            // (no films matching). In that case page=1 is still the
            // valid request — TMDB returns an empty list for page=1
            // but 400 for any other page.
            let ceiling = min(max(totalPages, 1), DiscoverFilter.randomPageCeiling)
            return randomSource(1...ceiling)
        }

        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let resolvedFilter = self.filter ?? DiscoverFilter.randomFilter()
            let key = LoadingKey.randomDiscover

            // Phase 1 — probe with `page=1` to learn total_pages.
            //
            // We DON'T use `makeTrackedHandler` here because that helper
            // dispatches `SetLoadingState(nil)` on success — but on the
            // success branch of phase 1 we may still need to fire phase 2.
            // Clearing the loading state between phases would briefly
            // unblock the UI and look like a flicker. Instead we set
            // `.loading` once up-front and clear it only at the end of
            // whichever phase produces the final data action.
            dispatch(MoviesActions.SetLoadingState(key: key, state: .loading))

            APIService.shared.GET(endpoint: .discover,
                                  params: resolvedFilter.toParams(page: 1)) { (probeResult: Result<PaginatedResponse<Movie>, APIService.APIError>) in
                switch probeResult {
                case .failure(let error):
                    let failure = MoviesListLoadFailurePresenter.failure(from: error)
                    dispatch(MoviesActions.SetLoadingState(key: key, state: .failed(failure)))

                case .success(let probe):
                    let probeTotalPages = probe.total_pages ?? 1
                    let targetPage: Int
                    if let randomSource = self.randomSource {
                        targetPage = FetchRandomDiscover.resolveTargetPage(
                            totalPages: probeTotalPages,
                            randomSource: randomSource
                        )
                    } else {
                        targetPage = FetchRandomDiscover.resolveTargetPage(totalPages: probeTotalPages)
                    }
                    if targetPage == 1 {
                        // We already have page-1's data; don't waste a request.
                        dispatch(MoviesActions.SetLoadingState(key: key, state: nil))
                        dispatch(SetRandomDiscover(filter: resolvedFilter, response: probe))
                        return
                    }

                    // Phase 2 — actually fetch the random page now that we know it's in range.
                    APIService.shared.GET(endpoint: .discover,
                                          params: resolvedFilter.toParams(page: targetPage)) { (result: Result<PaginatedResponse<Movie>, APIService.APIError>) in
                        switch result {
                        case .failure(let error):
                            let failure = MoviesListLoadFailurePresenter.failure(from: error)
                            dispatch(MoviesActions.SetLoadingState(key: key, state: .failed(failure)))
                        case .success(let response):
                            dispatch(MoviesActions.SetLoadingState(key: key, state: nil))
                            dispatch(SetRandomDiscover(filter: resolvedFilter, response: response))
                        }
                    }
                }
            }
        }
    }

    public struct GenresResponse: Codable, Sendable {
        public let genres: [Genre]

        public init(
            genres: [Genre]
        ) {
            self.genres = genres
        }
    }

    public struct FetchGenres: AsyncAction {

        public init() {}
        public func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
            let handler: (Result<GenresResponse, APIService.APIError>) -> Void
                = MoviesActions.makeTrackedHandler(key: .genres, dispatch: dispatch) { response in
                    dispatch(SetGenres(genres: response.genres))
                }
            APIService.shared.GET(endpoint: .genres,
                                  params: nil,
                                  completionHandler: handler)
        }
    }

    public struct SetMovieMenuList: Action {
        public let page: Int
        public let list: MoviesMenu
        public let response: PaginatedResponse<Movie>

        public init(
            page: Int,
            list: MoviesMenu,
            response: PaginatedResponse<Movie>
        ) {
            self.page = page
            self.list = list
            self.response = response
        }
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
    public struct SetLoadingState: Action {
        public let key: LoadingKey
        public let state: MoviesListLoadingState?

        public init(
            key: LoadingKey,
            state: MoviesListLoadingState? = nil
        ) {
            self.key = key
            self.state = state
        }
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
    static public func makeTrackedHandler<T>(
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

    public struct SetDetail: Action {
        public let movie: Int
        public let response: Movie

        public init(
            movie: Int,
            response: Movie
        ) {
            self.movie = movie
            self.response = response
        }
    }
    public struct SetRecommended: Action {
        public let movie: Int
        public let response: PaginatedResponse<Movie>

        public init(
            movie: Int,
            response: PaginatedResponse<Movie>
        ) {
            self.movie = movie
            self.response = response
        }
    }
    public struct SetSimilar: Action {
        public let movie: Int
        public let response: PaginatedResponse<Movie>

        public init(
            movie: Int,
            response: PaginatedResponse<Movie>
        ) {
            self.movie = movie
            self.response = response
        }
    }

    public struct SetVideos: Action {
        public let movie: Int
        public let response: PaginatedResponse<Video>

        public init(
            movie: Int,
            response: PaginatedResponse<Video>
        ) {
            self.movie = movie
            self.response = response
        }
    }

    public struct KeywordResponse: Codable {
        public let id: Int
        public let keywords: [Keyword]

        public init(
            id: Int,
            keywords: [Keyword]
        ) {
            self.id = id
            self.keywords = keywords
        }
    }

    public struct SetSearch: Action {
        public let query: String
        public let page: Int
        public let response: PaginatedResponse<Movie>

        public init(
            query: String,
            page: Int,
            response: PaginatedResponse<Movie>
        ) {
            self.query = query
            self.page = page
            self.response = response
        }
    }

    public struct SetGenres: Action {
        public let genres: [Genre]

        public init(
            genres: [Genre]
        ) {
            self.genres = genres
        }
    }

    public struct SetSearchKeyword: Action {
        public let query: String
        public let response: PaginatedResponse<Keyword>

        public init(
            query: String,
            response: PaginatedResponse<Keyword>
        ) {
            self.query = query
            self.response = response
        }
    }

    public struct AddToWishlist: Action {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }
    }

    public struct RemoveFromWishlist: Action {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }
    }

    public struct AddToSeenList: Action {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }
    }

    public struct RemoveFromSeenList: Action {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }
    }

    public struct SetMovieForGenre: Action {
        public let genre: Genre
        public let page: Int
        public let response: PaginatedResponse<Movie>

        public init(
            genre: Genre,
            page: Int,
            response: PaginatedResponse<Movie>
        ) {
            self.genre = genre
            self.page = page
            self.response = response
        }
    }

    public struct SetMovieWithCrew: Action {
        public let crew: Int
        public let response: PaginatedResponse<Movie>

        public init(
            crew: Int,
            response: PaginatedResponse<Movie>
        ) {
            self.crew = crew
            self.response = response
        }
    }

    public struct SetMovieWithKeyword: Action {
        public let keyword: Int
        public let page: Int
        public let response: PaginatedResponse<Movie>

        public init(
            keyword: Int,
            page: Int,
            response: PaginatedResponse<Movie>
        ) {
            self.keyword = keyword
            self.page = page
            self.response = response
        }
    }

    public struct ResetRandomDiscover: Action {

        public init() {}

    }

    public struct SetRandomDiscover: Action {
        public let filter: DiscoverFilter
        public let response: PaginatedResponse<Movie>

        public init(
            filter: DiscoverFilter,
            response: PaginatedResponse<Movie>
        ) {
            self.filter = filter
            self.response = response
        }
    }

    public struct SetActiveDiscoverFilter: Action {
        public let filter: DiscoverFilter

        public init(
            filter: DiscoverFilter
        ) {
            self.filter = filter
        }
    }

    public struct PushRandomDiscover: Action {
        public let movie: Int

        public init(
            movie: Int
        ) {
            self.movie = movie
        }
    }

    public struct PopRandromDiscover: Action {

        public init() {}

    }

    public struct SetMovieReviews: Action {
        public let movie: Int
        public let response: PaginatedResponse<Review>

        public init(
            movie: Int,
            response: PaginatedResponse<Review>
        ) {
            self.movie = movie
            self.response = response
        }
    }

    public struct AddCustomList: Action {
        public let list: CustomList

        public init(
            list: CustomList
        ) {
            self.list = list
        }
    }

    public struct EditCustomList: Action {
        public let list: Int
        public let title: String?
        public let cover: Int?

        public init(
            list: Int,
            title: String? = nil,
            cover: Int? = nil
        ) {
            self.list = list
            self.title = title
            self.cover = cover
        }
    }

    public struct AddMovieToCustomList: Action {
        public let list: Int
        public let movie: Int

        public init(
            list: Int,
            movie: Int
        ) {
            self.list = list
            self.movie = movie
        }
    }

    public struct AddMoviesToCustomList: Action {
        public let list: Int
        public let movies: [Int]

        public init(
            list: Int,
            movies: [Int]
        ) {
            self.list = list
            self.movies = movies
        }
    }

    public struct RemoveMovieFromCustomList: Action {
        public let list: Int
        public let movie: Int

        public init(
            list: Int,
            movie: Int
        ) {
            self.list = list
            self.movie = movie
        }
    }

    public struct RemoveCustomList: Action {
        public let list: Int

        public init(
            list: Int
        ) {
            self.list = list
        }
    }

    public struct SaveDiscoverFilter: Action {
        public let filter: DiscoverFilter

        public init(
            filter: DiscoverFilter
        ) {
            self.filter = filter
        }
    }

    public struct ClearSavedDiscoverFilters: Action {
        public init() {}
    }
}

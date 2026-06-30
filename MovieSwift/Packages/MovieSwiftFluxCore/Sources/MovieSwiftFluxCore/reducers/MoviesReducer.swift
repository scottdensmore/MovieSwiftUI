import Foundation
import Flux

// The Redux dispatch switch covers every MoviesActions case in one
// function — high cyclomatic complexity is intrinsic to the reducer
// pattern, so the rule is disabled at the function site rather than
// globally.
// swiftlint:disable:next cyclomatic_complexity
public func moviesStateReducer(state: MoviesState, action: Action) -> MoviesState {
    var state = state
    switch action {
    case let action as MoviesActions.SetMovieMenuList:
        if action.page == 1 {
            state.moviesList[action.list] = action.response.results.map { $0.id }
        } else {
            if var list = state.moviesList[action.list] {
                list.append(contentsOf: action.response.results.map { $0.id })
                state.moviesList[action.list] = list
            } else {
                state.moviesList[action.list] = action.response.results.map { $0.id }
            }
        }
        state.movies += action.response.results

    case let action as MoviesActions.SetLoadingState:
        // Generic loading-state transition: nil-state clears the
        // entry. Success paths in AsyncAction completion handlers
        // dispatch SetLoadingState(state: nil), so a successful
        // response banishes any prior error banner without an
        // additional reducer hook here.
        if let s = action.state {
            state.loadingStates[action.key] = s
        } else {
            state.loadingStates.removeValue(forKey: action.key)
        }

    case let action as MoviesActions.SetDetail:
        state.movies[action.movie] = action.response
        state.detailed.insert(action.movie)

    case let action as MoviesActions.SetRecommended:
        state.recommended[action.movie] = action.response.results.map { $0.id }
        state.recommendedLoaded.insert(action.movie)
        state = mergeMovies(movies: action.response.results, state: state)

    case let action as MoviesActions.SetSimilar:
        state.similar[action.movie] = action.response.results.map { $0.id }
        state.similarLoaded.insert(action.movie)
        state = mergeMovies(movies: action.response.results, state: state)

    case let action as MoviesActions.SetVideos:
        state.videos[action.movie] = action.response.results
        state.videosLoaded.insert(action.movie)

    case let action as MoviesActions.SetSearch:
        if action.page == 1 {
            state.search[action.query] = action.response.results.map { $0.id }
        } else {
            state.search[action.query]?.append(contentsOf: action.response.results.map { $0.id })
        }
        state = mergeMovies(movies: action.response.results, state: state)

    case let action as MoviesActions.SetSearchKeyword:
        state.searchKeywords[action.query] = action.response.results

    case let action as MoviesActions.AddToWishlist:
        state.wishlist.insert(action.movie)
        state.seenlist.remove(action.movie)

        var meta = state.moviesUserMeta[action.movie] ?? MovieUserMeta()
        meta.addedToList = Date()
        state.moviesUserMeta[action.movie] = meta

    case let action as MoviesActions.RemoveFromWishlist:
        state.wishlist.remove(action.movie)

    case let action as MoviesActions.AddToSeenList:
        state.seenlist.insert(action.movie)
        state.wishlist.remove(action.movie)

        var meta = state.moviesUserMeta[action.movie] ?? MovieUserMeta()
        meta.addedToList = Date()
        state.moviesUserMeta[action.movie] = meta

    case let action as MoviesActions.RemoveFromSeenList:
        state.seenlist.remove(action.movie)

    case let action as MoviesActions.AddMovieToCustomList:
        state.customLists[action.list]?.movies.insert(action.movie)

    case let action as MoviesActions.AddMoviesToCustomList:
        if var list = state.customLists[action.list] {
            for movie in action.movies {
                list.movies.insert(movie)
            }
            state.customLists[action.list] = list
        }

    case let action as MoviesActions.RemoveMovieFromCustomList:
        state.customLists[action.list]?.movies.remove(action.movie)

    case let action as MoviesActions.SetMovieForGenre:
        if action.page == 1 {
            state.withGenre[action.genre.id] = action.response.results.map { $0.id }
        } else {
            state.withGenre[action.genre.id]?.append(contentsOf: action.response.results.map { $0.id })
        }
        state = mergeMovies(movies: action.response.results, state: state)

    case let action as MoviesActions.SetRandomDiscover:
        if state.discover.isEmpty {
            state.discover = action.response.results.map { $0.id }
        } else if state.discover.count < 10 {
            state.discover.insert(contentsOf: action.response.results.map { $0.id }, at: 0)
        }
        state = mergeMovies(movies: action.response.results, state: state)
        state.discoverFilter = action.filter

    case let action as MoviesActions.SetActiveDiscoverFilter:
        state.discoverFilter = action.filter

    case let action as MoviesActions.SetMovieReviews:
        state.reviews[action.movie] = action.response.results
        state.reviewsLoaded.insert(action.movie)

    case let action as MoviesActions.SetMovieWithCrew:
        state.withCrew[action.crew] = action.response.results.map { $0.id }
        state = mergeMovies(movies: action.response.results, state: state)

    case let action as MoviesActions.SetMovieWithKeyword:
        if action.page == 1 {
            state.withKeywords[action.keyword] = action.response.results.map { $0.id }
        } else {
            state.withKeywords[action.keyword]?.append(contentsOf: action.response.results.map { $0.id })
        }

        state = mergeMovies(movies: action.response.results, state: state)

    case let action as MoviesActions.AddCustomList:
        state.customLists[action.list.id] = action.list

    case let action as MoviesActions.EditCustomList:
        if var list = state.customLists[action.list] {
            if let cover = action.cover {
                list.cover = cover
            }
            if let title = action.title {
                list.name = title
            }
            state.customLists[action.list] = list
        }

    case let action as MoviesActions.RemoveCustomList:
        state.customLists[action.list] = nil

    case let action as MoviesActions.PopDiscoverCard:
        // Remove the swiped card (normally the current/last card) and record the
        // swipe so the view can offer a true undo. Remove by id — falling back
        // to the last card — so a caller can never pop the wrong movie even if
        // `action.movie` ever diverges from the deck's tail.
        if let index = state.discover.lastIndex(of: action.movie) {
            state.discover.remove(at: index)
        } else {
            _ = state.discover.popLast()
        }
        state.discoverLastSwipe = DiscoverSwipe(movie: action.movie, destination: action.destination)
    case let action as  MoviesActions.PushRandomDiscover:
        state.discover.append(action.movie)
        state.discoverLastSwipe = nil

    case _ as  MoviesActions.ResetRandomDiscover:
        state.discoverFilter = nil
        state.discover = []
        state.discoverLastSwipe = nil

    case let action as MoviesActions.SetGenres:
        state.genres = action.genres
        state.genres.insert(Genre(id: -1, name: "Random"), at: 0)

    case let action as PeopleActions.SetPeopleCredits:
        if let crews = action.response.crew {
            state = mergeMovies(movies: crews, state: state)
        }

        if let casts = action.response.cast {
            state = mergeMovies(movies: casts, state: state)
        }

    case let action as MoviesActions.SaveDiscoverFilter:
        state.savedDiscoverFilters.append(action.filter)

    case _ as MoviesActions.ClearSavedDiscoverFilters:
        state.savedDiscoverFilters = []

    default:
        break
    }

    return state
}

public func += (lhs: inout [Int: Movie], rhs: [Movie]) {
    for movie in rhs {
        lhs[movie.id] = movie
    }
}

private func mergeMovies(movies: [Movie], state: MoviesState) -> MoviesState {
    var state = state
    for movie in movies where state.movies[movie.id] == nil {
        state.movies[movie.id] = movie
    }
    return state
}

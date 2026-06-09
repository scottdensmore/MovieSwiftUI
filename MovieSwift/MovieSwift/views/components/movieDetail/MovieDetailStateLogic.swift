import Foundation
import MovieSwiftFluxCore

enum MovieDetailLoadSlice: Equatable {
    case detail
    case credits
    case recommended
    case similar
    case reviews
    case videos
}

enum MovieDetailFetchPolicy {
    static func slicesToFetch(hasMovieDetail: Bool,
                              hasMovieCredits: Bool,
                              hasRecommended: Bool,
                              hasSimilar: Bool,
                              hasReviews: Bool,
                              hasVideos: Bool,
                              isRunningUISmokeTests: Bool) -> [MovieDetailLoadSlice] {
        guard !isRunningUISmokeTests else {
            return []
        }

        var slices: [MovieDetailLoadSlice] = []
        if !hasMovieDetail {
            slices.append(.detail)
        }
        if !hasMovieCredits {
            slices.append(.credits)
        }
        if !hasRecommended {
            slices.append(.recommended)
        }
        if !hasSimilar {
            slices.append(.similar)
        }
        if !hasReviews {
            slices.append(.reviews)
        }
        if !hasVideos {
            slices.append(.videos)
        }
        return slices
    }
}

enum MovieDetailState {
    static func movie(movieId: Int, from state: AppState) -> Movie? {
        state.moviesState.movies[movieId]
    }

    static func hasLoadedDetail(movieId: Int, from state: AppState) -> Bool {
        guard state.moviesState.detailed.contains(movieId),
              let movie = movie(movieId: movieId, from: state) else {
            return false
        }

        return movie.keywords != nil && movie.images != nil
    }

    static func hasLoadedRecommended(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.recommendedLoaded.contains(movieId) &&
            state.moviesState.recommended[movieId] != nil
    }

    static func hasLoadedSimilar(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.similarLoaded.contains(movieId) &&
            state.moviesState.similar[movieId] != nil
    }

    static func hasLoadedReviews(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.reviewsLoaded.contains(movieId) &&
            state.moviesState.reviews[movieId] != nil
    }

    static func hasLoadedVideos(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.videosLoaded.contains(movieId) &&
            state.moviesState.videos[movieId] != nil
    }
}

enum MovieDetailListState {
    static func isInWishlist(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.wishlist.contains(movieId)
    }

    static func isInSeenlist(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.seenlist.contains(movieId)
    }

    static func customLists(from state: AppState) -> [CustomList] {
        state.moviesState.customLists.compactMap { $0.value }
    }
}

enum MovieDetailPeopleState {
    static func characters(movieId: Int, from state: AppState) -> [People]? {
        contextualPeople(movieId: movieId,
                         from: state,
                         peopleIds: state.peoplesState.movieCastOrder[movieId],
                         metadata: state.peoplesState.casts) { people, role in
            var contextual = people
            contextual.character = role
            contextual.department = nil
            return contextual
        }
    }

    static func credits(movieId: Int, from state: AppState) -> [People]? {
        contextualPeople(movieId: movieId,
                         from: state,
                         peopleIds: state.peoplesState.movieCrewOrder[movieId],
                         metadata: state.peoplesState.crews) { people, department in
            var contextual = people
            contextual.character = nil
            contextual.department = department
            return contextual
        }
    }

    static func hasLoadedMovieCredits(movieId: Int, from state: AppState) -> Bool {
        guard state.peoplesState.movieCreditsLoaded.contains(movieId),
              state.peoplesState.movieCastOrder[movieId] != nil,
              state.peoplesState.movieCrewOrder[movieId] != nil else {
            return false
        }

        let hasResolvedPeople = characters(movieId: movieId, from: state)?.isEmpty == false ||
            credits(movieId: movieId, from: state)?.isEmpty == false
        let hasExplicitlyEmptyCredits = state.peoplesState.movieCastOrder[movieId]?.isEmpty == true &&
            state.peoplesState.movieCrewOrder[movieId]?.isEmpty == true

        return hasResolvedPeople || hasExplicitlyEmptyCredits
    }

    private static func contextualPeople(movieId: Int,
                                         from state: AppState,
                                         peopleIds: [Int]?,
                                         metadata: [Int: [Int: String]],
                                         transform: (People, String) -> People) -> [People]? {
        let resolvedPeopleIds = peopleIds ?? state.peoplesState.peoplesMovies[movieId]?.sorted()
        guard let resolvedPeopleIds = resolvedPeopleIds, !resolvedPeopleIds.isEmpty else {
            return nil
        }

        let contextual = resolvedPeopleIds.compactMap { peopleId -> People? in
            guard let people = state.peoplesState.peoples[peopleId],
                  let role = metadata[peopleId]?[movieId],
                  !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return transform(people, role)
        }

        return contextual.isEmpty ? nil : contextual
    }
}

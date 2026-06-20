import Foundation

public enum MoviesSort: Sendable {
    case byReleaseDate, byAddedDate, byScore, byPopularity

    public func title() -> String {
        // `bundle: .module`: localized strings live in the
        // MovieSwiftFluxCore package's own catalog, not the app bundle.
        switch self {
        case .byReleaseDate:
            return String(localized: "by release date", bundle: .module,
                          comment: "Sort option: order movies by release date")
        case .byAddedDate:
            return String(localized: "by added date", bundle: .module,
                          comment: "Sort option: order movies by when the user added them")
        case .byScore:
            return String(localized: "by rating", bundle: .module,
                          comment: "Sort option: order movies by rating")
        case .byPopularity:
            return String(localized: "by popularity", bundle: .module,
                          comment: "Sort option: order movies by popularity")
        }
    }

    public func sortByAPI() -> String {
        switch self {
        case .byReleaseDate:
            return "release_date.desc"
        case .byAddedDate:
            return "primary_release_date.desc"
        case .byScore:
            return "vote_average.desc"
        case .byPopularity:
            return "popularity.desc"
        }
    }
}

public extension Sequence where Iterator.Element == Int {
    func sortedMoviesIds(by: MoviesSort, state: AppState) -> [Int] {
        let ids = Array(self)

        switch by {
        case .byAddedDate:
            return ids.sorted {
                let lhs = state.moviesState.moviesUserMeta[$0]?.addedToList ?? .distantPast
                let rhs = state.moviesState.moviesUserMeta[$1]?.addedToList ?? .distantPast
                return lhs > rhs
            }
        case .byReleaseDate:
            return ids.sorted {
                let lhs = state.moviesState.movies[$0].flatMap { MovieSortValues.releaseDate(for: $0) } ?? .distantPast
                let rhs = state.moviesState.movies[$1].flatMap { MovieSortValues.releaseDate(for: $0) } ?? .distantPast
                return lhs > rhs
            }
        case .byPopularity:
            return ids.sorted {
                let lhs = state.moviesState.movies[$0]?.popularity ?? -Float.greatestFiniteMagnitude
                let rhs = state.moviesState.movies[$1]?.popularity ?? -Float.greatestFiniteMagnitude
                return lhs > rhs
            }
        case .byScore:
            return ids.sorted {
                let lhs = state.moviesState.movies[$0]?.voteAverage ?? -Float.greatestFiniteMagnitude
                let rhs = state.moviesState.movies[$1]?.voteAverage ?? -Float.greatestFiniteMagnitude
                return lhs > rhs
            }
        }
    }
}

private enum MovieSortValues {
    static func releaseDate(for movie: Movie) -> Date? {
        guard let releaseDate = movie.releaseDateString else {
            return nil
        }
        return Movie.dateFormatter.date(from: releaseDate)
    }
}

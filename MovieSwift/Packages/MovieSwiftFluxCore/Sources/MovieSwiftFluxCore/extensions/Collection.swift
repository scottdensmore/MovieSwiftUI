import Foundation

public enum MoviesSort {
    case byReleaseDate, byAddedDate, byScore, byPopularity
    
    public func title() -> String {
        switch self {
        case .byReleaseDate:
            return "by release date"
        case .byAddedDate:
            return "by added date"
        case .byScore:
            return "by rating"
        case .byPopularity:
            return "by popularity"
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
    public func sortedMoviesIds(by: MoviesSort, state: AppState) -> [Int] {
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
                let lhs = state.moviesState.movies[$0]?.vote_average ?? -Float.greatestFiniteMagnitude
                let rhs = state.moviesState.movies[$1]?.vote_average ?? -Float.greatestFiniteMagnitude
                return lhs > rhs
            }
        }
    }
}

private enum MovieSortValues {
    static func releaseDate(for movie: Movie) -> Date? {
        guard let releaseDate = movie.release_date else {
            return nil
        }
        return Movie.dateFormatter.date(from: releaseDate)
    }
}

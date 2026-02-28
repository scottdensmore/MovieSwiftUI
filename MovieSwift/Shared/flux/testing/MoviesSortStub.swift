import Foundation

enum MoviesSort {
    case byReleaseDate
    case byAddedDate
    case byScore
    case byPopularity

    func sortByAPI() -> String {
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

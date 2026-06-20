import Foundation

/// Builds links to the public themoviedb.org web pages — used by the Share
/// action on the movie/person detail screens so a shared link opens the
/// movie/person on TMDB (and the share sheet can fetch a rich preview from
/// the page's metadata).
public enum TMDBWeb {
    private static let base = "https://www.themoviedb.org"

    public static func movieURL(id: Int) -> URL {
        // swiftlint:disable:next force_unwrapping - constant https base + Int id is always valid
        URL(string: "\(base)/movie/\(id)")!
    }

    public static func personURL(id: Int) -> URL {
        // swiftlint:disable:next force_unwrapping - constant https base + Int id is always valid
        URL(string: "\(base)/person/\(id)")!
    }
}

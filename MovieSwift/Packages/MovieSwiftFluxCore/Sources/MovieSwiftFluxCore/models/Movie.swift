import Foundation
import SwiftUI
import Backend

public struct Movie: Codable, Identifiable, Sendable {
    public let id: Int

    public let originalTitle: String
    public let title: String

    // Swift properties are camelCase; the TMDB JSON keys (and the keys
    // persisted in user backups) are snake_case. `CodingKeys` bridges the
    // two so the decoded/encoded wire format is unchanged. The raw
    // `release_date` string is stored as `releaseDateString` because the
    // camelCase `releaseDate` name belongs to the computed `Date` below.
    public enum CodingKeys: String, CodingKey {
        case id
        case originalTitle = "original_title"
        case title
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case popularity
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDateString = "release_date"
        case genres
        case runtime
        case status
        case video
        case keywords
        case images
        case productionCountries = "production_countries"
        case character
        case department
    }

    public init(
        id: Int,
        originalTitle: String,
        title: String,
        overview: String,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        popularity: Float,
        voteAverage: Float,
        voteCount: Int,
        releaseDateString: String? = nil,
        genres: [Genre]? = nil,
        runtime: Int? = nil,
        status: String? = nil,
        video: Bool,
        keywords: Keywords? = nil,
        images: MovieImages? = nil,
        productionCountries: [ProductionCountry]? = nil,
        character: String? = nil,
        department: String? = nil
    ) {
        self.id = id
        self.originalTitle = originalTitle
        self.title = title
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.popularity = popularity
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.releaseDateString = releaseDateString
        self.genres = genres
        self.runtime = runtime
        self.status = status
        self.video = video
        self.keywords = keywords
        self.images = images
        self.productionCountries = productionCountries
        self.character = character
        self.department = department
    }
    public var userTitle: String {
        return AppUserDefaults.alwaysOriginalTitle ? originalTitle : title
    }

    public let overview: String
    public let posterPath: String?
    public let backdropPath: String?
    public let popularity: Float
    public let voteAverage: Float
    public let voteCount: Int

    public let releaseDateString: String?
    public var releaseDate: Date? {
        guard let releaseDateString else { return Date() }
        return Movie.dateFormatter.date(from: releaseDateString)
    }

    static public let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyy-MM-dd"
        return formatter
    }()

    public let genres: [Genre]?
    public let runtime: Int?
    public let status: String?
    public let video: Bool

    public var keywords: Keywords?
    public var images: MovieImages?

    public var productionCountries: [ProductionCountry]?

    public var character: String?
    public var department: String?

    public struct Keywords: Codable, Sendable {
        public let keywords: [Keyword]?

        public init(
            keywords: [Keyword]? = nil
        ) {
            self.keywords = keywords
        }
    }

    public struct MovieImages: Codable, Sendable {
        public let posters: [ImageData]?
        public let backdrops: [ImageData]?

        public init(
            posters: [ImageData]? = nil,
            backdrops: [ImageData]? = nil
        ) {
            self.posters = posters
            self.backdrops = backdrops
        }
    }

    public struct ProductionCountry: Codable, Identifiable, Sendable {

        public init(
            name: String
        ) {
            self.name = name
        }
        public var id: String {
            name
        }
        public let name: String
    }

    static public func placeholder(id: Int) -> Movie {
        Movie(id: id,
              originalTitle: "Movie unavailable",
              title: "Movie unavailable",
              overview: "Details for this saved movie are not currently cached.",
              posterPath: nil,
              backdropPath: nil,
              popularity: 0,
              voteAverage: 0,
              voteCount: 0,
              releaseDateString: nil,
              genres: nil,
              runtime: nil,
              status: nil,
              video: false,
              keywords: nil,
              images: nil,
              productionCountries: nil,
              character: nil,
              department: nil)
    }
}

public let sampleMovie = Movie(id: 0,
                        originalTitle: "Test movie Test movie Test movie Test movie Test movie Test movie Test movie ",
                        title: "Test movie Test movie Test movie Test movie Test movie Test movie Test movie  Test movie Test movie Test movie",
                        overview: "Test desc",
                        posterPath: "/uC6TTUhPpQCmgldGyYveKRAu8JN.jpg",
                        backdropPath: "/nl79FQ8xWZkhL3rDr1v2RFFR6J0.jpg",
                        popularity: 50.5,
                        voteAverage: 8.9,
                        voteCount: 1000,
                        releaseDateString: "1972-03-14",
                        genres: [Genre(id: 0, name: "test")],
                        runtime: 80,
                        status: "released",
                        video: false)

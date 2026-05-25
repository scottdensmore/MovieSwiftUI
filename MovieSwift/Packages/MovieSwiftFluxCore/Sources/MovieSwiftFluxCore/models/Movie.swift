import Foundation
import SwiftUI
import Backend

public struct Movie: Codable, Identifiable, Sendable {
    public let id: Int
    
    public let original_title: String
    public let title: String

    public init(
        id: Int,
        original_title: String,
        title: String,
        overview: String,
        poster_path: String? = nil,
        backdrop_path: String? = nil,
        popularity: Float,
        vote_average: Float,
        vote_count: Int,
        release_date: String? = nil,
        genres: [Genre]? = nil,
        runtime: Int? = nil,
        status: String? = nil,
        video: Bool,
        keywords: Keywords? = nil,
        images: MovieImages? = nil,
        production_countries: [productionCountry]? = nil,
        character: String? = nil,
        department: String? = nil
    ) {
        self.id = id
        self.original_title = original_title
        self.title = title
        self.overview = overview
        self.poster_path = poster_path
        self.backdrop_path = backdrop_path
        self.popularity = popularity
        self.vote_average = vote_average
        self.vote_count = vote_count
        self.release_date = release_date
        self.genres = genres
        self.runtime = runtime
        self.status = status
        self.video = video
        self.keywords = keywords
        self.images = images
        self.production_countries = production_countries
        self.character = character
        self.department = department
    }
    public var userTitle: String {
        return AppUserDefaults.alwaysOriginalTitle ? original_title : title
    }
    
    public let overview: String
    public let poster_path: String?
    public let backdrop_path: String?
    public let popularity: Float
    public let vote_average: Float
    public let vote_count: Int
    
    public let release_date: String?
    public var releaseDate: Date? {
        return release_date != nil ? Movie.dateFormatter.date(from: release_date!) : Date()
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
    
    public var production_countries: [productionCountry]?
    
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
    
    public struct productionCountry: Codable, Identifiable, Sendable {

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
              original_title: "Movie unavailable",
              title: "Movie unavailable",
              overview: "Details for this saved movie are not currently cached.",
              poster_path: nil,
              backdrop_path: nil,
              popularity: 0,
              vote_average: 0,
              vote_count: 0,
              release_date: nil,
              genres: nil,
              runtime: nil,
              status: nil,
              video: false,
              keywords: nil,
              images: nil,
              production_countries: nil,
              character: nil,
              department: nil)
    }
}

public let sampleMovie = Movie(id: 0,
                        original_title: "Test movie Test movie Test movie Test movie Test movie Test movie Test movie ",
                        title: "Test movie Test movie Test movie Test movie Test movie Test movie Test movie  Test movie Test movie Test movie",
                        overview: "Test desc",
                        poster_path: "/uC6TTUhPpQCmgldGyYveKRAu8JN.jpg",
                        backdrop_path: "/nl79FQ8xWZkhL3rDr1v2RFFR6J0.jpg",
                        popularity: 50.5,
                        vote_average: 8.9,
                        vote_count: 1000,
                        release_date: "1972-03-14",
                        genres: [Genre(id: 0, name: "test")],
                        runtime: 80,
                        status: "released",
                        video: false)

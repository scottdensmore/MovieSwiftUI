import Foundation
import SwiftUI

public struct DiscoverFilter: Codable {
    public let year: Int
    public let startYear: Int?
    public let endYear: Int?
    public let sort: String
    public let genre: Int?
    public let region: String?

    public init(
        year: Int,
        startYear: Int? = nil,
        endYear: Int? = nil,
        sort: String,
        genre: Int? = nil,
        region: String? = nil
    ) {
        self.year = year
        self.startYear = startYear
        self.endYear = endYear
        self.sort = sort
        self.genre = genre
        self.region = region
    }

    public var hasExplicitConstraints: Bool {
        startYear != nil || endYear != nil || genre != nil || region != nil
    }
    
    static public func randomFilter() -> DiscoverFilter {
        return DiscoverFilter(year: randomYear(),
                              startYear: nil,
                              endYear: nil,
                              sort: randomSort(),
                              genre: nil,
                              region: nil)
    }
    
    static public func randomYear() -> Int {
        let calendar = Calendar.current
        return Int.random(in: 1950..<calendar.component(.year, from: Date()))
    }
    
    static public func randomSort() -> String {
        let sortBy = ["popularity.desc",
                      "popularity.asc",
                      "vote_average.asc",
                      "vote_average.desc"]
        return sortBy[Int.random(in: 0..<sortBy.count)]
    }
    
    static public func randomPage() -> Int {
        return Int.random(in: 1..<20)
    }
    
    public func toParams() -> [String: String] {
        var params: [String: String] = [:]
        if let startYear = startYear, let endYear = endYear {
            params["primary_release_date.gte"] = "\(startYear)-01-01"
            params["primary_release_date.lte"] = "\(endYear)-12-31"
        } else {
            params["year"] = "\(year)"
        }
        if let genre = genre {
            params["with_genres"] = "\(genre)"
        }
        if let region = region {
            params["region"] = region
            // Restrict to movies originating from the selected country.
            params["with_origin_country"] = region
        }
        params["page"] = "\(DiscoverFilter.randomPage())"
        params["sort_by"] = sort
        params["language"] = "en-US"
        return params
    }
    
    public func toText(genres: [Genre]) -> String {
        var parts: [String] = []
        if let startYear = startYear, let endYear = endYear {
            parts.append("\(startYear)-\(endYear)")
        } else {
            parts.append("Random")
        }
        if let genre = genre,
            let stateGenre = genres.first(where: { (realGenre) -> Bool in
                realGenre.id == genre
            }) {
            parts.append(stateGenre.name)
        }
        if let region = region {
            parts.append(region)
        }
        return parts.joined(separator: " · ")
    }
}

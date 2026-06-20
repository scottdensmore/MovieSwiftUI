import Foundation
import Flux

public struct PeoplesState: FluxState, Codable, Sendable {
    public var peoples: [Int: People] = [:]
    public var peoplesMovies: [Int: Set<Int>] = [:]
    public var search: [String: [Int]] = [:]
    public var popular: [Int] = []

    public init(
        peoples: [Int: People] = [:],
        peoplesMovies: [Int: Set<Int>] = [:],
        search: [String: [Int]] = [:],
        popular: [Int] = [],
        detailed: Set<Int> = Set(),
        imagesLoaded: Set<Int> = Set(),
        creditsLoaded: Set<Int> = Set(),
        movieCreditsLoaded: Set<Int> = Set(),
        casts: [Int: [Int: String]] = [:],
        crews: [Int: [Int: String]] = [:],
        movieCastOrder: [Int: [Int]] = [:],
        movieCrewOrder: [Int: [Int]] = [:],
        fanClub: Set<Int> = Set()
    ) {
        self.peoples = peoples
        self.peoplesMovies = peoplesMovies
        self.search = search
        self.popular = popular
        self.detailed = detailed
        self.imagesLoaded = imagesLoaded
        self.creditsLoaded = creditsLoaded
        self.movieCreditsLoaded = movieCreditsLoaded
        self.casts = casts
        self.crews = crews
        self.movieCastOrder = movieCastOrder
        self.movieCrewOrder = movieCrewOrder
        self.fanClub = fanClub
    }
    public var popularLoading = false
    public var popularInitialLoadCompleted = false
    public var popularLoadFailed = false
    public var detailed: Set<Int> = Set()
    public var imagesLoaded: Set<Int> = Set()
    public var creditsLoaded: Set<Int> = Set()
    public var movieCreditsLoaded: Set<Int> = Set()

    /// [PeopleId: [MovieId:  Character]]
    public var casts: [Int: [Int: String]] = [:]
    /// [PeopleId: [MovieId:  Character]]
    public var crews: [Int: [Int: String]] = [:]
    /// [MovieId: [PeopleId]]
    public var movieCastOrder: [Int: [Int]] = [:]
    /// [MovieId: [PeopleId]]
    public var movieCrewOrder: [Int: [Int]] = [:]

    public var fanClub: Set<Int> = Set()

    public enum CodingKeys: String, CodingKey {
        case peoples
        case fanClub
        case casts
        case crews
        case movieCastOrder
        case movieCrewOrder
        case detailed
        case imagesLoaded
        case creditsLoaded
        case movieCreditsLoaded
    }
}

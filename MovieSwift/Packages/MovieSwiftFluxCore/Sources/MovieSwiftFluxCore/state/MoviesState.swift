import Foundation
import SwiftUIFlux

public struct MoviesState: FluxState, Codable, Sendable {
    public var movies: [Int: Movie] = [:]
    public var moviesList: [MoviesMenu: [Int]] = [:]

    public init(
        movies: [Int: Movie] = [:],
        moviesList: [MoviesMenu: [Int]] = [:],
        loadingStates: [LoadingKey: MoviesListLoadingState] = [:],
        detailed: Set<Int> = Set(),
        recommended: [Int: [Int]] = [:],
        similar: [Int: [Int ]] = [:],
        recommendedLoaded: Set<Int> = Set(),
        similarLoaded: Set<Int> = Set(),
        search: [String: [Int]] = [:],
        searchKeywords: [String: [Keyword]] = [:],
        recentSearches: Set<String> = Set(),
        moviesUserMeta: [Int: MovieUserMeta] = [:],
        discover: [Int] = [],
        discoverFilter: DiscoverFilter? = nil,
        savedDiscoverFilters: [DiscoverFilter] = [],
        wishlist: Set<Int> = Set(),
        seenlist: Set<Int> = Set(),
        videos: [Int: [Video]] = [:],
        videosLoaded: Set<Int> = Set(),
        withGenre: [Int: [Int]] = [:],
        withKeywords: [Int: [Int]] = [:],
        withCrew: [Int: [Int]] = [:],
        reviews: [Int: [Review]] = [:],
        reviewsLoaded: Set<Int> = Set(),
        customLists: [Int: CustomList] = [:],
        genres: [Genre] = []
    ) {
        self.movies = movies
        self.moviesList = moviesList
        self.loadingStates = loadingStates
        self.detailed = detailed
        self.recommended = recommended
        self.similar = similar
        self.recommendedLoaded = recommendedLoaded
        self.similarLoaded = similarLoaded
        self.search = search
        self.searchKeywords = searchKeywords
        self.recentSearches = recentSearches
        self.moviesUserMeta = moviesUserMeta
        self.discover = discover
        self.discoverFilter = discoverFilter
        self.savedDiscoverFilters = savedDiscoverFilters
        self.wishlist = wishlist
        self.seenlist = seenlist
        self.videos = videos
        self.videosLoaded = videosLoaded
        self.withGenre = withGenre
        self.withKeywords = withKeywords
        self.withCrew = withCrew
        self.reviews = reviews
        self.reviewsLoaded = reviewsLoaded
        self.customLists = customLists
        self.genres = genres
    }
    /// Transient: in-flight / failed-state tracker for every async
    /// fetcher in the app, keyed by `LoadingKey`. A missing entry
    /// means "no in-flight request" — the cached data (if any) is the
    /// latest known good. Excluded from CodingKeys because it
    /// represents network state, not data the user owns.
    ///
    /// Lives in MoviesState rather than PeoplesState (or AppState)
    /// because moviesStateReducer is the natural single owner — both
    /// Movies and People AsyncActions dispatch
    /// `MoviesActions.SetLoadingState` here.
    public var loadingStates: [LoadingKey: MoviesListLoadingState] = [:]
    public var detailed: Set<Int> = Set()
    
    public var recommended: [Int: [Int]] = [:]
    public var similar: [Int: [Int ]] = [:]
    public var recommendedLoaded: Set<Int> = Set()
    public var similarLoaded: Set<Int> = Set()
    
    public var search: [String: [Int]] = [:]
    public var searchKeywords: [String: [Keyword]] = [:]
    public var recentSearches: Set<String> = Set()
    
    public var moviesUserMeta: [Int: MovieUserMeta] = [:]
    
    public var discover: [Int] = []
    public var discoverFilter: DiscoverFilter?
    public var savedDiscoverFilters: [DiscoverFilter] = []
    
    public var wishlist: Set<Int> = Set()
    public var seenlist: Set<Int> = Set()
    
    public var videos: [Int: [Video]] = [:]
    public var videosLoaded: Set<Int> = Set()
    
    public var withGenre: [Int: [Int]] = [:]
    public var withKeywords: [Int: [Int]] = [:]
    public var withCrew: [Int: [Int]] = [:]
    public var reviews: [Int: [Review]] = [:]
    public var reviewsLoaded: Set<Int> = Set()
    
    public var customLists: [Int: CustomList] = [:]
    
    public var genres: [Genre] = []
    
    public enum CodingKeys: String, CodingKey {
        case movies, wishlist, seenlist, customLists, moviesUserMeta, savedDiscoverFilters, discoverFilter
        case detailed, recommendedLoaded, similarLoaded, videosLoaded, reviewsLoaded
    }
}

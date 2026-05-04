//
//  MoviesState.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUIFlux

struct MoviesState: FluxState, Codable {
    var movies: [Int: Movie] = [:]
    var moviesList: [MoviesMenu: [Int]] = [:]
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
    var loadingStates: [LoadingKey: MoviesListLoadingState] = [:]
    var detailed: Set<Int> = Set()
    
    var recommended: [Int: [Int]] = [:]
    var similar: [Int: [Int ]] = [:]
    var recommendedLoaded: Set<Int> = Set()
    var similarLoaded: Set<Int> = Set()
    
    var search: [String: [Int]] = [:]
    var searchKeywords: [String: [Keyword]] = [:]
    var recentSearches: Set<String> = Set()
    
    var moviesUserMeta: [Int: MovieUserMeta] = [:]
    
    var discover: [Int] = []
    var discoverFilter: DiscoverFilter?
    var savedDiscoverFilters: [DiscoverFilter] = []
    
    var wishlist: Set<Int> = Set()
    var seenlist: Set<Int> = Set()
    
    var videos: [Int: [Video]] = [:]
    var videosLoaded: Set<Int> = Set()
    
    var withGenre: [Int: [Int]] = [:]
    var withKeywords: [Int: [Int]] = [:]
    var withCrew: [Int: [Int]] = [:]
    var reviews: [Int: [Review]] = [:]
    var reviewsLoaded: Set<Int> = Set()
    
    var customLists: [Int: CustomList] = [:]
    
    var genres: [Genre] = []
    
    enum CodingKeys: String, CodingKey {
        case movies, wishlist, seenlist, customLists, moviesUserMeta, savedDiscoverFilters, discoverFilter
        case detailed, recommendedLoaded, similarLoaded, videosLoaded, reviewsLoaded
    }
}

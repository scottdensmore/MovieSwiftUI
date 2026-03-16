//
//  OutlineMenu.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 27/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUI

enum OutlineMenu: Int, CaseIterable, Identifiable {
    var id: Int {
        return self.rawValue
    }
    
    
    case popular, topRated, upcoming, nowPlaying, trending, genres, fanClub, discover, myLists, settings
    
    var title: String {
        switch self {
        case .popular:    return "Popular"
        case .topRated:   return "Top rated"
        case .upcoming:   return "Upcoming"
        case .nowPlaying: return "Now Playing"
        case .trending:   return "Trending"
        case .genres:     return "Genres"
        case .fanClub:    return "Fan Club"
        case .discover:   return "Discover"
        case .myLists:    return "My Lists"
        case .settings:   return "Settings"
        }
    }
    
    var image: String {
        switch self {
        case .popular:    return "film.fill"
        case .topRated:   return "star.fill"
        case .upcoming:   return "clock.fill"
        case .nowPlaying: return "play.circle.fill"
        case .trending:   return "chart.bar.fill"
        case .genres:     return "tag.fill"
        case .fanClub:    return "star.circle.fill"
        case .discover:   return "square.stack.fill"
        case .myLists:    return "text.badge.plus"
        case .settings:   return "wrench"
        }
    }
    
    private func detailRoot<Content: View>(title: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func moviesList(menu: MoviesMenu) -> some View {
        let listener = MoviesMenuListPageListener(menu: menu, loadOnInit: false)
        return detailRoot(title: menu.title()) {
            MoviesHomeList(menu: .constant(menu),
                           pageListener: listener)
                .onAppear { listener.loadPage() }
        }
    }
    
    private var genresList: some View {
        detailRoot(title: "Genres") {
            GenresList()
        }
    }
    
    private var discoverList: some View {
        detailRoot(title: "Discover") {
            DiscoverView()
        }
    }
    
    private var fanClubList: some View {
        detailRoot(title: "Fan Club") {
            FanClubHome(embedInNavigationStack: false,
                        showNavigationTitle: false)
        }
    }
    
    private var myListsList: some View {
        detailRoot(title: "My Lists") {
            MyLists(embedInNavigationStack: false,
                    showNavigationTitle: false)
        }
    }
    
    private var settingsList: some View {
        detailRoot(title: "Settings") {
            SettingsForm(embedInNavigationStack: false,
                         showNavigationTitle: false)
        }
    }
    
    @ViewBuilder
    var contentView: some View {
        switch self {
        case .popular:    moviesList(menu: .popular)
        case .topRated:   moviesList(menu: .topRated)
        case .upcoming:   moviesList(menu: .upcoming)
        case .nowPlaying: moviesList(menu: .nowPlaying)
        case .trending:   moviesList(menu: .trending)
        case .genres:     genresList
        case .fanClub:    fanClubList
        case .discover:   discoverList
        case .myLists:    myListsList
        case .settings:   settingsList
        }
    }
}

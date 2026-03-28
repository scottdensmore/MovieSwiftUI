//
//  HomeView.swift
//  MovieSwiftTV
//

import SwiftUI

struct HomeView: View {
    @State private var selectedTab = MoviesMenu.popular

    private static let movieTabs: [MoviesMenu] = MoviesMenu.allCases.filter { $0 != .genres }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Self.movieTabs, id: \.self) { menu in
                NavigationStack {
                    MoviesView(menu: menu)
                        .navigationTitle(menu.title())
                }
                .tabItem { Label(menu.title(), systemImage: tabIcon(for: menu)) }
                .tag(menu)
            }
        }
    }

    private func tabIcon(for menu: MoviesMenu) -> String {
        switch menu {
        case .popular:      return "flame"
        case .topRated:     return "star"
        case .upcoming:     return "calendar"
        case .nowPlaying:   return "play.circle"
        case .trending:     return "chart.line.uptrend.xyaxis"
        case .genres:       return "tag"
        }
    }
}

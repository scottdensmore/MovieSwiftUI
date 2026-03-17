//
//  MoviesHome.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 22/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Combine
import SwiftUIFlux

struct MoviesHome : View {
    private enum HomeMode {
        case list, grid
        
        func icon() -> String {
            switch self {
            case .list: return "rectangle.3.offgrid.fill"
            case .grid: return "rectangle.grid.1x2"
            }
        }
    }

    @StateObject private var selectedMenu = MoviesSelectedMenuStore(selectedMenu: MoviesMenu.allCases.first!)
    @State private var isSettingPresented = false
    @State private var homeMode = HomeMode.list
    @State private var navigationRoute: MoviesListNavigationRoute?
        
    private var settingButton: some View {
        Button(action: {
            self.isSettingPresented = true
        }) {
            HStack {
                Image(systemName: "wrench").imageScale(.medium)
            }.frame(width: 30, height: 30)
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("moviesHome.settingsButton")
    }
    
    private var swapHomeButton: some View {
        Button(action: {
            self.homeMode = self.homeMode == .grid ? .list : .grid
        }) {
            HStack {
                Image(systemName: self.homeMode.icon()).imageScale(.medium)
            }.frame(width: 30, height: 30)
        }
        .accessibilityLabel("Toggle layout")
        .accessibilityIdentifier("moviesHome.toggleLayoutButton")
    }
    
    @ViewBuilder
    private var homeAsList: some View {
        TabView(selection: $selectedMenu.menu) {
            ForEach(MoviesMenu.allCases, id: \.self) { menu in
                if menu == .genres {
                    GenresList()
                        .tag(menu)
                } else {
                    MoviesHomeList(menu: .constant(menu),
                                   navigationRoute: $navigationRoute,
                                   pageListener: selectedMenu.pageListener)
                        .tag(menu)
                }
            }
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
    
    private var homeAsGrid: some View {
        MoviesHomeGrid(navigationRoute: $navigationRoute)
    }
        
    var body: some View {
        NavigationStack {
            Group {
                switch homeMode {
                case .list:
                    homeAsList
                case .grid:
                    homeAsGrid
                }
            }
            .navigationTitle(selectedMenu.menu.title())
            .navigationBarTitleDisplayMode(homeMode == .list ? .inline : .automatic)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    swapHomeButton
                    settingButton
                }
            }
            .navigationDestination(item: $navigationRoute) { route in
                moviesListDestinationView(for: route)
            }
            .fullScreenCover(isPresented: $isSettingPresented,
                             content: {
                                 SettingsForm(onClose: {
                                     isSettingPresented = false
                                 })
                             })
        }
    }
}

#if DEBUG
struct MoviesHome_Previews : PreviewProvider {
    static var previews: some View {
        MoviesHome().environmentObject(sampleStore)
    }
}
#endif

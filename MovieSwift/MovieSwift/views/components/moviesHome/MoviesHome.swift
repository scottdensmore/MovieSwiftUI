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

enum MoviesHomeState {
    static func toggledMode(from mode: MoviesHome.HomeMode) -> MoviesHome.HomeMode {
        mode == .grid ? .list : .grid
    }

    static func navigationBarTitleDisplayMode(for mode: MoviesHome.HomeMode) -> NavigationBarItem.TitleDisplayMode {
        mode == .list ? .inline : .automatic
    }

    static func shouldLoadPage(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }
}

struct MoviesHome : View {
    enum HomeMode {
        case list, grid
        
        func icon() -> String {
            switch self {
            case .list: return "rectangle.3.offgrid.fill"
            case .grid: return "rectangle.grid.1x2"
            }
        }
    }

    @EnvironmentObject private var store: Store<AppState>
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
            self.homeMode = MoviesHomeState.toggledMode(from: self.homeMode)
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

    private func configurePageListener() {
        selectedMenu.pageListener.shouldLoadPage = {
            MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: appRuntime.isRunningUISmokeTests)
        }
        selectedMenu.pageListener.dispatchPage = { menu, page in
            store.dispatch(action: MoviesActions.FetchMoviesMenuList(list: menu, page: page))
        }
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
            .navigationBarTitleDisplayMode(MoviesHomeState.navigationBarTitleDisplayMode(for: homeMode))
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
            .onAppear {
                configurePageListener()
                selectedMenu.pageListener.loadPage()
            }
            .onChange(of: selectedMenu.menu) {
                configurePageListener()
                selectedMenu.pageListener.loadPage()
            }
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

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

    #if !os(macOS)
    static func navigationBarTitleDisplayMode(for mode: MoviesHome.HomeMode) -> NavigationBarItem.TitleDisplayMode {
        mode == .list ? .inline : .automatic
    }
    #endif

    static func shouldLoadPage(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }
}

struct MoviesHome : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
    }

    let isRunningUISmokeTests: Bool

    enum HomeMode {
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

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch)
    }
        
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
        #if !os(macOS)
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        #endif
    }
    
    private var homeAsGrid: some View {
        MoviesHomeGrid(navigationRoute: $navigationRoute,
                       isRunningUISmokeTests: isRunningUISmokeTests)
    }

    private func configurePageListener(props: Props) {
        selectedMenu.pageListener.shouldLoadPage = {
            MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: isRunningUISmokeTests)
        }
        selectedMenu.pageListener.dispatchPage = { menu, page in
            props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: page))
        }
    }
        
    func body(props: Props) -> some View {
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
            #if !os(macOS)
            .navigationBarTitleDisplayMode(MoviesHomeState.navigationBarTitleDisplayMode(for: homeMode))
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    swapHomeButton
                    settingButton
                }
            }
            .navigationDestination(item: $navigationRoute) { route in
                moviesListDestinationView(for: route)
            }
            #if os(macOS) || targetEnvironment(macCatalyst)
            .sheet(isPresented: $isSettingPresented,
                   content: {
                       SettingsForm(onClose: {
                           isSettingPresented = false
                       })
                   })
            #else
            .fullScreenCover(isPresented: $isSettingPresented,
                             content: {
                                 SettingsForm(onClose: {
                                     isSettingPresented = false
                                 })
                             })
            #endif
            .onAppear {
                configurePageListener(props: props)
                selectedMenu.pageListener.loadPage()
            }
            .onChange(of: selectedMenu.menu) {
                configurePageListener(props: props)
                selectedMenu.pageListener.loadPage()
            }
        }
    }
}

#if DEBUG
struct MoviesHome_Previews : PreviewProvider {
    static var previews: some View {
        MoviesHome(isRunningUISmokeTests: false).environmentObject(sampleStore)
    }
}
#endif

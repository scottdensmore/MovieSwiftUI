//
//  Tabbar.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import AppIntents

// MARK:- Shared View

private func makeAppStore() -> Store<AppState> {
#if DEBUG
    let processInfo = ProcessInfo.processInfo
    // UI smoke tests should not depend on live API/network availability.
    if processInfo.arguments.contains("--ui-smoke-tests")
        || processInfo.environment["UI_SMOKE_TESTS"] == "1" {
        return sampleStore
    }
#endif
    return Store<AppState>(reducer: appStateReducer,
                           middleware: [loggingMiddleware],
                           state: AppState())
}

let store = makeAppStore()

@main
struct HomeView: App {
    let archiveTimer: Timer
    
    init() {
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true, block: { _ in
            store.state.archiveState()
        })
        setupApperance()
    }
    
    #if targetEnvironment(macCatalyst)
    var body: some Scene {
        WindowGroup {
            StoreProvider(store: store) {
                SplitView().accentColor(.steam_gold)
            }
        }
    }
    #else
    var body: some Scene {
        WindowGroup {
            StoreProvider(store: store) {
                TabbarView().accentColor(.steam_gold)
            }
        }
    }
    #endif
    
    private func setupApperance() {
        let titleTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(named: "steam_gold")!,
            .font: UIFont(name: "FjallaOne-Regular", size: 22)!
        ]
        let largeTitleTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(named: "steam_gold")!,
            .font: UIFont(name: "FjallaOne-Regular", size: 40)!
        ]

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.titleTextAttributes = titleTextAttributes
        navigationAppearance.largeTitleTextAttributes = largeTitleTextAttributes

        UINavigationBar.appearance().titleTextAttributes = titleTextAttributes
        UINavigationBar.appearance().largeTitleTextAttributes = largeTitleTextAttributes
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().prefersLargeTitles = true
        
        UIBarButtonItem.appearance().setTitleTextAttributes([
                                                                NSAttributedString.Key.foregroundColor: UIColor(named: "steam_gold")!,
                                                                NSAttributedString.Key.font: UIFont(name: "FjallaOne-Regular", size: 16)!],
                                                            for: .normal)
        
        UIWindow.appearance().tintColor = UIColor(named: "steam_gold")

        #if targetEnvironment(macCatalyst)
        // Avoid saturated system selection colors and let our row styles drive selection visuals.
        let softTint = (UIColor(named: "steam_white") ?? .white).withAlphaComponent(0.35)
        UITableViewCell.appearance().selectionStyle = .none
        UITableView.appearance().tintColor = softTint
        UICollectionView.appearance().tintColor = softTint
        #endif
    }
}

// MARK: - iOS implementation
struct TabbarView: View {
    @State var selectedTab = Tab.movies
    
    enum Tab: Int {
        case movies, discover, fanClub, myLists
    }
    
    func tabbarItem(text: String, image: String) -> some View {
        VStack {
            Image(systemName: image)
                .imageScale(.large)
            Text(text)
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MoviesHome().tabItem{
                self.tabbarItem(text: "Movies", image: "film")
            }.tag(Tab.movies)
            DiscoverView().tabItem{
                self.tabbarItem(text: "Discover", image: "square.stack")
            }.tag(Tab.discover)
            FanClubHome().tabItem{
                self.tabbarItem(text: "Fan Club", image: "star.circle.fill")
            }.tag(Tab.fanClub)
            MyLists().tabItem{
                self.tabbarItem(text: "My Lists", image: "heart.circle")
            }.tag(Tab.myLists)
        }
    }
}

// MARK: - MacOS implementation
struct SplitView: View {
    @State private var selectedMenu: OutlineMenu? = .popular
    
    @ViewBuilder
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMenu) {
                ForEach(OutlineMenu.allCases, id: \.self) { menu in
                    OutlineRow(item: menu, isSelected: selectedMenu == menu)
                        .frame(height: 50)
                        .tag(menu)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMenu = menu
                        }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Movies")
            .frame(minWidth: 260, idealWidth: 300)
        } detail: {
            if let selectedMenu {
                selectedMenu.contentView
                    .padding(.leading, selectedMenu == .settings ? 0 : 12)
            } else {
                Text("Select a section")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#if DEBUG
let sampleCustomList = CustomList(id: 0,
                                  name: "TestName",
                                  cover: 0,
                                  movies: [0])
let sampleMoviesMenuState = Dictionary(uniqueKeysWithValues: MoviesMenu.allCases.map { ($0, [0]) })
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: AppState(moviesState:
                                                    MoviesState(movies: [0: sampleMovie],
                                                                moviesList: sampleMoviesMenuState,
                                                                recommended: [0: [0]],
                                                                similar: [0: [0]],
                                                                customLists: [0: sampleCustomList]),
                                                  peoplesState: PeoplesState(peoples: [0: sampleCasts.first!, 1: sampleCasts[1]],
                                                                             peoplesMovies: [:],
                                                                             search: [:])))
#endif

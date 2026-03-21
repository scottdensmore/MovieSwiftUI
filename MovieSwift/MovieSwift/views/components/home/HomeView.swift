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

private let defaultAppEnvironment = appEnvironment

@main
struct HomeView: App {
    private let environment: AppEnvironment
    private let store: Store<AppState>

    init() {
        self.init(environment: defaultAppEnvironment)
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        self.store = environment.store
        environment.runtime.startArchiving(store: store)
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
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
let uiSmokeTestStore = Store<AppState>(reducer: appStateReducer,
                                       state: makeUISmokeTestState())
#endif

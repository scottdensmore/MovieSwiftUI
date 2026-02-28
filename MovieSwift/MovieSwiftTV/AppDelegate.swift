//
//  AppDelegate.swift
//  MovieSwiftTV
//
//  Created by Thomas Ricouard on 06/01/2020.
//  Copyright © 2020 Thomas Ricouard. All rights reserved.
//

import UIKit
import SwiftUI
import SwiftUIFlux
import AppIntents

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private func configureWindowIfNeeded(for application: UIApplication) {
        guard window == nil else { return }
        guard let windowScene = application.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        let controller = UIHostingController(rootView:
            StoreProvider(store: store) {
                HomeView()
        })
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureWindowIfNeeded(for: application)
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        configureWindowIfNeeded(for: application)
    }
}

let store = Store<AppState>(reducer: appStateReducer,
                            middleware: [loggingMiddleware],
                            state: AppState())

#if DEBUG
let sampleCustomList = CustomList(id: 0,
                                  name: "TestName",
                                  cover: 0,
                                  movies: [0])
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: AppState(moviesState:
                                    MoviesState(movies: [0: sampleMovie],
                                                moviesList: [MoviesMenu.popular: [0]],
                                                recommended: [0: [0]],
                                                similar: [0: [0]],
                                                customLists: [0: sampleCustomList]),
                                                  peoplesState: PeoplesState(peoples: [0: sampleCasts.first!, 1: sampleCasts[1]],
                                                                             peoplesMovies: [:],
                                                                             search: [:])))
#endif

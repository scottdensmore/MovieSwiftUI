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

private let defaultTVAppEnvironment = appEnvironment

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let environment: AppEnvironment
    private let store: Store<AppState>

    override init() {
        self.environment = defaultTVAppEnvironment
        self.store = defaultTVAppEnvironment.store
        super.init()
        environment.runtime.startArchiving(store: store)
    }

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

#if DEBUG
let sampleStore = Store<AppState>(reducer: appStateReducer,
                                  state: makePreviewSampleState())
#endif

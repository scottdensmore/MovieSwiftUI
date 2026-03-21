//
//  AppState.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 26/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUIFlux

struct AppState: FluxState, Codable {
    var moviesState: MoviesState
    var peoplesState: PeoplesState

    init() {
        self.moviesState = MoviesState()
        self.peoplesState = PeoplesState()
        ensurePlaceholderData()
    }

    mutating func ensurePlaceholderData() {
        moviesState.movies[0] = sampleMovie
        peoplesState.peoples[0] = sampleCasts.first!
    }
    
    #if DEBUG
    init(moviesState: MoviesState, peoplesState: PeoplesState) {
        self.moviesState = moviesState
        self.peoplesState = peoplesState
        ensurePlaceholderData()
    }
    #endif
}

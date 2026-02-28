import Foundation
import SwiftUIFlux

struct AppState: FluxState, Codable {
    var moviesState: MoviesState
    var peoplesState: PeoplesState

    init(moviesState: MoviesState = MoviesState(), peoplesState: PeoplesState = PeoplesState()) {
        self.moviesState = moviesState
        self.peoplesState = peoplesState
    }
}

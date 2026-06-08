import Foundation
import SwiftUIFlux

public struct AppState: FluxState, Codable, Sendable {
    public var moviesState: MoviesState
    public var peoplesState: PeoplesState

    public init() {
        self.moviesState = MoviesState()
        self.peoplesState = PeoplesState()
        ensurePlaceholderData()
    }

    mutating public func ensurePlaceholderData() {
        moviesState.movies[0] = sampleMovie
        // sampleCasts is a non-empty compile-time constant fixture.
        // swiftlint:disable:next force_unwrapping
        peoplesState.peoples[0] = sampleCasts.first!
    }

    #if DEBUG
    public init(moviesState: MoviesState, peoplesState: PeoplesState) {
        self.moviesState = moviesState
        self.peoplesState = peoplesState
        ensurePlaceholderData()
    }
    #endif
}

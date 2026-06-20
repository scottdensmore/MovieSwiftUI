import Foundation
import Flux

/// Pure composition of the per-state reducers. App-shell concerns
/// (cache-reset, on-disk import) live in a wrapper reducer in the
/// app target, which delegates here for the routine action routing.
public func appStateReducer(state: AppState, action: Action) -> AppState {
    var state = state
    state.moviesState = moviesStateReducer(state: state.moviesState, action: action)
    state.peoplesState = peoplesStateReducer(state: state.peoplesState, action: action)
    return state
}

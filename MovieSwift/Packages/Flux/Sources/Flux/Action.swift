/// A state mutation request. Concrete actions are plain value types the
/// reducer pattern-matches on.
///
/// `Action` refines `Sendable` because the `Store` hops every dispatch onto
/// the main actor (see `Store.dispatch`); an action therefore crosses a
/// concurrency boundary and must be safe to do so. The app's actions are
/// value types over `Sendable` payloads, so this is satisfied for free.
public protocol Action: Sendable {}

/// An action that performs asynchronous work (typically a network fetch) and
/// dispatches follow-up synchronous `Action`s as results arrive.
///
/// `execute` is invoked by `asyncActionsMiddleware` during dispatch. The
/// `dispatch` it receives is the store's main-hopping dispatch, so callbacks
/// may call it from any thread.
public protocol AsyncAction: Action {
    func execute(state: FluxState?, dispatch: @escaping DispatchFunction)
}

/// Marker for a type that can serve as a `Store`'s root state.
///
/// Refines `Sendable`: the state is read both on the main actor (SwiftUI) and
/// handed to middleware/async-action `getState` closures, so it must be safe
/// to share. App state is a value struct over `Sendable` members, satisfying
/// this for free.
public protocol FluxState: Sendable {}

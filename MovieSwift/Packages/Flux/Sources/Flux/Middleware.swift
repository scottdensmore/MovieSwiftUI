/// A function that hands an action to the dispatch pipeline.
public typealias DispatchFunction = (Action) -> Void

/// A pure reducer: folds an action into the current state to produce the next.
public typealias Reducer<State> = (_ state: State, _ action: Action) -> State

/// A dispatch interceptor. Given the store's `dispatch` and a `getState`
/// accessor, it wraps the `next` link in the pipeline and returns a new
/// `DispatchFunction`. The outer closure is `@Sendable` (it captures nothing)
/// so middleware can live as module-level `let`s under Swift 6 concurrency
/// checking.
///
/// `State` is a phantom parameter — it names the store the middleware is
/// registered with for readability, but `getState` yields the type-erased
/// `FluxState?`, so `Middleware<AppState>` and `Middleware<FluxState>` are the
/// same concrete type. It mirrors the original library's signature.
public typealias Middleware<State> =
    @Sendable (@escaping DispatchFunction, @escaping () -> FluxState?)
    -> (@escaping DispatchFunction) -> DispatchFunction

/// Built-in middleware that runs `AsyncAction`s. When an action is an
/// `AsyncAction` it kicks off `execute(state:dispatch:)`, then passes the
/// action along the chain (the reducer typically ignores async actions).
/// Always appended last by the `Store`, so user middleware sees every action
/// first.
public let asyncActionsMiddleware: Middleware<FluxState> = { dispatch, getState in
    { next in
        { action in
            if let action = action as? AsyncAction {
                action.execute(state: getState(), dispatch: dispatch)
            }
            return next(action)
        }
    }
}

import Observation

/// The single source of truth: holds the app's `state`, runs every dispatched
/// action through the middleware chain and the reducer, and publishes changes
/// to SwiftUI via `@Observable`.
///
/// Concurrency: the store is `@MainActor`-isolated (hence implicitly
/// `Sendable`), so it can be captured by timers/closures without the
/// `@preconcurrency`/`nonisolated(unsafe)` dance the previous Combine-based
/// store required. `dispatch` is `nonisolated` and asynchronously hops onto
/// the main actor before touching state — it serialises mutations on the main
/// actor and defers them past the current synchronous call stack (the intent
/// of the original library's `DispatchQueue.main.async`; a `MainActor` task
/// rather than a GCD enqueue, equivalent here because dispatches in practice
/// originate on main, where both defer past the current call).
@MainActor
@Observable
public final class Store<State: FluxState> {
    public private(set) var state: State

    @ObservationIgnored private var dispatchFunction: DispatchFunction!
    @ObservationIgnored private let reducer: Reducer<State>

    public init(reducer: @escaping Reducer<State>,
                middleware: [Middleware<State>] = [],
                state: State) {
        self.reducer = reducer
        self.state = state

        // The pipeline always ends with `asyncActionsMiddleware` so async
        // actions fire regardless of what the caller registered.
        var middleware = middleware
        middleware.append(asyncActionsMiddleware)

        // Fold the middleware (outermost first) over the base reducer step.
        // Every closure here runs on the main actor because `dispatch` hops
        // there before invoking the chain; `assumeIsolated` lets these
        // nonisolated `DispatchFunction`s reach the main-actor state safely.
        // `unowned`: the pipeline is stored on `self` and never outlives the
        // Store, so the capture is safe — and `unowned` (not `weak`) is
        // required, since a `weak self?.reduce` would silently no-op a
        // dispatch if it were ever nil.
        let base: DispatchFunction = { [unowned self] action in
            MainActor.assumeIsolated { self.reduce(action) }
        }
        self.dispatchFunction = middleware
            .reversed()
            .reduce(base) { next, middleware in
                let dispatch: DispatchFunction = { [weak self] action in
                    self?.dispatch(action)
                }
                let getState: () -> FluxState? = { [weak self] in
                    MainActor.assumeIsolated { self?.state }
                }
                return middleware(dispatch, getState)(next)
            }
    }

    /// Enqueue an action. Safe to call from any thread; the action is applied
    /// on the main actor on the next runloop tick.
    nonisolated public func dispatch(_ action: Action) {
        Task { @MainActor in
            self.dispatchFunction(action)
        }
    }

    private func reduce(_ action: Action) {
        state = reducer(state, action)
    }
}

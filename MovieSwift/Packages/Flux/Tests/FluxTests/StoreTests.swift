import Testing
@testable import Flux

// MARK: - Test fixtures

private struct CounterState: FluxState {
    var count = 0
    var log: [String] = []
}

private struct Increment: Action {}
private struct Add: Action { let amount: Int }

/// An async action that, when executed, dispatches a follow-up sync action.
private struct AsyncBump: AsyncAction {
    func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
        dispatch(Add(amount: 5))
    }
}

/// An async action that does no work itself — used to prove the action is
/// still forwarded to the reducer after `execute`.
private struct NoOpAsync: AsyncAction {
    func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {}
}

/// An async action that reads the current `count` via the middleware's
/// `getState` and dispatches it back as an `Add` — proving `getState`
/// surfaces live state to `execute`.
private struct AddCurrentCount: AsyncAction {
    func execute(state: FluxState?, dispatch: @escaping DispatchFunction) {
        guard let current = (state as? CounterState)?.count else { return }
        dispatch(Add(amount: current))
    }
}

private func counterReducer(state: CounterState, action: Action) -> CounterState {
    var state = state
    switch action {
    case is Increment:
        state.count += 1
    case let add as Add:
        state.count += add.amount
    default:
        break
    }
    return state
}

/// Records the type name of every action it sees, so a test can prove which
/// actions actually reached the reducer.
private func loggingReducer(state: CounterState, action: Action) -> CounterState {
    var state = state
    state.log.append("\(type(of: action))")
    if let add = action as? Add { state.count += add.amount }
    return state
}

/// Spins the main actor until `condition` holds or a bounded number of yields
/// elapse — enough for the store's `Task { @MainActor … }` dispatch hop(s) to
/// drain without hanging a failing test forever.
@MainActor
private func settle(until condition: @escaping () -> Bool) async {
    // Well above what a single `Task { @MainActor }` dispatch hop (or a short
    // chain of them) needs; the bound only exists so a genuinely failing test
    // returns instead of hanging.
    let maxYields = 1000
    var tries = 0
    while !condition(), tries < maxYields {
        await Task.yield()
        tries += 1
    }
}

// MARK: - Tests

@Suite @MainActor struct StoreTests {
    @Test func dispatchAppliesReducerOnMainActor() async {
        let store = Store<CounterState>(reducer: counterReducer, state: CounterState())

        store.dispatch(Increment())
        await settle(until: { store.state.count == 1 })

        #expect(store.state.count == 1)
    }

    @Test func multipleDispatchesAccumulateInOrder() async {
        let store = Store<CounterState>(reducer: counterReducer, state: CounterState())

        store.dispatch(Increment())
        store.dispatch(Add(amount: 10))
        store.dispatch(Increment())
        await settle(until: { store.state.count == 12 })

        #expect(store.state.count == 12)
    }

    @Test func asyncActionMiddlewareExecutesAndFollowUpReduces() async {
        let store = Store<CounterState>(reducer: counterReducer, state: CounterState())

        store.dispatch(AsyncBump())
        await settle(until: { store.state.count == 5 })

        #expect(store.state.count == 5)
    }

    @Test func asyncActionIsAlsoForwardedToReducer() async {
        // `asyncActionsMiddleware` runs `execute` AND calls `next(action)`, so
        // the reducer still sees the async action itself (matching the
        // original library). A regression that short-circuits `next` would
        // drop it.
        let store = Store<CounterState>(reducer: loggingReducer, state: CounterState())

        store.dispatch(NoOpAsync())
        await settle(until: { !store.state.log.isEmpty })

        #expect(store.state.log.contains("NoOpAsync"))
    }

    @Test func asyncActionReceivesCurrentStateViaGetState() async {
        // The middleware's `getState` must surface live state to `execute`.
        // Starting at 3, the async action reads 3 and dispatches Add(3) → 6.
        let store = Store<CounterState>(reducer: counterReducer, state: CounterState(count: 3))

        store.dispatch(AddCurrentCount())
        await settle(until: { store.state.count == 6 })

        #expect(store.state.count == 6)
    }

    @Test func middlewareRunsInRegistrationOrderBeforeReducer() async {
        // Two recording middlewares prove ordering: outer (registered first)
        // sees each action before inner, and both run before the reducer. The
        // recorder is a Sendable reference the `@Sendable` middlewares may
        // capture; the dispatch pipeline serialises writes on the main actor.
        let recorder = OrderRecorder()
        let outer: Middleware<CounterState> = { _, _ in
            { next in
                { action in
                    if action is Increment { recorder.append("outer") }
                    return next(action)
                }
            }
        }
        let inner: Middleware<CounterState> = { _, _ in
            { next in
                { action in
                    if action is Increment { recorder.append("inner") }
                    return next(action)
                }
            }
        }
        let store = Store<CounterState>(reducer: counterReducer,
                                        middleware: [outer, inner],
                                        state: CounterState())

        store.dispatch(Increment())
        await settle(until: { store.state.count == 1 })

        #expect(recorder.items == ["outer", "inner"])
        #expect(store.state.count == 1)
    }
}

/// A `Sendable` recorder the ordering middlewares capture. Writes happen only
/// on the main actor during dispatch, so `@unchecked` is safe here.
private final class OrderRecorder: @unchecked Sendable {
    private(set) var items: [String] = []
    func append(_ value: String) { items.append(value) }
}

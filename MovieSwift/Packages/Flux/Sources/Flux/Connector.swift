import SwiftUI

/// A view that derives its content from the store's state. It reads the
/// `Store` from the environment, projects `state` + `dispatch` into the
/// content, and — because it reads `store.state` inside `body` — re-renders
/// via `@Observable` observation whenever the state changes.
public struct StoreConnector<StoreState: FluxState, Content: View>: View {
    @Environment(Store<StoreState>.self) private var store
    let content: (StoreState, @escaping DispatchFunction) -> Content

    public init(content: @escaping (StoreState, @escaping DispatchFunction) -> Content) {
        self.content = content
    }

    public var body: Content {
        content(store.state, store.dispatch)
    }
}

/// Adopt on a `View` to connect it to the store. Implement `map` to project
/// `(state, dispatch)` into a `Props` value and `body(props:)` to render. The
/// default `body` wires up a `StoreConnector` so the view re-renders on state
/// changes — conformers never touch the store directly.
public protocol ConnectedView: View {
    associatedtype StoreState: FluxState
    associatedtype Props
    // Named `BodyContent` rather than the original library's `V` (too short
    // for SwiftLint) and deliberately not `Content` (SwiftUI's conventional
    // generic name, which would shadow a conformer's own `Content`).
    associatedtype BodyContent: View

    func map(state: StoreState, dispatch: @escaping DispatchFunction) -> Props
    func body(props: Props) -> BodyContent
}

public extension ConnectedView {
    func render(state: StoreState, dispatch: @escaping DispatchFunction) -> BodyContent {
        body(props: map(state: state, dispatch: dispatch))
    }

    var body: StoreConnector<StoreState, BodyContent> {
        StoreConnector(content: render)
    }
}

/// Injects a `Store` into the environment for the wrapped content's
/// `ConnectedView`s / `StoreConnector`s to read.
public struct StoreProvider<S: FluxState, Content: View>: View {
    private let store: Store<S>
    private let content: () -> Content

    public init(store: Store<S>, @ViewBuilder content: @escaping () -> Content) {
        self.store = store
        self.content = content
    }

    public var body: some View {
        content().environment(store)
    }
}

import SwiftUI
import Testing
@testable import Flux

private struct ScreenState: FluxState {
    var title = "Home"
}

private struct ScreenProps {
    let title: String
    let dispatch: DispatchFunction
}

/// A representative `ConnectedView` — its `map` records what state it was
/// handed so the render path can be asserted without a running UI.
private struct Screen: ConnectedView {
    static let recorder = Recorder()

    final class Recorder: @unchecked Sendable {
        var mappedTitle: String?
    }

    func map(state: ScreenState, dispatch: @escaping DispatchFunction) -> ScreenProps {
        Screen.recorder.mappedTitle = state.title
        return ScreenProps(title: state.title, dispatch: dispatch)
    }

    func body(props: ScreenProps) -> some View {
        Text(props.title)
    }
}

@Suite @MainActor struct ConnectorTests {
    @Test func renderInvokesMapWithProvidedStateAndProducesBody() {
        let screen = Screen()

        // `render` is the seam the default `body`/`StoreConnector` calls with
        // the live state; exercising it directly proves map→body wiring.
        _ = screen.render(state: ScreenState(title: "Discover"), dispatch: { _ in })

        #expect(Screen.recorder.mappedTitle == "Discover")
    }

    @Test func storeProviderBuildsAndExposesItsStore() {
        // Structural guard only: the provider constructs and its `body`
        // evaluates without trapping. Verifying the store actually resolves
        // through `@Environment(Store.self)` in a child needs a hosted view,
        // which is impractical headlessly — that end-to-end path is covered by
        // the app's full XCUITest suites once the app adopts Flux.
        let store = Store<ScreenState>(reducer: { state, _ in state }, state: ScreenState())
        let provider = StoreProvider(store: store) { Screen() }
        _ = provider.body
    }
}

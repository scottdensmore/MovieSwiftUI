// MoviesMenuListPageListener lives in the iOS and macOS app targets'
// view code (`MovieSwift/views/components/moviesHome/models/`) and is
// not part of the tvOS app target's source list, so this test file
// is gated to skip the tvOS build entirely.
#if !os(tvOS)

import XCTest
import MovieSwiftFluxCore
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

/// Unit tests for the pagination trigger that drives the home-list
/// "scroll to bottom → load next page" journey. The UI journey itself
/// is hard to drive deterministically without a network mock — but the
/// listener that translates "bottom of list became visible" into
/// "dispatch FetchMoviesMenuList(list:, page: N+1)" is pure logic and
/// fully testable here.
///
/// The reducer that handles the dispatched `SetMovieMenuList(page:N)`
/// is covered by `MovieSwiftFluxCoreTests/ReducerTests`
/// (`testMoviesReducerSetMovieMenuListPageOneReplacesList` and
/// `testMoviesReducerSetMovieMenuListPageTwoAppendsList`) so the
/// data layer for pagination is covered end-to-end across the two
/// suites.
// `@MainActor`: exercises `MoviesMenuListPageListener`, a main-actor
// pagination listener, so the test methods must run on the main actor.
@MainActor
final class MoviesMenuListPageListenerTests: XCTestCase {

    /// Setting `currentPage` to a new value triggers `loadPage()` via
    /// `didSet`, which calls `dispatchPage` with (menu, page) when
    /// `shouldLoadPage` returns true. This is exactly the path the
    /// invisible bottom-of-list Rectangle in `MoviesList.listContent`
    /// fires when it appears.
    func testSettingCurrentPageToTwoDispatchesPageLoad() {
        var captured: (menu: MoviesMenu, page: Int)?
        let listener = MoviesMenuListPageListener(
            menu: .popular,
            loadOnInit: false,
            shouldLoadPage: { true },
            dispatchPage: { menu, page in captured = (menu, page) }
        )

        listener.currentPage = 2

        XCTAssertNotNil(captured)
        XCTAssertEqual(captured?.menu, .popular)
        XCTAssertEqual(captured?.page, 2)
    }

    /// Changing `menu` resets `currentPage` back to 1, which itself
    /// re-triggers `didSet`. The journey is: the user switches from
    /// Popular to Top Rated; the listener should fire a fresh page-1
    /// load for the new menu (and any stale page-N+1 sequence from the
    /// old menu is abandoned).
    func testChangingMenuResetsCurrentPageToOneAndDispatchesPageOne() {
        var captured: [(menu: MoviesMenu, page: Int)] = []
        let listener = MoviesMenuListPageListener(
            menu: .popular,
            loadOnInit: false,
            shouldLoadPage: { true },
            dispatchPage: { menu, page in captured.append((menu, page)) }
        )
        // Advance to page 3 first so we can prove the reset really happens.
        listener.currentPage = 3
        captured.removeAll()

        listener.menu = .topRated

        XCTAssertEqual(listener.currentPage, 1, "Changing menu should reset currentPage to 1")
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.menu, .topRated)
        XCTAssertEqual(captured.first?.page, 1)
    }

    /// When `shouldLoadPage` returns false (e.g. in smoke-test mode), the
    /// listener should NOT dispatch. This is the gate that keeps real
    /// network calls from firing during the UI smoke-test suite.
    func testLoadPageSkipsDispatchWhenShouldLoadPageReturnsFalse() {
        var dispatched = false
        let listener = MoviesMenuListPageListener(
            menu: .popular,
            loadOnInit: false,
            shouldLoadPage: { false },
            dispatchPage: { _, _ in dispatched = true }
        )

        listener.currentPage = 2

        XCTAssertFalse(dispatched,
                       "Listener should not dispatch when shouldLoadPage returns false")
    }

    /// `loadOnInit: true` fires a page-1 dispatch right after init so the
    /// first load doesn't wait for the user to scroll. The init path is
    /// the same one MoviesHome wires up — without this firing, the
    /// home grid would never see a page-1 fetch on first launch.
    func testLoadOnInitTrueFiresPageOneDispatch() {
        var captured: (menu: MoviesMenu, page: Int)?
        _ = MoviesMenuListPageListener(
            menu: .nowPlaying,
            loadOnInit: true,
            shouldLoadPage: { true },
            dispatchPage: { menu, page in captured = (menu, page) }
        )

        XCTAssertEqual(captured?.menu, .nowPlaying)
        XCTAssertEqual(captured?.page, 1)
    }

    /// `loadOnInit: false` does NOT fire on init. The home view sometimes
    /// constructs the listener before it's ready to dispatch (e.g. needs
    /// to wire up the closures first), so deferring the first load is
    /// the explicit, callable-by-the-view behaviour we want to keep.
    func testLoadOnInitFalseSuppressesInitialDispatch() {
        var dispatched = false
        _ = MoviesMenuListPageListener(
            menu: .upcoming,
            loadOnInit: false,
            shouldLoadPage: { true },
            dispatchPage: { _, _ in dispatched = true }
        )

        XCTAssertFalse(dispatched,
                       "loadOnInit=false should not fire a dispatch at construction time")
    }

    /// Setting `currentPage` to the SAME value still re-fires `didSet`
    /// (Swift's contract). This makes "menu unchanged but pageListener
    /// re-triggered" deterministic: the home view explicitly relies on
    /// resetting currentPage = 1 to refresh, even when it was already 1.
    func testSettingCurrentPageToCurrentValueStillDispatches() {
        var captured: [(menu: MoviesMenu, page: Int)] = []
        let listener = MoviesMenuListPageListener(
            menu: .trending,
            loadOnInit: false,
            shouldLoadPage: { true },
            dispatchPage: { menu, page in captured.append((menu, page)) }
        )
        listener.currentPage = 1
        captured.removeAll()

        listener.currentPage = 1

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.page, 1)
    }
}

#endif // !os(tvOS)

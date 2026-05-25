import Foundation
import Observation
import MovieSwiftFluxCore

@Observable
final class MoviesSelectedMenuStore {
    // The page listener is a plain reference, not observed UI state, so
    // exclude it from Observation tracking.
    @ObservationIgnored let pageListener: MoviesMenuListPageListener

    var menu: MoviesMenu {
        didSet {
            synchronizePageListener()
        }
    }

    init(selectedMenu: MoviesMenu, pageListener: MoviesMenuListPageListener? = nil) {
        self.menu = selectedMenu
        self.pageListener = pageListener ?? MoviesMenuListPageListener(menu: selectedMenu, loadOnInit: false)
        synchronizePageListener()
    }

    private func synchronizePageListener() {
        pageListener.menu = menu
    }
}

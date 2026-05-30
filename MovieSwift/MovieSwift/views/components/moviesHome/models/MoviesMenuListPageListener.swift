import Foundation
import MovieSwiftFluxCore

final class MoviesMenuListPageListener: MoviesPagesListener {
    var menu: MoviesMenu {
        didSet {
            currentPage = 1
        }
    }
    var shouldLoadPage: (() -> Bool)?
    var dispatchPage: ((MoviesMenu, Int) -> Void)?

    override func loadPage() {
        guard shouldLoadPage?() == true else {
            return
        }
        dispatchPage?(menu, currentPage)
    }

    init(menu: MoviesMenu,
         loadOnInit: Bool? = true,
         shouldLoadPage: (() -> Bool)? = nil,
         dispatchPage: ((MoviesMenu, Int) -> Void)? = nil) {
        self.menu = menu
        self.shouldLoadPage = shouldLoadPage
        self.dispatchPage = dispatchPage

        super.init()

        if loadOnInit == true {
            loadPage()
        }
    }
}

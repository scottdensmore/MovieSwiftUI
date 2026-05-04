import Foundation
import Combine
import SwiftUI

final class MoviesSelectedMenuStore: ObservableObject {
    let pageListener: MoviesMenuListPageListener
    
    @Published var menu: MoviesMenu {
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

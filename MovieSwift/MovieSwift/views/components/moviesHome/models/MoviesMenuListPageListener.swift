//
//  MoviesHomeListPageListener.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 22/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation

final class MoviesMenuListPageListener: MoviesPagesListener {
    var menu: MoviesMenu {
        didSet {
            currentPage = 1
        }
    }
    
    override func loadPage() {
        if isRunningUISmokeTests {
            return
        }
        store.dispatch(action: MoviesActions.FetchMoviesMenuList(list: menu, page: currentPage))
    }
    
    init(menu: MoviesMenu, loadOnInit: Bool? = true) {
        self.menu = menu
        
        super.init()
        
        if loadOnInit == true {
            loadPage()
        }
    }
}

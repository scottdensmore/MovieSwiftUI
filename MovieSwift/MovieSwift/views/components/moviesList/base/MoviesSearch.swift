//
//  MoviesSearch.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import UI

final class MoviesSearchPageListener: MoviesPagesListener {
    var text: String?
    var dispatchSearches: ((String, Int) -> Void)?

    init(dispatchSearches: ((String, Int) -> Void)? = nil) {
        self.dispatchSearches = dispatchSearches
    }
    
    override func loadPage() {
        if let text = text, !text.isEmpty {
            dispatchSearches?(text, currentPage)
        }
    }
}

final class MoviesSearchTextWrapper: SearchTextObservable {
    var searchPageListener: MoviesSearchPageListener

    init(dispatchSearches: ((String, Int) -> Void)? = nil) {
        self.searchPageListener = MoviesSearchPageListener(dispatchSearches: dispatchSearches)
    }

    func bindDispatchSearches(_ dispatchSearches: @escaping (String, Int) -> Void) {
        searchPageListener.dispatchSearches = dispatchSearches
    }
    
    override func onUpdateTextDebounced(text: String) {
        searchPageListener.text = text
        searchPageListener.currentPage = 1
    }
}

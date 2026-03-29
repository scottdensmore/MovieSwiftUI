//
//  MovieKeywordList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 16/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

final class KeywordPageListener: MoviesPagesListener {
    var keyword: Int?
    var dispatchPage: ((Int, Int) -> Void)?
    
    override func loadPage() {
        guard let keyword else {
            return
        }
        dispatchPage?(keyword, currentPage)
    }

    init(dispatchPage: ((Int, Int) -> Void)? = nil) {
        self.dispatchPage = dispatchPage
    }
}

enum MovieKeywordListState {
    static func movies(for keyword: Keyword, from state: AppState) -> [Int] {
        state.moviesState.withKeywords[keyword.id] ?? [0, 0, 0, 0]
    }
}

struct MovieKeywordList : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let movies: [Int]
    }

    @State var pageListener = KeywordPageListener()
    @State private var navigationRoute: MoviesListNavigationRoute?
    let keyword: Keyword

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              movies: MovieKeywordListState.movies(for: keyword, from: state))
    }

    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            MoviesList(movies: props.movies,
                       displaySearch: false,
                       pageListener: pageListener,
                       navigationRoute: $navigationRoute)
        }
        .navigationTitle(keyword.name.capitalized)
        .navigationDestination(item: $navigationRoute) { route in
            moviesListDestinationView(for: route)
        }
        .onAppear {
            self.pageListener.dispatchPage = { keyword, page in
                props.dispatch(MoviesActions.FetchMovieWithKeywords(keyword: keyword,
                                                                    page: page))
            }
            self.pageListener.keyword = self.keyword.id
            self.pageListener.loadPage()
        }
    }
}

#Preview {
    MovieKeywordList(keyword: Keyword(id: 0, name: "Test"))
        .environmentObject(sampleStore)
}

//
//  MoviesGenreList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 15/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum MovieGenrePageAction {
    static func fetch(genre: Genre, page: Int, sort: MoviesSort) -> Action {
        MoviesActions.FetchMoviesGenre(genre: genre, page: page, sortBy: sort)
    }
}

enum MoviesGenreListState {
    static func movies(for genre: Genre, from state: AppState) -> [Int] {
        state.moviesState.withGenre[genre.id] ?? []
    }
}

// MARK: - Page listener
final class MovieGenrePageListener: MoviesPagesListener {
    var genre: Genre
    var dispatch: DispatchFunction?
    
    var sort: MoviesSort = .byPopularity {
        didSet {
            currentPage = 1
            loadPage()
        }
    }
    
    override func loadPage() {
        dispatch?(MovieGenrePageAction.fetch(genre: genre, page: currentPage, sort: sort))
    }
    
    init(genre: Genre) {
        self.genre = genre
        super.init()
    }
}

// MARK: - View
struct MoviesGenreList: ConnectedView {
    struct Props {
        let movies: [Int]
        let dispatch: DispatchFunction
    }
    
    let genre: Genre
    let pageListener: MovieGenrePageListener
    
    @State var isSortSheetPresented = false
    @State var selectedSort: MoviesSort = .byPopularity
    @State private var navigationRoute: MoviesListNavigationRoute?
    
    init(genre: Genre) {
        self.genre = genre
        self.pageListener = MovieGenrePageListener(genre: self.genre)
    }
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movies: MoviesGenreListState.movies(for: genre, from: state),
              dispatch: dispatch)
    }
    
    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            MoviesList(movies: props.movies,
                       displaySearch: false,
                       pageListener: pageListener,
                       navigationRoute: $navigationRoute)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                #if os(macOS)
                Menu {
                    sortMenuButtons { sort in
                        self.selectedSort = sort
                        self.pageListener.sort = sort
                    }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .imageScale(.large)
                        .foregroundColor(.steam_gold)
                }
                #else
                Button(action: {
                    self.isSortSheetPresented.toggle()
                }, label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .imageScale(.large)
                        .foregroundColor(.steam_gold)
                })
                #endif
            }
        }
        .navigationTitle(genre.name)
        .navigationDestination(item: $navigationRoute) { route in
            moviesListDestinationView(for: route)
        }
        #if !os(macOS)
        .confirmationDialog("Sort movies by", isPresented: $isSortSheetPresented) {
            sortMenuButtons { sort in
                self.selectedSort = sort
                self.pageListener.sort = sort
            }
        }
        #endif
        .onAppear {
            self.pageListener.dispatch = props.dispatch
            self.pageListener.loadPage()
        }
    }
}

#Preview {
    MoviesGenreList(genre: Genre(id: 0, name: "test")).environmentObject(sampleStore)
}

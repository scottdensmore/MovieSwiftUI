//
//  MoviesHomeList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum MoviesHomeListState {
    static func movies(for menu: MoviesMenu, from state: AppState) -> [Int] {
        state.moviesState.moviesList[menu] ?? [0, 0, 0, 0]
    }
}

struct MoviesHomeList: ConnectedView {
    struct Props {
        let movies: [Int]
    }
    
    @Binding var menu: MoviesMenu
    let navigationRoute: Binding<MoviesListNavigationRoute?>
    
    let pageListener: MoviesMenuListPageListener

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movies: MoviesHomeListState.movies(for: menu, from: state))
    }
    
    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            MoviesList(movies: props.movies,
                       displaySearch: true,
                       pageListener: pageListener,
                       navigationRoute: navigationRoute)
        }
    }
}

#Preview {
    NavigationStack {
        MoviesHomeList(menu: .constant(.popular),
                       navigationRoute: .constant(nil),
                       pageListener: MoviesMenuListPageListener(menu: .popular, loadOnInit: false))
            .environmentObject(sampleStore)
    }
}

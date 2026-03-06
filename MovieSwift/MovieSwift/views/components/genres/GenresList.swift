//
//  GenresList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

struct GenresList: View {
    @EnvironmentObject private var store: Store<AppState>
    #if targetEnvironment(macCatalyst)
    @State private var selectedGenre: Genre?
    #endif

    var body: some View {
        List {
            ForEach(store.state.moviesState.genres) { genre in
                #if targetEnvironment(macCatalyst)
                Button(action: { selectedGenre = genre }) {
                    Text(genre.name)
                }
                .buttonStyle(.plain)
                .focusable(false)
                #else
                NavigationLink(destination: MoviesGenreList(genre: genre)) {
                    Text(genre.name)
                }
                #endif
            }
        }
        .listStyle(PlainListStyle())
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
        }
        #endif
        .onAppear {
            self.store.dispatch(action: MoviesActions.FetchGenres())
        }
    }
}

#if DEBUG
struct GenresList_Previews: PreviewProvider {
    static var previews: some View {
        GenresList()
    }
}
#endif

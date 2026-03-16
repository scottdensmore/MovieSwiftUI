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
    @FocusState private var focusedGenreId: Int?
    #endif

    var body: some View {
        List {
            ForEach(store.state.moviesState.genres) { genre in
                #if targetEnvironment(macCatalyst)
                CatalystFocusableLink(id: genre.id, focusedId: $focusedGenreId) {
                    selectedGenre = genre
                } label: {
                    Text(genre.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                }
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

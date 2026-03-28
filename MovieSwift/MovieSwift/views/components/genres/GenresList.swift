//
//  GenresList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum GenresListFetchPolicy {
    static func shouldFetchGenres(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }

    static func actionsToDispatch(isRunningUISmokeTests: Bool) -> [Action] {
        guard shouldFetchGenres(isRunningUISmokeTests: isRunningUISmokeTests) else {
            return []
        }

        return [MoviesActions.FetchGenres()]
    }
}

enum GenresListState {
    static func genres(from state: AppState) -> [Genre] {
        state.moviesState.genres
    }
}

struct GenresList: ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let genres: [Genre]
    }

    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests

    #if os(macOS)
    @State private var selectedGenre: Genre?
    @FocusState private var focusedGenreId: Int?
    #endif

    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            List {
                ForEach(props.genres) { genre in
                    #if os(macOS)
                    MacFocusableLink(id: genre.id, focusedId: $focusedGenreId) {
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
        }
        #if os(macOS)
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
        }
        #endif
        .onAppear {
            for action in GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: isRunningUISmokeTests) {
                props.dispatch(action)
            }
        }
    }

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              genres: GenresListState.genres(from: state))
    }
}

#if DEBUG
struct GenresList_Previews: PreviewProvider {
    static var previews: some View {
        GenresList()
            .environmentObject(sampleStore)
    }
}
#endif

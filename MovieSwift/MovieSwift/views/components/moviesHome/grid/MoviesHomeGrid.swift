//
//  MovieHomeGrid.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 10/10/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

struct MoviesHomeGrid: ConnectedView {
    struct Props {
        let movies: [MoviesMenu: [Int]]
        let genres: [Genre]
    }

    let navigationRoute: Binding<MoviesListNavigationRoute?>

    private struct MenuDestination: Hashable, Identifiable {
        let menu: MoviesMenu
        var id: MoviesMenu { menu }
    }

    @State private var selectedMenu: MenuDestination?
    @State private var selectedGenre: Genre?
    private func menuListView(for menu: MoviesMenu, props: Props) -> some View {
        MoviesList(movies: props.movies[menu] ?? [],
                   displaySearch: true,
                   pageListener: MoviesMenuListPageListener(menu: menu, loadOnInit: false),
                   navigationRoute: navigationRoute)
            .navigationBarTitle(menu.title())
    }
            
    private func moviesRow(menu: MoviesMenu, props: Props) -> some View{
        VStack(alignment: .leading) {
            HStack {
                Text(menu.title())
                    .titleFont(size: 23)
                    .foregroundColor(.steam_gold)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                Spacer()
                Button(action: {
                    selectedMenu = MenuDestination(menu: menu)
                }) {
                    Text("See all")
                        .foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            MoviesHomeGridMoviesRow(movies: props.movies[menu] ?? [])
                .padding(.bottom, 8)
        }.onAppear {
            if !isRunningUISmokeTests {
                store.dispatch(action: MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
            }
        }.listRowInsets(EdgeInsets())
    }
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        var genres = state.moviesState.genres
        if !genres.isEmpty {
            genres.removeFirst()
        }
        return Props(movies: state.moviesState.moviesList,
                     genres: genres)
    }
    
    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            List {
                ForEach(MoviesMenu.allCases, id: \.self) { menu in
                    Group {
                        if menu == .genres {
                            ForEach(props.genres) { genre in
                                Button(action: {
                                    selectedGenre = genre
                                }) {
                                    Text(genre.name)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            self.moviesRow(menu: menu, props: props)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationBarTitle("Movies", displayMode: .automatic)
        .navigationDestination(item: $selectedMenu) { destination in
            menuListView(for: destination.menu, props: props)
        }
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
        }
        .onAppear {
            if !isRunningUISmokeTests {
                store.dispatch(action: MoviesActions.FetchGenres())
            }
        }
    }
}

struct MoviesHomeGrid_Previews: PreviewProvider {
    static var previews: some View {
        MoviesHomeGrid(navigationRoute: .constant(nil))
    }
}

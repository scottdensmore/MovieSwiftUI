//
//  MoviesView.swift
//  MovieSwiftTV
//
//  Created by Thomas Ricouard on 06/01/2020.
//  Copyright © 2020 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend

struct MoviesView: ConnectedView {
    struct Poster: Identifiable {
        let id: Int
        let posterPath: String?
    }

    struct Props {
        let movies: [Poster]
        let loadMovies: () -> Void
    }
    
    @Binding var menu: MoviesMenu
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let movies = (state.moviesState.moviesList[menu] ?? []).map { id in
            Poster(id: id, posterPath: state.moviesState.movies[id]?.poster_path)
        }

        return Props(movies: movies,
                     loadMovies: {
                        dispatch(MoviesActions.FetchMoviesMenuList(list: self.menu, page: 1))
                     })
    }
    
    func body(props: Props) -> some View {
        NavigationView {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(props.movies) { movie in
                        NavigationLink(destination: Text("Test")) {
                            MoviePosterImage(imageLoader: ImageLoader(path: movie.posterPath,
                                                                      size: .medium),
                                posterSize: PosterStyle.Size.tv)
                        }
                    }
                }.frame(height: PosterStyle.Size.tv.height() + 50)
            }
            .onAppear{
                props.loadMovies()
            }
        }
    }
}

struct MoviesView_Previews: PreviewProvider {
    static var previews: some View {
        MoviesView(menu: .constant(.popular)).environmentObject(sampleStore)
    }
}

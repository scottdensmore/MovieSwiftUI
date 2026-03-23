//
//  MovieCoverRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 02/08/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend
import UI

struct MovieCoverPresentation {
    let backdropPath: String?
    let posterPath: String?
    let popularityScore: Int
    let ratingsText: String
    let genres: [Genre]
    let areGenresPlaceholder: Bool
}

enum MovieCoverState {
    static func presentation(for movie: Movie) -> MovieCoverPresentation {
        let placeholderGenres = (1...3).map { index in
            Genre(id: -index, name: "     ")
        }

        return MovieCoverPresentation(backdropPath: movie.backdrop_path ?? movie.poster_path,
                                      posterPath: movie.poster_path,
                                      popularityScore: Int(movie.vote_average * 10),
                                      ratingsText: "\(movie.vote_count) ratings",
                                      genres: movie.genres ?? placeholderGenres,
                                      areGenresPlaceholder: movie.genres == nil)
    }
}

struct MovieCoverRow : ConnectedView {
    let movieId: Int

    #if targetEnvironment(macCatalyst)
    @State private var selectedGenre: Genre?
    @FocusState private var focusedGenreId: Int?
    #endif

    struct Props {
        let movie: Movie?
    }

    private func presentation(props: Props) -> MovieCoverPresentation {
        MovieCoverState.presentation(for: props.movie ?? sampleMovie)
    }

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movie: state.moviesState.movies[movieId])
    }

    func body(props: Props) -> some View {
        guard props.movie != nil else {
            return AnyView(EmptyView())
        }
        let movie = props.movie ?? sampleMovie
        let presentation = presentation(props: props)

        return AnyView(ZStack {
            MovieTopBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: presentation.backdropPath,
                                                                                 size: .medium),
                                  fill: false)
            VStack(alignment: .leading) {
                HStack(spacing: 16) {
                    MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: presentation.posterPath,
                                                                                    size: .medium),
                                     posterSize: .medium)
                        .padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 16) {
                        MovieInfoRow(movie: movie)
                        HStack {
                            PopularityBadge(score: presentation.popularityScore, textColor: .white)
                            Text(presentation.ratingsText)
                                .lineLimit(1)
                                .foregroundColor(.white)
                        }
                    }
                }
                genresBadges(props: props).padding(.top, 16)
            }
        }
        .listRowInsets(EdgeInsets()))
    }
    
    private func genresBadges(props: Props) -> some View {
        let presentation = presentation(props: props)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presentation.genres) { genre in
                    #if targetEnvironment(macCatalyst)
                    CatalystFocusableLink(id: genre.id, focusedId: $focusedGenreId) {
                        selectedGenre = genre
                    } label: {
                        coverGenreBadge(text: genre.name)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .disabled(presentation.areGenresPlaceholder)
                    #else
                    NavigationLink(destination: MoviesGenreList(genre: genre)) {
                        coverGenreBadge(text: genre.name)
                            .padding(.vertical, 2)
                    }.disabled(presentation.areGenresPlaceholder)
                    #endif
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 4)
            .redacted(reason: presentation.areGenresPlaceholder ? .placeholder : [])
        }
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
        }
        #endif
    }

    private func coverGenreBadge(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text.capitalized)
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
    }
}

#if DEBUG
struct MovieCoverRow_Previews : PreviewProvider {
    static var previews: some View {
        MovieCoverRow(movieId: 0).environmentObject(sampleStore)
    }
}
#endif

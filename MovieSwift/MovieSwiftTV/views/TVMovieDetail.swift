//
//  TVMovieDetail.swift
//  MovieSwiftTV
//

import SwiftUI
import SwiftUIFlux
import Backend

struct TVMovieDetail: ConnectedView {
    struct Props {
        let movie: Movie?
        let characters: [People]
        let recommended: [Int]
        let movies: [Int: Movie]
        let dispatch: DispatchFunction
    }

    let movieId: Int

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let castIds = state.peoplesState.movieCastOrder[movieId] ?? []
        let characters = castIds.compactMap { state.peoplesState.peoples[$0] }
        return Props(movie: state.moviesState.movies[movieId],
              characters: characters,
              recommended: state.moviesState.recommended[movieId] ?? [],
              movies: state.moviesState.movies,
              dispatch: dispatch)
    }

    func body(props: Props) -> some View {
        ScrollView {
            if let movie = props.movie {
                VStack(alignment: .leading, spacing: 40) {
                    headerSection(movie: movie)
                    if !props.characters.isEmpty {
                        castSection(characters: props.characters)
                    }
                    if !props.recommended.isEmpty {
                        recommendedSection(movieIds: props.recommended, movies: props.movies)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 40)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(props.movie?.userTitle ?? "Movie")
        .onAppear {
            props.dispatch(MoviesActions.FetchDetail(movie: movieId))
            props.dispatch(PeopleActions.FetchMovieCasts(movie: movieId))
            props.dispatch(MoviesActions.FetchRecommended(movie: movieId))
        }
    }

    // MARK: - Sections

    private func headerSection(movie: Movie) -> some View {
        HStack(alignment: .top, spacing: 40) {
            MoviePosterImage(imageLoader: ImageLoader(path: movie.poster_path, size: .medium),
                            posterSize: PosterStyle.Size.tv)

            VStack(alignment: .leading, spacing: 16) {
                Text(movie.userTitle)
                    .font(.title)
                HStack(spacing: 24) {
                    if let date = movie.release_date {
                        Label(date, systemImage: "calendar")
                    }
                    if let runtime = movie.runtime {
                        Label("\(runtime) min", systemImage: "clock")
                    }
                    if movie.vote_average > 0 {
                        Label(String(format: "%.1f", movie.vote_average), systemImage: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)

                if !movie.overview.isEmpty {
                    Text(movie.overview)
                        .font(.body)
                        .lineLimit(6)
                }

                if let genres = movie.genres {
                    HStack {
                        ForEach(genres) { genre in
                            Text(genre.name)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private func castSection(characters: [People]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast")
                .font(.title3)
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(characters.prefix(10)) { person in
                        VStack {
                            AsyncImage(url: person.profile_path.flatMap {
                                ImageService.Size.cast.path(poster: $0)
                            }) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color.secondary.opacity(0.3)
                            }
                            .frame(width: 120, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text(person.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 120)
                        }
                    }
                }
            }
        }
    }

    private func recommendedSection(movieIds: [Int], movies: [Int: Movie]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended")
                .font(.title3)
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(movieIds.prefix(10), id: \.self) { id in
                        if let movie = movies[id] {
                            NavigationLink(value: id) {
                                VStack(spacing: 8) {
                                    MoviePosterImage(
                                        imageLoader: ImageLoader(path: movie.poster_path,
                                                                  size: .medium),
                                        posterSize: .medium)
                                    Text(movie.userTitle)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: PosterStyle.Size.medium.width())
                                }
                            }
                            .buttonStyle(.card)
                        }
                    }
                }
            }
        }
    }
}

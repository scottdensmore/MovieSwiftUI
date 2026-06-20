import SwiftUI
@preconcurrency import SwiftUIFlux
import Backend
import MovieSwiftFluxCore

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
                        .focusSection()
                    if !props.characters.isEmpty {
                        castSection(characters: props.characters)
                            .focusSection()
                    }
                    if !props.recommended.isEmpty {
                        recommendedSection(movieIds: props.recommended, movies: props.movies)
                            .focusSection()
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
        .accessibilityIdentifier(AccessibilityID.MovieDetail.container)
        .onAppear {
            props.dispatch(MoviesActions.FetchDetail(movie: movieId))
            props.dispatch(PeopleActions.FetchMovieCasts(movie: movieId))
            props.dispatch(MoviesActions.FetchRecommended(movie: movieId))
        }
    }

    // MARK: - Sections

    private func headerSection(movie: Movie) -> some View {
        HStack(alignment: .top, spacing: 40) {
            MoviePosterImage(imageLoader: ImageLoader(path: movie.posterPath, size: .medium),
                            posterSize: PosterStyle.Size.tv)

            VStack(alignment: .leading, spacing: 16) {
                Text(movie.userTitle)
                    .font(.title)
                    .accessibilityIdentifier(AccessibilityID.MovieDetail.title)
                HStack(spacing: 24) {
                    if let date = movie.releaseDateString {
                        Label(date, systemImage: "calendar")
                    }
                    if let runtime = movie.runtime {
                        Label("\(runtime) min", systemImage: "clock")
                    }
                    if movie.voteAverage > 0 {
                        Label(String(format: "%.1f", movie.voteAverage), systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

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
                .accessibilityIdentifier(AccessibilityID.MovieDetail.castHeader)
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(characters.prefix(10)) { person in
                        Button { } label: {
                            VStack {
                                AsyncImage(url: person.profilePath.flatMap {
                                    ImageService.Size.cast.path(poster: $0)
                                }) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.secondary.opacity(0.3)
                                }
                                .frame(width: 150, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(person.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 150)
                            }
                        }
                        .buttonStyle(.card)
                    }
                }
            }
        }
    }

    private func recommendedSection(movieIds: [Int], movies: [Int: Movie]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended")
                .font(.title3)
                .accessibilityIdentifier(AccessibilityID.MovieDetail.recommendedHeader)
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(movieIds.prefix(10), id: \.self) { id in
                        if let movie = movies[id] {
                            NavigationLink(value: id) {
                                VStack(spacing: 8) {
                                    MoviePosterImage(
                                        imageLoader: ImageLoader(path: movie.posterPath,
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

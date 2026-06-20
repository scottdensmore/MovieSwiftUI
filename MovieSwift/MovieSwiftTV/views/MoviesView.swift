import SwiftUI
@preconcurrency import SwiftUIFlux
import Backend
import MovieSwiftFluxCore

struct MoviesView: ConnectedView {
    struct Props {
        let movieIds: [Int]
        let movies: [Int: Movie]
        let dispatch: DispatchFunction
    }

    let menu: MoviesMenu
    @State private var currentPage = 1

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movieIds: state.moviesState.moviesList[menu] ?? [],
              movies: state.moviesState.movies,
              dispatch: dispatch)
    }

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)

    func body(props: Props) -> some View {
        ScrollView {
            LazyVGrid(columns: Self.gridColumns, spacing: 40) {
                ForEach(props.movieIds, id: \.self) { id in
                    if let movie = props.movies[id] {
                        NavigationLink(value: id) {
                            TVMovieCard(movie: movie)
                        }
                        .buttonStyle(.card)
                        .accessibilityIdentifier(AccessibilityID.MoviesList.movie(id))
                        .onAppear {
                            if id == props.movieIds.last {
                                currentPage += 1
                                props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: currentPage))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
        .navigationDestination(for: Int.self) { id in
            TVMovieDetail(movieId: id)
        }
        .onAppear {
            if props.movieIds.isEmpty {
                props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
            }
        }
    }
}

// MARK: - Movie Card
private struct TVMovieCard: View {
    let movie: Movie

    var body: some View {
        VStack(spacing: 12) {
            MoviePosterImage(imageLoader: ImageLoader(path: movie.posterPath,
                                                      size: .medium),
                            posterSize: PosterStyle.Size.tv)
            Text(movie.userTitle)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: PosterStyle.Size.tv.width())
        }
    }
}

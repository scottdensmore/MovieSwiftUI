import SwiftUI
import Backend
import UI
import MovieSwiftFluxCore

struct MovieGridRow: ConnectedView {
    struct Props {
        let movie: Movie
    }

    let movieId: Int

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movie: state.moviesState.movies[movieId] ?? Movie.placeholder(id: movieId))
    }

    func body(props: Props) -> some View {
        MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: props.movie.posterPath,
                                                                        size: .medium),
                         posterSize: .medium)
    }
}

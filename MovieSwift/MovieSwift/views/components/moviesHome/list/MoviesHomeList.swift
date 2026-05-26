import SwiftUI
@preconcurrency import SwiftUIFlux
import MovieSwiftFluxCore

enum MoviesHomeListState {
    static func movies(for menu: MoviesMenu, from state: AppState) -> [Int] {
        state.moviesState.moviesList[menu] ?? [0, 0, 0, 0]
    }

    static func loadingState(for menu: MoviesMenu, from state: AppState) -> MoviesListLoadingState? {
        state.moviesState.loadingStates[.homeMenu(menu)]
    }
}

struct MoviesHomeList: ConnectedView {
    struct Props {
        let movies: [Int]
        let loadingState: MoviesListLoadingState?
        let dispatch: DispatchFunction
    }

    @Binding var menu: MoviesMenu
    let navigationRoute: Binding<MoviesListNavigationRoute?>

    let pageListener: MoviesMenuListPageListener

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movies: MoviesHomeListState.movies(for: menu, from: state),
              loadingState: MoviesHomeListState.loadingState(for: menu, from: state),
              dispatch: dispatch)
    }

    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            // When the most recent fetch failed, show an inline
            // banner above the list so the user sees that something
            // is wrong (instead of staring at skeleton placeholders
            // forever) and gets a one-tap retry.
            if case .failed(let failure) = props.loadingState {
                MoviesListErrorBanner(failure: failure) {
                    props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
                }
            }
            MoviesList(movies: props.movies,
                       displaySearch: true,
                       pageListener: pageListener,
                       navigationRoute: navigationRoute)
        }
    }
}


#Preview {
    NavigationStack {
        MoviesHomeList(menu: .constant(.popular),
                       navigationRoute: .constant(nil),
                       pageListener: MoviesMenuListPageListener(menu: .popular, loadOnInit: false))
            .environmentObject(sampleStore)
    }
}

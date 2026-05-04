import SwiftUI
import SwiftUIFlux

enum MoviesCrewListState {
    static func movies(for crew: People, from state: AppState) -> [Int] {
        state.moviesState.withCrew[crew.id] ?? []
    }
}

struct MoviesCrewList : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let movies: [Int]
    }

    @State private var navigationRoute: MoviesListNavigationRoute?
    let crew: People

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              movies: MoviesCrewListState.movies(for: crew, from: state))
    }

    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            MoviesList(movies: props.movies,
                       displaySearch: false,
                       navigationRoute: $navigationRoute)
        }
        .navigationTitle(crew.name)
        .navigationDestination(item: $navigationRoute) { route in
            moviesListDestinationView(for: route)
        }
        .onAppear {
            props.dispatch(MoviesActions.FetchMovieWithCrew(crew: self.crew.id))
        }
    }
}

#Preview {
    MoviesCrewList(crew: sampleCasts.first!)
        .environmentObject(sampleStore)
}

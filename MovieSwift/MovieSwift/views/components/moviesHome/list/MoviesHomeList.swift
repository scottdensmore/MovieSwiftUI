import Backend
import MovieSwiftFluxCore
import SwiftUI

// MARK: - MoviesHomeListState

enum MoviesHomeListState {
    static func movies(for menu: MoviesMenu, from state: AppState) -> [Int] {
        state.moviesState.moviesList[menu] ?? [0, 0, 0, 0]
    }

    static func loadingState(for menu: MoviesMenu, from state: AppState) -> MoviesListLoadingState? {
        state.moviesState.loadingStates[.homeMenu(menu)]
    }
}

// MARK: - MoviesHomeList

struct MoviesHomeList: ConnectedView {
    struct Props {
        let movies: [Int]
        let loadingState: MoviesListLoadingState?
        let dispatch: DispatchFunction
    }

    @Binding var menu: MoviesMenu
    let navigationRoute: Binding<MoviesListNavigationRoute?>

    let pageListener: MoviesMenuListPageListener

    @State private var isRegionSettingsPresented = false
    /// Observe the region key directly so the caption refreshes the moment the
    /// user changes region in the presented Settings sheet (not just incidentally
    /// on dismiss). `AppUserDefaults.region` is the non-observable read path.
    @AppStorage(AppUserDefaults.regionKey) private var regionCode = Locale.current.region?.identifier ?? "US"

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movies: MoviesHomeListState.movies(for: menu, from: state),
              loadingState: MoviesHomeListState.loadingState(for: menu, from: state),
              dispatch: dispatch)
    }

    /// Now Playing / Upcoming are region-filtered by TMDB, so their results can
    /// look sparse for small markets. Surface the active region (and a way to
    /// change it) so an unexpectedly short list is self-explanatory.
    @ViewBuilder
    private var regionBar: some View {
        if menu.isRegionFiltered {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(menu.regionCaption(regionName: RegionPresentation.displayName(forRegionCode: regionCode)))
                    .font(.footnote)
                Spacer(minLength: 8)
                Button("Change") { isRegionSettingsPresented = true }
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(AccessibilityID.MoviesHome.regionChangeButton)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary)
        }
    }

    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            regionBar
            // When the most recent fetch failed, show an inline
            // banner above the list so the user sees that something
            // is wrong (instead of staring at skeleton placeholders
            // forever) and gets a one-tap retry.
            if case let .failed(failure) = props.loadingState {
                MoviesListErrorBanner(failure: failure) {
                    props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
                }
            }
            MoviesList(movies: props.movies,
                       displaySearch: true,
                       pageListener: pageListener,
                       navigationRoute: navigationRoute)
        }
        // A `.sheet` on both platforms (distinct presentation channel from the
        // gear button's `.fullScreenCover` in `MoviesHome`, so the two never
        // stack) opens Settings where the region can be changed.
        .sheet(isPresented: $isRegionSettingsPresented) {
            SettingsForm(onClose: { isRegionSettingsPresented = false })
        }
    }
}

#Preview {
    NavigationStack {
        MoviesHomeList(menu: .constant(.popular),
                       navigationRoute: .constant(nil),
                       pageListener: MoviesMenuListPageListener(menu: .popular, loadOnInit: false))
            .environment(sampleStore)
    }
}

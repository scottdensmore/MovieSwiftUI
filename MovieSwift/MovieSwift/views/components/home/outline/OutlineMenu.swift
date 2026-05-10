import Foundation
import SwiftUI
import SwiftUIFlux
import MovieSwiftFluxCore

enum OutlineMoviesMenuListFetchPolicy {
    static func shouldLoadInitialPage(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }
}

enum OutlineMenu: Int, CaseIterable, Identifiable {
    var id: Int {
        return self.rawValue
    }
    
    
    case popular, topRated, upcoming, nowPlaying, trending, genres, fanClub, discover, myLists, settings
    
    var title: String {
        switch self {
        case .popular:    return "Popular"
        case .topRated:   return "Top rated"
        case .upcoming:   return "Upcoming"
        case .nowPlaying: return "Now Playing"
        case .trending:   return "Trending"
        case .genres:     return "Genres"
        case .fanClub:    return "Fan Club"
        case .discover:   return "Discover"
        case .myLists:    return "My Lists"
        case .settings:   return "Settings"
        }
    }
    
    var image: String {
        switch self {
        case .popular:    return "film.fill"
        case .topRated:   return "star.fill"
        case .upcoming:   return "clock.fill"
        case .nowPlaying: return "play.circle.fill"
        case .trending:   return "chart.bar.fill"
        case .genres:     return "tag.fill"
        case .fanClub:    return "star.circle.fill"
        case .discover:   return "square.stack.fill"
        case .myLists:    return "text.badge.plus"
        case .settings:   return "wrench"
        }
    }
    
    private func detailRoot<Content: View>(title: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        #if os(macOS)
        // On macOS, SplitView wraps the detail column in a single
        // NavigationStack with a path binding it can reset on menu
        // change, so the inner per-menu NavigationStack is omitted
        // here to avoid stranding pushed destinations across menu
        // switches.
        content()
            .navigationTitle(title)
        #else
        NavigationStack {
            content()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
        #endif
    }
    
    private func moviesList(menu: MoviesMenu,
                            isRunningUISmokeTests: Bool,
                            navigationRoute: Binding<MoviesListNavigationRoute?>) -> some View {
        return detailRoot(title: menu.title()) {
            OutlineMoviesMenuList(menu: menu,
                                  shouldLoadInitialPage: OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: isRunningUISmokeTests),
                                  navigationRoute: navigationRoute)
        }
    }
    
    private var genresList: some View {
        detailRoot(title: "Genres") {
            GenresList()
        }
    }
    
    private var discoverList: some View {
        detailRoot(title: "Discover") {
            DiscoverView()
        }
    }
    
    private var fanClubList: some View {
        detailRoot(title: "Fan Club") {
            FanClubHome(embedInNavigationStack: false,
                        showNavigationTitle: false)
        }
    }
    
    private var myListsList: some View {
        detailRoot(title: "My Lists") {
            MyLists(embedInNavigationStack: false,
                    showNavigationTitle: false)
        }
    }
    
    private var settingsList: some View {
        detailRoot(title: "Settings") {
            SettingsForm(embedInNavigationStack: false,
                         showNavigationTitle: false)
        }
    }
    
    @ViewBuilder
    func contentView(isRunningUISmokeTests: Bool,
                     navigationRoute: Binding<MoviesListNavigationRoute?>) -> some View {
        switch self {
        case .popular:    moviesList(menu: .popular, isRunningUISmokeTests: isRunningUISmokeTests, navigationRoute: navigationRoute)
        case .topRated:   moviesList(menu: .topRated, isRunningUISmokeTests: isRunningUISmokeTests, navigationRoute: navigationRoute)
        case .upcoming:   moviesList(menu: .upcoming, isRunningUISmokeTests: isRunningUISmokeTests, navigationRoute: navigationRoute)
        case .nowPlaying: moviesList(menu: .nowPlaying, isRunningUISmokeTests: isRunningUISmokeTests, navigationRoute: navigationRoute)
        case .trending:   moviesList(menu: .trending, isRunningUISmokeTests: isRunningUISmokeTests, navigationRoute: navigationRoute)
        case .genres:     genresList
        case .fanClub:    fanClubList
        case .discover:   discoverList
        case .myLists:    myListsList
        case .settings:   settingsList
        }
    }
}

private struct OutlineMoviesMenuList: ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
    }

    let menu: MoviesMenu
    let shouldLoadInitialPage: Bool
    private let listener: MoviesMenuListPageListener
    @Binding var navigationRoute: MoviesListNavigationRoute?

    init(menu: MoviesMenu,
         shouldLoadInitialPage: Bool,
         navigationRoute: Binding<MoviesListNavigationRoute?>) {
        self.menu = menu
        self.shouldLoadInitialPage = shouldLoadInitialPage
        self._navigationRoute = navigationRoute
        self.listener = MoviesMenuListPageListener(menu: menu,
                                                   loadOnInit: false,
                                                   shouldLoadPage: { shouldLoadInitialPage })
    }

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch)
    }

    func body(props: Props) -> some View {
        MoviesHomeList(menu: .constant(menu),
                       navigationRoute: $navigationRoute,
                       pageListener: listener)
            .navigationDestination(item: $navigationRoute) { route in
                moviesListDestinationView(for: route)
            }
            .onAppear {
                listener.dispatchPage = { menu, page in
                    props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: page))
                }
                listener.loadPage()
            }
    }
}

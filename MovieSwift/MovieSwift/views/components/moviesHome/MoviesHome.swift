import SwiftUI
import Combine
import MovieSwiftFluxCore

enum MoviesHomeState {
    static func toggledMode(from mode: MoviesHome.HomeMode) -> MoviesHome.HomeMode {
        mode == .grid ? .list : .grid
    }

    #if !os(macOS)
    static func navigationBarTitleDisplayMode(for mode: MoviesHome.HomeMode) -> NavigationBarItem.TitleDisplayMode {
        mode == .list ? .inline : .automatic
    }
    #endif

    static func shouldLoadPage(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }
}

struct MoviesHome: ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
    }

    let isRunningUISmokeTests: Bool

    enum HomeMode {
        case list, grid

        func icon() -> String {
            switch self {
            case .list: return "rectangle.3.offgrid.fill"
            case .grid: return "rectangle.grid.1x2"
            }
        }
    }

    // `MoviesMenu.allCases.first` is non-nil at compile time
    // because the enum has at least one case (`.popular`), but
    // hard-coding the canonical default is clearer than
    // force-unwrapping and removes the audit-flagged `!`.
    // @ScaledMetric makes both the icon glyph size and the
    // surrounding tap area grow proportionally with Dynamic Type,
    // so users with larger accessibility text sizes get a
    // proportionally larger settings / view-mode toggle.
    // Hit-target floor stays at 44pt at the default Dynamic Type
    // setting — `minWidth/minHeight` lets the frame grow above 44.
    @ScaledMetric private var headerIconSize: CGFloat = 22
    @ScaledMetric private var headerHitSize: CGFloat = 44
    @State private var selectedMenu = MoviesSelectedMenuStore(selectedMenu: .popular)
    @State private var isSettingPresented = false
    @State private var homeMode = HomeMode.list
    @State private var navigationRoute: MoviesListNavigationRoute?

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch)
    }

    private var settingButton: some View {
        Button(action: {
            self.isSettingPresented = true
        }) {
            Image(systemName: "wrench")
                .resizable()
                .scaledToFit()
                .frame(width: headerIconSize, height: headerIconSize)
                .frame(minWidth: headerHitSize, minHeight: headerHitSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier(AccessibilityID.MoviesHome.settingsButton)
    }

    private var swapHomeButton: some View {
        Button(action: {
            self.homeMode = MoviesHomeState.toggledMode(from: self.homeMode)
        }) {
            Image(systemName: self.homeMode.icon())
                .resizable()
                .scaledToFit()
                .frame(width: headerIconSize, height: headerIconSize)
                .frame(minWidth: headerHitSize, minHeight: headerHitSize)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Toggle layout")
        .accessibilityIdentifier(AccessibilityID.MoviesHome.toggleLayoutButton)
    }

    @ViewBuilder
    private var homeAsList: some View {
        TabView(selection: $selectedMenu.menu) {
            ForEach(MoviesMenu.allCases, id: \.self) { menu in
                if menu == .genres {
                    GenresList()
                        .tag(menu)
                } else {
                    MoviesHomeList(menu: .constant(menu),
                                   navigationRoute: $navigationRoute,
                                   pageListener: selectedMenu.pageListener)
                        .tag(menu)
                }
            }
        }
        #if !os(macOS)
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        #endif
    }

    private var homeAsGrid: some View {
        MoviesHomeGrid(navigationRoute: $navigationRoute,
                       isRunningUISmokeTests: isRunningUISmokeTests)
    }

    private func configurePageListener(props: Props) {
        selectedMenu.pageListener.shouldLoadPage = {
            MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: isRunningUISmokeTests)
        }
        selectedMenu.pageListener.dispatchPage = { menu, page in
            props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: page))
        }
    }

    func body(props: Props) -> some View {
        NavigationStack {
            Group {
                switch homeMode {
                case .list:
                    homeAsList
                case .grid:
                    homeAsGrid
                }
            }
            .navigationTitle(selectedMenu.menu.title())
            #if !os(macOS)
            .navigationBarTitleDisplayMode(MoviesHomeState.navigationBarTitleDisplayMode(for: homeMode))
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    swapHomeButton
                    settingButton
                }
            }
            .navigationDestination(item: $navigationRoute) { route in
                moviesListDestinationView(for: route)
            }
            #if os(macOS)
            .sheet(isPresented: $isSettingPresented,
                   content: {
                       SettingsForm(onClose: {
                           isSettingPresented = false
                       })
                   })
            #else
            .fullScreenCover(isPresented: $isSettingPresented,
                             content: {
                                 SettingsForm(onClose: {
                                     isSettingPresented = false
                                 })
                             })
            #endif
            .onAppear {
                configurePageListener(props: props)
                selectedMenu.pageListener.loadPage()
            }
            .onChange(of: selectedMenu.menu) {
                configurePageListener(props: props)
                selectedMenu.pageListener.loadPage()
            }
        }
    }
}

#Preview {
    MoviesHome(isRunningUISmokeTests: false).environment(sampleStore)
}

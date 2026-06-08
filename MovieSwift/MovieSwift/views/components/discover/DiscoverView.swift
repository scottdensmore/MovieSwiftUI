import SwiftUI
@preconcurrency import SwiftUIFlux
import Backend
import UI
import MovieSwiftFluxCore

enum DiscoverSwipeDecision: Equatable {
    case wishlist
    case seenlist
    case none

    static func from(handler: DraggableCover.EndState) -> DiscoverSwipeDecision {
        switch handler {
        case .left:
            return .wishlist
        case .right:
            return .seenlist
        case .cancelled:
            return .none
        }
    }
}

enum DiscoverSwipeAction: Equatable {
    case wishlist(Int)
    case seenlist(Int)
}

enum DiscoverSwipeActionPlan {
    static func action(for decision: DiscoverSwipeDecision, currentMovieId: Int?) -> DiscoverSwipeAction? {
        guard let currentMovieId else { return nil }
        switch decision {
        case .wishlist:
            return .wishlist(currentMovieId)
        case .seenlist:
            return .seenlist(currentMovieId)
        case .none:
            return nil
        }
    }
}

enum DiscoverFetchPolicy {
    static func shouldFetchRandomMovies(currentMovieCount: Int,
                                        force: Bool,
                                        isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests && (currentMovieCount < 10 || force)
    }
}

enum DiscoverEmptyState {
    static func shouldShow(currentMovie: Movie?) -> Bool {
        currentMovie == nil
    }
}

struct DiscoverEmptyStatePresentation: Equatable {
    let title: String
    let message: String
    let showsRefill: Bool
}

enum DiscoverEmptyStateContent {
    static func presentation(filter: DiscoverFilter?, isRunningUISmokeTests: Bool) -> DiscoverEmptyStatePresentation {
        if filter?.hasExplicitConstraints == true {
            return DiscoverEmptyStatePresentation(title: "No more discover movies",
                                                 message: "Undo the last action, reset the filter, or refill this queue.",
                                                 showsRefill: !isRunningUISmokeTests)
        }

        return DiscoverEmptyStatePresentation(title: "No more discover movies",
                                             message: "Undo the last action or refill to keep browsing.",
                                             showsRefill: !isRunningUISmokeTests)
    }
}

struct DiscoverRefillPlan {
    let forceFetch: Bool
    let filter: DiscoverFilter?
}

enum DiscoverRefillActionPlan {
    static func plan(currentFilter: DiscoverFilter?, isRunningUISmokeTests: Bool) -> DiscoverRefillPlan? {
        guard !isRunningUISmokeTests else { return nil }
        return DiscoverRefillPlan(forceFetch: true, filter: currentFilter)
    }
}

enum DiscoverUndoState {
    static func canUndo(previousMovie: Int?, isDragging: Bool) -> Bool {
        previousMovie != nil && !isDragging
    }
}

struct DiscoverView: ConnectedView {
    @EnvironmentObject private var store: Store<AppState>
    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests

    // MARK: - Props
    struct Props {
        let movies: [Int]
        let posters: [Int: String]
        let currentMovie: Movie?
        let filter: DiscoverFilter?
        let genres: [Genre]
        let loadingFailure: MoviesListLoadFailure?
        let dispatch: DispatchFunction
    }

    // MARK: - State vars
    @State private var draggedViewState = DraggableCover.DragState.inactive
    @State private var previousMovie: Int?
    @State private var presentedMovie: Movie?
    @State private var isFilterFormPresented = false
    @State private var willEndPosition: CGSize?
    #if os(iOS)
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .soft)
    #endif

    #if os(macOS)
    private let bottomSafeInsetFix: CGFloat = 100
    #else
    private let bottomSafeInsetFix: CGFloat = 20
    #endif

    // MARK: - Map State to Props
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        var posters: [Int: String] = [:]
        let movies = state.moviesState.discover
        for movie in movies {
            posters[movie] = state.moviesState.movies[movie]?.poster_path
        }
        let loadingFailure: MoviesListLoadFailure?
        if case .failed(let f) = state.moviesState.loadingStates[.randomDiscover] {
            loadingFailure = f
        } else {
            loadingFailure = nil
        }
        return Props(movies: movies,
                     posters: posters,
                     currentMovie: movies.isEmpty ? nil : state.moviesState.movies[movies.reversed()[0]],
                     filter: state.moviesState.discoverFilter,
                     genres: state.moviesState.genres,
                     loadingFailure: loadingFailure,
                     dispatch: dispatch)
    }

    // MARK: - Functions
    private func scaleResistance() -> Double {
        Double(abs(willEndPosition?.width ?? draggedViewState.translation.width) / 6800)
    }

    private func dragResistance() -> CGFloat {
        abs(willEndPosition?.width ?? draggedViewState.translation.width) / 12
    }

    private func leftZoneResistance() -> CGFloat {
        -draggedViewState.translation.width / 1000
    }

    private func rightZoneResistance() -> CGFloat {
        draggedViewState.translation.width / 1000
    }

    private func draggableCoverEndGestureHandler(props: Props, handler: DraggableCover.EndState) {
        performDiscoverAction(decision: DiscoverSwipeDecision.from(handler: handler), props: props)
    }

    private func performDiscoverAction(decision: DiscoverSwipeDecision, props: Props) {
        guard let action = DiscoverSwipeActionPlan.action(for: decision,
                                                          currentMovieId: props.currentMovie?.id) else {
            return
        }
        let currentMovieId: Int
        switch action {
        case let .wishlist(movieId):
            currentMovieId = movieId
            props.dispatch(MoviesActions.AddToWishlist(movie: movieId))
        case let .seenlist(movieId):
            currentMovieId = movieId
            props.dispatch(MoviesActions.AddToSeenList(movie: movieId))
        }
        previousMovie = currentMovieId
        #if os(iOS)
        hapticFeedback.impactOccurred(intensity: 0.8)
        #endif
        props.dispatch(MoviesActions.PopRandromDiscover())
        willEndPosition = nil
        fetchRandomMovies(props: props, force: false, filter: props.filter)
    }

    private func fetchRandomMovies(props: Props, force: Bool, filter: DiscoverFilter?) {
        if DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: props.movies.count,
                                                       force: force,
                                                       isRunningUISmokeTests: isRunningUISmokeTests) {
            props.dispatch(MoviesActions.FetchRandomDiscover(filter: filter))
        }
    }

    private func primaryActionButton(systemImage: String,
                                     color: Color,
                                     decision: DiscoverSwipeDecision,
                                     accessibilityIdentifier: String,
                                     opacity: Double,
                                     xOffset: CGFloat,
                                     yOffset: CGFloat,
                                     props: Props) -> some View {
        Button(action: {
            self.performDiscoverAction(decision: decision, props: props)
        }, label: {
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: 1)
                Image(systemName: systemImage)
                    .foregroundStyle(color)
            }
            .frame(width: 50, height: 50)
            .padding(12)
            .contentShape(Rectangle())
        })
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(accessibilityIdentifier)
        // The ternary makes this a `String`, which binds to the
        // non-localizing `accessibilityLabel(_: StringProtocol)` overload —
        // so each branch must be `String(localized:)` to reach the catalog.
        .accessibilityLabel(decision == .wishlist
                            ? String(localized: "Add to wishlist", comment: "Accessibility label for the swipe-to-wishlist action on a Discover card")
                            : String(localized: "Add to seenlist", comment: "Accessibility label for the swipe-to-seenlist action on a Discover card"))
        .offset(x: xOffset, y: yOffset)
        .opacity(opacity)
        .animation(.spring(), value: self.draggedViewState.translation)
    }

    // MARK: Body views
    private func filterView(props: Props) -> some View {
        return BorderedButton(text: props.filter?.toText(genres: props.genres) ?? "Loading...",
                              systemImageName: "line.horizontal.3.decrease",
                              color: .steam_blue,
                              isOn: false) {
                                self.isFilterFormPresented = true
        }
        .accessibilityIdentifier("discover.filterButton")
    }

    private func actionsButtons(props: Props) -> some View {
        ZStack(alignment: .center) {
            if let currentMovie = props.currentMovie {
                Text(currentMovie.userTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .font(.FjallaOne(size: 18))
                    .lineLimit(2)
                    .accessibilityIdentifier("discover.currentMovieTitle")
                    .opacity(self.draggedViewState.isDragging ? 0.0 : 1.0)
                    .offset(x: 0, y: -15)
                    .animation(.easeInOut, value: self.draggedViewState.isDragging)

                primaryActionButton(systemImage: "heart.fill",
                                    color: .pink,
                                    decision: .wishlist,
                                    accessibilityIdentifier: "discover.wishlistButton",
                                    opacity: self.draggedViewState.isDragging ? 0.3 + Double(self.leftZoneResistance()) : 0.8,
                                    xOffset: -70,
                                    yOffset: 0,
                                    props: props)

                primaryActionButton(systemImage: "eye.fill",
                                    color: .green,
                                    decision: .seenlist,
                                    accessibilityIdentifier: "discover.seenlistButton",
                                    opacity: self.draggedViewState.isDragging ? 0.3 + Double(self.rightZoneResistance()) : 0.8,
                                    xOffset: 70,
                                    yOffset: 0,
                                    props: props)

                Button(action: {
                    #if os(iOS)
                    self.hapticFeedback.impactOccurred(intensity: 0.5)
                    #endif
                    self.previousMovie = currentMovie.id
                    props.dispatch(MoviesActions.PopRandromDiscover())
                    self.fetchRandomMovies(props: props, force: false, filter: props.filter)
                }, label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.red, lineWidth: 1)
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                    }
                    .frame(width: 50, height: 50)
                    .padding(12)
                    .contentShape(Rectangle())
                })
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("discover.dismissButton")
                    .accessibilityLabel("Skip movie")
                    .offset(x: 0, y: 30)
                    .opacity(self.draggedViewState.isDragging ? 0.0 : 1)
                    .animation(.spring(), value: self.draggedViewState.isDragging)

                Button(action: {
                    props.dispatch(MoviesActions.ResetRandomDiscover())
                    self.fetchRandomMovies(props: props, force: true, filter: nil)
                }, label: {
                    Image(systemName: "arrow.swap")
                        .foregroundStyle(Color.steam_blue)
                })
                    .frame(width: 50, height: 50)
                    .accessibilityIdentifier("discover.resetButton")
                    .accessibilityLabel("Reset discover")
                    .offset(x: 60, y: 30)
                    .opacity(self.draggedViewState.isDragging ? 0.0 : 1.0)
                    .animation(.spring(), value: self.draggedViewState.isDragging)
            } else if DiscoverEmptyState.shouldShow(currentMovie: props.currentMovie) {
                let presentation = DiscoverEmptyStateContent.presentation(filter: props.filter,
                                                                         isRunningUISmokeTests: isRunningUISmokeTests)
                VStack(spacing: 12) {
                    Text(presentation.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .font(.FjallaOne(size: 18))
                        .accessibilityIdentifier("discover.emptyState")

                    Text(presentation.message)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("discover.emptyStateMessage")

                    if presentation.showsRefill {
                        BorderedButton(text: "Refill discover",
                                       systemImageName: "arrow.clockwise",
                                       color: .steam_blue,
                                       isOn: false) {
                            if let plan = DiscoverRefillActionPlan.plan(currentFilter: props.filter,
                                                                        isRunningUISmokeTests: isRunningUISmokeTests) {
                                self.fetchRandomMovies(props: props, force: plan.forceFetch, filter: plan.filter)
                            }
                        }
                        .accessibilityIdentifier("discover.refillButton")
                    }
                }
            }

            Button(action: {
                guard let previousMovie = self.previousMovie else { return }
                props.dispatch(MoviesActions.PushRandomDiscover(movie: previousMovie))
                self.previousMovie = nil
            }, label: {
                Image(systemName: "gobackward").foregroundStyle(Color.steam_blue)
            }) .frame(width: 50, height: 50)
                .accessibilityIdentifier("discover.undoButton")
                .offset(x: -60, y: 30)
                .opacity(DiscoverUndoState.canUndo(previousMovie: self.previousMovie,
                                                   isDragging: self.draggedViewState.isActive) ? 1 : 0)
                .animation(.spring(),
                           value: DiscoverUndoState.canUndo(previousMovie: self.previousMovie,
                                                            isDragging: self.draggedViewState.isActive))
        }
    }

    private func swipeHintView(props: Props) -> some View {
        Group {
            if props.currentMovie != nil {
                Text("Swipe left to add to wishlist. Swipe right to add to seenlist.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }

    private func draggableMovies(props: Props) -> some View {
        // Stack depth = position in the reversed queue. The first
        // item is the front-of-stack draggable card; everything else
        // gets a depth-based scale + offset so the deck reads as
        // layered. Depth comes from a single firstIndex(of:) lookup
        // — the earlier `firstIndex(of: id)!` force-unwraps were a
        // crash hazard if `id` ever fell out of the array between
        // the if-check and the trailing modifiers (e.g. mid-update
        // after a Pop action).
        let reversed = props.movies.reversed().map { $0 }
        return ForEach(reversed, id: \.self) { id in
            let depth = reversed.firstIndex(of: id) ?? 0
            return Group {
                if depth == 0 {
                    presentMovieDetails(
                        DraggableCover(posterPath: DiscoverPosterLookup.posterPath(for: id, posters: props.posters),
                                       gestureViewState: self.$draggedViewState,
                                       onTapGesture: {
                                        self.presentedMovie = props.currentMovie
                        },
                                       willEndGesture: { position in
                                        self.willEndPosition = position
                        },
                                       endGestureHandler: { handler in
                                        self.draggableCoverEndGestureHandler(props: props, handler: handler)
                        })
                    )
                } else {
                    DiscoverCoverImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: props.posters[id],
                                                                                      size: .medium))
                        .scaleEffect(1.0 - CGFloat(depth) * 0.03 + CGFloat(self.scaleResistance()))
                        .padding(.bottom, CGFloat(depth * 16) - self.dragResistance())
                        .animation(self.draggedViewState.isActive ?
                            .easeIn(duration: 0) :
                            .spring(response: 0.5, dampingFraction: 0.5, blendDuration: 0),
                                   value: self.draggedViewState.translation)
                }
            }
        }
    }

    @ViewBuilder
    private func presentMovieDetails<Content: View>(_ content: Content) -> some View {
        #if os(macOS)
        content
            .popover(item: self.$presentedMovie,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: .bottom) { movie in
                NavigationStack {
                    MovieDetail(movieId: movie.id)
                }
                .environmentObject(store)
                .frame(minWidth: 760, idealWidth: 860, maxWidth: 980,
                       minHeight: 760, idealHeight: 860, maxHeight: 980)
            }
        #else
        content
            .sheet(item: self.$presentedMovie, onDismiss: {
                self.presentedMovie = nil
            }, content: { movie in
                NavigationStack {
                    MovieDetail(movieId: movie.id)
                }
                    .environmentObject(store)
            })
        #endif
    }

    @ViewBuilder
    func body(props: Props) -> some View {
        #if os(macOS)
        macOSBody(props: props)
        #else
        ZStack(alignment: .center) {
            draggableMovies(props: props)
            GeometryReader { reader in
                self.filterView(props: props)
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).minY + reader.safeAreaInsets.top + 10)
                    .frame(height: 50)
                    .sheet(isPresented: self.$isFilterFormPresented, content: { DiscoverFilterForm().environmentObject(store) })
                self.swipeHintView(props: props)
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).maxY - reader.safeAreaInsets.bottom - self.bottomSafeInsetFix - 85)
                self.actionsButtons(props: props)
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).maxY - reader.safeAreaInsets.bottom - self.bottomSafeInsetFix)
                if let failure = props.loadingFailure {
                    MoviesListErrorBanner(failure: failure) {
                        props.dispatch(MoviesActions.FetchRandomDiscover(filter: props.filter))
                    }
                    .position(x: reader.frame(in: .local).midX,
                              y: reader.frame(in: .local).minY + reader.safeAreaInsets.top + 80)
                }
            }
        }
        .background(FullscreenMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: props.currentMovie?.poster_path,
                                                                                              size: .original))
            .allowsHitTesting(false)
            .transition(.opacity)
            .animation(.easeInOut, value: props.currentMovie?.poster_path))
        .onAppear {
            self.hapticFeedback.prepare()
            self.fetchRandomMovies(props: props, force: false, filter: props.filter)
            props.dispatch(MoviesActions.FetchGenres())
        }
        #endif
    }

    #if os(macOS)
    private func macOSBody(props: Props) -> some View {
        ZStack {
            // Blurred poster backdrop
            FullscreenMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(
                path: props.currentMovie?.poster_path,
                size: .original))
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut, value: props.currentMovie?.poster_path)
                .overlay(Color.black.opacity(0.55))

            if let movie = props.currentMovie {
                VStack(spacing: 22) {
                    HStack {
                        filterView(props: props)
                            .sheet(isPresented: $isFilterFormPresented) {
                                DiscoverFilterForm().environmentObject(store)
                            }
                        Spacer()
                        resetButton(props: props)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    if let failure = props.loadingFailure {
                        MoviesListErrorBanner(failure: failure) {
                            props.dispatch(MoviesActions.FetchRandomDiscover(filter: props.filter))
                        }
                    }

                    Spacer(minLength: 0)

                    cardDeck(props: props)
                        .frame(maxWidth: 340, maxHeight: 500)

                    VStack(spacing: 6) {
                        Text(movie.userTitle)
                            .font(.FjallaOne(size: 28))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .accessibilityIdentifier("discover.currentMovieTitle")
                        if !movie.overview.isEmpty {
                            Text(movie.overview)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 40)
                        }
                    }

                    discoverActionsRow(props: props, movie: movie)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .popover(item: $presentedMovie,
                         attachmentAnchor: .rect(.bounds),
                         arrowEdge: .bottom) { movie in
                    NavigationStack {
                        MovieDetail(movieId: movie.id)
                    }
                    .environmentObject(store)
                    .frame(minWidth: 760, idealWidth: 860, maxWidth: 980,
                           minHeight: 760, idealHeight: 860, maxHeight: 980)
                }
            } else {
                // No current movie — either still loading the first
                // random batch, or the most recent fetch failed and
                // there's nothing to show. The banner tells the user
                // which case it is and offers a retry.
                VStack(spacing: 12) {
                    if let failure = props.loadingFailure {
                        MoviesListErrorBanner(failure: failure) {
                            props.dispatch(MoviesActions.FetchRandomDiscover(filter: props.filter))
                        }
                    } else {
                        ProgressView()
                        Text("Loading random movies…")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .onAppear {
            fetchRandomMovies(props: props, force: false, filter: props.filter)
            props.dispatch(MoviesActions.FetchGenres())
        }
    }

    /// A ZStack deck of the top-of-queue movies so Discover visually
    /// reads as a stack of cards the user is flipping through.
    private func cardDeck(props: Props) -> some View {
        let queue = Array(props.movies.reversed().prefix(4))
        return ZStack {
            ForEach(Array(queue.enumerated()).reversed(), id: \.element) { index, movieId in
                let depth = CGFloat(index)
                Button {
                    if index == 0, let movie = props.currentMovie {
                        presentedMovie = movie
                    }
                } label: {
                    DiscoverCoverImage(imageLoader: ImageLoaderCache.shared.loaderFor(
                        path: props.posters[movieId],
                        size: .medium))
                }
                .buttonStyle(.plain)
                .disabled(index != 0)
                .accessibilityHidden(index != 0)
                .scaleEffect(1.0 - depth * 0.04)
                .offset(y: depth * 6)
                .shadow(color: .black.opacity(0.5 - Double(depth) * 0.1),
                        radius: 14 - depth * 3,
                        y: 10 - depth * 2)
                .zIndex(Double(queue.count - index))
                .animation(.spring(response: 0.4, dampingFraction: 0.85),
                           value: props.currentMovie?.id)
            }
        }
    }

    private func discoverActionsRow(props: Props, movie: Movie) -> some View {
        HStack(spacing: 18) {
            discoverKeyButton(systemImage: "heart.fill",
                              tint: .pink,
                              title: "Wishlist",
                              hint: "←",
                              shortcut: .leftArrow,
                              accessibilityIdentifier: "discover.wishlistButton") {
                performDiscoverAction(decision: .wishlist, props: props)
            }
            discoverKeyButton(systemImage: "info.circle.fill",
                              tint: .steam_blue,
                              title: "Info",
                              hint: "↩",
                              shortcut: .return,
                              accessibilityIdentifier: "discover.infoButton") {
                presentedMovie = movie
            }
            discoverKeyButton(systemImage: "xmark",
                              tint: .gray,
                              title: "Skip",
                              hint: "esc",
                              shortcut: .escape,
                              accessibilityIdentifier: "discover.dismissButton") {
                previousMovie = movie.id
                props.dispatch(MoviesActions.PopRandromDiscover())
                fetchRandomMovies(props: props, force: false, filter: props.filter)
            }
            discoverKeyButton(systemImage: "eye.fill",
                              tint: .green,
                              title: "Seenlist",
                              hint: "→",
                              shortcut: .rightArrow,
                              accessibilityIdentifier: "discover.seenlistButton") {
                performDiscoverAction(decision: .seenlist, props: props)
            }
        }
    }

    private func resetButton(props: Props) -> some View {
        Button {
            props.dispatch(MoviesActions.ResetRandomDiscover())
            fetchRandomMovies(props: props, force: true, filter: nil)
        } label: {
            Label("Reset", systemImage: "arrow.swap")
                .foregroundStyle(Color.steam_blue)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover.resetButton")
        .accessibilityLabel("Reset discover")
    }

    private func discoverKeyButton(systemImage: String,
                                   tint: Color,
                                   title: String,
                                   hint: String,
                                   shortcut: KeyEquivalent,
                                   accessibilityIdentifier: String,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(tint, lineWidth: 1.5)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .frame(width: 58, height: 58)
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.95))
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: [])
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
    }
    #endif
}

#Preview {
    DiscoverView().environmentObject(sampleStore)
}

import SwiftUI
@preconcurrency import SwiftUIFlux
import UI
import MovieSwiftFluxCore

struct MovieDetail: ConnectedView {
    struct Props {
        let movie: Movie?
        let characters: [People]?
        let credits: [People]?
        let recommended: [Movie]?
        let similar: [Movie]?
        let reviewsCount: Int?
        let videos: [Video]?
        let hasMovieDetail: Bool
        let hasMovieCredits: Bool
        let hasRecommended: Bool
        let hasSimilar: Bool
        let hasReviews: Bool
        let hasVideos: Bool
        let isInWishlist: Bool
        let isInSeenlist: Bool
        let customLists: [CustomList]
        /// Failure for the top-level FetchDetail. Sub-row failures
        /// (recommended / similar / videos / reviews) are ignored
        /// here — those rows degrade gracefully when their data
        /// isn't loaded, and showing five separate banners would be
        /// noisy. The detail-level failure matters most because
        /// without it the whole page is empty.
        let detailFailure: MoviesListLoadFailure?
        let dispatch: DispatchFunction
    }

    let movieId: Int
    @EnvironmentObject private var store: Store<AppState>
    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests

    // MARK: View States
    @State var isAddSheetPresented = false
    @State var isCreateListFormPresented = false
    @State var isAddedToListBadgePresented = false
    @State var selectedPoster: ImageData?
    @State var selectedBackdrop: ImageData?
    @State private var selectedPeopleId: Int?
    @State private var selectedReviewMovieId: Int?
    @State private var selectedCrosslineRoute: MoviesListNavigationRoute?
    @State private var selectedGenre: Genre?
    @State private var selectedKeyword: Keyword?
    @State private var crosslineMoviesPresentation: CrosslineMoviesPresentation?
    @State private var peopleListPresentation: PeopleListPresentation?

    struct PeopleListPresentation: Identifiable, Hashable {
        let id: String
        let title: String
        let peopleIds: [Int]

        static func == (lhs: PeopleListPresentation, rhs: PeopleListPresentation) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    struct CrosslineMoviesPresentation: Identifiable, Hashable {
        let id: String
        let title: String
        let movieIds: [Int]

        static func == (lhs: CrosslineMoviesPresentation, rhs: CrosslineMoviesPresentation) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    #if os(macOS)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedDetailItem: MovieDetailFocusTarget?
    @State private var visibleRowIds: Set<String> = []
    #endif

    // MARK: Computed Props
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        var recommended: [Movie]?
        var similar: [Movie]?

        if let recommendedIds = state.moviesState.recommended[movieId] {
            recommended = recommendedIds.compactMap { state.moviesState.movies[$0] }
        }
        if let simillarIds = state.moviesState.similar[movieId] {
            similar = simillarIds.compactMap { state.moviesState.movies[$0] }
        }
        let detailFailure: MoviesListLoadFailure?
        if case .failed(let f) = state.moviesState.loadingStates[.movieDetail(movieId)] {
            detailFailure = f
        } else {
            detailFailure = nil
        }
        return Props(movie: MovieDetailState.movie(movieId: movieId, from: state),
                     characters: MovieDetailPeopleState.characters(movieId: movieId, from: state),
                     credits: MovieDetailPeopleState.credits(movieId: movieId, from: state),
                     recommended: recommended,
                     similar: similar,
                     reviewsCount: state.moviesState.reviews[movieId]?.count ?? nil,
                     videos: state.moviesState.videos[movieId],
                     hasMovieDetail: MovieDetailState.hasLoadedDetail(movieId: movieId, from: state),
                     hasMovieCredits: MovieDetailPeopleState.hasLoadedMovieCredits(movieId: movieId, from: state),
                     hasRecommended: MovieDetailState.hasLoadedRecommended(movieId: movieId, from: state),
                     hasSimilar: MovieDetailState.hasLoadedSimilar(movieId: movieId, from: state),
                     hasReviews: MovieDetailState.hasLoadedReviews(movieId: movieId, from: state),
                     hasVideos: MovieDetailState.hasLoadedVideos(movieId: movieId, from: state),
                     isInWishlist: MovieDetailListState.isInWishlist(movieId: movieId, from: state),
                     isInSeenlist: MovieDetailListState.isInSeenlist(movieId: movieId, from: state),
                     customLists: MovieDetailListState.customLists(from: state),
                     detailFailure: detailFailure,
                     dispatch: dispatch)
    }

    // MARK: - Fetch
    func fetchMovieDetails(props: Props) {
        for slice in MovieDetailFetchPolicy.slicesToFetch(hasMovieDetail: props.hasMovieDetail,
                                                          hasMovieCredits: props.hasMovieCredits,
                                                          hasRecommended: props.hasRecommended,
                                                          hasSimilar: props.hasSimilar,
                                                          hasReviews: props.hasReviews,
                                                          hasVideos: props.hasVideos,
                                                          isRunningUISmokeTests: isRunningUISmokeTests) {
            switch slice {
            case .detail:
                props.dispatch(MoviesActions.FetchDetail(movie: movieId))
            case .credits:
                props.dispatch(PeopleActions.FetchMovieCasts(movie: movieId))
            case .recommended:
                props.dispatch(MoviesActions.FetchRecommended(movie: movieId))
            case .similar:
                props.dispatch(MoviesActions.FetchSimilar(movie: movieId))
            case .reviews:
                props.dispatch(MoviesActions.FetchMovieReviews(movie: movieId))
            case .videos:
                props.dispatch(MoviesActions.FetchVideos(movie: movieId))
            }
        }
    }

    // MARK: - View actions
    func displaySavedBadge() {
        isAddedToListBadgePresented = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isAddedToListBadgePresented = false
        }
    }

    func onAddButton() {
        isAddSheetPresented.toggle()
    }

    private func selectPeople(_ id: Int) {
        selectedPeopleId = id
    }

    private func primaryPeopleCredit(props: Props) -> People? {
        props.credits?.first(where: {
            ($0.department ?? "").localizedCaseInsensitiveContains("direct")
        })
    }

    private func presentCrosslineMoviesList(title: String, movies: [Movie]) {
        crosslineMoviesPresentation = CrosslineMoviesPresentation(
            id: "crossline-\(title)-\(movieId)",
            title: title,
            movieIds: MovieCrosslineState.movieIds(from: movies)
        )
    }

    private func presentPeopleList(title: String, peoples: [People]) {
        // Use a stable id based on title so repeated taps don't churn navigation.
        peopleListPresentation = PeopleListPresentation(
            id: "peopleList-\(title)-\(movieId)",
            title: title,
            peopleIds: peoples.map { $0.id }
        )
    }

    #if os(macOS)
    /// Builds the pure focus model from the current props. All Tab-order /
    /// target logic lives in `MovieDetailFocusModel` (see MovieDetailFocus.swift);
    /// the view keeps only the `@FocusState` glue below.
    private func focusModel(props: Props) -> MovieDetailFocusModel {
        MovieDetailFocusModel(movie: props.movie,
                              characters: props.characters,
                              credits: props.credits,
                              similar: props.similar,
                              recommended: props.recommended,
                              videos: props.videos,
                              reviewsCount: props.reviewsCount,
                              topPersonId: primaryPeopleCredit(props: props)?.id)
    }

    private func restoreDetailFocus(props: Props, force: Bool = false) {
        guard selectedPoster == nil else {
            return
        }

        let model = focusModel(props: props)
        let availableTargets = model.availableTopTargets
        guard !availableTargets.isEmpty else {
            focusedDetailItem = nil
            return
        }

        // Re-pick the preferred target when:
        //   force == true (user nav action),
        //   nothing is focused yet,
        //   or the focused item is no longer in the available list.
        // The earlier `availableTargets.contains(focusedDetailItem!)`
        // forced an unwrap that was already guarded by the
        // immediately-preceding `focusedDetailItem == nil` check —
        // restructured to make the guard explicit.
        if force {
            focusedDetailItem = model.preferredFocusTarget
        } else if let focused = focusedDetailItem {
            if !availableTargets.contains(focused) {
                focusedDetailItem = model.preferredFocusTarget
            }
        } else {
            focusedDetailItem = model.preferredFocusTarget
        }
    }
    #endif

    // Crossline movies list is presented as a sheet — see the See-all sheet
    // explanation on peopleListPresentation.

    // Kept as a method for backwards-compat but not used as a navigation destination —
    // using a method there caused MovieDetail.body to be invalidated in a loop.

    // MARK: - Computed views

    // MARK: - Body

    func peopleRow(role: String, people: People?) -> some View {
        Group {
            if let people {
                let accessibilityId = AccessibilityID.MovieDetail.topPerson(people.id)
                #if os(macOS)
                MacFocusableLink(id: .topPerson(people.id), focusedId: $focusedDetailItem) {
                    selectPeople(people.id)
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Text(role + ": ").font(.callout)
                        Text(people.name).font(.body).foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(role): \(people.name)")
                    .accessibilityIdentifier(accessibilityId)
                }
                #else
                Button(action: {
                    selectPeople(people.id)
                }) {
                    HStack(alignment: .center, spacing: 0) {
                        Text(role + ": ").font(.callout)
                        Text(people.name).font(.body).foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(role): \(people.name)")
                    .accessibilityIdentifier(accessibilityId)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(accessibilityId)
                #endif
            }
        }
    }

    func peopleRows(props: Props) -> some View {
        Group {
            peopleRow(role: "Director", people: primaryPeopleCredit(props: props))
        }
    }

    @ViewBuilder
    func smokeTestTopPersonShortcut(props: Props) -> some View {
        #if DEBUG
        if isRunningUISmokeTests,
           let people = primaryPeopleCredit(props: props) ?? props.characters?.first ?? props.credits?.first {
            Button(action: {
                selectPeople(people.id)
            }) {
                Text("Open person: \(people.name)")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.MovieDetail.topPersonShortcut)
        }
        #endif
    }

    @ViewBuilder
    func topContent(props: Props) -> some View {
        #if os(macOS)
        MovieCoverRow(movieId: movieId, focusedItem: $focusedDetailItem) { genre in
            selectedGenre = genre
        }
        .trackedDetailRow("row.cover", visibleRowIds: $visibleRowIds)
        MovieButtonsRow(movieId: movieId,
                        showCustomListSheet: $isAddSheetPresented,
                        focusedItem: $focusedDetailItem)
        .trackedDetailRow("row.buttons", visibleRowIds: $visibleRowIds)
        #else
        MovieCoverRow(movieId: movieId)
        MovieButtonsRow(movieId: movieId, showCustomListSheet: $isAddSheetPresented)
        #endif
        smokeTestTopPersonShortcut(props: props)
        if let reviewsCount = props.reviewsCount, reviewsCount > 0 {
            #if os(macOS)
            MacFocusableLink(id: .reviewLink, focusedId: $focusedDetailItem) {
                selectedReviewMovieId = movieId
            } label: {
                Text("\(reviewsCount) reviews")
                    .foregroundStyle(Color.steam_blue)
                    .lineLimit(1)
                    .padding(.leading)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
            }
            .trackedDetailRow("row.review", visibleRowIds: $visibleRowIds)
            #else
            Button(action: {
                selectedReviewMovieId = movieId
            }) {
                Text("\(reviewsCount) reviews")
                    .foregroundStyle(Color.steam_blue)
                    .lineLimit(1)
                    .padding(.leading)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            #endif
        }
        if props.credits?.isEmpty == false {
            #if os(macOS)
            peopleRows(props: props).trackedDetailRow("row.director", visibleRowIds: $visibleRowIds)
            #else
            peopleRows(props: props)
            #endif
        }
        if let movie = props.movie, !movie.overview.isEmpty {
            #if os(macOS)
            MovieOverview(movie: movie, focusedItem: $focusedDetailItem)
                .trackedDetailRow("row.overview", visibleRowIds: $visibleRowIds)
            #else
            MovieOverview(movie: movie)
            #endif
        }
    }

    @ViewBuilder
    func bottomContent(props: Props) -> some View {
        if let movie = props.movie,
           movie.keywords?.keywords?.isEmpty == false,
           let keywords = movie.keywords?.keywords {
            #if os(macOS)
            MovieKeywords(keywords: keywords,
                          onSelectKeyword: { keyword in
                              selectedKeyword = keyword
                          },
                          focusedItem: $focusedDetailItem)
                .trackedDetailRow("row.keywords", visibleRowIds: $visibleRowIds)
            #else
            MovieKeywords(keywords: keywords)
            #endif
        }
        if props.characters?.isEmpty == false {
            #if os(macOS)
            MovieCrosslinePeopleRow(title: "Cast",
                                    peoples: props.characters ?? [],
                                    onSelectPeople: selectPeople,
                                    onSelectSeeAll: {
                                        presentPeopleList(title: "Cast",
                                                          peoples: props.characters ?? [])
                                    },
                                    focusedItem: $focusedDetailItem,
                                    personFocusTarget: { .castPerson($0) },
                                    seeAllFocusTarget: .castSeeAll)
                .trackedDetailRow("row.cast", visibleRowIds: $visibleRowIds)
            #else
            MovieCrosslinePeopleRow(title: "Cast",
                                    peoples: props.characters ?? [],
                                    onSelectPeople: selectPeople,
                                    onSelectSeeAll: {
                                        presentPeopleList(title: "Cast",
                                                          peoples: props.characters ?? [])
                                    })
            #endif
        }
        if props.credits?.isEmpty == false {
            #if os(macOS)
            MovieCrosslinePeopleRow(title: "Crew",
                                    peoples: props.credits ?? [],
                                    onSelectPeople: selectPeople,
                                    onSelectSeeAll: {
                                        presentPeopleList(title: "Crew",
                                                          peoples: props.credits ?? [])
                                    },
                                    focusedItem: $focusedDetailItem,
                                    personFocusTarget: { .crewPerson($0) },
                                    seeAllFocusTarget: .crewSeeAll)
                .trackedDetailRow("row.crew", visibleRowIds: $visibleRowIds)
            #else
            MovieCrosslinePeopleRow(title: "Crew",
                                    peoples: props.credits ?? [],
                                    onSelectPeople: selectPeople,
                                    onSelectSeeAll: {
                                        presentPeopleList(title: "Crew",
                                                          peoples: props.credits ?? [])
                                    })
            #endif
        }
        if props.similar?.isEmpty == false {
            #if os(macOS)
            MovieCrosslineRow(title: "Similar Movies",
                              movies: props.similar ?? [],
                              onSelectMovie: { selectedCrosslineRoute = .movie($0) },
                              onSelectSeeAll: {
                                  presentCrosslineMoviesList(title: "Similar Movies",
                                                             movies: props.similar ?? [])
                              },
                              focusedItem: $focusedDetailItem,
                              movieFocusTarget: { .similarMovie($0) },
                              seeAllFocusTarget: .similarSeeAll)
                .trackedDetailRow("row.similar", visibleRowIds: $visibleRowIds)
            #else
            MovieCrosslineRow(title: "Similar Movies",
                              movies: props.similar ?? [],
                              onSelectMovie: { selectedCrosslineRoute = .movie($0) },
                              onSelectSeeAll: {
                                  presentCrosslineMoviesList(title: "Similar Movies",
                                                             movies: props.similar ?? [])
                              })
            #endif
        }
        if  props.recommended?.isEmpty == false {
            #if os(macOS)
            MovieCrosslineRow(title: "Recommended Movies",
                              movies: props.recommended ?? [],
                              onSelectMovie: { selectedCrosslineRoute = .movie($0) },
                              onSelectSeeAll: {
                                  presentCrosslineMoviesList(title: "Recommended Movies",
                                                             movies: props.recommended ?? [])
                              },
                              focusedItem: $focusedDetailItem,
                              movieFocusTarget: { .recommendedMovie($0) },
                              seeAllFocusTarget: .recommendedSeeAll)
                .trackedDetailRow("row.recommended", visibleRowIds: $visibleRowIds)
            #else
            MovieCrosslineRow(title: "Recommended Movies",
                              movies: props.recommended ?? [],
                              onSelectMovie: { selectedCrosslineRoute = .movie($0) },
                              onSelectSeeAll: {
                                  presentCrosslineMoviesList(title: "Recommended Movies",
                                                             movies: props.recommended ?? [])
                              })
            #endif
        }
        // Videos sit with the other media (after the Recommended carousel,
        // before posters/backdrops). Guard on the *filtered* presentations
        // so a movie with only non-YouTube videos shows no row.
        if let videos = props.videos, !MovieVideosState.presentations(from: videos).isEmpty {
            #if os(macOS)
            MovieVideosRow(videos: videos, focusedItem: $focusedDetailItem)
                .trackedDetailRow("row.videos", visibleRowIds: $visibleRowIds)
            #else
            MovieVideosRow(videos: videos)
            #endif
        }
        if let movie = props.movie,
           movie.images?.posters?.isEmpty == false,
           let posters = movie.images?.posters {
            #if os(macOS)
            MoviePostersRow(posters: posters,
                            selectedPoster: $selectedPoster,
                            focusedItem: $focusedDetailItem)
                .trackedDetailRow("row.posters", visibleRowIds: $visibleRowIds)
            #else
            MoviePostersRow(posters: posters,
                            selectedPoster: $selectedPoster)
            #endif
        }
        if let movie = props.movie,
           movie.images?.backdrops?.isEmpty == false,
           let backdrops = movie.images?.backdrops {
            #if os(macOS)
            MovieBackdropsRow(backdrops: backdrops,
                              focusedItem: $focusedDetailItem,
                              selectedBackdrop: $selectedBackdrop)
                .trackedDetailRow("row.backdrops", visibleRowIds: $visibleRowIds)
            #else
            MovieBackdropsRow(backdrops: backdrops)
            #endif
        }
    }

    @ViewBuilder
    func detailContent(props: Props) -> some View {
        #if os(macOS)
        ScrollViewReader { scrollProxy in
            ScrollView {
                // Non-lazy so every row's .id() is registered with the
                // ScrollViewReader from the start — LazyVStack would
                // hold back posters / backdrops until they scroll into
                // view, and scrollTo(id) can't target an unbuilt view.
                VStack(alignment: .leading, spacing: 0) {
                    topContent(props: props)
                    bottomContent(props: props)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            .onChange(of: focusedDetailItem) { _, newValue in
                guard let newValue else { return }
                let rowId = MovieDetailFocusRow.scrollId(for: newValue)
                // Only scroll if the row isn't already on-screen — otherwise
                // every Tab would snap the focused row to the top edge even
                // when the user could already see it.
                guard !visibleRowIds.contains(rowId) else { return }
                withAnimation {
                    scrollProxy.scrollTo(rowId, anchor: .top)
                }
            }
        }
        .onKeyPress(.tab, phases: .down) { press in
            let forward = !press.modifiers.contains(.shift)
            return moveTabFocus(props: props, forward: forward)
        }
        // macOS delivers Shift+Tab as the back-tab character (U+0019),
        // not as Tab with a shift modifier — add an explicit handler so
        // Shift+Tab walks through section headings in reverse instead
        // of falling back to the system's per-item traversal.
        .onKeyPress(characters: CharacterSet(charactersIn: "\u{19}"), phases: .down) { _ in
            return moveTabFocus(props: props, forward: false)
        }
        .onKeyPress(.leftArrow) {
            return moveArrowFocus(props: props, forward: false)
        }
        .onKeyPress(.rightArrow) {
            return moveArrowFocus(props: props, forward: true)
        }
        #else
        List {
            Section {
                topContent(props: props)
            }
            Section {
                bottomContent(props: props)
            }
        }
        #endif
    }

    #if os(macOS)
    /// Tab / Shift+Tab moves to the first target of the next / previous group,
    /// so each Tab lands on a section heading rather than walking through
    /// every item inside a row. Always returns .handled so the system's
    /// default Tab traversal can't walk into the focusable items inside a
    /// group (e.g. individual crew members after the last heading).
    private func moveTabFocus(props: Props, forward: Bool) -> KeyPress.Result {
        let groups = focusModel(props: props).focusGroups
        guard !groups.isEmpty else { return .ignored }
        if let next = MovieDetailFocusNavigation.nextGroupStart(from: focusedDetailItem,
                                                                in: groups,
                                                                forward: forward) {
            focusedDetailItem = next
        }
        return .handled
    }

    /// Left / Right arrow moves within the currently focused group only.
    /// If focus has reached the edge of the group or is on a single-item
    /// group (e.g. Read more), the event is ignored so the system can
    /// still scroll or handle it naturally.
    private func moveArrowFocus(props: Props, forward: Bool) -> KeyPress.Result {
        guard let current = focusedDetailItem else { return .ignored }
        let groups = focusModel(props: props).focusGroups
        if let next = MovieDetailFocusNavigation.adjacentInGroup(from: current,
                                                                 in: groups,
                                                                 forward: forward) {
            focusedDetailItem = next
            return .handled
        }
        return .ignored
    }
    #endif

    @ViewBuilder
    func unavailableView(props: Props) -> some View {
        VStack(spacing: 12) {
            // When the load failed, show the structured error banner
            // with a retry. When it didn't fail (e.g. movie isn't in
            // the cache for some other reason), fall back to the
            // generic "not available" message.
            if let failure = props.detailFailure {
                MoviesListErrorBanner(failure: failure) {
                    props.dispatch(MoviesActions.FetchDetail(movie: movieId))
                }
            } else {
                Text("Movie not available")
                    .font(.headline)
                Text("This movie could not be loaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    func addButton(props: Props) -> some View {
        if props.movie != nil {
            #if os(macOS)
            addMenu(props: props)
            #else
            Button(action: onAddButton) {
                Image(systemName: "text.badge.plus").imageScale(.large)
            }
            .accessibilityIdentifier(AccessibilityID.MovieDetail.addToListButton)
            .accessibilityLabel("Add to list")
            #endif
        }
    }

    #if os(macOS)
    private func addMenu(props: Props) -> some View {
        Menu {
            Button(props.isInWishlist ? "Remove from wishlist" : "Add to wishlist") {
                if props.isInWishlist {
                    props.dispatch(MoviesActions.RemoveFromWishlist(movie: movieId))
                } else {
                    props.dispatch(MoviesActions.AddToWishlist(movie: movieId))
                }
                displaySavedBadge()
            }
            Button(props.isInSeenlist ? "Remove from seenlist" : "Add to seenlist") {
                if props.isInSeenlist {
                    props.dispatch(MoviesActions.RemoveFromSeenList(movie: movieId))
                } else {
                    props.dispatch(MoviesActions.AddToSeenList(movie: movieId))
                }
                displaySavedBadge()
            }
            Divider()
            ForEach(props.customLists) { list in
                Button(list.movies.contains(movieId)
                       ? "Remove from \(list.name)"
                       : "Add to \(list.name)") {
                    if list.movies.contains(movieId) {
                        props.dispatch(MoviesActions.RemoveMovieFromCustomList(list: list.id, movie: movieId))
                    } else {
                        props.dispatch(MoviesActions.AddMovieToCustomList(list: list.id, movie: movieId))
                    }
                    displaySavedBadge()
                }
            }
            Divider()
            Button("Create list") {
                isCreateListFormPresented = true
            }
        } label: {
            Image(systemName: "text.badge.plus").imageScale(.large)
        }
        .accessibilityIdentifier(AccessibilityID.MovieDetail.addToListButton)
        .accessibilityLabel("Add to list")
    }
    #endif

    func body(props: Props) -> some View {
        _ = props.movie?.images?.posters ?? []

        return ZStack(alignment: .bottom) {
            Group {
                if let movie = props.movie {
                    detailContent(props: props)
                    .navigationTitle(movie.userTitle)
                } else {
                    unavailableView(props: props)
                        .navigationTitle("Movie")
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    addButton(props: props)
                }
            }
            .onAppear {
                self.fetchMovieDetails(props: props)
            }
            #if !os(macOS)
            .confirmationDialog(
                "Add or remove from your lists",
                isPresented: $isAddSheetPresented,
                titleVisibility: .visible
            ) {
                Button(props.isInWishlist ? "Remove from wishlist" : "Add to wishlist",
                       role: props.isInWishlist ? .destructive : nil) {
                    props.dispatch(props.isInWishlist
                        ? MoviesActions.RemoveFromWishlist(movie: movieId)
                        : MoviesActions.AddToWishlist(movie: movieId))
                    displaySavedBadge()
                }
                Button(props.isInSeenlist ? "Remove from seenlist" : "Add to seenlist",
                       role: props.isInSeenlist ? .destructive : nil) {
                    props.dispatch(props.isInSeenlist
                        ? MoviesActions.RemoveFromSeenList(movie: movieId)
                        : MoviesActions.AddToSeenList(movie: movieId))
                    displaySavedBadge()
                }
                ForEach(props.customLists) { list in
                    let isInList = list.movies.contains(movieId)
                    Button(isInList ? "Remove from \(list.name)" : "Add to \(list.name)",
                           role: isInList ? .destructive : nil) {
                        props.dispatch(isInList
                            ? MoviesActions.RemoveMovieFromCustomList(list: list.id, movie: movieId)
                            : MoviesActions.AddMovieToCustomList(list: list.id, movie: movieId))
                        displaySavedBadge()
                    }
                }
                Button("Create list") {
                    isCreateListFormPresented = true
                }
            }
            #endif
            .sheet(isPresented: $isCreateListFormPresented,
                   content: { CustomListForm(editingListId: nil)
                    .environmentObject(store) })
            .disabled(selectedPoster != nil || selectedBackdrop != nil)
            .blur(radius: (selectedPoster != nil || selectedBackdrop != nil) ? 30 : 0)
            .scaleEffect((selectedPoster != nil || selectedBackdrop != nil) ? 0.8 : 1)

            NotificationBadge(text: "Added successfully",
                              color: .blue,
                              show: $isAddedToListBadgePresented).padding(.bottom, 10)
            if selectedPoster != nil {
                ImagesCarouselView(posters: props.movie?.images?.posters ?? [],
                                       selectedPoster: $selectedPoster)
                    .transition(.opacity)
            }
            if selectedBackdrop != nil {
                ImagesCarouselView(posters: props.movie?.images?.backdrops ?? [],
                                       selectedPoster: $selectedBackdrop)
                    .transition(.opacity)
            }
        }
        .navigationDestination(item: $selectedPeopleId) { id in
            PeopleDetail(peopleId: id)
                .macBackKeyboardShortcut()
        }
        .navigationDestination(item: $selectedReviewMovieId) { id in
            MovieReviews(movie: id)
                .macBackKeyboardShortcut()
        }
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
                .macBackKeyboardShortcut()
        }
        .navigationDestination(item: $selectedKeyword) { keyword in
            MovieKeywordList(keyword: keyword)
                .macBackKeyboardShortcut()
        }
        .sheet(item: $crosslineMoviesPresentation) { presentation in
            NavigationStack {
                MoviesList(movies: presentation.movieIds,
                           displaySearch: false,
                           pageListener: nil,
                           navigationRoute: $selectedCrosslineRoute)
                    .navigationTitle(presentation.title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { crosslineMoviesPresentation = nil }
                        }
                    }
            }
            .frame(minWidth: 500, minHeight: 600)
        }
        .navigationDestination(item: $selectedCrosslineRoute) { route in
            moviesListDestinationView(for: route)
                .macBackKeyboardShortcut()
        }
        // Note: using .sheet instead of .navigationDestination here —
        // .navigationDestination(item:) with a custom struct type triggers
        // an infinite body-invalidation loop on macOS 26. Sheet works cleanly.
        .sheet(item: $peopleListPresentation) { presentation in
            NavigationStack {
                MoviePeopleListDestination(
                    title: presentation.title,
                    peopleIds: presentation.peopleIds,
                    selectedPeopleId: $selectedPeopleId,
                    onDismiss: { peopleListPresentation = nil }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { peopleListPresentation = nil }
                    }
                }
            }
            .frame(minWidth: 460, minHeight: 560)
        }
        #if os(macOS)
        .onAppear {
            restoreDetailFocus(props: props, force: true)
        }
        .onChange(of: selectedPoster?.id) { oldValue, newValue in
            // When the carousel closes, keep focus on the poster that was
            // selected so the user doesn't get snapped back to the top of
            // the detail view.
            if newValue == nil {
                if let lastPosterPath = oldValue {
                    focusedDetailItem = .poster(lastPosterPath)
                } else {
                    restoreDetailFocus(props: props)
                }
            }
        }
        .onChange(of: selectedBackdrop?.id) { oldValue, newValue in
            if newValue == nil {
                if let lastBackdropPath = oldValue {
                    focusedDetailItem = .backdrop(lastBackdropPath)
                } else {
                    restoreDetailFocus(props: props)
                }
            }
        }
        .onChange(of: props.movie?.id) { _, _ in
            restoreDetailFocus(props: props, force: true)
        }
        .onChange(of: props.reviewsCount) { _, _ in
            restoreDetailFocus(props: props)
        }
        .onChange(of: props.credits?.count) { _, _ in
            restoreDetailFocus(props: props)
        }
        .onChange(of: props.videos?.count) { _, _ in
            restoreDetailFocus(props: props)
        }
        #endif
    }

}

// MARK: - People list destination view
/// Shown as a sheet from MovieDetail's "See all" for cast/crew.
/// ConnectedView resolves [People] from ids on demand.
private struct MoviePeopleListDestination: ConnectedView {
    let title: String
    let peopleIds: [Int]
    @Binding var selectedPeopleId: Int?
    let onDismiss: () -> Void

    struct Props {
        let peoples: [People]
    }

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(peoples: peopleIds.compactMap { state.peoplesState.peoples[$0] })
    }

    func body(props: Props) -> some View {
        List {
            ForEach(Array(props.peoples.enumerated()), id: \.offset) { _, people in
                PeopleListItem(people: people) {
                    selectedPeopleId = people.id
                    onDismiss()
                }
            }
        }
        .navigationTitle(title)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MovieDetail(movieId: sampleMovie.id).environmentObject(sampleStore)
    }
}

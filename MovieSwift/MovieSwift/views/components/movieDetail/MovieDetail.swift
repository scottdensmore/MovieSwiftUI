import SwiftUI
@preconcurrency import SwiftUIFlux
import Combine
import UI
import MovieSwiftFluxCore

enum MovieDetailLoadSlice: Equatable {
    case detail
    case credits
    case recommended
    case similar
    case reviews
    case videos
}

enum MovieDetailFetchPolicy {
    static func slicesToFetch(hasMovieDetail: Bool,
                              hasMovieCredits: Bool,
                              hasRecommended: Bool,
                              hasSimilar: Bool,
                              hasReviews: Bool,
                              hasVideos: Bool,
                              isRunningUISmokeTests: Bool) -> [MovieDetailLoadSlice] {
        guard !isRunningUISmokeTests else {
            return []
        }

        var slices: [MovieDetailLoadSlice] = []
        if !hasMovieDetail {
            slices.append(.detail)
        }
        if !hasMovieCredits {
            slices.append(.credits)
        }
        if !hasRecommended {
            slices.append(.recommended)
        }
        if !hasSimilar {
            slices.append(.similar)
        }
        if !hasReviews {
            slices.append(.reviews)
        }
        if !hasVideos {
            slices.append(.videos)
        }
        return slices
    }
}

enum MovieDetailState {
    static func movie(movieId: Int, from state: AppState) -> Movie? {
        state.moviesState.movies[movieId]
    }

    static func hasLoadedDetail(movieId: Int, from state: AppState) -> Bool {
        guard state.moviesState.detailed.contains(movieId),
              let movie = movie(movieId: movieId, from: state) else {
            return false
        }

        return movie.keywords != nil && movie.images != nil
    }

    static func hasLoadedRecommended(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.recommendedLoaded.contains(movieId) &&
            state.moviesState.recommended[movieId] != nil
    }

    static func hasLoadedSimilar(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.similarLoaded.contains(movieId) &&
            state.moviesState.similar[movieId] != nil
    }

    static func hasLoadedReviews(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.reviewsLoaded.contains(movieId) &&
            state.moviesState.reviews[movieId] != nil
    }

    static func hasLoadedVideos(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.videosLoaded.contains(movieId) &&
            state.moviesState.videos[movieId] != nil
    }
}

enum MovieDetailListState {
    static func isInWishlist(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.wishlist.contains(movieId)
    }

    static func isInSeenlist(movieId: Int, from state: AppState) -> Bool {
        state.moviesState.seenlist.contains(movieId)
    }

    static func customLists(from state: AppState) -> [CustomList] {
        state.moviesState.customLists.compactMap { $0.value }
    }
}

enum MovieDetailPeopleState {
    static func characters(movieId: Int, from state: AppState) -> [People]? {
        contextualPeople(movieId: movieId,
                         from: state,
                         peopleIds: state.peoplesState.movieCastOrder[movieId],
                         metadata: state.peoplesState.casts) { people, role in
            var contextual = people
            contextual.character = role
            contextual.department = nil
            return contextual
        }
    }

    static func credits(movieId: Int, from state: AppState) -> [People]? {
        contextualPeople(movieId: movieId,
                         from: state,
                         peopleIds: state.peoplesState.movieCrewOrder[movieId],
                         metadata: state.peoplesState.crews) { people, department in
            var contextual = people
            contextual.character = nil
            contextual.department = department
            return contextual
        }
    }

    static func hasLoadedMovieCredits(movieId: Int, from state: AppState) -> Bool {
        guard state.peoplesState.movieCreditsLoaded.contains(movieId),
              state.peoplesState.movieCastOrder[movieId] != nil,
              state.peoplesState.movieCrewOrder[movieId] != nil else {
            return false
        }

        let hasResolvedPeople = characters(movieId: movieId, from: state)?.isEmpty == false ||
            credits(movieId: movieId, from: state)?.isEmpty == false
        let hasExplicitlyEmptyCredits = state.peoplesState.movieCastOrder[movieId]?.isEmpty == true &&
            state.peoplesState.movieCrewOrder[movieId]?.isEmpty == true

        return hasResolvedPeople || hasExplicitlyEmptyCredits
    }

    private static func contextualPeople(movieId: Int,
                                         from state: AppState,
                                         peopleIds: [Int]?,
                                         metadata: [Int: [Int: String]],
                                         transform: (People, String) -> People) -> [People]? {
        let resolvedPeopleIds = peopleIds ?? state.peoplesState.peoplesMovies[movieId]?.sorted()
        guard let resolvedPeopleIds = resolvedPeopleIds, !resolvedPeopleIds.isEmpty else {
            return nil
        }

        let contextual = resolvedPeopleIds.compactMap { peopleId -> People? in
            guard let people = state.peoplesState.peoples[peopleId],
                  let role = metadata[peopleId]?[movieId],
                  !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return transform(people, role)
        }

        return contextual.isEmpty ? nil : contextual
    }
}

// `nonisolated`: a pure focus-identity value type used as a `@FocusState`
// value, whose Hashable conformance is consumed by nonisolated SwiftUI
// internals — it must not inherit the app target's default main-actor
// isolation.
nonisolated enum MovieDetailFocusTarget: Hashable {
    case genre(Int)
    case wishlistButton
    case seenlistButton
    case customListButton
    case reviewLink
    case topPerson(Int)
    case readMoreButton
    case keyword(Int)
    case castPerson(Int)
    case castSeeAll
    case crewPerson(Int)
    case crewSeeAll
    case similarMovie(Int)
    case similarSeeAll
    case recommendedMovie(Int)
    case recommendedSeeAll
    case poster(String)
    case backdrop(String)
}

#if os(macOS)
/// Adds standard macOS keyboard shortcuts to pop a pushed NavigationStack
/// destination: Cmd+[ (native "back" shortcut that matches Safari/Finder)
/// and Escape.
private struct MacBackKeyboardShortcut: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .onExitCommand { dismiss() }
            .background {
                Button(action: { dismiss() }) {
                    EmptyView()
                }
                .keyboardShortcut("[", modifiers: .command)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            }
    }
}

extension View {
    /// On macOS, enables Cmd+[ and Escape to pop the current pushed
    /// NavigationStack destination. No-op on other platforms.
    func macBackKeyboardShortcut() -> some View {
        modifier(MacBackKeyboardShortcut())
    }
}
#else
extension View {
    func macBackKeyboardShortcut() -> some View { self }
}
#endif

private struct TrackedDetailRowModifier: ViewModifier {
    let id: String
    @Binding var visibleRowIds: Set<String>

    func body(content: Content) -> some View {
        content
            .id(id)
            .onScrollVisibilityChange(threshold: 0.5) { visible in
                if visible {
                    visibleRowIds.insert(id)
                } else {
                    visibleRowIds.remove(id)
                }
            }
    }
}

extension View {
    /// Tags a detail-view row with a stable scroll-anchor id and tracks
    /// whether it's at least 50% on-screen, feeding visibility into
    /// `visibleRowIds` so Tab navigation can skip scrolling when the
    /// focused row is already visible.
    func trackedDetailRow(_ id: String, visibleRowIds: Binding<Set<String>>) -> some View {
        modifier(TrackedDetailRowModifier(id: id, visibleRowIds: visibleRowIds))
    }
}

/// Maps a focus target to the scroll-anchor id of the row it lives in.
/// Used by the outer ScrollViewReader to scroll the focused row into
/// view when Tab / Shift+Tab jumps to an off-screen section.
enum MovieDetailFocusRow {
    static func scrollId(for target: MovieDetailFocusTarget) -> String {
        switch target {
        case .genre:                                return "row.cover"
        case .wishlistButton,
             .seenlistButton,
             .customListButton:                     return "row.buttons"
        case .reviewLink:                           return "row.review"
        case .topPerson:                            return "row.director"
        case .readMoreButton:                       return "row.overview"
        case .keyword:                              return "row.keywords"
        case .castPerson, .castSeeAll:              return "row.cast"
        case .crewPerson, .crewSeeAll:              return "row.crew"
        case .similarMovie, .similarSeeAll:         return "row.similar"
        case .recommendedMovie, .recommendedSeeAll: return "row.recommended"
        case .poster:                               return "row.posters"
        case .backdrop:                             return "row.backdrops"
        }
    }
}

/// Pure navigation decisions for the detail view's Tab / arrow focus.
/// Groups are passed in so tests can exercise the logic without a view.
enum MovieDetailFocusNavigation {
    /// Tab / Shift+Tab — jump to the first item of the next/previous group.
    /// When current is nil, returns the first (or last) group's first item.
    /// Returns nil if at the edge.
    static func nextGroupStart(from current: MovieDetailFocusTarget?,
                               in groups: [[MovieDetailFocusTarget]],
                               forward: Bool) -> MovieDetailFocusTarget? {
        guard !groups.isEmpty else { return nil }
        guard let current else {
            return forward ? groups.first?.first : groups.last?.first
        }
        guard let currentGroup = groups.firstIndex(where: { $0.contains(current) }) else {
            return forward ? groups.first?.first : groups.last?.first
        }
        let nextGroup = currentGroup + (forward ? 1 : -1)
        guard groups.indices.contains(nextGroup) else { return nil }
        return groups[nextGroup].first
    }

    /// Left / Right arrow — move within the current group only. Returns nil
    /// at the edge so the caller can leave focus alone.
    static func adjacentInGroup(from current: MovieDetailFocusTarget,
                                in groups: [[MovieDetailFocusTarget]],
                                forward: Bool) -> MovieDetailFocusTarget? {
        guard let group = groups.first(where: { $0.contains(current) }),
              let idx = group.firstIndex(of: current) else {
            return nil
        }
        let nextIdx = idx + (forward ? 1 : -1)
        guard group.indices.contains(nextIdx) else { return nil }
        return group[nextIdx]
    }
}

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
            recommended = recommendedIds.compactMap{ state.moviesState.movies[$0] }
        }
        if let simillarIds = state.moviesState.similar[movieId] {
            similar = simillarIds.compactMap{ state.moviesState.movies[$0] }
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
    private func genreTargets(props: Props) -> [MovieDetailFocusTarget] {
        (props.movie?.genres ?? []).map { .genre($0.id) }
    }

    private var actionTargets: [MovieDetailFocusTarget] {
        [.wishlistButton, .seenlistButton, .customListButton]
    }

    private func reviewTarget(props: Props) -> MovieDetailFocusTarget? {
        guard props.reviewsCount ?? 0 > 0 else {
            return nil
        }
        return .reviewLink
    }

    private func topPersonTarget(props: Props) -> MovieDetailFocusTarget? {
        primaryPeopleCredit(props: props).map { .topPerson($0.id) }
    }

    private func supplementalTargets(props: Props) -> [MovieDetailFocusTarget] {
        [reviewTarget(props: props), topPersonTarget(props: props)].compactMap { $0 }
    }

    private func readMoreTarget(props: Props) -> MovieDetailFocusTarget? {
        guard let movie = props.movie, !movie.overview.isEmpty else {
            return nil
        }
        return .readMoreButton
    }

    private func keywordTargets(props: Props) -> [MovieDetailFocusTarget] {
        (props.movie?.keywords?.keywords ?? []).map { .keyword($0.id) }
    }

    private func castTargets(props: Props) -> [MovieDetailFocusTarget] {
        guard let characters = props.characters, !characters.isEmpty else {
            return []
        }
        var targets: [MovieDetailFocusTarget] = characters.map { .castPerson($0.id) }
        targets.append(.castSeeAll)
        return targets
    }

    private func crewTargets(props: Props) -> [MovieDetailFocusTarget] {
        guard let credits = props.credits, !credits.isEmpty else {
            return []
        }
        var targets: [MovieDetailFocusTarget] = credits.map { .crewPerson($0.id) }
        targets.append(.crewSeeAll)
        return targets
    }

    private func similarTargets(props: Props) -> [MovieDetailFocusTarget] {
        guard let similar = props.similar, !similar.isEmpty else {
            return []
        }
        var targets: [MovieDetailFocusTarget] = similar.map { .similarMovie($0.id) }
        targets.append(.similarSeeAll)
        return targets
    }

    private func recommendedTargets(props: Props) -> [MovieDetailFocusTarget] {
        guard let recommended = props.recommended, !recommended.isEmpty else {
            return []
        }
        var targets: [MovieDetailFocusTarget] = recommended.map { .recommendedMovie($0.id) }
        targets.append(.recommendedSeeAll)
        return targets
    }

    private func posterTargets(props: Props) -> [MovieDetailFocusTarget] {
        let posters = props.movie?.images?.posters ?? []
        guard !posters.isEmpty else { return [] }
        return posters.map { .poster($0.file_path) }
    }

    private func backdropTargets(props: Props) -> [MovieDetailFocusTarget] {
        let backdrops = props.movie?.images?.backdrops ?? []
        guard !backdrops.isEmpty else { return [] }
        return backdrops.map { .backdrop($0.file_path) }
    }


    /// Groups of focus targets, in Tab order. Each group is a horizontal row
    /// of related items (genres, action buttons, keywords, cast, crew etc).
    /// Tab / Shift+Tab moves between groups; Left/Right arrows move within.
    private func focusGroups(props: Props) -> [[MovieDetailFocusTarget]] {
        var groups: [[MovieDetailFocusTarget]] = []
        let genres = genreTargets(props: props)
        if !genres.isEmpty { groups.append(genres) }
        groups.append(actionTargets)
        if let review = reviewTarget(props: props) { groups.append([review]) }
        if let person = topPersonTarget(props: props) { groups.append([person]) }
        if let readMore = readMoreTarget(props: props) { groups.append([readMore]) }
        let keywords = keywordTargets(props: props)
        if !keywords.isEmpty { groups.append(keywords) }
        let cast = castTargets(props: props)
        if !cast.isEmpty { groups.append(cast) }
        let crew = crewTargets(props: props)
        if !crew.isEmpty { groups.append(crew) }
        let similar = similarTargets(props: props)
        if !similar.isEmpty { groups.append(similar) }
        let recommended = recommendedTargets(props: props)
        if !recommended.isEmpty { groups.append(recommended) }
        let posters = posterTargets(props: props)
        if !posters.isEmpty { groups.append(posters) }
        let backdrops = backdropTargets(props: props)
        if !backdrops.isEmpty { groups.append(backdrops) }
        return groups
    }

    private func availableTopTargets(props: Props) -> [MovieDetailFocusTarget] {
        focusGroups(props: props).flatMap { $0 }
    }

    private func preferredFocusTarget(props: Props) -> MovieDetailFocusTarget? {
        genreTargets(props: props).first ?? actionTargets.first
    }

    private func restoreDetailFocus(props: Props, force: Bool = false) {
        guard selectedPoster == nil else {
            return
        }

        let availableTargets = availableTopTargets(props: props)
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
            focusedDetailItem = preferredFocusTarget(props: props)
        } else if let focused = focusedDetailItem {
            if !availableTargets.contains(focused) {
                focusedDetailItem = preferredFocusTarget(props: props)
            }
        } else {
            focusedDetailItem = preferredFocusTarget(props: props)
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
            if people != nil {
                let accessibilityId = "movieDetail.topPerson.\(people!.id)"
                #if os(macOS)
                MacFocusableLink(id: .topPerson(people!.id), focusedId: $focusedDetailItem) {
                    selectPeople(people!.id)
                } label: {
                    HStack(alignment: .center, spacing: 0) {
                        Text(role + ": ").font(.callout)
                        Text(people!.name).font(.body).foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(role): \(people!.name)")
                    .accessibilityIdentifier(accessibilityId)
                }
                #else
                Button(action: {
                    selectPeople(people!.id)
                }) {
                    HStack(alignment: .center, spacing: 0) {
                        Text(role + ": ").font(.callout)
                        Text(people!.name).font(.body).foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    .padding(.trailing, 10)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(role): \(people!.name)")
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
            .accessibilityIdentifier("movieDetail.topPersonShortcut")
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
        let groups = focusGroups(props: props)
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
        let groups = focusGroups(props: props)
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
            .accessibilityIdentifier("movieDetail.addToListButton")
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
        .accessibilityIdentifier("movieDetail.addToListButton")
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

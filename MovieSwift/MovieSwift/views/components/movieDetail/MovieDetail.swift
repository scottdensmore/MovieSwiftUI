//
//  MovieDetail.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Combine
import UI

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

#if os(macOS)
enum MovieDetailFocusTarget: Hashable {
    case genre(Int)
    case wishlistButton
    case seenlistButton
    case customListButton
    case reviewLink
    case topPerson(Int)
}
#endif

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
    @State private var selectedPeopleId: Int?
    @State private var selectedReviewMovieId: Int?
    @State private var selectedCrosslineRoute: MoviesListNavigationRoute?
    @State private var selectedGenre: Genre?
    @State private var selectedKeyword: Keyword?
    @State private var isCrosslineMoviesListPresented = false
    @State private var crosslineMoviesListTitle = ""
    @State private var crosslineMoviesListMovieIds: [Int] = []
    @State private var isPeopleListPresented = false
    @State private var peopleListTitle = ""
    @State private var peopleListEntries: [People] = []

    #if os(macOS)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedDetailItem: MovieDetailFocusTarget?
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
        crosslineMoviesListTitle = title
        crosslineMoviesListMovieIds = MovieCrosslineState.movieIds(from: movies)
        isCrosslineMoviesListPresented = true
    }

    private func presentPeopleList(title: String, peoples: [People]) {
        peopleListTitle = title
        peopleListEntries = peoples
        isPeopleListPresented = true
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

    private func availableTopTargets(props: Props) -> [MovieDetailFocusTarget] {
        genreTargets(props: props) + actionTargets + supplementalTargets(props: props)
    }

    private func preferredFocusTarget(props: Props) -> MovieDetailFocusTarget? {
        genreTargets(props: props).first ?? actionTargets.first
    }

    private func adjacentFocusTarget(in targets: [MovieDetailFocusTarget], offset: Int) -> MovieDetailFocusTarget? {
        guard let focusedDetailItem,
              let index = targets.firstIndex(of: focusedDetailItem) else {
            return nil
        }

        let nextIndex = index + offset
        guard targets.indices.contains(nextIndex) else {
            return nil
        }

        return targets[nextIndex]
    }

    private func topFocusLeftTarget(props: Props) -> MovieDetailFocusTarget? {
        let genres = genreTargets(props: props)
        let supplemental = supplementalTargets(props: props)

        return adjacentFocusTarget(in: genres, offset: -1) ??
            adjacentFocusTarget(in: actionTargets, offset: -1) ??
            adjacentFocusTarget(in: supplemental, offset: -1)
    }

    private func topFocusRightTarget(props: Props) -> MovieDetailFocusTarget? {
        let genres = genreTargets(props: props)
        let supplemental = supplementalTargets(props: props)

        return adjacentFocusTarget(in: genres, offset: 1) ??
            adjacentFocusTarget(in: actionTargets, offset: 1) ??
            adjacentFocusTarget(in: supplemental, offset: 1)
    }

    private func topFocusUpTarget(props: Props) -> MovieDetailFocusTarget? {
        guard let focusedDetailItem else {
            return nil
        }

        if actionTargets.contains(focusedDetailItem),
           let firstGenre = genreTargets(props: props).first {
            return firstGenre
        }

        if supplementalTargets(props: props).contains(focusedDetailItem),
           let firstAction = actionTargets.first {
            return firstAction
        }

        return nil
    }

    private func topFocusDownTarget(props: Props) -> MovieDetailFocusTarget? {
        guard let focusedDetailItem else {
            return nil
        }

        if genreTargets(props: props).contains(focusedDetailItem),
           let firstAction = actionTargets.first {
            return firstAction
        }

        if actionTargets.contains(focusedDetailItem),
           let firstSupplemental = supplementalTargets(props: props).first {
            return firstSupplemental
        }

        return nil
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

        if force || focusedDetailItem == nil || !availableTargets.contains(focusedDetailItem!) {
            focusedDetailItem = preferredFocusTarget(props: props)
        }
    }
    #endif

    private var crosslineMoviesListView: some View {
        MoviesList(movies: crosslineMoviesListMovieIds,
                   displaySearch: false,
                   pageListener: nil,
                   navigationRoute: $selectedCrosslineRoute)
            .navigationTitle(crosslineMoviesListTitle)
    }

    private var peopleListView: some View {
        List(peopleListEntries) { people in
            PeopleListItem(people: people) {
                selectedPeopleId = people.id
            }
        }
        .navigationTitle(peopleListTitle)
    }
    
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
                        Text(people!.name).font(.body).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
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
                        Text(people!.name).font(.body).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
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
        MovieButtonsRow(movieId: movieId,
                        showCustomListSheet: $isAddSheetPresented,
                        focusedItem: $focusedDetailItem)
        #else
        MovieCoverRow(movieId: movieId)
        MovieButtonsRow(movieId: movieId, showCustomListSheet: $isAddSheetPresented)
        #endif
        smokeTestTopPersonShortcut(props: props)
        if props.reviewsCount ?? 0 > 0 {
            #if os(macOS)
            MacFocusableLink(id: .reviewLink, focusedId: $focusedDetailItem) {
                selectedReviewMovieId = movieId
            } label: {
                Text("\(props.reviewsCount!) reviews")
                    .foregroundColor(.steam_blue)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            #else
            Button(action: {
                selectedReviewMovieId = movieId
            }) {
                Text("\(props.reviewsCount!) reviews")
                    .foregroundColor(.steam_blue)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            #endif
        }
        if props.credits?.isEmpty == false {
            peopleRows(props: props)
        }
        if let movie = props.movie, !movie.overview.isEmpty {
            MovieOverview(movie: movie)
        }
    }
    
    @ViewBuilder
    func bottomContent(props: Props) -> some View {
        if let movie = props.movie,
           movie.keywords?.keywords?.isEmpty == false,
           let keywords = movie.keywords?.keywords {
            #if os(macOS)
            MovieKeywords(keywords: keywords) { keyword in
                selectedKeyword = keyword
            }
            #else
            MovieKeywords(keywords: keywords)
            #endif
        }
        if props.characters?.isEmpty == false {
            MovieCrosslinePeopleRow(title: "Cast",
                                    peoples: props.characters ?? [],
                                    onSelectPeople: selectPeople,
                                    onSelectSeeAll: {
                                        presentPeopleList(title: "Cast",
                                                          peoples: props.characters ?? [])
                                    })
        }
        if props.credits?.isEmpty == false {
            MovieCrosslinePeopleRow(title: "Crew",
                                    peoples: props.credits ?? [],
                                    onSelectPeople: selectPeople,
                                    onSelectSeeAll: {
                                        presentPeopleList(title: "Crew",
                                                          peoples: props.credits ?? [])
                                    })
        }
        if props.similar?.isEmpty == false {
            MovieCrosslineRow(title: "Similar Movies",
                              movies: props.similar ?? [],
                              onSelectMovie: { selectedCrosslineRoute = .movie($0) },
                              onSelectSeeAll: {
                                  presentCrosslineMoviesList(title: "Similar Movies",
                                                             movies: props.similar ?? [])
                              })
        }
        if  props.recommended?.isEmpty == false {
            MovieCrosslineRow(title: "Recommended Movies",
                              movies: props.recommended ?? [],
                              onSelectMovie: { selectedCrosslineRoute = .movie($0) },
                              onSelectSeeAll: {
                                  presentCrosslineMoviesList(title: "Recommended Movies",
                                                             movies: props.recommended ?? [])
                              })
        }
        if let movie = props.movie,
           movie.images?.posters?.isEmpty == false,
           let posters = movie.images?.posters {
            MoviePostersRow(posters: posters.prefix(8).map{ $0 },
                            selectedPoster: $selectedPoster)
        }
        if let movie = props.movie,
           movie.images?.backdrops?.isEmpty == false,
           let backdrops = movie.images?.backdrops {
            MovieBackdropsRow(backdrops: backdrops.prefix(8).map{ $0 })
        }
    }

    @ViewBuilder
    func detailContent(props: Props) -> some View {
        #if os(macOS)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                topContent(props: props)
                bottomContent(props: props)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 24)
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

    @ViewBuilder
    func unavailableView() -> some View {
        VStack(spacing: 12) {
            Text("Movie not available")
                .font(.headline)
            Text("This movie could not be loaded.")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
        let posters = props.movie?.images?.posters ?? []

        return ZStack(alignment: .bottom) {
            Group {
                if let movie = props.movie {
                    detailContent(props: props)
                    .navigationTitle(movie.userTitle)
                } else {
                    unavailableView()
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
            .disabled(selectedPoster != nil)
            .blur(radius: selectedPoster != nil ? 30 : 0)
            .scaleEffect(selectedPoster != nil ? 0.8 : 1)
            
            NotificationBadge(text: "Added successfully",
                              color: .blue,
                              show: $isAddedToListBadgePresented).padding(.bottom, 10)
            ImagesCarouselView(posters: props.movie?.images?.posters ?? [],
                                   selectedPoster: $selectedPoster)
                .blur(radius: selectedPoster != nil ? 0 : 10)
                .scaleEffect(selectedPoster != nil ? 1 : 1.2)
                .opacity(selectedPoster != nil ? 1 : 0)
        }
        .navigationDestination(item: $selectedPeopleId) { id in
            PeopleDetail(peopleId: id)
        }
        .navigationDestination(item: $selectedReviewMovieId) { id in
            MovieReviews(movie: id)
        }
        .navigationDestination(item: $selectedGenre) { genre in
            MoviesGenreList(genre: genre)
        }
        .navigationDestination(item: $selectedKeyword) { keyword in
            MovieKeywordList(keyword: keyword)
        }
        .navigationDestination(isPresented: $isPeopleListPresented) {
            peopleListView
        }
        .navigationDestination(isPresented: $isCrosslineMoviesListPresented) {
            crosslineMoviesListView
        }
        .navigationDestination(item: $selectedCrosslineRoute) { route in
            moviesListDestinationView(for: route)
        }
        #if os(macOS)
        .onAppear {
            restoreDetailFocus(props: props, force: true)
        }
        .onChange(of: selectedPoster?.id) { _, newValue in
            if newValue == nil {
                restoreDetailFocus(props: props, force: true)
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

// MARK: - Preview
#Preview {
    NavigationStack {
        MovieDetail(movieId: sampleMovie.id).environmentObject(sampleStore)
    }
}

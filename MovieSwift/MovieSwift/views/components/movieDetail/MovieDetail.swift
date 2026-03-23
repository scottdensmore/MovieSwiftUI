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

    #if targetEnvironment(macCatalyst)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedDetailItem: Int?
    private let reviewsSentinel = -998
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

    private var crosslineMoviesListView: some View {
        MoviesList(movies: crosslineMoviesListMovieIds,
                   displaySearch: false,
                   pageListener: nil,
                   navigationRoute: $selectedCrosslineRoute)
            .navigationBarTitle(crosslineMoviesListTitle)
    }

    private var peopleListView: some View {
        List(peopleListEntries) { people in
            PeopleListItem(people: people) {
                selectedPeopleId = people.id
            }
        }
        .navigationBarTitle(peopleListTitle)
    }
    
    // MARK: - Computed views
    func addActionSheet(props: Props) -> ActionSheet {
        let movieTitle = props.movie?.userTitle ?? "this movie"
        var buttons: [Alert.Button] = []
        let wishlistButton = ActionSheet.wishlistButton(isInWishlist: props.isInWishlist,
                                                        movie: movieId,
                                                        dispatch: props.dispatch) {
            self.displaySavedBadge()
        }
        let seenButton = ActionSheet.seenListButton(isInSeenlist: props.isInSeenlist,
                                                    movie: movieId,
                                                    dispatch: props.dispatch) {
            self.displaySavedBadge()
        }
        let customListButtons = ActionSheet.customListsButttons(customLists: props.customLists,
                                                                movie: movieId,
                                                                dispatch: props.dispatch) {
            self.displaySavedBadge()
        }
        let createListButton: Alert.Button = .default(Text("Create list")) {
            self.isCreateListFormPresented = true
        }
        let cancelButton = Alert.Button.cancel {
            
        }
        buttons.append(wishlistButton)
        buttons.append(seenButton)
        buttons.append(contentsOf: customListButtons)
        buttons.append(createListButton)
        buttons.append(cancelButton)
        let sheet = ActionSheet(title: Text("Add or remove \(movieTitle) from your lists"),
                                message: nil,
                                buttons: buttons)
        return sheet
    }
    
    // MARK: - Body
    
    func peopleRow(role: String, people: People?) -> some View {
        Group {
            if people != nil {
                let accessibilityId = "movieDetail.topPerson.\(people!.id)"
                #if targetEnvironment(macCatalyst)
                CatalystFocusableLink(id: people!.id, focusedId: $focusedDetailItem) {
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

    func topSection(props: Props) -> some View {
        Section {
            #if targetEnvironment(macCatalyst)
            MovieCoverRow(movieId: movieId) { genre in
                selectedGenre = genre
            }
            #else
            MovieCoverRow(movieId: movieId)
            #endif
            MovieButtonsRow(movieId: movieId, showCustomListSheet: $isAddSheetPresented)
            smokeTestTopPersonShortcut(props: props)
            if props.reviewsCount ?? 0 > 0 {
                #if targetEnvironment(macCatalyst)
                CatalystFocusableLink(id: reviewsSentinel, focusedId: $focusedDetailItem) {
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
    }
    
    func bottomSection(props: Props) -> some View {
        Section {
            if let movie = props.movie,
               movie.keywords?.keywords?.isEmpty == false,
               let keywords = movie.keywords?.keywords {
                #if targetEnvironment(macCatalyst)
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
            Button(action: onAddButton) {
                Image(systemName: "text.badge.plus").imageScale(.large)
            }
            .accessibilityIdentifier("movieDetail.addToListButton")
        }
    }
    
    func body(props: Props) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                if let movie = props.movie {
                    List {
                        topSection(props: props)
                        bottomSection(props: props)
                    }
                    .navigationBarTitle(Text(movie.userTitle), displayMode: .large)
                } else {
                    unavailableView()
                        .navigationBarTitle(Text("Movie"), displayMode: .large)
                }
            }
            .navigationBarItems(trailing: addButton(props: props))
            .onAppear {
                self.fetchMovieDetails(props: props)
            }
            .actionSheet(isPresented: $isAddSheetPresented, content: { addActionSheet(props: props) })
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
        #if targetEnvironment(macCatalyst)
        .onKeyPress(.escape) { dismiss(); return .handled }
        #endif
    }
    
    
}

// MARK: - Preview
#if DEBUG
struct MovieDetail_Previews : PreviewProvider {
    static var previews: some View {
        NavigationView {
            MovieDetail(movieId: sampleMovie.id).environmentObject(sampleStore)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
#endif

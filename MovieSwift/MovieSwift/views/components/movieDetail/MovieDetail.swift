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

enum MovieDetailFetchPolicy {
    static func shouldFetchLiveData(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
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

struct MovieDetail: ConnectedView {
    struct Props {
        let movie: Movie
        let characters: [People]?
        let credits: [People]?
        let recommended: [Movie]?
        let similar: [Movie]?
        let reviewsCount: Int?
        let videos: [Video]?
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

    #if targetEnvironment(macCatalyst)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedDetailItem: Int?
    private let reviewsSentinel = -998
    #endif
        
    // MARK: Computed Props
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        var characters: [People]?
        var credits: [People]?
        var recommended: [Movie]?
        var similar: [Movie]?
        
        if let peopleIds = state.peoplesState.peoplesMovies[movieId]?.sorted() {
            let peoples = peopleIds.compactMap{ state.peoplesState.peoples[$0] }
            characters = peoples.filter{ $0.character != nil}
            credits = peoples.filter{ $0.department != nil }
            if let recommendedIds = state.moviesState.recommended[movieId] {
                recommended = recommendedIds.compactMap{ state.moviesState.movies[$0] }
            }
            if let simillarIds = state.moviesState.similar[movieId] {
                similar = simillarIds.compactMap{ state.moviesState.movies[$0] }
            }
        }
        return Props(movie: state.moviesState.movies[movieId]!,
                     characters: characters,
                     credits: credits,
                     recommended: recommended,
                     similar: similar,
                     reviewsCount: state.moviesState.reviews[movieId]?.count ?? nil,
                     videos: state.moviesState.videos[movieId],
                     isInWishlist: MovieDetailListState.isInWishlist(movieId: movieId, from: state),
                     isInSeenlist: MovieDetailListState.isInSeenlist(movieId: movieId, from: state),
                     customLists: MovieDetailListState.customLists(from: state),
                     dispatch: dispatch)
    }
    
    // MARK: - Fetch
    func fetchMovieDetails(props: Props) {
        if !MovieDetailFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: isRunningUISmokeTests) {
            return
        }
        props.dispatch(MoviesActions.FetchDetail(movie: movieId))
        props.dispatch(PeopleActions.FetchMovieCasts(movie: movieId))
        props.dispatch(MoviesActions.FetchRecommended(movie: movieId))
        props.dispatch(MoviesActions.FetchSimilar(movie: movieId))
        props.dispatch(MoviesActions.FetchMovieReviews(movie: movieId))
        props.dispatch(MoviesActions.FetchVideos(movie: movieId))
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
    
    // MARK: - Computed views
    func addActionSheet(props: Props) -> ActionSheet {
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
        let sheet = ActionSheet(title: Text("Add or remove \(props.movie.userTitle) from your lists"),
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
            MovieCoverRow(movieId: movieId)
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
            if !props.movie.overview.isEmpty {
                MovieOverview(movie: props.movie)
            }
        }
    }
    
    func bottomSection(props: Props) -> some View {
        Section {
            if props.movie.keywords?.keywords?.isEmpty == false {
                MovieKeywords(keywords: props.movie.keywords!.keywords!)
            }
            if props.characters?.isEmpty == false {
                MovieCrosslinePeopleRow(title: "Cast",
                                        peoples: props.characters ?? [])
            }
            if props.credits?.isEmpty == false {
                MovieCrosslinePeopleRow(title: "Crew",
                                        peoples: props.credits ?? [])
            }
            if props.similar?.isEmpty == false {
                MovieCrosslineRow(title: "Similar Movies",
                                  movies: props.similar ?? [],
                                  navigationRoute: $selectedCrosslineRoute)
            }
            if  props.recommended?.isEmpty == false {
                MovieCrosslineRow(title: "Recommended Movies",
                                  movies: props.recommended ?? [],
                                  navigationRoute: $selectedCrosslineRoute)
            }
            if props.movie.images?.posters?.isEmpty == false {
                MoviePostersRow(posters: props.movie.images!.posters!.prefix(8).map{ $0 },
                                selectedPoster: $selectedPoster)
            }
            if props.movie.images?.backdrops?.isEmpty == false {
                MovieBackdropsRow(backdrops: props.movie.images!.backdrops!.prefix(8).map{ $0 })
            }
        }
    }
    
    func body(props: Props) -> some View {
        ZStack(alignment: .bottom) {
            List {
                topSection(props: props)
                bottomSection(props: props)
            }
            .navigationBarTitle(Text(props.movie.userTitle), displayMode: .large)
            .navigationBarItems(trailing: Button(action: onAddButton) {
                Image(systemName: "text.badge.plus").imageScale(.large)
            }
            .accessibilityIdentifier("movieDetail.addToListButton"))
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
            ImagesCarouselView(posters: props.movie.images?.posters ?? [],
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

//
//  PeopleDetail.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import UI

enum PeopleDetailFetchPolicy {
    static func shouldFetchLiveData(isRunningUISmokeTests: Bool) -> Bool {
        !isRunningUISmokeTests
    }
}

enum PeopleDetailState {
    static func people(for peopleId: Int, from state: AppState) -> People {
        state.peoplesState.peoples[peopleId] ?? People(id: peopleId,
                                                       name: "Unknown person",
                                                       character: nil,
                                                       department: nil,
                                                       profile_path: nil,
                                                       known_for_department: nil,
                                                       known_for: nil,
                                                       also_known_as: nil,
                                                       birthDay: nil,
                                                       deathDay: nil,
                                                       place_of_birth: nil,
                                                       biography: nil,
                                                       popularity: nil,
                                                       images: nil)
    }

    static func shouldShowBiographySection(for people: People) -> Bool {
        let biography = people.biography?.trimmingCharacters(in: .whitespacesAndNewlines)
        return biography?.isEmpty == false ||
            people.birthDay != nil ||
            people.place_of_birth != nil ||
            people.deathDay != nil
    }

    static func shouldShowImagesSection(for images: [ImageData]?) -> Bool {
        guard let images else {
            return false
        }
        return !images.isEmpty
    }

    static func sortedYears(from movieByYears: [String: [PeopleDetail.MovieRole]]) -> [String] {
        movieByYears.compactMap { $0.key }.sorted(by: { lhs, rhs in
            switch (lhs, rhs) {
            case ("Upcoming", "Upcoming"):
                return false
            case ("Upcoming", _):
                return false
            case (_, "Upcoming"):
                return true
            default:
                return lhs > rhs
            }
        })
    }
}

enum PeopleDetailMovieGrouping {
    static func group(credits: [Int: String], movies: [Int: Movie]) -> [String: [PeopleDetail.MovieRole]] {
        var years: [String: [PeopleDetail.MovieRole]] = [:]
        for (_, value) in credits.enumerated() {
            if let movie = movies[value.key] {
                if movie.release_date != nil && movie.release_date?.isEmpty == false {
                    let year = String(movie.release_date!.prefix(4))
                    if years[year] == nil {
                        years[year] = []
                    }
                    years[year]?.append(PeopleDetail.MovieRole(movie: movie, role: value.value))
                } else {
                    if years["Upcoming"] == nil {
                        years["Upcoming"] = []
                    }
                    years["Upcoming"]?.append(PeopleDetail.MovieRole(movie: movie, role: value.value))
                }
            }
        }
        for value in years {
            years[value.key] = value.value.sorted(by: { $0.movie.id > $1.movie.id })
        }
        return years
    }
}

struct PeopleDetail: ConnectedView {
    // MARK: - Props
    struct Props {
        let dispatch: DispatchFunction
        let people: People
        let movieByYears: [String: [MovieRole]]
        let isInFanClub: Binding<Bool>
        let movieScore: Int?
    }
    
    struct MovieRole: Identifiable {
        var id: Int { movie.id }
        let movie: Movie
        let role: String
    }
    
    let peopleId: Int

    @State var selectedPoster: ImageData?
    @State var isFanScoreUpdated = false
    @State private var selectedMovieId: Int?
    @Environment(\.isRunningUISmokeTests) private var isRunningUISmokeTests

    #if targetEnvironment(macCatalyst)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedMovieId: Int?
    #endif
    
    private func fetchPeopleData(props: Props) {
        if !PeopleDetailFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: isRunningUISmokeTests) {
            return
        }
        props.dispatch(PeopleActions.FetchDetail(people: self.peopleId))
        props.dispatch(PeopleActions.FetchImages(people: self.peopleId))
        props.dispatch(PeopleActions.FetchPeopleCredits(people: self.peopleId))
    }

    private func selectMovie(_ id: Int) {
        selectedMovieId = id
    }

    private func movieAccessibilityIdentifier(_ id: Int) -> String {
        "peopleDetail.movie.\(id)"
    }
    
    //MARK: - Views
    private func toggleScoreUpdate() {
        withAnimation {
            self.isFanScoreUpdated = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    self.isFanScoreUpdated = false
                }
            }
        }
    }
    
    private func moviesSection(props: Props, year: String) -> some View {
        Section(header: Text(year)) {
            ForEach(props.movieByYears[year]!) { meta in
                #if targetEnvironment(macCatalyst)
                CatalystFocusableLink(id: meta.id, focusedId: $focusedMovieId) {
                    selectMovie(meta.id)
                } label: {
                    PeopleDetailMovieRow(movie: meta.movie, role: meta.role, onMovieContextMenu: {
                        if props.isInFanClub.wrappedValue {
                            self.toggleScoreUpdate()
                        }
                    })
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #else
                Button(action: {
                    selectMovie(meta.id)
                }) {
                    PeopleDetailMovieRow(movie: meta.movie, role: meta.role, onMovieContextMenu: {
                        if props.isInFanClub.wrappedValue {
                            self.toggleScoreUpdate()
                        }
                    })
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(movieAccessibilityIdentifier(meta.id))
                #endif
            }
        }
    }
    
    private func barbuttons(props: Props) -> some View {
        Button(action: {
            props.isInFanClub.wrappedValue.toggle()
        }, label: {
            Image(systemName: props.isInFanClub.wrappedValue ? "star.circle.fill" : "star.circle")
                .resizable()
                .foregroundColor(props.isInFanClub.wrappedValue ? .steam_gold : .primary)
                .scaleEffect(props.isInFanClub.wrappedValue ? 1.2 : 1.0)
                .frame(width: 25, height: 25)
                .animation(.spring(), value: props.isInFanClub.wrappedValue)
        })
    }
    
    private func scoreUpdateView(props: Props) -> some View {
        Group {
            if isFanScoreUpdated {
                VStack(spacing: 30) {
                    Text("Fan level updated!")
                        .font(.FjallaOne(size: 30))
                        .foregroundColor(.steam_gold)
                    PopularityBadge(score: props.movieScore ?? 0)
                        .scaleEffect(2.0)
                }
                .transition(.scale)
                .animation(Animation
                    .interpolatingSpring(stiffness: 70, damping: 7)
                .delay(0.3), value: isFanScoreUpdated)
                .onTapGesture {
                    self.isFanScoreUpdated = false
                }
            }
        }
    }
    
    private func imagesCarouselView(props: Props) -> some View {
        ImagesCarouselView(posters: props.people.images ?? [],
                           selectedPoster: $selectedPoster)
            .scaleEffect(selectedPoster != nil ? 1.0 : 1.2)
            .blur(radius: selectedPoster != nil ? 0 : 10)
            .opacity(selectedPoster != nil ? 1 : 0)
            .animation(.spring(), value: selectedPoster != nil)
    }
    
    func body(props: Props) -> some View {
        ZStack(alignment: .center) {
            List {
                Section {
                    PeopleDetailHeaderRow(people: props.people)
                    if PeopleDetailState.shouldShowBiographySection(for: props.people) {
                        PeopleDetailBiographyRow(biography: props.people.biography,
                                                 birthDate: props.people.birthDay,
                                                 deathDate: props.people.deathDay,
                                                 placeOfBirth: props.people.place_of_birth)
                    }
                    if props.isInFanClub.wrappedValue {
                        VStack {
                            Text("Fan level")
                                .titleStyle()
                            PopularityBadge(score: props.movieScore ?? 0)
                        }
                    }
                    if PeopleDetailState.shouldShowImagesSection(for: props.people.images) {
                        PeopleDetailImagesRow(images: props.people.images ?? [], selectedPoster: $selectedPoster)
                    }
                }
                ForEach(sortedYears(props: props), id: \.self, content: { year in
                    self.moviesSection(props: props, year: year)
                })
            }
            .transaction { transaction in
                transaction.animation = nil
            }
            .blur(radius: selectedPoster != nil || isFanScoreUpdated ? 30 : 0)
            .scaleEffect(selectedPoster != nil ? 0.8 : 1)
            .animation(.interactiveSpring(), value: selectedPoster != nil || isFanScoreUpdated)
            imagesCarouselView(props: props)
            scoreUpdateView(props: props)
        }
        .animation(.spring(), value: isFanScoreUpdated)
        .navigationDestination(item: $selectedMovieId) { id in
            MovieDetail(movieId: id)
        }
        #if targetEnvironment(macCatalyst)
        .onKeyPress(.escape) { dismiss(); return .handled }
        #endif
        .navigationBarItems(trailing: barbuttons(props: props))
        .navigationBarTitle(props.people.name)
        .onAppear {
            self.fetchPeopleData(props: props)
        }
        .onChange(of: self.peopleId) { _, _ in
            self.selectedPoster = nil
            self.isFanScoreUpdated = false
            self.fetchPeopleData(props: props)
        }
    }
}

// MARK: - Map state to props
extension PeopleDetail {
    private func sortedYears(props: Props) -> [String] {
        PeopleDetailState.sortedYears(from: props.movieByYears)
    }
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        var credits: [Int: String] = state.peoplesState.crews[peopleId] ?? [:]
        credits.merge(state.peoplesState.casts[peopleId] ?? [:]) { (current, _) in current }
        let years = PeopleDetailMovieGrouping.group(credits: credits, movies: state.moviesState.movies)
        
        let isInFanClub = Binding<Bool>(
            get: { state.peoplesState.fanClub.contains(self.peopleId) },
            set: {
                if !$0 {
                    dispatch(PeopleActions.RemoveFromFanClub(people: self.peopleId))
                } else {
                    dispatch(PeopleActions.AddToFanClub(people: self.peopleId))
                }
        }
        )
        
        var movieScore: Int = 0
        if isInFanClub.wrappedValue {
            let roles = years.map{ $0.value }.flatMap{ $0 }.map{ $0.id }
            let rolesCount = roles.count
            let userMovies = roles.filter { movie -> Bool in
                            state.moviesState.seenlist.contains(movie) ||
                            state.moviesState.wishlist.contains(movie) ||
                                state.moviesState.customLists.contains{ $1.movies.contains(movie) }
                        }
            movieScore = userMovies.count > 0 ? Int((Float(userMovies.count) / Float(rolesCount)) * 100) : 0
        }
        
        return Props(dispatch: dispatch,
                     people: PeopleDetailState.people(for: peopleId, from: state),
                     movieByYears: years,
                     isInFanClub: isInFanClub,
                     movieScore: movieScore)
        
    }
    
}

#if DEBUG
struct PeopleDetail_Previews : PreviewProvider {
    static var previews: some View {
        NavigationView {
            PeopleDetail(peopleId: sampleCasts.first!.id).environmentObject(sampleStore)
        }
    }
}
#endif

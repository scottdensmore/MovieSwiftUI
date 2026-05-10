import SwiftUI
import SwiftUIFlux
import UI
import MovieSwiftFluxCore

enum PeopleDetailFetchPolicy {
    static func shouldFetchDetail(isRunningUISmokeTests: Bool, hasLoadedDetail: Bool) -> Bool {
        !isRunningUISmokeTests && !hasLoadedDetail
    }

    static func shouldFetchImages(isRunningUISmokeTests: Bool, hasLoadedImages: Bool) -> Bool {
        !isRunningUISmokeTests && !hasLoadedImages
    }

    static func shouldFetchCredits(isRunningUISmokeTests: Bool, hasLoadedCredits: Bool) -> Bool {
        !isRunningUISmokeTests && !hasLoadedCredits
    }
}

/// Navigable focus target for the actor detail view. Images live in a
/// horizontal group (left/right arrows), movies live in per-year
/// vertical groups (up/down arrows). Tab walks between groups and
/// lands on the first item.
enum PeopleDetailFocusTarget: Hashable {
    case readMoreButton
    case image(String)
    case movie(year: String, id: Int)
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

enum PeopleDetailCreditsState {
    static func mergedCredits(cast: [Int: String], crew: [Int: String]) -> [Int: String] {
        var merged = crew
        for (movieId, castRole) in cast {
            if let crewRole = merged[movieId] {
                merged[movieId] = mergeRoles(primary: castRole, secondary: crewRole)
            } else {
                merged[movieId] = castRole
            }
        }
        return merged
    }

    private static func mergeRoles(primary: String, secondary: String) -> String {
        let roles = [primary, secondary]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var unique: [String] = []
        for role in roles where !unique.contains(role) {
            unique.append(role)
        }
        return unique.joined(separator: " • ")
    }
}

struct PeopleDetail: ConnectedView {
    // MARK: - Props
    struct Props {
        let dispatch: DispatchFunction
        let people: People
        let movieByYears: [String: [MovieRole]]
        let hasLoadedDetail: Bool
        let hasLoadedImages: Bool
        let hasLoadedCredits: Bool
        let isInFanClub: Binding<Bool>
        let movieScore: Int?
        /// Failure for the top-level FetchDetail. Sub-row failures
        /// (images, credits) degrade gracefully; the detail-level
        /// failure matters most because without it the page is empty.
        let detailFailure: MoviesListLoadFailure?
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

    #if os(macOS)
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedDetailItem: PeopleDetailFocusTarget?
    #endif
    
    private func fetchPeopleData(props: Props) {
        if PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: isRunningUISmokeTests,
                                                     hasLoadedDetail: props.hasLoadedDetail) {
            props.dispatch(PeopleActions.FetchDetail(people: self.peopleId))
        }
        if PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: isRunningUISmokeTests,
                                                     hasLoadedImages: props.hasLoadedImages) {
            props.dispatch(PeopleActions.FetchImages(people: self.peopleId))
        }
        if PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: isRunningUISmokeTests,
                                                      hasLoadedCredits: props.hasLoadedCredits) {
            props.dispatch(PeopleActions.FetchPeopleCredits(people: self.peopleId))
        }
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
    
    @ViewBuilder
    private func moviesSection(props: Props, year: String) -> some View {
        // ForEach iterates sortedYears(from: movieByYears) so every
        // year key is guaranteed to be present in the dict when this
        // function runs — but defending with `?? []` removes a
        // crash class for free if the helper ever drifts.
        let metas = props.movieByYears[year] ?? []
        #if os(macOS)
        VStack(alignment: .leading, spacing: 0) {
            Text(year)
                .titleStyle()
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)
            ForEach(metas) { meta in
                MacFocusableLink(id: PeopleDetailFocusTarget.movie(year: year, id: meta.id),
                                 focusedId: $focusedDetailItem) {
                    selectMovie(meta.id)
                } label: {
                    PeopleDetailMovieRow(movie: meta.movie, role: meta.role, onMovieContextMenu: {
                        if props.isInFanClub.wrappedValue {
                            self.toggleScoreUpdate()
                        }
                    })
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(PeopleDetailFocusTarget.movie(year: year, id: meta.id))
                .accessibilityIdentifier(movieAccessibilityIdentifier(meta.id))
            }
        }
        #else
        Section(header: Text(year)) {
            ForEach(metas) { meta in
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
            }
        }
        #endif
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
                // Bump the tappable area to the 44×44 HIG minimum
                // without changing the visual icon size.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        })
        .accessibilityLabel(props.isInFanClub.wrappedValue
                            ? "Remove from fan club"
                            : "Add to fan club")
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
        platformBody(props: props)
            .animation(.spring(), value: isFanScoreUpdated)
            .navigationDestination(item: $selectedMovieId) { id in
                MovieDetail(movieId: id)
            }
            #if os(macOS)
            .onKeyPress(.escape) {
                // When the image carousel overlay is up, let it handle
                // Escape (it clears selectedPoster to dismiss itself).
                // Only pop PeopleDetail once no overlay is showing.
                if selectedPoster != nil {
                    selectedPoster = nil
                    return .handled
                }
                dismiss()
                return .handled
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    barbuttons(props: props)
                }
            }
            .navigationTitle(props.people.name)
            .onAppear {
                self.fetchPeopleData(props: props)
            }
            .onChange(of: self.peopleId) { _, _ in
                self.selectedPoster = nil
                self.isFanScoreUpdated = false
                self.fetchPeopleData(props: props)
            }
    }

    @ViewBuilder
    private func platformBody(props: Props) -> some View {
        #if os(macOS)
        macOSBody(props: props)
        #else
        ZStack(alignment: .center) {
            List {
                if let failure = props.detailFailure {
                    MoviesListErrorBanner(failure: failure) {
                        props.dispatch(PeopleActions.FetchDetail(people: peopleId))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
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
        #endif
    }

    #if os(macOS)
    private func macOSBody(props: Props) -> some View {
        ZStack(alignment: .center) {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let failure = props.detailFailure {
                            MoviesListErrorBanner(failure: failure) {
                                props.dispatch(PeopleActions.FetchDetail(people: peopleId))
                            }
                        }
                        PeopleDetailHeaderRow(people: props.people)
                        if PeopleDetailState.shouldShowBiographySection(for: props.people) {
                            PeopleDetailBiographyRow(biography: props.people.biography,
                                                     birthDate: props.people.birthDay,
                                                     deathDate: props.people.deathDay,
                                                     placeOfBirth: props.people.place_of_birth,
                                                     focusedItem: $focusedDetailItem)
                        }
                        if props.isInFanClub.wrappedValue {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Fan level")
                                    .titleStyle()
                                PopularityBadge(score: props.movieScore ?? 0)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        if PeopleDetailState.shouldShowImagesSection(for: props.people.images) {
                            PeopleDetailImagesRow(images: props.people.images ?? [],
                                                  selectedPoster: $selectedPoster,
                                                  focusedItem: $focusedDetailItem)
                        }
                        ForEach(sortedYears(props: props), id: \.self) { year in
                            moviesSection(props: props, year: year)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 24)
                }
                .onChange(of: focusedDetailItem) { _, newValue in
                    guard let newValue else { return }
                    withAnimation {
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onKeyPress(.tab, phases: .down) { press in
                    let forward = !press.modifiers.contains(.shift)
                    return movePeopleTab(props: props, forward: forward)
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "\u{19}"), phases: .down) { _ in
                    return movePeopleTab(props: props, forward: false)
                }
                .onKeyPress(.leftArrow) {
                    return movePeopleArrow(props: props, axis: .horizontal, forward: false)
                }
                .onKeyPress(.rightArrow) {
                    return movePeopleArrow(props: props, axis: .horizontal, forward: true)
                }
                .onKeyPress(.upArrow) {
                    return movePeopleArrow(props: props, axis: .vertical, forward: false)
                }
                .onKeyPress(.downArrow) {
                    return movePeopleArrow(props: props, axis: .vertical, forward: true)
                }
            }
            .blur(radius: selectedPoster != nil || isFanScoreUpdated ? 30 : 0)
            .scaleEffect(selectedPoster != nil ? 0.8 : 1)
            .animation(.interactiveSpring(), value: selectedPoster != nil || isFanScoreUpdated)
            imagesCarouselView(props: props)
            scoreUpdateView(props: props)
        }
    }

    private enum PeopleFocusAxis { case horizontal, vertical }

    private func peopleFocusGroups(props: Props) -> [[PeopleDetailFocusTarget]] {
        var groups: [[PeopleDetailFocusTarget]] = []
        if PeopleDetailState.shouldShowBiographySection(for: props.people),
           PeopleDetailBiographyState.shouldShowBiographyToggle(props.people.biography) {
            groups.append([.readMoreButton])
        }
        if PeopleDetailState.shouldShowImagesSection(for: props.people.images),
           let images = props.people.images, !images.isEmpty {
            groups.append(images.map { .image($0.file_path) })
        }
        for year in sortedYears(props: props) {
            let metas = props.movieByYears[year] ?? []
            if !metas.isEmpty {
                groups.append(metas.map { .movie(year: year, id: $0.id) })
            }
        }
        return groups
    }

    private func isHorizontalGroup(_ first: PeopleDetailFocusTarget) -> Bool {
        if case .image = first { return true }
        return false
    }

    private func movePeopleTab(props: Props, forward: Bool) -> KeyPress.Result {
        let groups = peopleFocusGroups(props: props)
        guard !groups.isEmpty else { return .ignored }
        if let current = focusedDetailItem,
           let idx = groups.firstIndex(where: { $0.contains(current) }) {
            let next = idx + (forward ? 1 : -1)
            if groups.indices.contains(next),
               let first = groups[next].first {
                focusedDetailItem = first
            }
        } else {
            focusedDetailItem = forward ? groups.first?.first : groups.last?.first
        }
        return .handled
    }

    private func movePeopleArrow(props: Props, axis: PeopleFocusAxis, forward: Bool) -> KeyPress.Result {
        guard let current = focusedDetailItem else { return .ignored }
        let groups = peopleFocusGroups(props: props)
        guard let group = groups.first(where: { $0.contains(current) }),
              let first = group.first else {
            return .ignored
        }
        // Images group responds to horizontal arrows; movie groups respond
        // to vertical arrows. Other axes pass through.
        let groupIsHorizontal = isHorizontalGroup(first)
        if groupIsHorizontal && axis != .horizontal { return .ignored }
        if !groupIsHorizontal && axis != .vertical { return .ignored }

        guard let idx = group.firstIndex(of: current) else { return .ignored }
        let next = idx + (forward ? 1 : -1)
        guard group.indices.contains(next) else { return .ignored }
        focusedDetailItem = group[next]
        return .handled
    }
    #endif
}

// MARK: - Map state to props
extension PeopleDetail {
    private func sortedYears(props: Props) -> [String] {
        PeopleDetailState.sortedYears(from: props.movieByYears)
    }
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let credits = PeopleDetailCreditsState.mergedCredits(cast: state.peoplesState.casts[peopleId] ?? [:],
                                                             crew: state.peoplesState.crews[peopleId] ?? [:])
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
        
        let detailFailure: MoviesListLoadFailure?
        if case .failed(let f) = state.moviesState.loadingStates[.personDetail(peopleId)] {
            detailFailure = f
        } else {
            detailFailure = nil
        }
        return Props(dispatch: dispatch,
                     people: PeopleDetailState.people(for: peopleId, from: state),
                     movieByYears: years,
                     hasLoadedDetail: state.peoplesState.detailed.contains(peopleId),
                     hasLoadedImages: state.peoplesState.imagesLoaded.contains(peopleId),
                     hasLoadedCredits: state.peoplesState.creditsLoaded.contains(peopleId),
                     isInFanClub: isInFanClub,
                     movieScore: movieScore,
                     detailFailure: detailFailure)

    }
    
}

#Preview {
    NavigationStack {
        PeopleDetail(peopleId: sampleCasts.first!.id).environmentObject(sampleStore)
    }
}

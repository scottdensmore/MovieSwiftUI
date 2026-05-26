import SwiftUI
@preconcurrency import SwiftUIFlux
import UI
import MovieSwiftFluxCore

enum FanClubState {
    static func fanClubPeople(from state: AppState) -> [Int] {
        state.peoplesState.fanClub.map { $0 }.sorted()
    }

    static func popularPeople(from state: AppState) -> [Int] {
        state.peoplesState.popular
            .filter { !state.peoplesState.fanClub.contains($0) }
            .filter { state.peoplesState.peoples[$0] != nil }
            .sorted { (state.peoplesState.peoples[$0]?.name ?? "") < (state.peoplesState.peoples[$1]?.name ?? "") }
    }
}

enum FanClubPaginationPolicy {
    static func initialPopularPage(popularCount: Int,
                                   nextPage: Int,
                                   popularLoading: Bool,
                                   popularInitialLoadCompleted: Bool) -> Int? {
        guard popularCount == 0,
              nextPage == 1,
              !popularLoading,
              !popularInitialLoadCompleted else {
            return nil
        }
        return nextPage
    }

    static func nextPopularPage(popular: [Int], lastTriggeredPopularId: Int?, nextPage: Int) -> Int? {
        guard let lastPopularId = popular.last,
              lastTriggeredPopularId != lastPopularId else {
            return nil
        }
        return nextPage
    }
}

enum FanClubPresentation {
    struct EmptyState {
        let title: String
        let message: String
        let accessibilityIdentifier: String
        let showsRetry: Bool
        /// SF Symbol for the ContentUnavailableView. `nil` marks the
        /// loading state, which renders a ProgressView instead (the
        /// idiomatic control for in-progress work).
        let systemImage: String?
    }

    static func emptyState(peoples: [Int],
                           popular: [Int],
                           popularLoading: Bool,
                           popularInitialLoadCompleted: Bool,
                           popularLoadFailed: Bool) -> EmptyState? {
        guard peoples.isEmpty, popular.isEmpty else {
            return nil
        }

        if popularLoading || !popularInitialLoadCompleted {
            return EmptyState(title: "Loading people",
                              message: "Fetching popular people for your Fan Club.",
                              accessibilityIdentifier: "fanClub.loadingState",
                              showsRetry: false,
                              systemImage: nil)
        }

        if popularLoadFailed {
            return EmptyState(title: "Could not load popular people",
                              message: "Check your connection and try again.",
                              accessibilityIdentifier: "fanClub.errorState",
                              showsRetry: true,
                              systemImage: "exclamationmark.triangle")
        }

        return EmptyState(title: "No popular people right now",
                          message: "Try again later to find people to add to your Fan Club.",
                          accessibilityIdentifier: "fanClub.emptyState",
                          showsRetry: false,
                          systemImage: "person.2.slash")
    }
}

struct FanClubHome: ConnectedView {
    struct Props {
        let peoples: [Int]
        let popular: [Int]
        let popularLoading: Bool
        let popularInitialLoadCompleted: Bool
        let popularLoadFailed: Bool
        let searchResults: [Int]?
        let dispatch: DispatchFunction
    }

    var embedInNavigationStack = true
    var showNavigationTitle = true
    @State private var nextPopularPage = 1
    @State private var lastTriggeredPopularId: Int?
    @State private var searchTextWrapper = MoviesSearchTextWrapper()
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    #if os(macOS)
    @State private var selectedPeopleId: Int?
    @State private var highlightedPeopleId: Int?
    @FocusState private var isFanClubFocused: Bool
    #endif

    func map(state: AppState , dispatch: @escaping DispatchFunction) -> Props {
        searchTextWrapper.bindDispatchSearches { text, page in
            dispatch(PeopleActions.FetchSearch(query: text, page: page))
        }

        let query = searchTextWrapper.searchText
        let searchResults: [Int]? = (isSearching && !query.isEmpty)
            ? state.peoplesState.search[query]
            : nil

        return Props(peoples: FanClubState.fanClubPeople(from: state),
                     popular: FanClubState.popularPeople(from: state),
                     popularLoading: state.peoplesState.popularLoading,
                     popularInitialLoadCompleted: state.peoplesState.popularInitialLoadCompleted,
                     popularLoadFailed: state.peoplesState.popularLoadFailed,
                     searchResults: searchResults,
                     dispatch: dispatch)
    }
    
    @ViewBuilder
    private func peopleNavigationLink(people: Int) -> some View {
        #if os(macOS)
        PeopleRow(peopleId: people)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .leading)
            .macFocusHighlight(isFocused: highlightedPeopleId == people)
            .id(people)
            .accessibilityIdentifier("fanClub.person.\(people)")
            .onTapGesture {
                highlightedPeopleId = people
                isFanClubFocused = true
            }
            .onTapGesture(count: 2) {
                selectedPeopleId = people
            }
        #else
        NavigationLink(destination: PeopleDetail(peopleId: people).id(people)) {
            PeopleRow(peopleId: people)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SoftSelectionButtonStyle())
        .accessibilityIdentifier("fanClub.person.\(people)")
        #endif
    }
    
    private var searchField: some View {
        SearchField(searchTextWrapper: searchTextWrapper,
                    placeholder: "Search actors",
                    isSearching: $isSearching,
                    focused: $isSearchFieldFocused)
    }

    private func listView(props: Props) -> some View {
        #if os(macOS)
        let isActivelySearching = isSearching && !searchTextWrapper.searchText.isEmpty
        let allPeople: [Int] = isActivelySearching
            ? (props.searchResults ?? [])
            : (props.peoples + props.popular)

        // Search field is outside the ScrollView so Tab from the
        // sidebar lands on it first; a second Tab moves focus into
        // the list for arrow-key navigation.
        return VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if isActivelySearching {
                            if props.searchResults == nil {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else if (props.searchResults ?? []).isEmpty {
                                Text("No actors found for \"\(searchTextWrapper.searchText)\"")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else {
                                ForEach(props.searchResults ?? [], id: \.self) { people in
                                    peopleNavigationLink(people: people)
                                }
                            }
                        } else {
                            if !props.peoples.isEmpty {
                                ForEach(props.peoples, id: \.self) { people in
                                    peopleNavigationLink(people: people)
                                }
                                Divider().padding(.vertical, 8)
                            }
                            Text("Popular people to add to your Fan Club")
                                .titleStyle()
                                .padding(.horizontal)
                                .padding(.top, 4)
                                .padding(.bottom, 6)
                            ForEach(props.popular, id: \.self) { people in
                                peopleNavigationLink(people: people)
                            }
                            if let lastPopularId = props.popular.last {
                                Rectangle()
                                    .foregroundStyle(.clear)
                                    .frame(height: 1)
                                    .onAppear {
                                        fetchNextPopularPageIfNeeded(props: props, lastPopularId: lastPopularId)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .focusable()
                .focused($isFanClubFocused)
                .focusEffectDisabled()
            .onKeyPress(.downArrow) {
                guard !allPeople.isEmpty else { return .ignored }
                if let current = highlightedPeopleId,
                   let idx = allPeople.firstIndex(of: current),
                   idx + 1 < allPeople.count {
                    let next = allPeople[idx + 1]
                    highlightedPeopleId = next
                    withAnimation { scrollProxy.scrollTo(next, anchor: .center) }
                } else {
                    highlightedPeopleId = allPeople.first
                    if let first = allPeople.first {
                        withAnimation { scrollProxy.scrollTo(first, anchor: .center) }
                    }
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard !allPeople.isEmpty else { return .ignored }
                if let current = highlightedPeopleId,
                   let idx = allPeople.firstIndex(of: current),
                   idx > 0 {
                    let prev = allPeople[idx - 1]
                    highlightedPeopleId = prev
                    withAnimation { scrollProxy.scrollTo(prev, anchor: .center) }
                }
                return .handled
            }
            .onKeyPress(.return) {
                if let id = highlightedPeopleId {
                    selectedPeopleId = id
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(characters: .init(charactersIn: " ")) { _ in
                if let id = highlightedPeopleId {
                    selectedPeopleId = id
                    return .handled
                }
                return .ignored
            }
            .onAppear {
                if highlightedPeopleId == nil {
                    highlightedPeopleId = allPeople.first
                }
            }
            .onChange(of: allPeople) { _, newList in
                // If current highlight is no longer in the visible list
                // (e.g. user started searching and the list switched to
                // results), snap highlight to the first new item.
                if let current = highlightedPeopleId, !newList.contains(current) {
                    highlightedPeopleId = newList.first
                } else if highlightedPeopleId == nil {
                    highlightedPeopleId = newList.first
                }
            }
            }  // end ScrollViewReader
        }  // end VStack
        .animation(.spring(), value: props.peoples.count + props.popular.count)
        .navigationDestination(item: $selectedPeopleId) { id in
            PeopleDetail(peopleId: id)
                .macBackKeyboardShortcut()
        }
        #else
        let isActivelySearching = isSearching && !searchTextWrapper.searchText.isEmpty
        return List {
            Section {
                searchField
            }

            if isActivelySearching {
                if props.searchResults == nil {
                    ProgressView()
                } else if (props.searchResults ?? []).isEmpty {
                    Text("No actors found for \"\(searchTextWrapper.searchText)\"")
                        .foregroundStyle(.secondary)
                } else {
                    Section(header: Text("Search results")) {
                        ForEach(props.searchResults ?? [], id: \.self) { people in
                            peopleNavigationLink(people: people)
                        }
                    }
                }
            } else {
                Section {
                    ForEach(props.peoples, id: \.self) { people in
                        peopleNavigationLink(people: people)
                    }.onDelete(perform: { index in
                        props.dispatch(PeopleActions.RemoveFromFanClub(people: props.peoples[index.first!]))
                    })
                }

                Section(header: Text("Popular people to add to your Fan Club")) {
                    ForEach(props.popular, id: \.self) { people in
                        peopleNavigationLink(people: people)
                    }
                }

                if let lastPopularId = props.popular.last {
                    Rectangle()
                        .foregroundStyle(.clear)
                        .onAppear {
                            fetchNextPopularPageIfNeeded(props: props, lastPopularId: lastPopularId)
                        }
                }
            }
        }
        .animation(.spring(), value: props.peoples.count + props.popular.count)
        #endif
    }

    private func retryPopularLoad(props: Props) {
        nextPopularPage = 2
        lastTriggeredPopularId = nil
        props.dispatch(PeopleActions.FetchPopular(page: 1))
    }

    @ViewBuilder
    private func emptyStateView(_ state: FanClubPresentation.EmptyState, props: Props) -> some View {
        Group {
            if let systemImage = state.systemImage {
                // Error / empty states → ContentUnavailableView, the
                // modern idiom (consistent layout, built-in a11y).
                ContentUnavailableView {
                    Label(state.title, systemImage: systemImage)
                } description: {
                    Text(state.message)
                } actions: {
                    if state.showsRetry {
                        Button("Retry") {
                            retryPopularLoad(props: props)
                        }
                        .accessibilityIdentifier("fanClub.retryButton")
                    }
                }
            } else {
                // Loading state → ProgressView is the right control for
                // in-progress work (ContentUnavailableView is for absence).
                // Keeps both the title and message the empty-state view
                // showed before, so no copy is dropped for this case.
                VStack(spacing: 12) {
                    ProgressView()
                    Text(state.title)
                        .font(.headline)
                    Text(state.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        // `.contain` keeps child identities (e.g. the retry button keeps
        // its own identifier) while still exposing this state identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(state.accessibilityIdentifier)
    }

    @ViewBuilder
    private func screen(props: Props) -> some View {
        let content = Group {
            if let emptyState = FanClubPresentation.emptyState(peoples: props.peoples,
                                                               popular: props.popular,
                                                               popularLoading: props.popularLoading,
                                                               popularInitialLoadCompleted: props.popularInitialLoadCompleted,
                                                               popularLoadFailed: props.popularLoadFailed) {
                emptyStateView(emptyState, props: props)
            } else {
                listView(props: props)
            }
        }

        if showNavigationTitle {
            content.navigationTitle("Fan Club")
        } else {
            content
        }
    }

    private func fetchInitialPopularPageIfNeeded(props: Props) {
        guard let page = FanClubPaginationPolicy.initialPopularPage(popularCount: props.popular.count,
                                                                    nextPage: nextPopularPage,
                                                                    popularLoading: props.popularLoading,
                                                                    popularInitialLoadCompleted: props.popularInitialLoadCompleted) else {
            return
        }
        nextPopularPage += 1
        props.dispatch(PeopleActions.FetchPopular(page: page))
    }

    private func fetchNextPopularPageIfNeeded(props: Props, lastPopularId: Int) {
        guard let page = FanClubPaginationPolicy.nextPopularPage(popular: props.popular,
                                                                 lastTriggeredPopularId: lastTriggeredPopularId,
                                                                 nextPage: nextPopularPage) else {
            return
        }
        lastTriggeredPopularId = lastPopularId
        nextPopularPage += 1
        props.dispatch(PeopleActions.FetchPopular(page: page))
    }
    
    func body(props: Props) -> some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    screen(props: props)
                }
            } else {
                screen(props: props)
            }
        }
        .onAppear {
            fetchInitialPopularPageIfNeeded(props: props)
        }
    }
}

#Preview {
    FanClubHome()
}

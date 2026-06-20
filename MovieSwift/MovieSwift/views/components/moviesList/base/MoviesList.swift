import SwiftUI
import Combine
import UI
import Backend
import MovieSwiftFluxCore

enum MoviesListNavigationRoute: Identifiable, Hashable {
    case movie(Int)
    case people(Int)
    case keyword(Keyword)

    var id: String {
        switch self {
        case .movie(let id):
            return "movie-\(id)"
        case .people(let id):
            return "people-\(id)"
        case .keyword(let keyword):
            return "keyword-\(keyword.id)"
        }
    }

    static func == (lhs: MoviesListNavigationRoute, rhs: MoviesListNavigationRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.movie(lhsId), .movie(rhsId)):
            return lhsId == rhsId
        case let (.people(lhsId), .people(rhsId)):
            return lhsId == rhsId
        case let (.keyword(lhsKeyword), .keyword(rhsKeyword)):
            return lhsKeyword.id == rhsKeyword.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .movie(let id):
            hasher.combine(0)
            hasher.combine(id)
        case .people(let id):
            hasher.combine(1)
            hasher.combine(id)
        case .keyword(let keyword):
            hasher.combine(2)
            hasher.combine(keyword.id)
        }
    }
}

// `@MainActor`: builds main-actor-isolated ConnectedViews (MovieDetail,
// PeopleDetail, MovieKeywordList). Every caller is a `.navigationDestination`
// closure inside a SwiftUI view body, so it already runs on the main actor.
@MainActor
@ViewBuilder
func moviesListDestinationView(for route: MoviesListNavigationRoute) -> some View {
    switch route {
    case .movie(let id):
        MovieDetail(movieId: id)
            .macBackKeyboardShortcut()
    case .people(let id):
        PeopleDetail(peopleId: id)
            .macBackKeyboardShortcut()
    case .keyword(let keyword):
        MovieKeywordList(keyword: keyword)
            .macBackKeyboardShortcut()
    }
}

enum MoviesListSearchState {
    static func searchedMovies(query: String, from state: AppState) -> [Int]? {
        state.moviesState.search[query]
    }

    static func searchedKeywords(query: String, from state: AppState) -> [Keyword]? {
        state.moviesState.searchKeywords[query]?.prefix(5).map { $0 }
    }

    static func searchedPeoples(query: String, from state: AppState) -> [Int]? {
        state.peoplesState.search[query]
    }

    static func recentSearches(from state: AppState) -> [String] {
        state.moviesState.recentSearches.map { $0 }
    }
}

enum MoviesListPaginationPolicy {
    static func shouldAdvanceSearchPage(isSearching: Bool, searchedMovies: [Int]?) -> Bool {
        isSearching && searchedMovies?.isEmpty == false
    }

    static func shouldAdvanceListPage(isSearching: Bool, pageListenerExists: Bool, movies: [Int]) -> Bool {
        !isSearching && pageListenerExists && !movies.isEmpty
    }
}

// MARK: - Movies List
struct MoviesList: ConnectedView {
    struct Props {
        let searchedMovies: [Int]?
        let searchedKeywords: [Keyword]?
        let searcherdPeoples: [Int]?
        let recentSearches: [String]
    }

    enum SearchFilter: Int {
        case movies, peoples
    }

    // MARK: - binding
    @State private var searchFilter: Int = SearchFilter.movies.rawValue
    @State private var searchTextWrapper = MoviesSearchTextWrapper()
    @State private var isSearching = false
    @FocusState private var isSearchFieldFocused: Bool
    #if os(macOS)
    @State private var highlightedMovieId: Int?
    @State private var selectedMovieId: Int?
    @FocusState private var isListFocused: Bool
    #endif

    // MARK: - Public var
    let movies: [Int]
    let displaySearch: Bool
    var pageListener: MoviesPagesListener?
    @Binding var navigationRoute: MoviesListNavigationRoute?

    // MARK: - Private var
    // MARK: - Computed Props
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        searchTextWrapper.bindDispatchSearches { text, page in
            dispatch(MoviesActions.FetchSearchKeyword(query: text))
            dispatch(MoviesActions.FetchSearch(query: text, page: page))
            dispatch(PeopleActions.FetchSearch(query: text, page: page))
        }

        if isSearching {
            return Props(searchedMovies: MoviesListSearchState.searchedMovies(query: searchTextWrapper.searchText, from: state),
                         searchedKeywords: MoviesListSearchState.searchedKeywords(query: searchTextWrapper.searchText, from: state),
                         searcherdPeoples: MoviesListSearchState.searchedPeoples(query: searchTextWrapper.searchText, from: state),
                         recentSearches: MoviesListSearchState.recentSearches(from: state))
        }
        return Props(searchedMovies: nil, searchedKeywords: nil, searcherdPeoples: nil, recentSearches: [])
    }

    // MARK: - Computed views
    private func moviesRows(props: Props) -> some View {
        let movieIds = isSearching ? props.searchedMovies ?? [] : movies
        // Use enumeration-based identity so duplicate movie ids (e.g. 0
        // placeholders) don't collide in the LazyVStack.
        return ForEach(Array(movieIds.enumerated()), id: \.offset) { offset, id in
            Button(action: { navigationRoute = .movie(id) }) {
                MovieRow(movieId: id)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            // Attach contextMenu at the Button level so iOS's gesture
            // coordinator routes long-press to UIContextMenuInteraction
            // instead of the Button's own action handler.
            .contextMenu { MovieContextMenu(movieId: id) }
            .accessibilityIdentifier(AccessibilityID.MoviesList.movie(id))
            #if os(macOS)
            .id(offset)
            .macFocusHighlight(isFocused: selectedMovieId == id || highlightedMovieId == id)
            .onTapGesture {
                selectedMovieId = id
                isListFocused = true
            }
            .onTapGesture(count: 2) {
                navigationRoute = .movie(id)
            }
            #endif
        }
    }

    private func movieSection(props: Props) -> some View {
        Group {
            if isSearching {
                Section(header: Text("Results for \(searchTextWrapper.searchText)")) {
                    if isSearching && props.searchedMovies == nil {
                        MovieRow(movieId: 0)
                        MovieRow(movieId: 0)
                        MovieRow(movieId: 0)
                        MovieRow(movieId: 0)
                    } else if isSearching && props.searchedMovies?.isEmpty == true {
                        Text("No results")
                    } else {
                        moviesRows(props: props)
                    }
                }
            } else {
                Section {
                    moviesRows(props: props)
                }
            }
        }
    }

    private func peoplesSection(props: Props) -> some View {
        Section {
            if isSearching && props.searcherdPeoples == nil {
                PeopleRow(peopleId: 0)
                PeopleRow(peopleId: 0)
                PeopleRow(peopleId: 0)
                PeopleRow(peopleId: 0)
            } else if isSearching && props.searcherdPeoples?.isEmpty == true {
                Text("No results")
            } else {
                ForEach(props.searcherdPeoples ?? [], id: \.self) { id in
                    Button(action: { navigationRoute = .people(id) }) {
                        PeopleRow(peopleId: id)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { PeopleContextMenu(people: id) }
                }
            }
        }
    }

    private func keywordsSection(props: Props) -> some View {
        Section(header: Text("Keywords")) {
            ForEach(props.searchedKeywords ?? []) {keyword in
                Button(action: { navigationRoute = .keyword(keyword) }) {
                    Text(keyword.name)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var searchField: some View {
        SearchField(searchTextWrapper: searchTextWrapper,
                    placeholder: "Search any movies or person",
                    isSearching: $isSearching,
                    focused: $isSearchFieldFocused)
            .scrollDismissesKeyboard(.interactively)
    }

    private var searchFilterView: some View {
        Picker(selection: $searchFilter, label: Text("")) {
            Text("Movies").tag(SearchFilter.movies.rawValue)
            Text("People").tag(SearchFilter.peoples.rawValue)
        }.pickerStyle(.segmented)
    }

    // MARK: - List content
    @ViewBuilder
    private func listContent(props: Props) -> some View {
        if isSearching {
            searchFilterView
            if props.searchedKeywords != nil && searchFilter == SearchFilter.movies.rawValue {
                keywordsSection(props: props)
            }
        }

        if isSearching && searchFilter == SearchFilter.peoples.rawValue {
            peoplesSection(props: props)
        } else {
            movieSection(props: props)
        }

        /// The pagination is done by appending a invisible rectancle at the bottom of the list, and trigerining the next page load as it appear.
        /// Hacky way for now, hope it'll be possible to find a better solution in a future version of SwiftUI.
        /// Could be possible to do with GeometryReader.
        if !movies.isEmpty || props.searchedMovies?.isEmpty == false {
            Rectangle()
                .foregroundStyle(.clear)
                .onAppear {
                    if MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: self.isSearching,
                                                                         searchedMovies: props.searchedMovies) {
                        self.searchTextWrapper.searchPageListener.currentPage += 1
                    } else if MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: self.isSearching,
                                                                               pageListenerExists: self.pageListener != nil,
                                                                               movies: self.movies) {
                        self.pageListener?.currentPage += 1
                    }
                }
        }
    }

    // MARK: - Body
    func body(props: Props) -> some View {
        ZStack {
            #if os(macOS)
            VStack(spacing: 0) {
                if displaySearch {
                    searchField
                }
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            listContent(props: props)
                        }
                        .padding(.horizontal, 4)
                    }
                    .focusable()
                    .focused($isListFocused)
                    .focusEffectDisabled()
                    .onKeyPress(.downArrow) {
                        let movieIds = isSearching ? props.searchedMovies ?? [] : movies
                        guard !movieIds.isEmpty else { return .ignored }
                        if let current = selectedMovieId,
                           let idx = movieIds.firstIndex(of: current),
                           idx + 1 < movieIds.count {
                            let nextIdx = idx + 1
                            selectedMovieId = movieIds[nextIdx]
                            withAnimation { scrollProxy.scrollTo(nextIdx, anchor: .center) }
                        } else {
                            selectedMovieId = movieIds[0]
                            withAnimation { scrollProxy.scrollTo(0, anchor: .center) }
                        }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        let movieIds = isSearching ? props.searchedMovies ?? [] : movies
                        guard !movieIds.isEmpty else { return .ignored }
                        if let current = selectedMovieId,
                           let idx = movieIds.firstIndex(of: current),
                           idx - 1 >= 0 {
                            let prevIdx = idx - 1
                            selectedMovieId = movieIds[prevIdx]
                            withAnimation { scrollProxy.scrollTo(prevIdx, anchor: .center) }
                        }
                        return .handled
                    }
                    .onKeyPress(.return) {
                        if let id = selectedMovieId {
                            navigationRoute = .movie(id)
                            return .handled
                        }
                        return .ignored
                    }
                }
                .onChange(of: selectedMovieId) { _, newValue in
                    if newValue != nil {
                        highlightedMovieId = nil
                    }
                }
                .onAppear {
                    if selectedMovieId == nil, let firstMovie = movies.first {
                        selectedMovieId = firstMovie
                    }
                    // Don't auto-grab focus on appear — it would steal the
                    // keyboard away from the sidebar whenever the user
                    // arrow-keys to a different menu. Focus moves here
                    // when the user clicks into the list or Tabs into it.
                }
                .onChange(of: movies) { _, newMovies in
                    if selectedMovieId == nil, let firstMovie = newMovies.first {
                        selectedMovieId = firstMovie
                    }
                }
            }
            #else
            VStack(spacing: 0) {
                List {
                    if displaySearch {
                        Section {
                            searchField
                        }
                    }
                    listContent(props: props)
                }
                .listStyle(.plain)
                .defaultFocus($isSearchFieldFocused, true, priority: .userInitiated)
            }
            #endif
        }
    }
}

#Preview {
    MoviesList(movies: [sampleMovie.id],
               displaySearch: true,
               navigationRoute: .constant(nil))
        .environment(sampleStore)
}

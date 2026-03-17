//
//  MoviesList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Combine
import UI
import Backend

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

@ViewBuilder
func moviesListDestinationView(for route: MoviesListNavigationRoute) -> some View {
    switch route {
    case .movie(let id):
        MovieDetail(movieId: id)
    case .people(let id):
        PeopleDetail(peopleId: id)
    case .keyword(let keyword):
        MovieKeywordList(keyword: keyword)
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
    #if targetEnvironment(macCatalyst)
    @State private var highlightedMovieId: Int?
    @FocusState private var focusedMovieId: Int?
    #endif
    
    // MARK: - Public var
    let movies: [Int]
    let displaySearch: Bool
    var pageListener: MoviesPagesListener?
    @Binding var navigationRoute: MoviesListNavigationRoute?
    
    // MARK: - Private var
    // MARK: - Computed Props
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        if isSearching {
            return Props(searchedMovies: state.moviesState.search[searchTextWrapper.searchText],
                         searchedKeywords: state.moviesState.searchKeywords[searchTextWrapper.searchText]?.prefix(5).map{ $0 },
                         searcherdPeoples: state.peoplesState.search[searchTextWrapper.searchText],
                         recentSearches: state.moviesState.recentSearches.map{ $0 })
        }
        return Props(searchedMovies: nil, searchedKeywords: nil, searcherdPeoples: nil, recentSearches: [])
    }
    
    // MARK: - Computed views
    private func moviesRows(props: Props) -> some View {
        let movieIds = isSearching ? props.searchedMovies ?? [] : movies
        return ForEach(Array(movieIds.enumerated()), id: \.offset) { _, id in
            Button(action: { navigationRoute = .movie(id) }) {
                MovieRow(movieId: id)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    #if targetEnvironment(macCatalyst)
                    .padding(6)
                    #endif
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("moviesList.movie.\(id)")
            #if targetEnvironment(macCatalyst)
            .focusable()
            .focused($focusedMovieId, equals: id)
            .onKeyPress(.return) { navigationRoute = .movie(id); return .handled }
            .onKeyPress(characters: .init(charactersIn: " ")) { _ in navigationRoute = .movie(id); return .handled }
            .catalystFocusHighlight(isFocused: focusedMovieId == id || highlightedMovieId == id)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }
        
    private var searchField: some View {
        #if targetEnvironment(macCatalyst)
        SearchField(searchTextWrapper: searchTextWrapper,
                    placeholder: "Search any movies or person",
                    isSearching: $isSearching,
                    focused: $isSearchFieldFocused)
        #else
        SearchField(searchTextWrapper: searchTextWrapper,
                    placeholder: "Search any movies or person",
                    isSearching: $isSearching,
                    focused: $isSearchFieldFocused)
            .onPreferenceChange(OffsetTopPreferenceKey.self) { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        #endif
    }
    
    private var searchFilterView: some View {
        Picker(selection: $searchFilter, label: Text("")) {
            Text("Movies").tag(SearchFilter.movies.rawValue)
            Text("People").tag(SearchFilter.peoples.rawValue)
        }.pickerStyle(SegmentedPickerStyle())
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
                .foregroundColor(.clear)
                .onAppear {
                    if self.isSearching && props.searchedMovies?.isEmpty == false {
                        self.searchTextWrapper.searchPageListener.currentPage += 1
                    } else if self.pageListener != nil && !self.isSearching && !self.movies.isEmpty {
                        self.pageListener?.currentPage += 1
                    }
                }
        }
    }

    // MARK: - Body
    func body(props: Props) -> some View {
        ZStack {
            #if targetEnvironment(macCatalyst)
            VStack(spacing: 0) {
                if displaySearch {
                    searchField
                }
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        listContent(props: props)
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: focusedMovieId) { _, newValue in
                    if newValue != nil {
                        highlightedMovieId = nil
                    }
                }
                .onAppear {
                    if focusedMovieId == nil, let firstMovie = movies.first {
                        focusedMovieId = firstMovie
                    }
                }
                .onChange(of: movies) { _, newMovies in
                    if focusedMovieId == nil, let firstMovie = newMovies.first {
                        focusedMovieId = firstMovie
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
                .listStyle(PlainListStyle())
                .defaultFocus($isSearchFieldFocused, true, priority: .userInitiated)
            }
            #endif
        }
    }
}

// MARK: - Mac Catalyst detail focus & back navigation
#if targetEnvironment(macCatalyst)
/// A UIKit view that automatically becomes first responder when the detail
/// view appears, keeping focus in the detail pane (not the sidebar).
/// Handles Escape, Left Arrow, and Delete to navigate back.
struct CatalystBackNavigationView: UIViewRepresentable {
    var onBack: () -> Void

    func makeUIView(context: Context) -> KeyHandlingView {
        let view = KeyHandlingView()
        view.onBack = onBack
        return view
    }

    func updateUIView(_ uiView: KeyHandlingView, context: Context) {
        uiView.onBack = onBack
    }

    class KeyHandlingView: UIView {
        var onBack: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.becomeFirstResponder()
                }
            }
        }

        override var keyCommands: [UIKeyCommand]? {
            let esc = UIKeyCommand(input: UIKeyCommand.inputEscape,
                                   modifierFlags: [], action: #selector(handleBack))
            esc.wantsPriorityOverSystemBehavior = true
            let left = UIKeyCommand(input: UIKeyCommand.inputLeftArrow,
                                    modifierFlags: [], action: #selector(handleBack))
            left.wantsPriorityOverSystemBehavior = true
            let del = UIKeyCommand(input: "\u{8}",
                                   modifierFlags: [], action: #selector(handleBack))
            del.wantsPriorityOverSystemBehavior = true
            return [esc, left, del]
        }

        @objc private func handleBack() {
            onBack?()
        }
    }
}
#endif

#if DEBUG
struct MoviesList_Previews : PreviewProvider {
    static var previews: some View {
        MoviesList(movies: [sampleMovie.id],
                   displaySearch: true,
                   navigationRoute: .constant(nil))
            .environmentObject(sampleStore)
    }
}
#endif

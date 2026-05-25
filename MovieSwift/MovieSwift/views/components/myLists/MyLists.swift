import SwiftUI
import SwiftUIFlux
import MovieSwiftFluxCore

enum MyListsPresentation {
    static func customLists(from customLists: [Int: CustomList]) -> [CustomList] {
        customLists.compactMap { $0.value }
    }

    static func sortedMovies(_ movies: [Int], by sort: MoviesSort, state: AppState) -> [Int] {
        movies.sortedMoviesIds(by: sort, state: state)
    }
}

struct MyLists : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let customLists: [CustomList]
        let wishlist: [Int]
        let seenlist: [Int]
        let movieLookup: [Int: Movie]
    }
    
    // MARK: - Vars
    var embedInNavigationStack = true
    var showNavigationTitle = true
    @EnvironmentObject private var store: Store<AppState>
    @State private var selectedList: Int = 0
    @State private var selectedMoviesSort = MoviesSort.byReleaseDate
    @State private var isSortActionSheetPresented = false
    @State private var isEditingFormPresented = false
    #if os(macOS)
    private struct MovieNav: Hashable { let id: Int }
    private struct CustomListNav: Hashable { let id: Int }
    @State private var selectedMovie: MovieNav?
    @State private var selectedCustomList: CustomListNav?
    @State private var highlightedItemId: Int?
    @FocusState private var isListFocused: Bool
    #endif
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              customLists: MyListsPresentation.customLists(from: state.moviesState.customLists),
              wishlist: MyListsPresentation.sortedMovies(state.moviesState.wishlist.map { $0 },
                                                         by: selectedMoviesSort,
                                                         state: state),
              seenlist: MyListsPresentation.sortedMovies(state.moviesState.seenlist.map { $0 },
                                                         by: selectedMoviesSort,
                                                         state: state),
              movieLookup: state.moviesState.movies)
    }
    
    // MARK: - Dynamic views
    
    private func customListsSection(props: Props) -> some View {
        Section(header: Text("Custom Lists")) {
            Button(action: {
                self.isEditingFormPresented = true
            }) {
                Text("Create custom list").foregroundStyle(Color.steam_blue)
            }
            .accessibilityIdentifier("myLists.createCustomListButton")
            ForEach(props.customLists) { list in
                #if os(macOS)
                Button(action: { selectedCustomList = CustomListNav(id: list.id) }) {
                    CustomListRow(list: list,
                                  coverMovie: CustomListPresentation.coverMovie(for: list,
                                                                               movies: props.movieLookup))
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable()
                .onKeyPress(.return) { selectedCustomList = CustomListNav(id: list.id); return .handled }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in selectedCustomList = CustomListNav(id: list.id); return .handled }
                #else
                NavigationLink(destination: CustomListDetail(listId: list.id)) {
                    CustomListRow(list: list,
                                  coverMovie: CustomListPresentation.coverMovie(for: list,
                                                                               movies: props.movieLookup))
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let list = props.customLists[index.first!]
                props.dispatch(MoviesActions.RemoveCustomList(list: list.id))
            }
        }
    }
    
    private func wishlistSection(props: Props) -> some View {
        Section(header: Text("\(props.wishlist.count) movies in wishlist (\(selectedMoviesSort.title()))")) {
            ForEach(props.wishlist, id: \.self) {id in
                #if os(macOS)
                Button(action: { selectedMovie = MovieNav(id: id) }) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable()
                .onKeyPress(.return) { selectedMovie = MovieNav(id: id); return .handled }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in selectedMovie = MovieNav(id: id); return .handled }
                #else
                NavigationLink(destination: MovieDetail(movieId: id)) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let movie = props.wishlist[index.first!]
                props.dispatch(MoviesActions.RemoveFromWishlist(movie: movie))

            }
        }
    }

    private func seenSection(props: Props) -> some View {
        Section(header: Text("\(props.seenlist.count) movies in seenlist (\(selectedMoviesSort.title()))")) {
            ForEach(props.seenlist, id: \.self) {id in
                #if os(macOS)
                Button(action: { selectedMovie = MovieNav(id: id) }) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                .focusable()
                .onKeyPress(.return) { selectedMovie = MovieNav(id: id); return .handled }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in selectedMovie = MovieNav(id: id); return .handled }
                #else
                NavigationLink(destination: MovieDetail(movieId: id)) {
                    MovieRow(movieId: id, displayListImage: false)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(SoftSelectionButtonStyle())
                #endif
            }
            .onDelete { (index) in
                let movie = props.seenlist[index.first!]
                props.dispatch(MoviesActions.RemoveFromSeenList(movie: movie))
            }
        }
    }
    
    @ViewBuilder
    private func listView(props: Props) -> some View {
        #if os(macOS)
        macOSListView(props: props)
        #else
        List {
            customListsSection(props: props)

            Picker(selection: $selectedList, label: Text("")) {
                Text("Wishlist").tag(0)
                Text("Seenlist").tag(1)
            }.pickerStyle(.segmented)

            if selectedList == 0 {
                wishlistSection(props: props)
            } else if selectedList == 1 {
                seenSection(props: props)
            }
        }
        #if os(iOS) || os(tvOS)
        .listStyle(.grouped)
        #endif
        .confirmationDialog("Sort movies by", isPresented: $isSortActionSheetPresented) {
            sortMenuButtons { self.selectedMoviesSort = $0 }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    self.isSortActionSheetPresented.toggle()
                }, label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                })
                .accessibilityLabel("Sort")
                .accessibilityIdentifier("myLists.sortButton")
            }
        }
        #endif
    }

    #if os(macOS)
    @FocusState private var focusedSection: MyListsSection?

    private var sectionSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(MyListsSection.allCases) { section in
                sectionTabButton(section: section)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func sectionTabButton(section: MyListsSection) -> some View {
        let isSelected = selectedList == section.rawValue
        return Button {
            selectedList = section.rawValue
            focusedSection = section
        } label: {
            Label(section.title, systemImage: section.systemImage)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(focusedSection == section ? Color.accentColor : .clear,
                                lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedSection, equals: section)
        .focusEffectDisabled()
        .accessibilityIdentifier("myLists.section.\(section.title)")
        // Tab from any section tab moves focus into the movies / lists
        // below; arrow keys still navigate between the three tabs.
        .onKeyPress(.tab, phases: .down) { press in
            guard !press.modifiers.contains(.shift) else { return .ignored }
            focusedSection = nil
            isListFocused = true
            return .handled
        }
        .onKeyPress(.rightArrow) { moveSection(offset: 1) }
        .onKeyPress(.leftArrow) { moveSection(offset: -1) }
    }

    private func moveSection(offset: Int) -> KeyPress.Result {
        let all = MyListsSection.allCases
        guard let current = focusedSection,
              let idx = all.firstIndex(of: current) else {
            return .ignored
        }
        let nextIdx = idx + offset
        guard all.indices.contains(nextIdx) else { return .ignored }
        let next = all[nextIdx]
        focusedSection = next
        selectedList = next.rawValue
        return .handled
    }

    private enum MyListsSection: Int, CaseIterable, Identifiable, Hashable {
        case wishlist, seenlist, customLists
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .wishlist: return "Wishlist"
            case .seenlist: return "Seenlist"
            case .customLists: return "Custom Lists"
            }
        }
        var systemImage: String {
            switch self {
            case .wishlist: return "heart.fill"
            case .seenlist: return "eye.fill"
            case .customLists: return "pin.fill"
            }
        }
    }

    private func macOSListView(props: Props) -> some View {
        VStack(spacing: 0) {
            sectionSwitcher
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        currentSectionContent(props: props)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 24)
                }
                .focusable()
                .focused($isListFocused)
                .focusEffectDisabled()
                .onKeyPress(.downArrow) {
                    let ids = currentSectionItemIds(props: props)
                    return moveHighlight(ids: ids, forward: true, scrollProxy: scrollProxy)
                }
                .onKeyPress(.upArrow) {
                    let ids = currentSectionItemIds(props: props)
                    return moveHighlight(ids: ids, forward: false, scrollProxy: scrollProxy)
                }
                .onKeyPress(.return) { openHighlighted(props: props) }
                .onKeyPress(characters: .init(charactersIn: " ")) { _ in openHighlighted(props: props) }
                // Shift+Tab (delivered as the back-tab character U+0019 on macOS)
                // moves focus back to the currently selected section tab.
                .onKeyPress(characters: CharacterSet(charactersIn: "\u{19}"), phases: .down) { _ in
                    isListFocused = false
                    focusedSection = MyListsSection(rawValue: selectedList) ?? .wishlist
                    return .handled
                }
            }
        }
        .onChange(of: selectedList) { _, _ in
            // When the user switches section, reset the highlight to the
            // first item of the new list.
            highlightedItemId = currentSectionItemIds(props: props).first
        }
        .navigationDestination(item: $selectedMovie) { nav in
            MovieDetail(movieId: nav.id)
                .macBackKeyboardShortcut()
        }
        .navigationDestination(item: $selectedCustomList) { nav in
            CustomListDetail(listId: nav.id)
                .macBackKeyboardShortcut()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    sortMenuButtons { self.selectedMoviesSort = $0 }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel("Sort")
                .accessibilityIdentifier("myLists.sortButton")
            }
        }
    }

    @ViewBuilder
    private func currentSectionContent(props: Props) -> some View {
        switch MyListsSection(rawValue: selectedList) ?? .wishlist {
        case .wishlist:
            moviesRows(movieIds: props.wishlist,
                       props: props,
                       emptyText: "No movies in your wishlist yet",
                       sectionHeader: "\(props.wishlist.count) movies in wishlist (\(selectedMoviesSort.title()))")
        case .seenlist:
            moviesRows(movieIds: props.seenlist,
                       props: props,
                       emptyText: "No movies in your seenlist yet",
                       sectionHeader: "\(props.seenlist.count) movies in seenlist (\(selectedMoviesSort.title()))")
        case .customLists:
            customListsRows(props: props)
        }
    }

    @ViewBuilder
    private func moviesRows(movieIds: [Int],
                            props: Props,
                            emptyText: String,
                            sectionHeader: String) -> some View {
        Text(sectionHeader)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

        if movieIds.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ForEach(Array(movieIds.enumerated()), id: \.offset) { _, id in
                MovieRow(movieId: id, displayListImage: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .macFocusHighlight(isFocused: highlightedItemId == id)
                    .id(id)
                    .onTapGesture {
                        highlightedItemId = id
                        isListFocused = true
                    }
                    .onTapGesture(count: 2) {
                        selectedMovie = MovieNav(id: id)
                    }
                    .accessibilityIdentifier("myLists.movie.\(id)")
            }
        }
    }

    @ViewBuilder
    private func customListsRows(props: Props) -> some View {
        Button {
            isEditingFormPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.steam_blue)
                Text("Create custom list")
                    .foregroundStyle(Color.steam_blue)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("myLists.createCustomListButton")

        if props.customLists.isEmpty {
            Text("No custom lists yet. Create one to group movies however you like.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ForEach(props.customLists) { list in
                CustomListRow(list: list,
                              coverMovie: CustomListPresentation.coverMovie(for: list,
                                                                           movies: props.movieLookup))
                    .macFocusHighlight(isFocused: highlightedItemId == list.id)
                    .id(list.id)
                    .onTapGesture {
                        highlightedItemId = list.id
                        isListFocused = true
                    }
                    .onTapGesture(count: 2) {
                        selectedCustomList = CustomListNav(id: list.id)
                    }
            }
        }
    }

    private func currentSectionItemIds(props: Props) -> [Int] {
        switch MyListsSection(rawValue: selectedList) ?? .wishlist {
        case .wishlist:    return props.wishlist
        case .seenlist:    return props.seenlist
        case .customLists: return props.customLists.map { $0.id }
        }
    }

    private func moveHighlight(ids: [Int],
                               forward: Bool,
                               scrollProxy: ScrollViewProxy) -> KeyPress.Result {
        guard !ids.isEmpty else { return .ignored }
        if let current = highlightedItemId,
           let idx = ids.firstIndex(of: current) {
            let nextIdx = idx + (forward ? 1 : -1)
            if ids.indices.contains(nextIdx) {
                let next = ids[nextIdx]
                highlightedItemId = next
                withAnimation { scrollProxy.scrollTo(next, anchor: .center) }
            }
        } else {
            let first = ids.first
            highlightedItemId = first
            if let first { withAnimation { scrollProxy.scrollTo(first, anchor: .center) } }
        }
        return .handled
    }

    private func openHighlighted(props: Props) -> KeyPress.Result {
        guard let id = highlightedItemId else { return .ignored }
        let section = MyListsSection(rawValue: selectedList) ?? .wishlist
        switch section {
        case .customLists:
            selectedCustomList = CustomListNav(id: id)
        case .wishlist, .seenlist:
            selectedMovie = MovieNav(id: id)
        }
        return .handled
    }
    #endif
    
    @ViewBuilder
    private func screen(props: Props) -> some View {
        if showNavigationTitle {
            listView(props: props).navigationTitle("My Lists")
        } else {
            listView(props: props)
        }
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
        .sheet(isPresented: $isEditingFormPresented) {
                CustomListForm(editingListId: nil).environmentObject(self.store)
        }
    }
}

#Preview {
    MyLists().environmentObject(sampleStore)
}

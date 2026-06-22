import Backend
import MovieSwiftFluxCore
import SwiftUI
import UI

// MARK: - CustomListFormSearchWrapper

final class CustomListFormSearchWrapper: SearchTextObservable {
    private var dispatchSearches: ((String, Int) -> Void)?

    init(dispatchSearches: ((String, Int) -> Void)? = nil) {
        self.dispatchSearches = dispatchSearches
        super.init()
    }

    func bindDispatchSearches(_ dispatchSearches: @escaping (String, Int) -> Void) {
        self.dispatchSearches = dispatchSearches
    }

    override func onUpdateTextDebounced(text: String) {
        if !text.isEmpty {
            dispatchSearches?(text, 1)
        }
    }
}

// MARK: - CustomListFormState

enum CustomListFormState {
    static func editingValues(editingListId: Int?, customLists: [Int: CustomList]) -> (name: String, cover: Int?)? {
        guard let id = editingListId, let list = customLists[id] else {
            return nil
        }
        return (name: list.name, cover: list.cover)
    }

    /// A list can only be created/saved once the name has real content —
    /// the redesigned form disables Create/Save until this is true so a
    /// list can never be saved with an empty or whitespace-only name.
    static func canSubmit(name: String) -> Bool {
        !sanitizedName(name).isEmpty
    }

    /// The name actually persisted: trimmed of surrounding whitespace so a
    /// padded entry (which `canSubmit` still accepts) never reaches the
    /// reducer with stray spaces.
    static func sanitizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - CustomListFormPresentation

enum CustomListFormPresentation {
    static func coverMovie(coverId: Int?, movies: [Int: Movie]) -> Movie? {
        guard let coverId else {
            return nil
        }
        return movies[coverId]
    }

    static func searchedMovies(searchText: String,
                               searchResults: [String: [Int]],
                               movies: [Int: Movie]) -> [Movie] {
        guard !searchText.isEmpty else {
            return []
        }
        return (searchResults[searchText] ?? []).compactMap { movies[$0] }
    }
}

// MARK: - CustomListForm

struct CustomListForm: ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let customLists: [Int: CustomList]
        let searchedMovies: [Movie]
        let coverMovie: Movie?
    }

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // `@StateObject` (not `@State`): the inline search `TextField` binds
    // directly to `$searchTextWrapper.searchText`, so SwiftUI must subscribe
    // to the wrapper's `@Published` changes to re-run `map(state:dispatch:)`
    // and refresh `props.searchedMovies` on each keystroke. (Other
    // ConnectedViews keep `@State` because `UI.SearchField` supplies that
    // subscription via its own `@ObservedObject`; this form dropped it.)
    @StateObject private var searchTextWrapper = CustomListFormSearchWrapper()
    @State var listName: String = ""
    @State var listMovieCover: Int?

    let editingListId: Int?

    private var isEditing: Bool {
        editingListId != nil
    }

    private var title: String {
        isEditing ? "Edit list" : "New list"
    }

    private var confirmTitle: String {
        isEditing ? "Save changes" : "Create"
    }

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              customLists: state.moviesState.customLists,
              searchedMovies: CustomListFormPresentation.searchedMovies(searchText: searchTextWrapper.searchText,
                                                                        searchResults: state.moviesState.search,
                                                                        movies: state.moviesState.movies),
              coverMovie: CustomListFormPresentation.coverMovie(coverId: listMovieCover,
                                                                movies: state.moviesState.movies))
    }

    // MARK: - Sections

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Name")
            TextField("Name your list", text: $listName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(AccessibilityID.CustomListForm.nameField)
        }
    }

    /// Inline replacement for `UI.SearchField`: that component is built around
    /// a `GeometryReader` + fixed height for scroll-offset tracking, which
    /// collapsed into a broken sliver inside this dialog. No `isSearching`
    /// flag is needed here.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search for a movie…", text: $searchTextWrapper.searchText)
                .textFieldStyle(.plain)
            if !searchTextWrapper.searchText.isEmpty {
                Button(action: { searchTextWrapper.searchText = "" }, label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                })
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }

    private func poster(for movie: Movie) -> some View {
        MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: movie.posterPath,
                                                                        size: .medium),
                         posterSize: .medium)
    }

    private func selectedCover(_ movie: Movie) -> some View {
        HStack(alignment: .top, spacing: 12) {
            poster(for: movie)
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.userTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Button(role: .destructive, action: {
                    withAnimationIfAllowed { listMovieCover = nil }
                }, label: {
                    Label("Remove cover", systemImage: "xmark.circle")
                })
                .buttonStyle(.borderless)
            }
            Spacer(minLength: 0)
        }
    }

    private func resultsStrip(props: Props) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(props.searchedMovies) { movie in
                    Button(action: {
                        withAnimationIfAllowed {
                            listMovieCover = movie.id
                            searchTextWrapper.searchText = ""
                        }
                    }, label: {
                        poster(for: movie)
                    })
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(movie.userTitle) as cover")
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: PosterStyle.Size.medium.height() + 8)
    }

    private func coverSection(props: Props) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Cover")
            // Falls through to the search field when no cover is set, OR when a
            // cover id is set but its movie isn't in state yet (e.g. first
            // appear of an existing list) — the section self-heals once the
            // movie loads, and the user can search meanwhile rather than see a
            // blank gap.
            if listMovieCover != nil, let movie = props.coverMovie {
                selectedCover(movie)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    searchField
                    if !props.searchedMovies.isEmpty {
                        resultsStrip(props: props)
                    } else if !searchTextWrapper.searchText.isEmpty {
                        Text("No movies found.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func footer(props: Props) -> some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Button("Cancel", action: {
                presentationMode.wrappedValue.dismiss()
            })
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier(AccessibilityID.CustomListForm.cancelButton)

            Button(confirmTitle, action: { submit(props: props) })
                .buttonStyle(.borderedProminent)
                .tint(.steam_gold)
                .keyboardShortcut(.defaultAction)
                .disabled(!CustomListFormState.canSubmit(name: listName))
                .accessibilityIdentifier(AccessibilityID.CustomListForm.createButton)
        }
    }

    func body(props: Props) -> some View {
        layout(props: props)
            .onAppear {
                searchTextWrapper.bindDispatchSearches { text, page in
                    props.dispatch(MoviesActions.FetchSearch(query: text, page: page))
                }
                if let editingValues = CustomListFormState.editingValues(editingListId: editingListId,
                                                                         customLists: props.customLists) {
                    listMovieCover = editingValues.cover
                    listName = editingValues.name
                }
            }
    }

    @ViewBuilder
    private func layout(props: Props) -> some View {
        #if os(macOS)
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    coverSection(props: props)
                }
                .padding(20)
                Divider()
                footer(props: props)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
            }
            .frame(width: 460)
        #else
            NavigationStack {
                VStack(spacing: 0) {
                    // Scrollable so the fields stay reachable when the keyboard
                    // is up on small devices; the footer stays pinned below.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            nameField
                            coverSection(props: props)
                        }
                        .padding(20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    Divider()
                    footer(props: props)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                .navigationTitle(title)
            }
        #endif
    }

    #if os(macOS)
        // macOS-only: iOS uses the navigation bar title instead of an in-content
        // header, so this view is never built there.
        private var header: some View {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.title2)
                    .foregroundStyle(Color.steam_gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text("Give your list a name and an optional cover.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    #endif

    // MARK: - Actions

    private func submit(props: Props) {
        guard CustomListFormState.canSubmit(name: listName) else { return }
        let name = CustomListFormState.sanitizedName(listName)
        if let id = editingListId {
            props.dispatch(MoviesActions.EditCustomList(list: id,
                                                        title: name,
                                                        cover: listMovieCover))
        } else {
            // One past the largest existing id — a unique, collision-free id.
            // (Replaces a `1000 ^ 3` range whose `^` is bitwise XOR, not a
            // power: it yields 1003 and traps once a user has 1003+ lists.)
            let newId = (props.customLists.keys.max() ?? 0) + 1
            let newList = CustomList(id: newId,
                                     name: name,
                                     cover: listMovieCover,
                                     movies: [])
            props.dispatch(MoviesActions.AddCustomList(list: newList))
        }
        presentationMode.wrappedValue.dismiss()
    }

    private func withAnimationIfAllowed(_ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(.easeInOut(duration: 0.2), body)
        }
    }
}

#Preview {
    CustomListForm(editingListId: nil).environment(sampleStore)
}

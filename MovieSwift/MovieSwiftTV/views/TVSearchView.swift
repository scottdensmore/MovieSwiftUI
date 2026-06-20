import SwiftUI
import Backend
import MovieSwiftFluxCore

struct TVSearchView: ConnectedView {
    struct Props {
        let searchResults: [Int]
        let movies: [Int: Movie]
        let dispatch: DispatchFunction
    }

    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let results = searchText.isEmpty ? [] : (state.moviesState.search[searchText] ?? [])
        return Props(searchResults: results,
                     movies: state.moviesState.movies,
                     dispatch: dispatch)
    }

    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 40), count: 5)

    func body(props: Props) -> some View {
        // Branch outside the ScrollView: ContentUnavailableView wants to
        // fill its container, which it can't do inside a ScrollView's
        // unbounded height. Only the results grid needs to scroll.
        Group {
            if searchText.isEmpty {
                ContentUnavailableView("Search for movies",
                                       systemImage: "magnifyingglass",
                                       description: Text("Find movies by title."))
                    .accessibilityIdentifier(AccessibilityID.Search.emptyState)
            } else if props.searchResults.isEmpty {
                // System-standard "No Results for \"…\"" empty state.
                ContentUnavailableView.search(text: searchText)
                    .accessibilityIdentifier(AccessibilityID.Search.noResults)
            } else {
                ScrollView {
                    LazyVGrid(columns: Self.gridColumns, spacing: 40) {
                        ForEach(props.searchResults, id: \.self) { id in
                            if let movie = props.movies[id] {
                                NavigationLink(value: id) {
                                    TVSearchCard(movie: movie)
                                }
                                .buttonStyle(.card)
                                .accessibilityIdentifier(AccessibilityID.Search.result(id))
                            }
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.vertical, 40)
                }
            }
        }
        .navigationDestination(for: Int.self) { id in
            TVMovieDetail(movieId: id)
        }
        .searchable(text: $searchText, prompt: "Movie title")
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            guard !newValue.isEmpty else { return }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                props.dispatch(MoviesActions.FetchSearch(query: newValue, page: 1))
            }
        }
    }
}

private struct TVSearchCard: View {
    let movie: Movie

    var body: some View {
        VStack(spacing: 12) {
            MoviePosterImage(imageLoader: ImageLoader(path: movie.posterPath,
                                                      size: .medium),
                            posterSize: PosterStyle.Size.tv)
            Text(movie.userTitle)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: PosterStyle.Size.tv.width())
        }
    }
}

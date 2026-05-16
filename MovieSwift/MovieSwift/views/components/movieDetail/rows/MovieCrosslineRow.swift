import SwiftUI
import SwiftUIFlux
import Backend
import UI
import MovieSwiftFluxCore

struct MovieCrosslineItemPresentation {
    let title: String
    let posterPath: String?
    let popularityScore: Int
}

enum MovieCrosslineState {
    static func movieIds(from movies: [Movie]) -> [Int] {
        movies.map(\.id)
    }

    static func presentation(for movie: Movie) -> MovieCrosslineItemPresentation {
        MovieCrosslineItemPresentation(title: movie.userTitle,
                                       posterPath: movie.poster_path,
                                       popularityScore: Int(movie.vote_average * 10))
    }
}

struct MovieCrosslineRow : View {
    let title: String
    let movies: [Movie]
    let onSelectMovie: (Int) -> Void
    let onSelectSeeAll: () -> Void
    #if os(macOS)
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    let movieFocusTarget: (Int) -> MovieDetailFocusTarget
    let seeAllFocusTarget: MovieDetailFocusTarget
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                Spacer()
                #if os(macOS)
                MacFocusableLink(id: seeAllFocusTarget, focusedId: focusedItem) {
                    onSelectSeeAll()
                } label: {
                    Text("See all").foregroundColor(.steam_blue)
                }
                .padding(.trailing)
                #else
                Button(action: {
                    onSelectSeeAll()
                }) {
                    Text("See all")
                        .foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                #endif
            }
            #if os(macOS)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 32) {
                        ForEach(Array(self.movies.enumerated()), id: \.offset) { index, movie in
                            MovieDetailRowItem(movie: movie,
                                               onSelect: { onSelectMovie(movie.id) },
                                               focusedItem: focusedItem,
                                               focusTarget: movieFocusTarget(movie.id))
                                .id(index)
                        }
                    }.padding(.leading)
                }
                .clipped()
                .onChange(of: focusedItem.wrappedValue) { _, newValue in
                    guard let newValue,
                          let index = movies.firstIndex(where: { movieFocusTarget($0.id) == newValue }) else {
                        return
                    }
                    withAnimation {
                        scrollProxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            #else
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(self.movies) { movie in
                        MovieDetailRowItem(movie: movie) {
                            onSelectMovie(movie.id)
                        }
                    }
                }.padding(.leading)
            }
            #endif
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

struct MovieDetailRowItem: View {
    let movie: Movie
    var onSelect: () -> Void
    #if os(macOS)
    var focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    var focusTarget: MovieDetailFocusTarget
    #endif

    private var presentation: MovieCrosslineItemPresentation {
        MovieCrosslineState.presentation(for: movie)
    }

    var body: some View {
        #if os(macOS)
        MacFocusableLink(id: focusTarget, focusedId: focusedItem) {
            onSelect()
        } label: {
            movieContent
        }
        .contextMenu { MovieContextMenu(movieId: movie.id) }
        .accessibilityIdentifier("movieDetail.crossline.movie.\(movie.id)")
        #else
        Button(action: onSelect) {
            movieContent
        }
        .buttonStyle(.plain)
        .contextMenu { MovieContextMenu(movieId: movie.id) }
        .accessibilityIdentifier("movieDetail.crossline.movie.\(movie.id)")
        #endif
    }

    private var movieContent: some View {
        VStack(alignment: .center) {
            ZStack(alignment: .topLeading) {
                MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: presentation.posterPath,
                                                                                size: .medium),
                                 posterSize: .medium)
                ListImage(movieId: movie.id)

            }.fixedSize()
            Text(presentation.title)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(1)
            PopularityBadge(score: presentation.popularityScore)
        }.frame(width: 120, height: 240)
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return NavigationStack {
        MovieCrosslineRow(title: "Sample",
                          movies: [sampleMovie, sampleMovie],
                          onSelectMovie: { _ in },
                          onSelectSeeAll: {},
                          focusedItem: $item,
                          movieFocusTarget: { .similarMovie($0) },
                          seeAllFocusTarget: .similarSeeAll)
    }
}
#else
#Preview {
    NavigationStack {
        MovieCrosslineRow(title: "Sample",
                          movies: [sampleMovie, sampleMovie],
                          onSelectMovie: { _ in },
                          onSelectSeeAll: {})
    }
}
#endif

//
//  MovieRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend
import UI

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
    #if os(macOS) || targetEnvironment(macCatalyst)
    @FocusState private var focusedId: Int?
    private let seeAllSentinel = -999
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                Spacer()
                Button(action: {
                    onSelectSeeAll()
                }) {
                    Text("See all")
                        .foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                #if os(macOS) || targetEnvironment(macCatalyst)
                .focused($focusedId, equals: seeAllSentinel)
                #endif
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(self.movies) { movie in
                        MovieDetailRowItem(movie: movie) {
                            onSelectMovie(movie.id)
                        }
                    }
                }.padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

struct MovieDetailRowItem: View {
    let movie: Movie
    var onSelect: () -> Void

    private var presentation: MovieCrosslineItemPresentation {
        MovieCrosslineState.presentation(for: movie)
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        Button(action: onSelect) {
            movieContent
        }
        .buttonStyle(.plain)
        #if os(macOS) || targetEnvironment(macCatalyst)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) { onSelect(); return .handled }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in onSelect(); return .handled }
        .catalystFocusHighlight(isFocused: isFocused)
        #endif
        .contextMenu{ MovieContextMenu(movieId: movie.id) }
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

#if DEBUG
struct MovieDetailRow_Previews : PreviewProvider {
    static var previews: some View {
        NavigationView {
            MovieCrosslineRow(title: "Sample",
                              movies: [sampleMovie, sampleMovie],
                              onSelectMovie: { _ in },
                              onSelectSeeAll: {})
        }
    }
}
#endif

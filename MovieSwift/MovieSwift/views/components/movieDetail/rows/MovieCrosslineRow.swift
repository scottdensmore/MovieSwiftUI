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

struct MovieCrosslineRow : View {
    let title: String
    let movies: [Movie]
    @Binding var navigationRoute: MoviesListNavigationRoute?

    @State private var selectedMovieId: Int?
    @State private var showSeeAll = false
    #if targetEnvironment(macCatalyst)
    @FocusState private var focusedId: Int?
    private let seeAllSentinel = -999
    #endif

    private var listView: some View {
        MoviesList(movies: movies.map{ $0.id },
                   displaySearch: false,
                   pageListener: nil,
                   navigationRoute: $navigationRoute)
            .navigationBarTitle(title)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                Spacer()
                Button(action: {
                    showSeeAll = true
                }) {
                    Text("See all")
                        .foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                #if targetEnvironment(macCatalyst)
                .focused($focusedId, equals: seeAllSentinel)
                #endif
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(self.movies) { movie in
                        MovieDetailRowItem(movie: movie) {
                            selectedMovieId = movie.id
                        }
                    }
                }.padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
        .navigationDestination(item: $selectedMovieId) { id in
            MovieDetail(movieId: id)
        }
        .navigationDestination(isPresented: $showSeeAll) {
            listView
        }
    }
}

struct MovieDetailRowItem: View {
    let movie: Movie
    var onSelect: () -> Void

    #if targetEnvironment(macCatalyst)
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        Button(action: onSelect) {
            movieContent
        }
        .buttonStyle(.plain)
        #if targetEnvironment(macCatalyst)
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
                MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: movie.poster_path,
                                                                                size: .medium),
                                 posterSize: .medium)
                ListImage(movieId: movie.id)

            }.fixedSize()
            Text(movie.userTitle)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(1)
            PopularityBadge(score: Int(movie.vote_average * 10))
        }.frame(width: 120, height: 240)
    }
}

#if DEBUG
struct MovieDetailRow_Previews : PreviewProvider {
    static var previews: some View {
        NavigationView {
            MovieCrosslineRow(title: "Sample",
                              movies: [sampleMovie, sampleMovie],
                              navigationRoute: .constant(nil))
        }
    }
}
#endif

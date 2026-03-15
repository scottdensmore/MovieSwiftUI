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

    #if targetEnvironment(macCatalyst)
    @State private var selectedMovieId: Int?
    @State private var showSeeAll = false
    @FocusState private var focusedId: Int?
    private let seeAllSentinel = -999
    #endif

    private var listView: some View {
        MoviesList(movies: movies.map{ $0.id },
                   displaySearch: false,
                   pageListener: nil).navigationBarTitle(title)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .titleStyle()
                    .padding(.leading)
                #if targetEnvironment(macCatalyst)
                CatalystFocusableLink(id: seeAllSentinel, focusedId: $focusedId) {
                    showSeeAll = true
                } label: {
                    Text("See all")
                        .foregroundColor(.steam_blue)
                }
                #else
                NavigationLink(destination: listView) {
                    Text("See all")
                        .foregroundColor(.steam_blue)
                }
                #endif
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 32) {
                    ForEach(self.movies) { movie in
                        #if targetEnvironment(macCatalyst)
                        MovieDetailRowItem(movie: movie) {
                            selectedMovieId = movie.id
                        }
                        #else
                        MovieDetailRowItem(movie: movie)
                        #endif
                    }
                }.padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
        #if targetEnvironment(macCatalyst)
        .navigationDestination(item: $selectedMovieId) { id in
            MovieDetail(movieId: id)
        }
        .navigationDestination(isPresented: $showSeeAll) {
            listView
        }
        #endif
    }
}

struct MovieDetailRowItem: View {
    let movie: Movie

    #if targetEnvironment(macCatalyst)
    var onSelect: (() -> Void)? = nil
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        #if targetEnvironment(macCatalyst)
        Button(action: { onSelect?() }) {
            movieContent
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($isFocused)
        .onKeyPress(.return) { onSelect?(); return .handled }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in onSelect?(); return .handled }
        .catalystFocusHighlight(isFocused: isFocused)
        .contextMenu { MovieContextMenu(movieId: movie.id) }
        #else
        NavigationLink(destination: MovieDetail(movieId: movie.id)) {
            movieContent
        }.contextMenu{ MovieContextMenu(movieId: movie.id) }
        #endif
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
            MovieCrosslineRow(title: "Sample", movies: [sampleMovie, sampleMovie])
        }
    }
}
#endif

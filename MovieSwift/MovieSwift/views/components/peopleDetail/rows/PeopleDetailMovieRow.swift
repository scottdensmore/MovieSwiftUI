//
//  PeopleDetailMovieRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct PeopleDetailMovieRow : View {
    let movie: Movie
    let role: String
    
    let onMovieContextMenu: () -> Void
    
    var body: some View {
        HStack {
            ZStack {
                MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: movie.poster_path,
                                                                                size: .small),
                                 posterSize: .small)
                ListImage(movieId: movie.id)
            }.fixedSize()
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .accessibilityIdentifier("peopleDetail.movie.\(movie.id)")
                Text(role)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .accessibilityIdentifier("peopleDetail.movie.\(movie.id)")
        .accessibilityElement(children: .combine)
        .contextMenu{ MovieContextMenu(movieId: movie.id, onAction: onMovieContextMenu) }
    }
}

#if DEBUG
struct PeopleDetailMovieRow_Previews : PreviewProvider {
    static var previews: some View {
        PeopleDetailMovieRow(movie: sampleMovie, role: "Test", onMovieContextMenu: {
            
        })
    }
}
#endif

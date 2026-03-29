//
//  CustomListCoverRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 08/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct CustomListCoverRow : View {
    let movie: Movie
    
    var body: some View {
        MovieBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: movie.backdrop_path ?? movie.poster_path,
                                                                          size: .medium))
    }
}

#Preview {
    CustomListCoverRow(movie: sampleMovie)
}

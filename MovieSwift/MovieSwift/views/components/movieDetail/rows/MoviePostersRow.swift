//
//  MoviePostersRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 22/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct MoviePosterPresentation: Identifiable {
    let image: ImageData

    var id: String {
        image.file_path
    }

    var path: String {
        image.file_path
    }
}

enum MoviePostersState {
    static func presentations(from posters: [ImageData]) -> [MoviePosterPresentation] {
        posters.map(MoviePosterPresentation.init(image:))
    }

    static func selectedPoster(afterSelecting poster: MoviePosterPresentation) -> ImageData {
        poster.image
    }
}

struct MoviePostersRow : View {
    let posters: [ImageData]
    @Binding var selectedPoster: ImageData?
    #if os(macOS)
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    #endif

    private var presentations: [MoviePosterPresentation] {
        MoviePostersState.presentations(from: posters)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Other posters")
                .titleStyle()
                .padding(.leading)
            #if os(macOS)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 32) {
                        ForEach(Array(presentations.enumerated()), id: \.offset) { index, poster in
                            MacFocusableLink(id: .poster(poster.path), focusedId: focusedItem) {
                                withAnimation {
                                    selectedPoster = MoviePostersState.selectedPoster(afterSelecting: poster)
                                }
                            } label: {
                                MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: poster.path,
                                                                                                size: .medium),
                                                 posterSize: .medium)
                            }
                            .id(index)
                            .padding(.vertical)
                        }
                    }
                    .padding(.leading)
                }
                .clipped()
                .onChange(of: focusedItem.wrappedValue) { _, newValue in
                    guard let newValue,
                          let index = presentations.firstIndex(where: { .poster($0.path) == newValue }) else {
                        return
                    }
                    withAnimation {
                        scrollProxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            #else
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 32) {
                    ForEach(presentations) { poster in
                        MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: poster.path,
                                                                                        size: .medium),
                                         posterSize: .medium)
                            .onTapGesture {
                                withAnimation {
                                    self.selectedPoster = MoviePostersState.selectedPoster(afterSelecting: poster)
                                }
                        }
                        .padding(.vertical)
                    }
                }
                .padding(.leading)
            }
            #endif
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return MoviePostersRow(posters: [ImageData(aspect_ratio: 0.666666666666667,
                                               file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                               height: 720,
                                               width: 1280)],
                           selectedPoster: .constant(nil),
                           focusedItem: $item)
}
#else
#Preview {
    MoviePostersRow(posters: [ImageData(aspect_ratio: 0.666666666666667,
                                         file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                         height: 720,
                                         width: 1280)],
                    selectedPoster: .constant(nil))
}
#endif

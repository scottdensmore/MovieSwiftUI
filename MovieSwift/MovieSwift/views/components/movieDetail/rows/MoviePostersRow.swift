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

    #if os(macOS) || targetEnvironment(macCatalyst)
    @FocusState private var focusedPosterId: String?
    #endif

    private var presentations: [MoviePosterPresentation] {
        MoviePostersState.presentations(from: posters)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Other posters")
                .titleStyle()
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 32) {
                    ForEach(presentations) { poster in
                        #if os(macOS) || targetEnvironment(macCatalyst)
                        Button {
                            withAnimation {
                                selectedPoster = MoviePostersState.selectedPoster(afterSelecting: poster)
                            }
                        } label: {
                            MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: poster.path,
                                                                                            size: .medium),
                                             posterSize: .medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(focusedPosterId == poster.id ? Color.accentColor : .clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(.plain)
                        .focusable()
                        .focused($focusedPosterId, equals: poster.id)
                        .onKeyPress(.return) { withAnimation { selectedPoster = MoviePostersState.selectedPoster(afterSelecting: poster) }; return .handled }
                        .onKeyPress(characters: .init(charactersIn: " ")) { _ in withAnimation { selectedPoster = MoviePostersState.selectedPoster(afterSelecting: poster) }; return .handled }
                        .focusEffectDisabled()
                        .padding(.vertical)
                        #else
                        MoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: poster.path,
                                                                                        size: .medium),
                                         posterSize: .medium)
                            .onTapGesture {
                                withAnimation {
                                    self.selectedPoster = MoviePostersState.selectedPoster(afterSelecting: poster)
                                }
                        }
                        .padding(.vertical)
                        #endif
                    }
                }
                .padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

#if DEBUG
struct MoviePostersRow_Previews : PreviewProvider {
    static var previews: some View {
        MoviePostersRow(posters: [ImageData(aspect_ratio: 0.666666666666667,
                                             file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                             height: 720,
                                             width: 1280)],
                        selectedPoster: .constant(nil))
    }
}
#endif

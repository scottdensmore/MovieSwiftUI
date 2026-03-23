//
//  MoviePostersCarouselView.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 23/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct ImagesCarouselView : View {
    let posters: [ImageData]
    @Binding var selectedPoster: ImageData?

    private var selectedPosterId: Binding<String> {
        Binding(
            get: { selectedPoster?.id ?? posters.first?.id ?? "" },
            set: { newValue in
                selectedPoster = posters.first(where: { $0.id == newValue })
            }
        )
    }

    private func posterPage(_ poster: ImageData) -> some View {
        BigMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: poster.file_path,
                                                                           size: .medium))
            .tag(poster.id)
            .padding(.horizontal, 24)
    }

    private func carousel(reader: GeometryProxy) -> some View {
        TabView(selection: selectedPosterId) {
            ForEach(posters) { poster in
                posterPage(poster)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: posters.count > 1 ? .automatic : .never))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .interactive))
        .frame(width: reader.size.width,
               height: min(reader.size.height * 0.8, 460))
    }

    private func closeButton() -> some View {
        Button(action: {
            selectedPoster = nil
        }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
        }
        .padding()
    }

    var body: some View {
        if !posters.isEmpty {
            GeometryReader { reader in
                ZStack {
                    Color.black.opacity(0.72)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedPoster = nil
                        }

                    VStack(spacing: 20) {
                        Spacer()
                        carousel(reader: reader)
                        closeButton()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

#if DEBUG
struct MoviePostersCarouselView_Previews : PreviewProvider {
    static var previews: some View {
        ImagesCarouselView(posters: [ImageData(aspect_ratio: 0.666666666666667,
                                                      file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                      height: 720,
                                                      width: 1280),
                                           ImageData(aspect_ratio: 0.666666666666667,
                                                      file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                      height: 720,
                                                      width: 1280),
                                           ImageData(aspect_ratio: 0.666666666666667,
                                                      file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                      height: 720,
                                                      width: 1280),
                                           ImageData(aspect_ratio: 0.666666666666667,
                                                      file_path: "/fpemzjF623QVTe98pCVlwwtFC5N.jpg",
                                                      height: 720,
                                                      width: 1280)],
                                 selectedPoster: .constant(nil))
    }
}
#endif

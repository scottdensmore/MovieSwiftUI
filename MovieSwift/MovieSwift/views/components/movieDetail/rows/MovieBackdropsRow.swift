//
//  MovieBackdropsRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 22/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct MovieBackdropsRow : View {
    let backdrops: [ImageData]

    #if targetEnvironment(macCatalyst)
    @FocusState private var focusedBackdropId: String?
    #endif

    var body: some View {
        VStack(alignment: .leading) {
            Text("Images")
                .titleStyle()
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(self.backdrops) { backdrop in
                        #if targetEnvironment(macCatalyst)
                        MovieBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: backdrop.file_path,
                                                                                          size: .original))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(focusedBackdropId == backdrop.file_path ? Color.accentColor : .clear, lineWidth: 3)
                            )
                            .focusable()
                            .focused($focusedBackdropId, equals: backdrop.file_path)
                            .focusEffectDisabled()
                        #else
                        MovieBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: backdrop.file_path,
                                                                                          size: .original))
                        #endif
                    }
                }.padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.top)
        .padding(.bottom)
    }
}

#if DEBUG
struct MovieBackdropsRow_Previews : PreviewProvider {
    static var previews: some View {
        MovieBackdropsRow(backdrops: [ImageData(aspect_ratio: 1.7,
                                             file_path: "/fCayJrkfRaCRCTh8GqN30f8oyQF.jpg",
                                             height: 1200,
                                             width: 1800)])
    }
}
#endif

//
//  PeopleDetailImagesRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 06/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

enum PeopleDetailImagesState {
    static func accessibilityIdentifier(for index: Int) -> String {
        "peopleDetail.image.\(index)"
    }

    static func accessibilityLabel(for index: Int, total: Int) -> String {
        "Image \(index + 1) of \(total)"
    }
}

struct PeopleDetailImagesRow : View {
    let images: [ImageData]
    @Binding var selectedPoster: ImageData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Images")
                .titleStyle()
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 16) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Button(action: {
                            withAnimation {
                                self.selectedPoster = image
                            }
                        }) {
                            PeopleImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: image.file_path, size: .cast))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(PeopleDetailImagesState.accessibilityIdentifier(for: index))
                        .accessibilityLabel(PeopleDetailImagesState.accessibilityLabel(for: index, total: images.count))
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.leading)
            }
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

#Preview {
    PeopleDetailImagesRow(images: sampleCasts.first!.images ?? [], selectedPoster: .constant(nil))
}

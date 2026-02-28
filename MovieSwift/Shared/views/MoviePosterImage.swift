//
//  MoviePosterImage.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 13/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import Backend

struct MoviePosterImage: View {
    @ObservedObject var imageLoader: ImageLoader
    let posterSize: PosterStyle.Size
    
    var body: some View {
        if let image = imageLoader.image {
            Image(uiImage: image)
                .resizable()
                .renderingMode(.original)
                .posterStyle(loaded: true, size: posterSize)
                .animation(.easeInOut, value: imageLoader.image != nil)
                .transition(.opacity)
        } else {
            Rectangle()
                .foregroundColor(.gray)
                .posterStyle(loaded: false, size: posterSize)
        }
    }
}

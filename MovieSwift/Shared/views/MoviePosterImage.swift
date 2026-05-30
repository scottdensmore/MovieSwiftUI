import SwiftUI
import Backend

struct MoviePosterImage: View {
    var imageLoader: ImageLoader
    let posterSize: PosterStyle.Size

    var body: some View {
        if let imageData = imageLoader.image {
            DataImage(data: imageData, renderingMode: .original)
                .posterStyle(loaded: true, size: posterSize)
                .animation(.easeInOut, value: imageLoader.image != nil)
                .transition(.opacity)
        } else {
            Rectangle()
                .foregroundStyle(.gray)
                .posterStyle(loaded: false, size: posterSize)
        }
    }
}

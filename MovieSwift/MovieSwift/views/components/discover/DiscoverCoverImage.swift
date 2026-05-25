import SwiftUI
import Backend

struct DiscoverPosterStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .aspectRatio(0.66, contentMode: .fit)
            .frame(maxWidth: 245)
            .cornerRadius(5)
    }
}

extension View {
    func discoverPosterStyle() -> some View {
        ModifiedContent(content: self, modifier: DiscoverPosterStyle())
    }
}

struct DiscoverCoverImage : View {
    @ObservedObject var imageLoader: ImageLoader
        
    var body: some View {
        if let imageData = imageLoader.image {
            DataImage(data: imageData, renderingMode: .original)
                .discoverPosterStyle()
        } else if imageLoader.path == nil {
            Rectangle()
                .foregroundStyle(.gray)
                .discoverPosterStyle()
        } else {
            Rectangle()
                .foregroundStyle(.clear)
                .frame(width: 50, height: 50)
        }
    }
}


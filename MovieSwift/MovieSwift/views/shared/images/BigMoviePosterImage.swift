import SwiftUI
import Backend

struct BigMoviePosterImage : View {
    @ObservedObject var imageLoader: ImageLoader
    @State var isImageLoaded = false
    
    var body: some View {
        ZStack(alignment: .center) {
            if let imageData = self.imageLoader.image {
                DataImage(data: imageData, renderingMode: .original)
                    .posterStyle(loaded: true, size: .big)
                    .scaleEffect(self.isImageLoaded ? 1 : 0.6)
                    .animation(.spring(), value: self.isImageLoaded)
                    .onAppear{
                        self.isImageLoaded = true
                }
            } else {
                Rectangle()
                    .foregroundStyle(.gray)
                    .posterStyle(loaded: false, size: .big)
            }
            }
    }
}

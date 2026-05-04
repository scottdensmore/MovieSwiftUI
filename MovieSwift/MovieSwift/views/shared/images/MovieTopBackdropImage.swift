import SwiftUI
import Backend

struct MovieTopBackdropImage : View {
    @ObservedObject var imageLoader: ImageLoader
    @State var isImageLoaded = false
    
    var fill: Bool = false
    var height: CGFloat = 250
          
    var body: some View {
        if let imageData = imageLoader.image {
            DataImage(data: imageData)
                .blur(radius: 50, opaque: true)
                .overlay(Color.black.opacity(0.3))
                .frame(height: fill ? 50 : height)
                .onAppear{
                    isImageLoaded = true
                }
                .animation(.easeInOut, value: imageLoader.image != nil)
                .transition(.opacity)
        } else {
            Rectangle()
                .foregroundColor(.black)
                .opacity(0.3)
                .frame(height: fill ? 50 : height)
        }
    }
}

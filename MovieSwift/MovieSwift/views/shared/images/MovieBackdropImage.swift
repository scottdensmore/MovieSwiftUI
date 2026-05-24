import SwiftUI
import Backend

struct MovieBackdropImage : View {
    enum DisplayMode {
        case background, normal
    }
    
    @ObservedObject var imageLoader: ImageLoader
    @State var isImageLoaded = false
    @State var displayMode: DisplayMode = .normal
    
    var body: some View {
        ZStack {
            if let imageData = self.imageLoader.image {
                DataImage(data: imageData, renderingMode: .original)
                    .frame(width: 280, height: displayMode == .normal ? 168 : 50)
                    .animation(.easeInOut, value: self.imageLoader.image != nil)
                    .onAppear{
                        DispatchQueue.main.async {
                            self.isImageLoaded = true
                        }
                }
            } else {
                Rectangle()
                    .foregroundColor(.gray)
                    .opacity(0.1)
                    .frame(width: 280, height: displayMode == .normal ? 168 : 50)
            }
        }
    }
}

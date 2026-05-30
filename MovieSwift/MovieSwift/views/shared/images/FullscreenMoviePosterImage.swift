import SwiftUI
import Backend

struct FullscreenMoviePosterImage: View {
    var imageLoader: ImageLoader

    var body: some View {
        ZStack {
            if let imageData = self.imageLoader.image {
                ZStack {
                    GeometryReader { geometry in
                        DataImage(data: imageData)
                            .blur(radius: 50)
                            .overlay(Color.black.opacity(0.5))
                            .frame(width: geometry.frame(in: .global).width,
                                   height: geometry.frame(in: .global).height)
                    }
                }.edgesIgnoringSafeArea(.all)
            } else {
                ZStack {
                    GeometryReader { geometry in
                        Rectangle()
                            .foregroundStyle(Color.black.opacity(0.8))
                            .frame(width: geometry.frame(in: .global).width,
                                   height: geometry.frame(in: .global).height)
                    }
                }.edgesIgnoringSafeArea(.all)

            }
        }
    }
}

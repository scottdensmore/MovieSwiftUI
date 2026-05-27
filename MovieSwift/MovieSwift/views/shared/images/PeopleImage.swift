import SwiftUI
import Backend

struct PeopleImage : View {
    @ObservedObject var imageLoader: ImageLoader

    var body: some View {
        ZStack {
            if let imageData = self.imageLoader.image {
                DataImage(data: imageData, renderingMode: .original)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(width: 60, height: 90)
            } else {
                Rectangle()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(width: 60, height: 90)
                    .foregroundStyle(.gray)
                    .opacity(0.1)
            }
        }
    }
}


struct BigPeopleImage : View {
    @ObservedObject var imageLoader: ImageLoader

    var body: some View {
        ZStack {
            if let imageData = self.imageLoader.image {
                DataImage(data: imageData, renderingMode: .original)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(width: 100, height: 150)
            } else {
                Rectangle()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(width: 100, height: 150)
                    .foregroundStyle(.gray)
                    .opacity(0.1)
            }
        }
    }
}

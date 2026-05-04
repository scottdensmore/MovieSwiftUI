import SwiftUI
import Backend

struct CustomListRow : View {
    let list: CustomList
    let coverMovie: Movie?
    
    var body: some View {
        HStack(spacing: 12) {
            SmallMoviePosterImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: coverMovie?.poster_path,
                                                                                 size: .medium))
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name).font(.headline).fontWeight(.bold)
                Text("\(list.movies.count) movies").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets())
            .frame(minHeight: 66)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct SmallMoviePosterImage : View {
    @ObservedObject var imageLoader: ImageLoader
    @State var isImageLoaded = false
    
    var body: some View {
        ZStack {
            if let imageData = self.imageLoader.image {
                DataImage(data: imageData, renderingMode: .original)
                    .frame(width: 33, height: 50)
                    .cornerRadius(3)
                    .opacity(isImageLoaded ? 1 : 0.1)
                    .shadow(radius: 2)
                    .animation(.easeInOut, value: self.isImageLoaded)
                    .onAppear{
                        self.isImageLoaded = true
                }
            } else {
                Rectangle()
                    .foregroundColor(.gray)
                    .frame(width: 33, height: 50)
                    .cornerRadius(3)
                    .opacity(0.3)
            }
            }
    }
}

#Preview {
    CustomListRow(list: CustomList(id: 0, name: "Wow", cover: 0, movies: [0]),
                  coverMovie: sampleMovie)
}

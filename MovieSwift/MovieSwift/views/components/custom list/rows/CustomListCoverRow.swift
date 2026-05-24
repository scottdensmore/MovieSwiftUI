import SwiftUI
import Backend
import MovieSwiftFluxCore

struct CustomListCoverRow : View {
    let movie: Movie
    
    var body: some View {
        MovieBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: movie.backdrop_path ?? movie.poster_path,
                                                                          size: .medium))
    }
}

#Preview {
    CustomListCoverRow(movie: sampleMovie)
}

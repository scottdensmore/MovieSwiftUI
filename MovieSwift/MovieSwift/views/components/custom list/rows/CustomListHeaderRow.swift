import SwiftUI
import Backend
import MovieSwiftFluxCore

struct CustomListHeaderRow : View {
    @Binding var sorting: MoviesSort
    
    let list: CustomList
    let coverBackdropMovie: Movie?
    
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.name)
                .font(.FjallaOne(size: 40))
                .foregroundStyle(Color.steam_gold)
            Text("\(list.movies.count) movies sorted \(sorting.title())")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding()
    }
    
    var body: some View {
        Group {
            if coverBackdropMovie != nil {
                ZStack(alignment: .bottomLeading) {
                    MovieTopBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: coverBackdropMovie?.backdrop_path ?? coverBackdropMovie?.poster_path,
                                                                                         size: .original),
                                          height: 200)
                    headerText
                }
                .frame(height: 200)
            } else {
                headerText
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .background(Color.clear)
            }
        }
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    CustomListHeaderRow(sorting: .constant(.byAddedDate),
                        list: CustomList(id: 0, name: "Wow", cover: 0, movies: [0]),
                        coverBackdropMovie: sampleMovie)
}

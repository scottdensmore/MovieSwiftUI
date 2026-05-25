import SwiftUI
import MovieSwiftFluxCore

struct MovieOverview : View {
    let movie: Movie
    @State var isOverviewExpanded: Bool = false

    #if os(macOS)
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview:")
                .titleStyle()
                .lineLimit(1)
            Text(movie.overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(self.isOverviewExpanded ? nil : 4)
                .onTapGesture {
                    withAnimation {
                        self.isOverviewExpanded.toggle()
                    }
            }
            #if os(macOS)
            MacFocusableLink(id: .readMoreButton, focusedId: focusedItem) {
                withAnimation {
                    self.isOverviewExpanded.toggle()
                }
            } label: {
                Text(self.isOverviewExpanded ? "Less" : "Read more")
                    .lineLimit(1)
                    .foregroundStyle(Color.steam_blue)
            }
            #else
            Button(action: {
                withAnimation {
                    self.isOverviewExpanded.toggle()
                }
            }, label: {
                Text(self.isOverviewExpanded ? "Less" : "Read more")
                    .lineLimit(1)
                    .foregroundStyle(Color.steam_blue)
            })
            #endif
        }
        .padding(.leading)
        .padding(.trailing)
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return MovieOverview(movie: sampleMovie, focusedItem: $item)
}
#else
#Preview {
    MovieOverview(movie: sampleMovie)
}
#endif

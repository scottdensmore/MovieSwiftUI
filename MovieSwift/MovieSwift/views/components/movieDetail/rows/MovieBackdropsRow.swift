import SwiftUI
import Backend

struct MovieBackdropPresentation: Identifiable {
    let image: ImageData

    var id: String {
        image.file_path
    }

    var path: String {
        image.file_path
    }
}

enum MovieBackdropsState {
    static func presentations(from backdrops: [ImageData]) -> [MovieBackdropPresentation] {
        backdrops.map(MovieBackdropPresentation.init(image:))
    }
}

struct MovieBackdropsRow : View {
    let backdrops: [ImageData]
    #if os(macOS)
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    @Binding var selectedBackdrop: ImageData?
    #endif

    private var presentations: [MovieBackdropPresentation] {
        MovieBackdropsState.presentations(from: backdrops)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Images")
                .titleStyle()
                .padding(.leading)
            #if os(macOS)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(presentations.enumerated()), id: \.offset) { index, backdrop in
                            MacFocusableLink(id: .backdrop(backdrop.path), focusedId: focusedItem) {
                                withAnimation {
                                    selectedBackdrop = backdrop.image
                                }
                            } label: {
                                MovieBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(
                                    path: backdrop.path,
                                    size: .original))
                            }
                            .id(index)
                        }
                    }.padding(.leading)
                }
                .clipped()
                .onChange(of: focusedItem.wrappedValue) { _, newValue in
                    guard let newValue,
                          let index = presentations.firstIndex(where: { .backdrop($0.path) == newValue }) else {
                        return
                    }
                    withAnimation {
                        scrollProxy.scrollTo(index, anchor: .center)
                    }
                }
            }
            #else
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(presentations) { backdrop in
                        MovieBackdropImage(imageLoader: ImageLoaderCache.shared.loaderFor(path: backdrop.path,
                                                                                          size: .original))
                    }
                }.padding(.leading)
            }
            #endif
        }
        .listRowInsets(EdgeInsets())
        .padding(.top)
        .padding(.bottom)
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return MovieBackdropsRow(backdrops: [ImageData(aspect_ratio: 1.7,
                                                   file_path: "/fCayJrkfRaCRCTh8GqN30f8oyQF.jpg",
                                                   height: 1200,
                                                   width: 1800)],
                             focusedItem: $item,
                             selectedBackdrop: .constant(nil))
}
#else
#Preview {
    MovieBackdropsRow(backdrops: [ImageData(aspect_ratio: 1.7,
                                         file_path: "/fCayJrkfRaCRCTh8GqN30f8oyQF.jpg",
                                         height: 1200,
                                         width: 1800)])
}
#endif

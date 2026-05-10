import SwiftUI
import UI
import MovieSwiftFluxCore

struct MovieKeywords : View {
    let keywords: [Keyword]
    #if os(macOS)
    let onSelectKeyword: (Keyword) -> Void
    let focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keywords")
                .titleStyle()
                .padding(.leading)
            #if os(macOS)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(keywords) { keyword in
                            MacFocusableLink(id: .keyword(keyword.id), focusedId: focusedItem) {
                                onSelectKeyword(keyword)
                            } label: {
                                RoundedBadge(text: keyword.name, color: .steam_background)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                            }
                            .id(keyword.id)
                        }
                    }
                    .padding(.leading)
                    .padding(.trailing)
                    .padding(.vertical, 4)
                }
                .clipped()
                .onChange(of: focusedItem.wrappedValue) { _, newValue in
                    if case let .keyword(id) = newValue {
                        withAnimation {
                            scrollProxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
            #else
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(keywords) { keyword in
                        NavigationLink(destination: MovieKeywordList(keyword: keyword)) {
                            RoundedBadge(text: keyword.name, color: .steam_background)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.leading)
                .padding(.trailing)
                .padding(.vertical, 4)
            }
            #endif
        }
        .listRowInsets(EdgeInsets())
        .padding(.vertical)
    }
}

#if os(macOS)
#Preview {
    @FocusState var item: MovieDetailFocusTarget?
    return MovieKeywords(keywords: [Keyword(id: 0, name: "Test")],
                         onSelectKeyword: { _ in },
                         focusedItem: $item)
}
#else
#Preview {
    MovieKeywords(keywords: [Keyword(id: 0, name: "Test")])
}
#endif

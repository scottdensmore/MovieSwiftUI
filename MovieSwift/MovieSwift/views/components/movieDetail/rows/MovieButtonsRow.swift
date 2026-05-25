import SwiftUI
import SwiftUIFlux
import Backend
import UI
import MovieSwiftFluxCore

enum MovieButtonsToggleAction: Equatable {
    case addToWishlist(movie: Int)
    case removeFromWishlist(movie: Int)
    case addToSeenlist(movie: Int)
    case removeFromSeenlist(movie: Int)

    static func wishlistAction(movieId: Int, isInWishlist: Bool) -> MovieButtonsToggleAction {
        isInWishlist ? .removeFromWishlist(movie: movieId) : .addToWishlist(movie: movieId)
    }

    static func seenlistAction(movieId: Int, isInSeenlist: Bool) -> MovieButtonsToggleAction {
        isInSeenlist ? .removeFromSeenlist(movie: movieId) : .addToSeenlist(movie: movieId)
    }
}

struct MovieButtonsRow: ConnectedView {
    let movieId: Int
    @Binding var showCustomListSheet: Bool
    #if os(macOS)
    var focusedItem: FocusState<MovieDetailFocusTarget?>.Binding
    #endif
    
    struct Props {
        let isInWishlist: Bool
        let isInSeenlist: Bool
        let isInCustomList: Bool
        let onWishlistTap: () -> Void
        let onSeenlistTap: () -> Void
    }
    
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let isInWishlist = state.moviesState.wishlist.contains(movieId)
        let isInSeenlist = state.moviesState.seenlist.contains(movieId)
        return Props(isInWishlist: isInWishlist,
                     isInSeenlist: isInSeenlist,
                     isInCustomList: state.moviesState.customLists.contains(where:
                                                                               { (_, value) -> Bool in
                                                                                   value.movies.contains(self.movieId)
                                                                               }),
                     onWishlistTap: {
                        switch MovieButtonsToggleAction.wishlistAction(movieId: self.movieId, isInWishlist: isInWishlist) {
                        case let .addToWishlist(movie):
                            dispatch(MoviesActions.AddToWishlist(movie: movie))
                        case let .removeFromWishlist(movie):
                            dispatch(MoviesActions.RemoveFromWishlist(movie: movie))
                        default:
                            break
                        }
                     },
                     onSeenlistTap: {
                        switch MovieButtonsToggleAction.seenlistAction(movieId: self.movieId, isInSeenlist: isInSeenlist) {
                        case let .addToSeenlist(movie):
                            dispatch(MoviesActions.AddToSeenList(movie: movie))
                        case let .removeFromSeenlist(movie):
                            dispatch(MoviesActions.RemoveFromSeenList(movie: movie))
                        default:
                            break
                        }
                     })
    }
    
    func body(props: Props) -> some View {
        HStack(alignment: .center, spacing: 8) {
            #if os(macOS)
            macButton(id: .wishlistButton,
                           text: props.isInWishlist ? "In wishlist" : "Wishlist",
                           systemImageName: "heart",
                           color: .pink,
                           isOn: props.isInWishlist,
                           action: props.onWishlistTap)
            
            macButton(id: .seenlistButton,
                           text: props.isInSeenlist ? "Seen" : "Seenlist",
                           systemImageName: "eye",
                           color: .green,
                           isOn: props.isInSeenlist,
                           action: props.onSeenlistTap)
            
            macButton(id: .customListButton,
                           text: "List",
                           systemImageName: "pin",
                           color: .steam_gold,
                           isOn: props.isInCustomList,
                           action: {
                               self.showCustomListSheet = true
                           })
            #else
            BorderedButton(text: props.isInWishlist ? "In wishlist" : "Wishlist",
                           systemImageName: "heart",
                           color: .pink,
                           isOn: props.isInWishlist,
                           action: props.onWishlistTap)
            
            BorderedButton(text: props.isInSeenlist ? "Seen" : "Seenlist",
                           systemImageName: "eye",
                           color: .green,
                           isOn: props.isInSeenlist,
                           action: props.onSeenlistTap)
            
            BorderedButton(text: "List",
                           systemImageName: "pin",
                           color: .steam_gold,
                           isOn: props.isInCustomList,
                           action: {
                            self.showCustomListSheet = true
                           })
            #endif
        }
        .padding(.leading)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(), value: props.isInWishlist || props.isInSeenlist || props.isInCustomList)
    }

    #if os(macOS)
    private func macButton(id: MovieDetailFocusTarget,
                                text: String,
                                systemImageName: String,
                                color: Color,
                                isOn: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: systemImageName)
                    .foregroundStyle(isOn ? .white : color)
                Text(text)
                    .foregroundStyle(isOn ? .white : color)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: isOn ? 0 : 2)
                    .background(isOn ? color : .clear)
                    .cornerRadius(8)
            )
        }
        .buttonStyle(.plain)
        .focusable()
        .focused(focusedItem, equals: id)
        .onKeyPress(.return) {
            DispatchQueue.main.async {
                action()
            }
            return .handled
        }
        .onKeyPress(characters: .init(charactersIn: " ")) { _ in
            DispatchQueue.main.async {
                action()
            }
            return .handled
        }
        .macFocusHighlight(isFocused: focusedItem.wrappedValue == id)
    }
    #endif
}

#if DEBUG && os(macOS)
private struct MovieButtonsRowMacPreviewHost: View {
    @FocusState private var focusedItem: MovieDetailFocusTarget?

    var body: some View {
        MovieButtonsRow(movieId: 0,
                        showCustomListSheet: .constant(false),
                        focusedItem: $focusedItem)
            .environmentObject(sampleStore)
    }
}
#endif

#Preview {
    #if os(macOS)
    MovieButtonsRowMacPreviewHost()
    #else
    MovieButtonsRow(movieId: 0, showCustomListSheet: .constant(false)).environmentObject(sampleStore)
    #endif
}

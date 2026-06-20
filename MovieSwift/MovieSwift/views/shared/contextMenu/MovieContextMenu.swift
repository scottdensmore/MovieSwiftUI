import SwiftUI
import MovieSwiftFluxCore

// MARK: View
struct MovieContextMenu: ConnectedView {
    struct Props {
        let isInWishlist: Bool
        let isInSeenList: Bool
        let customLists: [Int: CustomList]
        let onAddToWishlist: () -> Void
        let onAddToSeenList: () -> Void
        let onAddToCustomList: (Int) -> Void
    }

    let movieId: Int

    var onAction: (() -> Void)?

    private func customListsView(props: Props) -> some View {
        ForEach(props.customLists.compactMap { $0.value }, id: \.id) { list in
            let isIn = list.movies.contains(self.movieId)
            let label = isIn ? "Remove from \(list.name)" : "Add to \(list.name)"
            Button(action: {
                props.onAddToCustomList(list.id)
                self.onAction?()
            }) {
                HStack {
                    Text(label)
                    Image(systemName: isIn ? "text.badge.xmark" : "text.badge.plus")
                        .imageScale(.small)
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityLabel(Text(label))
            .accessibilityIdentifier(AccessibilityID.MovieContextMenu.customList(list.id))
        }
    }

    func body(props: Props) -> some View {
        let wishlistLabel = props.isInWishlist ? "Remove from wishlist" : "Add to wishlist"
        let seenlistLabel = props.isInSeenList ? "Remove from seenlist" : "Add to seenlist"
        return VStack {
            Button(action: {
                props.onAddToWishlist()
                self.onAction?()
            }) {
                HStack {
                    Text(wishlistLabel)
                    Image(systemName: props.isInWishlist ? "heart.fill" : "heart")
                        .imageScale(.small)
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityLabel(Text(wishlistLabel))
            .accessibilityIdentifier(AccessibilityID.MovieContextMenu.wishlistToggle)
            Button(action: {
                props.onAddToSeenList()
                self.onAction?()
            }) {
                HStack {
                    Text(seenlistLabel)
                    Image(systemName: props.isInSeenList ? "eye.fill" : "eye")
                        .imageScale(.small)
                        .foregroundStyle(.primary)
                }
            }
            .accessibilityLabel(Text(seenlistLabel))
            .accessibilityIdentifier(AccessibilityID.MovieContextMenu.seenlistToggle)
            customListsView(props: props)
        }
    }

}

// MARK: - State to props
extension MovieContextMenu {
    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        let isInWishlist = state.moviesState.wishlist.contains(movieId)
        let isInSeenList = state.moviesState.seenlist.contains(movieId)
        let lists = state.moviesState.customLists
        return Props(isInWishlist: isInWishlist,
                     isInSeenList: isInSeenList,
                     customLists: lists,
                     onAddToWishlist: {
                        self.onAddToWishlist(isIn: isInWishlist, dispatch: dispatch)
        }, onAddToSeenList: {
            self.onAddToSeenlist(isIn: isInSeenList, dispatch: dispatch)
        }, onAddToCustomList: { list in
            let isIn = lists[list]?.movies.contains(self.movieId) == true
            self.onAddToCustomList(list: list, isIn: isIn, dispatch: dispatch)
        })
    }

}

// MARK: - Actions
extension MovieContextMenu {
    private func onAddToWishlist(isIn: Bool, dispatch: DispatchFunction) {
        if isIn {
            dispatch(MoviesActions.RemoveFromWishlist(movie: movieId))
        } else {
            dispatch(MoviesActions.AddToWishlist(movie: movieId))
        }
    }

    private func onAddToSeenlist(isIn: Bool, dispatch: DispatchFunction) {
        if isIn {
            dispatch(MoviesActions.RemoveFromSeenList(movie: movieId))
        } else {
            dispatch(MoviesActions.AddToSeenList(movie: movieId))
        }
    }

    private func onAddToCustomList(list: Int, isIn: Bool, dispatch: DispatchFunction) {
        if isIn {
            dispatch(MoviesActions.RemoveMovieFromCustomList(list: list, movie: movieId))
        } else {
            dispatch(MoviesActions.AddMovieToCustomList(list: list, movie: movieId))
        }
    }

}

#Preview {
    MovieContextMenu(movieId: 0).environment(sampleStore)
}

//
//  MovieButtonsRow.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/12/2020.
//  Copyright © 2020 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux
import Backend
import UI

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
        }
        .padding(.vertical, 8)
        .animation(.spring(), value: props.isInWishlist || props.isInSeenlist || props.isInCustomList)
    }
}

struct MovieButtonsRow_Previews: PreviewProvider {
    static var previews: some View {
        MovieButtonsRow(movieId: 0, showCustomListSheet: .constant(false)).environmentObject(sampleStore)
    }
}

//
//  ActionSheet.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 09/07/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftUIFlux

#if !os(macOS)
enum ActionSheetMovieListAction: Equatable {
    case addToWishlist(movie: Int)
    case removeFromWishlist(movie: Int)
    case addToSeenlist(movie: Int)
    case removeFromSeenlist(movie: Int)
    case addToCustomList(list: Int, movie: Int)
    case removeFromCustomList(list: Int, movie: Int)

    static func wishlist(movie: Int, isInWishlist: Bool) -> ActionSheetMovieListAction {
        isInWishlist ? .removeFromWishlist(movie: movie) : .addToWishlist(movie: movie)
    }

    static func seenlist(movie: Int, isInSeenlist: Bool) -> ActionSheetMovieListAction {
        isInSeenlist ? .removeFromSeenlist(movie: movie) : .addToSeenlist(movie: movie)
    }

    static func customList(list: CustomList, movie: Int) -> ActionSheetMovieListAction {
        list.movies.contains(movie) ? .removeFromCustomList(list: list.id, movie: movie) : .addToCustomList(list: list.id, movie: movie)
    }
}

extension ActionSheet {
    private static func dispatch(_ action: ActionSheetMovieListAction,
                                 with dispatch: @escaping DispatchFunction,
                                 onTrigger: (() -> Void)?) {
        switch action {
        case let .addToWishlist(movie):
            dispatch(MoviesActions.AddToWishlist(movie: movie))
            #if !os(tvOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        case let .removeFromWishlist(movie):
            dispatch(MoviesActions.RemoveFromWishlist(movie: movie))
        case let .addToSeenlist(movie):
            dispatch(MoviesActions.AddToSeenList(movie: movie))
            #if !os(tvOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        case let .removeFromSeenlist(movie):
            dispatch(MoviesActions.RemoveFromSeenList(movie: movie))
        case let .addToCustomList(list, movie):
            dispatch(MoviesActions.AddMovieToCustomList(list: list, movie: movie))
            #if !os(tvOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        case let .removeFromCustomList(list, movie):
            dispatch(MoviesActions.RemoveMovieFromCustomList(list: list, movie: movie))
        }

        onTrigger?()
    }

    static func wishlistButton(isInWishlist: Bool, movie: Int, dispatch: @escaping DispatchFunction, onTrigger: (() -> Void)?) -> Alert.Button {
        let action = ActionSheetMovieListAction.wishlist(movie: movie, isInWishlist: isInWishlist)
        switch action {
        case .removeFromWishlist:
            return .destructive(Text("Remove from wishlist")) {
                self.dispatch(action, with: dispatch, onTrigger: onTrigger)
            }
        case .addToWishlist:
            return .default(Text("Add to wishlist")) {
                self.dispatch(action, with: dispatch, onTrigger: onTrigger)
            }
        default:
            return .cancel()
        }
    }
    
    static func seenListButton(isInSeenlist: Bool, movie: Int, dispatch: @escaping DispatchFunction, onTrigger: (() -> Void)?) -> Alert.Button {
        let action = ActionSheetMovieListAction.seenlist(movie: movie, isInSeenlist: isInSeenlist)
        switch action {
        case .removeFromSeenlist:
            return .destructive(Text("Remove from seenlist")) {
                self.dispatch(action, with: dispatch, onTrigger: onTrigger)
            }
        case .addToSeenlist:
            return .default(Text("Add to seenlist")) {
                self.dispatch(action, with: dispatch, onTrigger: onTrigger)
            }
        default:
            return .cancel()
        }
    }
    
    static func customListsButttons(customLists: [CustomList], movie: Int, dispatch: @escaping DispatchFunction, onTrigger: (() -> Void)?) -> [Alert.Button] {
        var buttons: [Alert.Button] = []
        for list in customLists {
            let action = ActionSheetMovieListAction.customList(list: list, movie: movie)
            switch action {
            case .removeFromCustomList:
                buttons.append(.destructive(Text("Remove from \(list.name)")) {
                    self.dispatch(action, with: dispatch, onTrigger: onTrigger)
                })
            case .addToCustomList:
                buttons.append(.default(Text("Add to \(list.name)")) {
                    self.dispatch(action, with: dispatch, onTrigger: onTrigger)
                })
            default:
                break
            }
        }
        return buttons
    }
    
    static func sortActionSheet(onAction: @escaping ((MoviesSort?) -> Void)) -> ActionSheet {
        let byAddedDate: Alert.Button = .default(Text("Sort by added date")) {
            onAction(.byAddedDate)
        }
        let byReleaseDate: Alert.Button = .default(Text("Sort by release date")) {
            onAction(.byReleaseDate)
        }
        let byScore: Alert.Button = .default(Text("Sort by ratings")) {
            onAction(.byScore)
        }
        let byPopularity: Alert.Button = .default(Text("Sort by popularity")) {
            onAction(.byPopularity)
        }
        
        return ActionSheet(title: Text("Sort movies by"),
                           message: nil,
                           buttons: [byAddedDate, byReleaseDate, byScore, byPopularity, Alert.Button.cancel({
                            onAction(nil)
                           })])
    }
}
#endif

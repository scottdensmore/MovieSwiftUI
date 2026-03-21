//
//  MovieReviews.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 16/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum MovieReviewsFetchPolicy {
    static func shouldFetchReviews(existingReviews: [Review]) -> Bool {
        existingReviews.isEmpty
    }
}

enum MovieReviewsState {
    static func reviews(for movie: Int, in state: AppState) -> [Review] {
        state.moviesState.reviews[movie] ?? []
    }
}

struct MovieReviews : ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let reviews: [Review]
    }

    let movie: Int

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              reviews: MovieReviewsState.reviews(for: movie, in: state))
    }

    func body(props: Props) -> some View {
        List(props.reviews) { review in
            ReviewRow(review: review)
        }
        .navigationBarTitle(Text("Reviews"))
        .onAppear{
            if MovieReviewsFetchPolicy.shouldFetchReviews(existingReviews: props.reviews) {
                props.dispatch(MoviesActions.FetchMovieReviews(movie: self.movie))
            }
        }
    }
}

//
//  MoviesHomeList.swift
//  MovieSwift
//
//  Created by Thomas Ricouard on 07/06/2019.
//  Copyright © 2019 Thomas Ricouard. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

enum MoviesHomeListState {
    static func movies(for menu: MoviesMenu, from state: AppState) -> [Int] {
        state.moviesState.moviesList[menu] ?? [0, 0, 0, 0]
    }

    static func loadingState(for menu: MoviesMenu, from state: AppState) -> MoviesListLoadingState? {
        state.moviesState.moviesListLoadingState[menu]
    }
}

struct MoviesHomeList: ConnectedView {
    struct Props {
        let movies: [Int]
        let loadingState: MoviesListLoadingState?
        let dispatch: DispatchFunction
    }

    @Binding var menu: MoviesMenu
    let navigationRoute: Binding<MoviesListNavigationRoute?>

    let pageListener: MoviesMenuListPageListener

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(movies: MoviesHomeListState.movies(for: menu, from: state),
              loadingState: MoviesHomeListState.loadingState(for: menu, from: state),
              dispatch: dispatch)
    }

    func body(props: Props) -> some View {
        VStack(spacing: 0) {
            // When the most recent fetch failed, show an inline
            // banner above the list so the user sees that something
            // is wrong (instead of staring at skeleton placeholders
            // forever) and gets a one-tap retry.
            if case .failed(let failure) = props.loadingState {
                MoviesListErrorBanner(failure: failure) {
                    props.dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
                }
            }
            MoviesList(movies: props.movies,
                       displaySearch: true,
                       pageListener: pageListener,
                       navigationRoute: navigationRoute)
        }
    }
}

/// Inline error banner shown above the home menu list when the most
/// recent TMDB fetch failed. Adapts copy + CTA to the failure kind
/// (offline / rate-limited / unauthorized / generic).
struct MoviesListErrorBanner: View {
    let failure: MoviesListLoadFailure
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 26, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(failure.message)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(failure.retryActionTitle, action: retry)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.steam_blue)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("moviesHome.errorBanner.retryButton")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.steam_rust.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.steam_rust.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("moviesHome.errorBanner")
    }

    private var iconName: String {
        switch failure.kind {
        case .offline:                       return "wifi.slash"
        case .rateLimited:                   return "hourglass"
        case .missingAPIKey, .unauthorized,
             .forbidden:                     return "key.slash"
        case .server:                        return "exclamationmark.icloud"
        case .decode, .other:                return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch failure.kind {
        case .offline, .rateLimited, .server, .decode, .other:
            return .steam_rust
        case .missingAPIKey, .unauthorized, .forbidden:
            return .steam_gold
        }
    }
}

#Preview {
    NavigationStack {
        MoviesHomeList(menu: .constant(.popular),
                       navigationRoute: .constant(nil),
                       pageListener: MoviesMenuListPageListener(menu: .popular, loadOnInit: false))
            .environmentObject(sampleStore)
    }
}

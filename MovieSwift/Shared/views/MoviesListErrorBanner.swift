//
//  MoviesListErrorBanner.swift
//  MovieSwift
//
//  Inline error banner shared across every list/detail view that
//  reads from `MoviesState.loadingStates`. Adapts copy and CTA to
//  the failure kind (offline / rate-limited / missing key / etc.)
//  and provides a one-tap retry. Lives in Shared so MoviesHomeList,
//  MovieDetail, PeopleDetail, MoviesSearch, DiscoverView, and
//  GenresList can all render the same component.
//

import SwiftUI

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
                    .accessibilityIdentifier("errorBanner.retryButton")
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
        .accessibilityIdentifier("errorBanner")
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

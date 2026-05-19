//  Inline error banner shared across every list/detail view that
//  reads from `MoviesState.loadingStates`. Adapts copy and CTA to
//  the failure kind (offline / rate-limited / missing key / etc.)
//  and provides a one-tap retry. Lives in Shared so MoviesHomeList,
//  MovieDetail, PeopleDetail, MoviesSearch, DiscoverView, and
//  GenresList can all render the same component.

import SwiftUI
import MovieSwiftFluxCore

struct MoviesListErrorBanner: View {
    let failure: MoviesListLoadFailure
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon column — slightly larger and circled so the failure
            // kind reads at a glance even before the user scans the copy.
            Image(systemName: iconName)
                .font(.title.weight(.semibold))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("errorBanner.title")
                Text(failure.message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: retry) {
                    Text(failure.retryActionTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.steam_blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.steam_blue.opacity(0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.steam_blue.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityIdentifier("errorBanner.retryButton")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.steam_rust.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.steam_rust.opacity(0.30), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("errorBanner")
    }

    /// Short headline above the long-form failure message. The headline
    /// gives a glanceable summary of *what went wrong* so a user
    /// scanning the screen can tell offline from server-side trouble
    /// without parsing the prose.
    private var title: String {
        switch failure.kind {
        case .offline:        return String(localized: "You're offline",
                                            comment: "Error banner title for transport offline")
        case .rateLimited:    return String(localized: "Slow down a bit",
                                            comment: "Error banner title for HTTP 429 rate-limit")
        case .missingAPIKey:  return String(localized: "TMDB API key needed",
                                            comment: "Error banner title when no API key is configured")
        case .unauthorized:   return String(localized: "TMDB rejected the key",
                                            comment: "Error banner title for HTTP 401 unauthorized")
        case .forbidden:      return String(localized: "Access denied",
                                            comment: "Error banner title for HTTP 403 forbidden")
        case .server:         return String(localized: "TMDB is having trouble",
                                            comment: "Error banner title for HTTP 5xx server errors")
        case .decode:         return String(localized: "Unexpected response",
                                            comment: "Error banner title when the response JSON can't be decoded")
        case .other:          return String(localized: "Something went wrong",
                                            comment: "Error banner title for unrecognised failures")
        }
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

#Preview("Other failure (HTTP 400)") {
    MoviesListErrorBanner(
        failure: MoviesListLoadFailure(
            kind: .other,
            message: "TMDB returned an unexpected response (400).",
            retryActionTitle: "Try again"
        ),
        retry: {}
    )
    .padding()
}

#Preview("Offline") {
    MoviesListErrorBanner(
        failure: MoviesListLoadFailure(
            kind: .offline,
            message: "Couldn't reach TMDB. Check your connection and try again.",
            retryActionTitle: "Try again"
        ),
        retry: {}
    )
    .padding()
}

#Preview("Missing API key") {
    MoviesListErrorBanner(
        failure: MoviesListLoadFailure(
            kind: .missingAPIKey,
            message: "MovieSwift is missing a TMDB API key. Add yours in Settings to load movies.",
            retryActionTitle: "Open Settings"
        ),
        retry: {}
    )
    .padding()
}

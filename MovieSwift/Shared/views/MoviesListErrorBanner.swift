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

    /// Brief feedback state flipping the "Copy diagnostic" button's label
    /// to "Copied!" for ~1.5s after a successful clipboard write. Lives
    /// on the banner because it's purely view-local and doesn't belong
    /// in the Redux store.
    @State private var didCopyDiagnostic: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon column — slightly larger and circled so the failure
            // kind reads at a glance even before the user scans the copy.
            Image(systemName: iconName)
                .font(.title.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.15))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    // `.foregroundStyle(.primary)` (vs `.foregroundColor(.primary)`)
                    // explicitly draws from SwiftUI's foreground-style stack —
                    // necessary here because DiscoverView renders a
                    // `FullscreenMoviePosterImage` fallback (black @ 0.8) as its
                    // background, and `Color.primary` was being resolved against
                    // the system color scheme (light) instead of the actually-dark
                    // background, leaving title text dark-on-dark.
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("errorBanner.title")
                Text(failure.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button(action: retry) {
                        capsuleLabel(failure.retryActionTitle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("errorBanner.retryButton")

                    Button(action: copyDiagnostic) {
                        capsuleLabel(didCopyDiagnostic
                                     ? String(localized: "Copied!",
                                              comment: "Transient confirmation that the diagnostic info was copied to the clipboard.")
                                     : String(localized: "Copy diagnostic info",
                                              comment: "Button that copies a sanitized failure-diagnostic blob to the clipboard for pasting into a bug report."))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("errorBanner.copyDiagnosticButton")
                    .accessibilityHint(Text("Copies a sanitized summary of the failure (app version, OS, device, locale, error kind) for pasting into a bug report. Does not include your TMDB key or any saved data."))
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // `.regularMaterial` is a SwiftUI system material that adapts
        // to whatever's under it AND sets the appropriate foreground
        // vibrancy context — so `.primary` / `.secondary` text resolve
        // against the material's actual luminance instead of the
        // ambient color scheme. This is the fix for the "card sits on
        // a dark backdrop but title renders as black" bug visible on
        // DiscoverView's full-screen poster background.
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        )
        // Steam-themed accent on top of the material — preserves the
        // app's visual language while keeping the material's contrast
        // benefits underneath.
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.steam_rust.opacity(0.45), lineWidth: 1)
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

    /// Shared capsule chrome used by both the retry button and the
    /// copy-diagnostic button. Pulled out into a helper so the two
    /// buttons render identically without copy-pasting the modifier
    /// stack.
    private func capsuleLabel(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.steam_blue)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.steam_blue.opacity(0.18))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.steam_blue.opacity(0.5), lineWidth: 1)
            )
    }

    /// Build the diagnostic blob, copy it to the system clipboard,
    /// and flip the button's label to "Copied!" for ~1.5s as feedback.
    /// The diagnostic content is built by `ErrorDiagnostic.text(for:)`
    /// — see that helper for what is (and isn't) included.
    private func copyDiagnostic() {
        let diagnostic = ErrorDiagnostic.text(for: failure)
        let succeeded = Clipboard.copy(diagnostic)
        guard succeeded else { return }
        didCopyDiagnostic = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            didCopyDiagnostic = false
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

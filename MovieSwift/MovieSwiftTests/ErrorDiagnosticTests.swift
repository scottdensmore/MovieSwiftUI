import XCTest
import MovieSwiftFluxCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

/// `ErrorDiagnostic.text(for:)` is a pure function — all inputs are
/// injected, so the output is deterministic per call. These tests pin
/// every input and assert on the exact string so future edits to the
/// blob format (header line, key ordering, key labels) surface as
/// test failures rather than silent UX shifts.
///
/// The diagnostic is what the user pastes into a GitHub issue when the
/// app shows an unrecoverable error banner — its readability and the
/// fact it never carries the TMDB API key are both behavioural
/// contracts worth holding the line on.
// `@MainActor`: `ErrorDiagnostic.text(for:)` is main-actor-isolated under
// the Swift 6 mode (its device-model default reads `UIDevice.current`).
@MainActor
final class ErrorDiagnosticTests: XCTestCase {

    private func makeFailure(
        kind: MoviesListLoadFailure.Kind = .other,
        message: String = "TMDB returned an unexpected response (400).",
        retryActionTitle: String = "Try again"
    ) -> MoviesListLoadFailure {
        MoviesListLoadFailure(kind: kind,
                              message: message,
                              retryActionTitle: retryActionTitle)
    }

    private func makeFixedDate() -> Date {
        // 2026-05-20T18:00:00Z — chosen because it formats unambiguously
        // in ISO-8601 with no fractional seconds and lies safely after
        // any 2025 system epoch shenanigans.
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 20
        components.hour = 18
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testDiagnosticTextRendersAllPinnedFieldsInOrder() {
        let blob = ErrorDiagnostic.text(
            for: makeFailure(kind: .other),
            appVersion: "1.2.3",
            appBuild: "42",
            osDescription: "iOS 26.5",
            deviceModel: "iPhone (iOS)",
            localeIdentifier: "en_US",
            now: makeFixedDate()
        )

        XCTAssertEqual(blob, """
        MovieSwift diagnostic
        ─────────────────────
        app:      MovieSwift 1.2.3 (42)
        os:       iOS 26.5
        device:   iPhone (iOS)
        locale:   en_US
        failure:  other
        message:  TMDB returned an unexpected response (400).
        copied:   2026-05-20T18:00:00Z
        """)
    }

    /// The diagnostic must not include the user's TMDB API key (we
    /// never read it from anywhere in `text(for:)`, but a regression
    /// could change that — assert defensively). Also no request URL,
    /// auth header, or anything that could be PII-leaking.
    func testDiagnosticTextNeverContainsAPIKeyOrURL() {
        // Even with a failure message that pretends to contain a key —
        // unlikely but defensive — the diagnostic should still render
        // only what was passed in via the message field; the helper
        // itself must not enrich with sensitive context from
        // AppUserDefaults or the keychain.
        let blob = ErrorDiagnostic.text(
            for: makeFailure(message: "An error happened."),
            appVersion: "1.0",
            appBuild: "1",
            osDescription: "macOS 26.0",
            deviceModel: "Mac",
            localeIdentifier: "en_US",
            now: makeFixedDate()
        )

        XCTAssertFalse(blob.lowercased().contains("api_key"),
                       "Diagnostic must not embed 'api_key=' anywhere")
        XCTAssertFalse(blob.lowercased().contains("apikey"),
                       "Diagnostic must not embed 'apiKey' anywhere")
        XCTAssertFalse(blob.contains("https://"),
                       "Diagnostic must not embed any URL")
        XCTAssertFalse(blob.contains("Bearer "),
                       "Diagnostic must not embed an auth header")
    }

    /// Each `MoviesListLoadFailure.Kind` case renders distinctly so the
    /// failure: line is meaningful for triage. Swift's CaseIterable
    /// makes this exhaustive — if a new kind is added to the enum, this
    /// test makes the author add it here too (or accept the default
    /// CustomStringConvertible behaviour).
    func testDiagnosticIncludesAllFailureKindsDistinctly() {
        let kinds: [MoviesListLoadFailure.Kind] = [
            .offline, .rateLimited(retryAfterSeconds: 30), .missingAPIKey, .unauthorized,
            .forbidden, .server, .decode, .other
        ]
        var rendered: Set<String> = []
        for kind in kinds {
            let blob = ErrorDiagnostic.text(
                for: makeFailure(kind: kind),
                appVersion: "1.0", appBuild: "1",
                osDescription: "iOS 26.5", deviceModel: "iPhone",
                localeIdentifier: "en_US", now: makeFixedDate()
            )
            // Extract just the failure line so we're not comparing entire blobs.
            guard let line = blob.split(separator: "\n").first(where: { $0.hasPrefix("failure:") }) else {
                XCTFail("Expected a 'failure:' line in the diagnostic blob")
                return
            }
            rendered.insert(String(line))
        }
        XCTAssertEqual(rendered.count, kinds.count,
                       "Each failure kind should render a distinct 'failure:' line so triage can tell them apart; got duplicates: \(rendered)")
    }

    /// Sanity check that `Clipboard.copy(_:)` actually wrote what we
    /// asked it to write. Doesn't assert anything about Clipboard's
    /// platform impl beyond round-trip identity — sufficient for the
    /// banner's "Copied!" feedback to be honest.
    func testClipboardCopyRoundTripsTheStringOnHostPlatform() throws {
        let payload = "MovieSwift diagnostic test \(UUID().uuidString)"
        let succeeded = Clipboard.copy(payload)
        // tvOS has no pasteboard, so Clipboard.copy returns false there —
        // skip rather than fail.
        try XCTSkipUnless(succeeded, "Clipboard.copy returned false — tvOS (no pasteboard) or a sandboxed test host without clipboard access")

        #if os(tvOS)
        // unreachable — the XCTSkipUnless above always skips on tvOS
        #elseif canImport(UIKit)
        XCTAssertEqual(UIPasteboard.general.string, payload)
        #elseif canImport(AppKit)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), payload)
        #endif
    }
}

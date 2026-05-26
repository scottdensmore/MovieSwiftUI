//  Builds a sanitized diagnostic blob describing an in-app failure so
//  users can paste it into a GitHub issue. Deliberately conservative
//  about what goes in:
//
//    INCLUDED:
//      - app version + build
//      - OS family + version
//      - device model
//      - failure kind (offline / rateLimited / missingAPIKey / etc.)
//      - failure message
//      - the user's locale identifier (useful because TMDB filters by it)
//      - timestamp the user copied it (ISO-8601, UTC, no millis)
//
//    NOT INCLUDED:
//      - TMDB API key (never; it's behind a separate provider chain)
//      - request URLs (could contain query params with PII like region/genre)
//      - the user's saved movies / lists / wishlist
//      - hostname, MAC, advertising id, push token
//
//  Output is a plain-text block with a small header line and key/value
//  rows so it pastes legibly into any issue tracker without markdown
//  rendering shenanigans.

import Foundation
import MovieSwiftFluxCore

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

enum ErrorDiagnostic {

    /// Build the diagnostic blob for a `MoviesListLoadFailure`. `now`
    /// and the bundle/device readers are injectable so the unit test can
    /// pin them to known values.
    ///
    /// `@MainActor`: the `deviceModel` default reads `UIDevice.current`,
    /// which is main-actor-isolated. The production caller is a SwiftUI
    /// view and the tests inject every value, so this stays effectively
    /// pure while satisfying the isolation requirement.
    @MainActor
    static func text(
        for failure: MoviesListLoadFailure,
        appVersion: String = AppDataExport.bundleVersion(),
        appBuild: String = AppDataExport.bundleBuild(),
        osDescription: String = ErrorDiagnostic.defaultOSDescription(),
        deviceModel: String = ErrorDiagnostic.defaultDeviceModel(),
        localeIdentifier: String = Locale.current.identifier,
        now: Date = Date()
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: now)

        return """
        MovieSwift diagnostic
        ─────────────────────
        app:      MovieSwift \(appVersion) (\(appBuild))
        os:       \(osDescription)
        device:   \(deviceModel)
        locale:   \(localeIdentifier)
        failure:  \(failure.kind)
        message:  \(failure.message)
        copied:   \(timestamp)
        """
    }

    // MARK: - Platform readers

    /// e.g. "iOS 26.5", "macOS 26.0", "tvOS 26.5".
    static func defaultOSDescription() -> String {
        #if os(iOS) || os(tvOS) || os(visionOS)
        // ProcessInfo gives us major.minor.patch reliably across iOS/tvOS.
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let name: String
        #if os(iOS)
        name = "iOS"
        #elseif os(tvOS)
        name = "tvOS"
        #else
        name = "visionOS"
        #endif
        return "\(name) \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #elseif os(macOS)
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #else
        return "unknown OS"
        #endif
    }

    /// Best-effort device model string. Different platforms expose this
    /// in different places; we deliberately accept "Mac" or "Apple TV"
    /// as the fallback instead of trying to read the IOKit identifier.
    ///
    /// `@MainActor`: `UIDevice.current` is main-actor-isolated under the
    /// Swift 6 mode. The sole production caller (`MoviesListErrorBanner`)
    /// is a SwiftUI view, and the unit tests pass `deviceModel` explicitly
    /// so this default is never evaluated off the main actor.
    @MainActor
    static func defaultDeviceModel() -> String {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let device = UIDevice.current
        return "\(device.model) (\(device.systemName))"
        #elseif os(macOS)
        return "Mac"
        #else
        return "unknown device"
        #endif
    }
}

// MARK: - Clipboard

enum Clipboard {
    /// Cross-platform copy. Returns true if the write appeared to succeed.
    ///
    /// tvOS is checked FIRST and separately: `canImport(UIKit)` is true
    /// on tvOS, but `UIPasteboard` is unavailable there (tvOS has no
    /// general pasteboard concept), so the UIKit branch below would fail
    /// to compile. tvOS never shows MoviesListErrorBanner anyway — the
    /// file is only in the tvOS target because it lives in Shared/ — so
    /// returning false is the correct no-op.
    @discardableResult
    static func copy(_ string: String) -> Bool {
        #if os(tvOS)
        return false
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        return UIPasteboard.general.string == string
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
        #else
        return false
        #endif
    }
}

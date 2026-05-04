//  Builds a JSON-encoded export of the user's persistent app data —
//  wishlist, seenlist, custom lists, fan club, and the cached metadata
//  for those movies / people. Wraps the snapshot in an envelope with a
//  format version, export date, and app version so future imports can
//  detect format drift.

import Foundation

/// Versioned envelope around an `AppState` snapshot, written out as JSON.
///
/// The envelope is intentionally a separate type from `AppState` so the
/// import side can read the version field before attempting to decode
/// the snapshot body — letting older or newer formats fail with a clear
/// error instead of silently corrupting state.
struct AppDataExportEnvelope: Codable {
    /// Bumped when the on-disk export format changes in a way that
    /// would prevent older readers from understanding the file.
    static let currentFormatVersion: Int = 1

    let formatVersion: Int
    let exportDate: Date
    let appVersion: String
    let appBuild: String
    let snapshot: AppState
}

enum AppDataExport {
    /// Default JSON encoder used for exports. Pretty-printed and ISO 8601
    /// dates so the file is human-inspectable.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Builds the export envelope from the live app state. Reuses
    /// `AppStateCacheReset.persistentSnapshot(from:)` so transient
    /// caches (search results, popular lists, recommended sets, etc.)
    /// are stripped — only the user's actual data ships.
    static func envelope(from state: AppState,
                         exportDate: Date = Date(),
                         appVersion: String = bundleVersion(),
                         appBuild: String = bundleBuild()) -> AppDataExportEnvelope {
        AppDataExportEnvelope(
            formatVersion: AppDataExportEnvelope.currentFormatVersion,
            exportDate: exportDate,
            appVersion: appVersion,
            appBuild: appBuild,
            snapshot: AppStateCacheReset.persistentSnapshot(from: state)
        )
    }

    /// Encodes the envelope as pretty-printed JSON.
    static func data(from envelope: AppDataExportEnvelope,
                     encoder: JSONEncoder = makeEncoder()) throws -> Data {
        try encoder.encode(envelope)
    }

    /// Convenience: build the envelope and encode in one step.
    static func data(from state: AppState,
                     exportDate: Date = Date()) throws -> Data {
        try data(from: envelope(from: state, exportDate: exportDate))
    }

    /// "MovieSwift-Export-2026-05-02.json" style filename based on the
    /// export date, without spaces or path separators.
    static func suggestedFilename(for date: Date,
                                  calendar: Calendar = .init(identifier: .gregorian),
                                  timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "MovieSwift-Export-\(formatter.string(from: date))"
    }

    // MARK: - Bundle helpers

    static func bundleVersion(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    static func bundleBuild(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

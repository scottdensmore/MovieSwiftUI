//
//  AppStatePersistedFormat.swift
//  MovieSwift
//
//  Versioned envelope for the on-disk persisted state file.
//
//  Without a format version, the day someone adds a non-optional
//  field to AppState every existing user's userData file silently
//  fails to decode — they open the app, find their wishlist empty,
//  and conclude something corrupted them. This wraps AppState in an
//  envelope with a format version, validates that version on load,
//  and transparently falls back to the legacy bare-AppState format
//  so installs from pre-versioning builds upgrade cleanly.
//
//  The export envelope (AppDataExportEnvelope) and this persisted
//  envelope are deliberately separate types: exports go to a file
//  the user shares with themselves and may carry version metadata
//  (app version, export date) that doesn't make sense on the local
//  cache file, while the persisted envelope is internal-only and
//  optimised for fast load.
//

import Foundation

/// Wraps `AppState` with a format version so future schema changes
/// can be detected (and rejected, if they're newer than this build
/// understands) instead of silently producing junk data.
struct PersistedAppStateEnvelope: Codable {
    /// Bumped when the persisted on-disk schema changes in a way
    /// that older builds would mis-decode. New optional fields
    /// don't require a bump; renames, removals, and required-field
    /// additions do.
    static let currentFormatVersion: Int = 1

    let formatVersion: Int
    let savedAt: Date
    let state: AppState
}

enum AppStatePersistedFormat {

    /// Errors surfaced when a persisted file can't be loaded.
    enum LoadError: LocalizedError {
        case unsupportedFutureVersion(found: Int, supported: ClosedRange<Int>)
        case decodeFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .unsupportedFutureVersion(let found, let supported):
                return "Saved data uses format version \(found), which this build of MovieSwift can't read (supported: \(supported.lowerBound)–\(supported.upperBound)). Update the app and try again."
            case .decodeFailed(let underlying):
                return "Couldn't read saved data: \(underlying.localizedDescription)"
            }
        }
    }

    /// Format versions this build can read. The lower bound stays at
    /// 1 forever so we can always migrate forward; the upper bound
    /// matches `PersistedAppStateEnvelope.currentFormatVersion`.
    static let supportedFormatVersions: ClosedRange<Int> = 1...PersistedAppStateEnvelope.currentFormatVersion

    /// Default JSON encoder. Uses `.deferredToDate` (TimeInterval) for
    /// Date encoding to match the legacy bare-AppState format —
    /// changing the strategy would break the legacy fallback path on
    /// the read side.
    static func makeEncoder() -> JSONEncoder { JSONEncoder() }

    /// Default JSON decoder. Same reasoning: `.deferredToDate` so we
    /// can decode old files written before the envelope existed.
    static func makeDecoder() -> JSONDecoder { JSONDecoder() }

    // MARK: - Encode

    /// Encodes `state` as a versioned envelope.
    static func encode(state: AppState,
                       savedAt: Date = Date(),
                       encoder: JSONEncoder = makeEncoder()) throws -> Data {
        let envelope = PersistedAppStateEnvelope(
            formatVersion: PersistedAppStateEnvelope.currentFormatVersion,
            savedAt: savedAt,
            state: state
        )
        return try encoder.encode(envelope)
    }

    // MARK: - Decode

    /// Decodes persisted data, transparently handling both the
    /// modern envelope format and the legacy bare-`AppState` format
    /// written by builds before this envelope existed.
    ///
    /// Order of attempts:
    ///   1. Decode as `PersistedAppStateEnvelope`. If successful,
    ///      validate the format version against
    ///      `supportedFormatVersions`.
    ///   2. If envelope decode failed (most likely because the file
    ///      lacks `formatVersion` — i.e. it's a legacy bare-AppState
    ///      file), retry as a bare `AppState`.
    ///   3. If both attempts failed, surface the original envelope
    ///      decode error wrapped in `decodeFailed`.
    ///
    /// Throws `LoadError.unsupportedFutureVersion` for files written
    /// by a newer build than the current one.
    static func decode(data: Data,
                       decoder: JSONDecoder = makeDecoder()) throws -> AppState {
        do {
            let envelope = try decoder.decode(PersistedAppStateEnvelope.self, from: data)
            guard supportedFormatVersions.contains(envelope.formatVersion) else {
                throw LoadError.unsupportedFutureVersion(
                    found: envelope.formatVersion,
                    supported: supportedFormatVersions
                )
            }
            return envelope.state
        } catch let error as LoadError {
            throw error
        } catch let envelopeError {
            // Try the legacy bare-AppState format. If that also
            // fails, surface the original envelope error — the bare
            // format is a fallback for pre-versioning installs, not
            // a parallel format we want to surface in error messages.
            if let state = try? decoder.decode(AppState.self, from: data) {
                return state
            }
            throw LoadError.decodeFailed(underlying: envelopeError)
        }
    }
}

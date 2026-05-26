//  Inverse of AppDataExport: reads a JSON envelope produced by Export
//  my data, validates the format version, and merges the imported user
//  data (wishlist, seenlist, custom lists, fan club, cached movie /
//  people metadata) into the live AppState.
//
//  The merge is intentionally non-destructive — current user data is
//  preserved and the imported data is unioned in. This prevents an
//  accidental import from wiping a user's collection. To replace
//  state outright a caller would clear it first, then import.

import Foundation
import MovieSwiftFluxCore

nonisolated enum AppDataImport {

    /// Errors surfaced to the UI when an import can't proceed.
    enum ImportError: LocalizedError {
        case decodeFailed(underlying: Error)
        case unsupportedFormatVersion(found: Int, supported: ClosedRange<Int>)

        var errorDescription: String? {
            switch self {
            case .decodeFailed(let error):
                return String(localized: "Couldn't read the export file: \(error.localizedDescription)",
                              comment: "Error shown when an Import my data picked file fails to decode (corrupt JSON or wrong shape). The interpolated value is the underlying system error.")
            case .unsupportedFormatVersion(let found, let supported):
                return String(localized: "Export file format version \(found) isn't supported by this version of MovieSwift (supported: \(supported.lowerBound)–\(supported.upperBound)).",
                              comment: "Error shown when an Import my data picked file uses a format version produced by a newer build of MovieSwift than the one running. \\(found), \\(supported.lowerBound), \\(supported.upperBound) are integer format-version numbers.")
            }
        }
    }

    /// Format versions this build of MovieSwift can read. Bump the
    /// upper bound when introducing breaking schema changes; bump
    /// `AppDataExportEnvelope.currentFormatVersion` to write them.
    static let supportedFormatVersions: ClosedRange<Int> = 1...AppDataExportEnvelope.currentFormatVersion

    /// Preview of what a merge would change. Surfaces in the import
    /// confirmation alert so the user sees the scope of the change
    /// before they commit to it.
    struct Counts: Equatable {
        let wishlistAdded: Int
        let seenlistAdded: Int
        let customListsAdded: Int
        let customListsUpdated: Int
        let fanClubAdded: Int

        var total: Int {
            wishlistAdded + seenlistAdded + customListsAdded + customListsUpdated + fanClubAdded
        }

        var hasAnyChanges: Bool { total > 0 }
    }

    // MARK: - Decoding

    /// Decodes a JSON-encoded export envelope and validates that this
    /// build can read its format version.
    static func decodeEnvelope(from data: Data,
                               decoder: JSONDecoder = AppDataExport.makeDecoder()) throws -> AppDataExportEnvelope {
        let envelope: AppDataExportEnvelope
        do {
            envelope = try decoder.decode(AppDataExportEnvelope.self, from: data)
        } catch {
            throw ImportError.decodeFailed(underlying: error)
        }
        guard supportedFormatVersions.contains(envelope.formatVersion) else {
            throw ImportError.unsupportedFormatVersion(
                found: envelope.formatVersion,
                supported: supportedFormatVersions
            )
        }
        return envelope
    }

    // MARK: - Preview

    /// Counts what `merge(envelope:into:)` would add to `state`,
    /// without mutating anything. `customListsUpdated` counts
    /// imported lists whose id matches an existing list (those get
    /// overwritten on merge).
    static func previewCounts(for envelope: AppDataExportEnvelope,
                              against state: AppState) -> Counts {
        let imported = envelope.snapshot

        let wishlistAdded = imported.moviesState.wishlist
            .subtracting(state.moviesState.wishlist).count
        let seenlistAdded = imported.moviesState.seenlist
            .subtracting(state.moviesState.seenlist).count
        let fanClubAdded = imported.peoplesState.fanClub
            .subtracting(state.peoplesState.fanClub).count

        let importedListIds = Set(imported.moviesState.customLists.keys)
        let currentListIds = Set(state.moviesState.customLists.keys)
        let customListsAdded = importedListIds.subtracting(currentListIds).count
        let customListsUpdated = importedListIds.intersection(currentListIds).count

        return Counts(wishlistAdded: wishlistAdded,
                      seenlistAdded: seenlistAdded,
                      customListsAdded: customListsAdded,
                      customListsUpdated: customListsUpdated,
                      fanClubAdded: fanClubAdded)
    }

    // MARK: - Merge

    /// Returns a new AppState with the imported snapshot merged in.
    ///
    /// Merge rules:
    /// - `wishlist`, `seenlist`, `fanClub` — set union with current.
    /// - `customLists` — upsert by id; imported wins on conflict so
    ///   the user gets the version they intentionally exported.
    /// - `movies`, `peoples` reverse caches — current wins on conflict.
    ///   Current entries are likely fresher; imported only fills in
    ///   the entries needed to render the imported lists.
    /// - `moviesUserMeta` — current wins on conflict, same reasoning.
    /// - `savedDiscoverFilters` — append imported filters that aren't
    ///   already present (compared by JSON encoding to dodge the
    ///   missing Equatable conformance on DiscoverFilter).
    /// - `discoverFilter` (the active selection) — preserved as-is.
    static func merge(envelope: AppDataExportEnvelope, into state: AppState) -> AppState {
        var state = state
        let imported = envelope.snapshot

        // User collections.
        state.moviesState.wishlist.formUnion(imported.moviesState.wishlist)
        state.moviesState.seenlist.formUnion(imported.moviesState.seenlist)
        state.peoplesState.fanClub.formUnion(imported.peoplesState.fanClub)

        // Custom lists — imported wins on conflict.
        for (id, list) in imported.moviesState.customLists {
            state.moviesState.customLists[id] = list
        }

        // Reverse caches — only fill in entries the current state
        // doesn't already have.
        for (id, movie) in imported.moviesState.movies {
            if state.moviesState.movies[id] == nil {
                state.moviesState.movies[id] = movie
            }
        }
        for (id, meta) in imported.moviesState.moviesUserMeta {
            if state.moviesState.moviesUserMeta[id] == nil {
                state.moviesState.moviesUserMeta[id] = meta
            }
        }
        for (id, person) in imported.peoplesState.peoples {
            if state.peoplesState.peoples[id] == nil {
                state.peoplesState.peoples[id] = person
            }
        }

        // Saved discover filters — append any that don't already
        // exist in the current state. DiscoverFilter doesn't conform
        // to Equatable, so compare by encoded JSON. `.sortedKeys` is
        // essential here; without it, dictionary key ordering varies
        // per encode call and the dedupe set never matches.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let existingEncodings = Set(state.moviesState.savedDiscoverFilters
            .compactMap { try? encoder.encode($0) })
        for filter in imported.moviesState.savedDiscoverFilters {
            if let encoded = try? encoder.encode(filter),
               !existingEncodings.contains(encoded) {
                state.moviesState.savedDiscoverFilters.append(filter)
            }
        }

        return state
    }
}

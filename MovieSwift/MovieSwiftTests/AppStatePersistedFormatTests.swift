import Testing
import Foundation
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

@Suite struct AppStatePersistedFormatTests {

    private func makeMovie(id: Int) -> Movie {
        Movie(id: id,
              original_title: "Movie \(id)",
              title: "Movie \(id)",
              overview: "Overview",
              poster_path: nil,
              backdrop_path: nil,
              popularity: 0,
              vote_average: 0,
              vote_count: 0,
              release_date: nil,
              genres: nil,
              runtime: nil,
              status: nil,
              video: false,
              keywords: nil,
              images: nil,
              production_countries: nil,
              character: nil,
              department: nil)
    }

    private func makePeople(id: Int) -> People {
        People(id: id,
               name: "Person \(id)",
               character: nil,
               department: nil,
               profile_path: nil,
               known_for_department: nil,
               known_for: nil,
               also_known_as: nil,
               birthDay: nil,
               deathDay: nil,
               place_of_birth: nil,
               biography: nil,
               popularity: nil,
               images: nil)
    }

    // MARK: - Encode

    @Test func encodeProducesEnvelopeWithCurrentFormatVersion() throws {
        let data = try AppStatePersistedFormat.encode(state: AppState())

        // The encoded data must decode as the envelope and carry the
        // current format version. Decoding straight as bare AppState
        // should fail (or at least not roundtrip to the original
        // values), confirming we wrote the envelope shape.
        let decoder = AppStatePersistedFormat.makeDecoder()
        let envelope = try decoder.decode(PersistedAppStateEnvelope.self, from: data)
        #expect(envelope.formatVersion == PersistedAppStateEnvelope.currentFormatVersion)
    }

    @Test func encodeStampsSavedAtCloseToProvidedDate() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try AppStatePersistedFormat.encode(state: AppState(),
                                                       savedAt: date)

        let envelope = try AppStatePersistedFormat.makeDecoder()
            .decode(PersistedAppStateEnvelope.self, from: data)
        #expect(envelope.savedAt == date)
    }

    // MARK: - Round trip

    @Test func roundTripPreservesUserCollections() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.wishlist.insert(1)
        state.moviesState.seenlist.insert(2)
        state.moviesState.customLists[10] = CustomList(id: 10, name: "Favs", cover: 1, movies: [1])
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.fanClub.insert(5)

        let data = try AppStatePersistedFormat.encode(state: state)
        let decoded = try AppStatePersistedFormat.decode(data: data)

        #expect(decoded.moviesState.wishlist.contains(1))
        #expect(decoded.moviesState.seenlist.contains(2))
        #expect(decoded.moviesState.customLists[10]?.name == "Favs")
        #expect(decoded.peoplesState.fanClub.contains(5))
        #expect(decoded.peoplesState.peoples[5] != nil)
    }

    // MARK: - Legacy bare-AppState fallback (the critical path)

    @Test func decodeFallsBackToLegacyBareAppStateFormat() throws {
        // Pre-versioning builds wrote `try? encoder.encode(state)`
        // directly — no envelope. Existing user installs upgrading
        // to the new build must continue to load their data.
        var legacyState = AppState()
        legacyState.moviesState.movies[42] = makeMovie(id: 42)
        legacyState.moviesState.wishlist.insert(42)
        legacyState.peoplesState.fanClub.insert(7)

        let legacyData = try AppStatePersistedFormat.makeEncoder()
            .encode(legacyState)

        let decoded = try AppStatePersistedFormat.decode(data: legacyData)

        #expect(decoded.moviesState.wishlist.contains(42),
                "Legacy bare-AppState files must keep loading after the upgrade")
        #expect(decoded.peoplesState.fanClub.contains(7))
    }

    @Test func legacyFallbackPreservesSampleStateLikeProduction() throws {
        // A pre-versioning install would also have the sample
        // placeholder rows from `ensurePlaceholderData()`. Make sure
        // those survive the legacy decode path.
        let legacyState = AppState()
        let legacyData = try AppStatePersistedFormat.makeEncoder()
            .encode(legacyState)

        let decoded = try AppStatePersistedFormat.decode(data: legacyData)

        #expect(decoded.moviesState.movies[0] != nil,
                "AppState() initializer always seeds movies[0] = sampleMovie")
    }

    // MARK: - Version validation

    @Test func decodeRejectsFormatVersionFromAFutureBuild() throws {
        // Build an envelope with a version ahead of what this build
        // supports, encode, then attempt to decode. Should throw
        // unsupportedFutureVersion rather than silently producing
        // wrong data.
        let future = PersistedAppStateEnvelope(
            formatVersion: PersistedAppStateEnvelope.currentFormatVersion + 1,
            savedAt: Date(),
            state: AppState()
        )
        let data = try AppStatePersistedFormat.makeEncoder().encode(future)

        do {
            _ = try AppStatePersistedFormat.decode(data: data)
            Issue.record("Expected unsupportedFutureVersion, but no error was thrown")
        } catch {
            guard case AppStatePersistedFormat.LoadError.unsupportedFutureVersion(let found, _) = error else {
                Issue.record("Expected unsupportedFutureVersion, got \(error)")
                return
            }
            #expect(found == PersistedAppStateEnvelope.currentFormatVersion + 1)
        }
    }

    // MARK: - Garbage / corrupt data

    @Test func decodeWrapsCorruptDataInDecodeFailedError() {
        let bogus = Data("not actually json".utf8)

        do {
            _ = try AppStatePersistedFormat.decode(data: bogus)
            Issue.record("Expected decodeFailed, but no error was thrown")
        } catch {
            guard case AppStatePersistedFormat.LoadError.decodeFailed = error else {
                Issue.record("Expected decodeFailed, got \(error)")
                return
            }
        }
    }

    // MARK: - Supported range invariant

    @Test func supportedFormatVersionsCoversCurrentFormat() {
        #expect(
            AppStatePersistedFormat.supportedFormatVersions
                .contains(PersistedAppStateEnvelope.currentFormatVersion),
            "Whatever the current format version is, this build must be able to read it"
        )
    }
}

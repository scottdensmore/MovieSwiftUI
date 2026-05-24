import XCTest
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

/// End-to-end integration tests for the user-data Export → Import journey.
///
/// `AppDataExportTests` covers `AppDataExport.data(from:)` in isolation;
/// `AppDataImportTests` covers `AppDataImport.decodeEnvelope`,
/// `previewCounts`, and `merge` in isolation. Both sides have unit
/// coverage. What's been missing is a test that ties them together to
/// prove the contract end users actually rely on:
///
///   "I exported my library on Phone A. I install MovieSwift on Phone B.
///    I tap Import on Phone B and pick the file. My wishlist, seenlist,
///    fan club, and custom lists are now on Phone B."
///
/// A regression that breaks the JSON contract on either side, the merge
/// logic, or the snapshot-trim that runs before encoding, would still
/// pass the per-side unit tests but break the journey. These tests fail
/// loudly if any of those pieces drifts.
final class AppDataRoundTripTests: XCTestCase {

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

    /// Phone A builds a library, exports the JSON file, ships it (in
    /// memory here) to Phone B which has empty user data. After import,
    /// every user-facing list on Phone B contains exactly what Phone A
    /// had, and the cached movie/person records that those lists reference
    /// rode along too.
    func testFullRoundTripFromPopulatedPhoneAToEmptyPhoneB() throws {
        // Phone A: user has built up a library across all four list types.
        var phoneA = AppState()
        phoneA.moviesState.movies[100] = makeMovie(id: 100)
        phoneA.moviesState.movies[200] = makeMovie(id: 200)
        phoneA.moviesState.movies[300] = makeMovie(id: 300)
        phoneA.moviesState.wishlist.insert(100)
        phoneA.moviesState.seenlist.insert(200)
        phoneA.moviesState.customLists[42] = CustomList(id: 42,
                                                        name: "Favorites",
                                                        cover: 100,
                                                        movies: [300])
        phoneA.peoplesState.peoples[7] = makePeople(id: 7)
        phoneA.peoplesState.fanClub.insert(7)

        // Phone A: user taps Export. The bytes are what would land in
        // their iCloud Drive / AirDrop / Files share.
        let bytes = try AppDataExport.data(from: phoneA)

        // Phone B: fresh install, empty user data.
        let phoneB = AppState()

        // Phone B: user taps Import → file picker → decode → preview →
        // confirm. Each line is exactly what `SettingsForm` runs in
        // sequence in `handleImportSelection` + `confirmImport`.
        let envelope = try AppDataImport.decodeEnvelope(from: bytes)
        let counts = AppDataImport.previewCounts(for: envelope, against: phoneB)
        let merged = AppDataImport.merge(envelope: envelope, into: phoneB)

        // Phone B's lists now match Phone A's.
        XCTAssertEqual(merged.moviesState.wishlist, Set([100]))
        XCTAssertEqual(merged.moviesState.seenlist, Set([200]))
        XCTAssertEqual(merged.peoplesState.fanClub, Set([7]))
        XCTAssertEqual(merged.moviesState.customLists.count, 1)
        XCTAssertEqual(merged.moviesState.customLists[42]?.name, "Favorites")
        XCTAssertEqual(merged.moviesState.customLists[42]?.cover, 100)
        XCTAssertEqual(merged.moviesState.customLists[42]?.movies, Set([300]))

        // The cached movie/people records the lists refer to rode along —
        // otherwise Phone B would have wishlist[100] but no Movie 100 to
        // render, and the row would be empty.
        XCTAssertEqual(merged.moviesState.movies[100]?.id, 100)
        XCTAssertEqual(merged.moviesState.movies[200]?.id, 200)
        XCTAssertEqual(merged.moviesState.movies[300]?.id, 300)
        XCTAssertEqual(merged.peoplesState.peoples[7]?.name, "Person 7")

        // The preview-counts UI shows the same numbers the user is
        // committing to.
        XCTAssertEqual(counts.wishlistAdded, 1)
        XCTAssertEqual(counts.seenlistAdded, 1)
        XCTAssertEqual(counts.fanClubAdded, 1)
        XCTAssertEqual(counts.customListsAdded, 1)
        XCTAssertEqual(counts.customListsUpdated, 0)
        XCTAssertTrue(counts.hasAnyChanges)
    }

    /// Phone B already has its own data; importing Phone A's export
    /// should UNION rather than overwrite. Catches regressions where the
    /// merge implementation accidentally replaces local state with the
    /// envelope's snapshot.
    func testFullRoundTripUnionsWithExistingPhoneBData() throws {
        var phoneA = AppState()
        phoneA.moviesState.movies[100] = makeMovie(id: 100)
        phoneA.moviesState.wishlist.insert(100)
        phoneA.peoplesState.peoples[7] = makePeople(id: 7)
        phoneA.peoplesState.fanClub.insert(7)

        var phoneB = AppState()
        phoneB.moviesState.movies[200] = makeMovie(id: 200)
        phoneB.moviesState.wishlist.insert(200)
        phoneB.peoplesState.peoples[8] = makePeople(id: 8)
        phoneB.peoplesState.fanClub.insert(8)

        let bytes = try AppDataExport.data(from: phoneA)
        let envelope = try AppDataImport.decodeEnvelope(from: bytes)
        let merged = AppDataImport.merge(envelope: envelope, into: phoneB)

        // Both Phone A's and Phone B's prior lists are present.
        XCTAssertTrue(merged.moviesState.wishlist.contains(100))
        XCTAssertTrue(merged.moviesState.wishlist.contains(200))
        XCTAssertTrue(merged.peoplesState.fanClub.contains(7))
        XCTAssertTrue(merged.peoplesState.fanClub.contains(8))
        XCTAssertNotNil(merged.moviesState.movies[100])
        XCTAssertNotNil(merged.moviesState.movies[200])
    }

    /// Re-importing the same export onto a Phone B that already has
    /// the data is a no-op — preview counts say "nothing new" and the
    /// merged state equals the input. Catches regressions where the
    /// merge double-counts or duplicates entries.
    func testReImportingSameExportIsAnIdempotentNoOp() throws {
        var state = AppState()
        state.moviesState.movies[100] = makeMovie(id: 100)
        state.moviesState.wishlist.insert(100)
        state.peoplesState.peoples[7] = makePeople(id: 7)
        state.peoplesState.fanClub.insert(7)

        let bytes = try AppDataExport.data(from: state)
        let envelope = try AppDataImport.decodeEnvelope(from: bytes)
        let counts = AppDataImport.previewCounts(for: envelope, against: state)

        XCTAssertEqual(counts.wishlistAdded, 0)
        XCTAssertEqual(counts.fanClubAdded, 0)
        XCTAssertEqual(counts.customListsAdded, 0)
        XCTAssertEqual(counts.customListsUpdated, 0)
        XCTAssertFalse(counts.hasAnyChanges,
                       "Re-importing the same data should not be a 'has any changes' state")

        let merged = AppDataImport.merge(envelope: envelope, into: state)
        XCTAssertEqual(merged.moviesState.wishlist, state.moviesState.wishlist)
        XCTAssertEqual(merged.peoplesState.fanClub, state.peoplesState.fanClub)
    }

    /// The export envelope's snapshot strips transient fetch caches that
    /// don't belong to the user — pagination keys, search-result
    /// dictionaries, popular-people lists, etc. After roundtripping,
    /// Phone B should NOT inherit Phone A's transient fetch state, only
    /// the user-owned lists.
    func testRoundTripDoesNotLeakTransientFetchCaches() throws {
        var phoneA = AppState()
        phoneA.moviesState.wishlist.insert(100)  // user-owned
        phoneA.moviesState.movies[100] = makeMovie(id: 100)
        // Transient caches that should NOT cross to Phone B:
        phoneA.moviesState.search["godfather"] = [1, 2, 3]
        phoneA.moviesState.recentSearches = Set(["godfather", "casablanca"])
        phoneA.peoplesState.popular = [1, 2, 3, 4, 5]
        phoneA.peoplesState.search["spielberg"] = [10, 20]

        let bytes = try AppDataExport.data(from: phoneA)
        let envelope = try AppDataImport.decodeEnvelope(from: bytes)
        let merged = AppDataImport.merge(envelope: envelope, into: AppState())

        // User data crosses.
        XCTAssertTrue(merged.moviesState.wishlist.contains(100))

        // Transient caches DO NOT cross.
        XCTAssertTrue(merged.moviesState.search.isEmpty,
                      "Phone A's search results should not appear on Phone B")
        XCTAssertTrue(merged.moviesState.recentSearches.isEmpty,
                      "Phone A's recent searches should not appear on Phone B")
        XCTAssertTrue(merged.peoplesState.popular.isEmpty,
                      "Phone A's popular-people list should not appear on Phone B")
        XCTAssertTrue(merged.peoplesState.search.isEmpty,
                      "Phone A's people search cache should not appear on Phone B")
    }
}

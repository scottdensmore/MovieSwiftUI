import XCTest
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class AppDataImportTests: XCTestCase {

    private func makeMovie(id: Int, title: String? = nil) -> Movie {
        Movie(id: id,
              original_title: "Movie \(id)",
              title: title ?? "Movie \(id)",
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

    /// Builds an envelope wrapping `state` so tests can call merge / preview
    /// without rebuilding the envelope structure each time.
    private func envelope(wrapping state: AppState,
                          formatVersion: Int = AppDataExportEnvelope.currentFormatVersion) -> AppDataExportEnvelope {
        AppDataExportEnvelope(formatVersion: formatVersion,
                              exportDate: Date(),
                              appVersion: "1.0",
                              appBuild: "1",
                              snapshot: state)
    }

    // MARK: - Decoding

    func testDecodeEnvelopeRoundTripsExportedData() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.wishlist.insert(1)

        let data = try AppDataExport.data(from: state)
        let decoded = try AppDataImport.decodeEnvelope(from: data)

        XCTAssertEqual(decoded.formatVersion, AppDataExportEnvelope.currentFormatVersion)
        XCTAssertTrue(decoded.snapshot.moviesState.wishlist.contains(1))
    }

    func testDecodeEnvelopeRejectsUnsupportedFormatVersion() throws {
        // Build an envelope by hand with a future format version.
        let unsupported = AppDataExportEnvelope(
            formatVersion: AppDataExportEnvelope.currentFormatVersion + 1,
            exportDate: Date(),
            appVersion: "9.9",
            appBuild: "999",
            snapshot: AppState()
        )
        let data = try AppDataExport.data(from: unsupported)

        XCTAssertThrowsError(try AppDataImport.decodeEnvelope(from: data)) { error in
            guard case AppDataImport.ImportError.unsupportedFormatVersion(let found, _) = error else {
                XCTFail("Expected unsupportedFormatVersion error, got \(error)")
                return
            }
            XCTAssertEqual(found, AppDataExportEnvelope.currentFormatVersion + 1)
        }
    }

    func testDecodeEnvelopeWrapsCorruptDataInDecodeFailedError() {
        let bogus = Data("not actually json".utf8)

        XCTAssertThrowsError(try AppDataImport.decodeEnvelope(from: bogus)) { error in
            guard case AppDataImport.ImportError.decodeFailed = error else {
                XCTFail("Expected decodeFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - Preview counts

    func testPreviewCountsTrackOnlyAdditionsAndUpserts() {
        var current = AppState()
        current.moviesState.wishlist.insert(1) // already present
        current.moviesState.customLists[10] = CustomList(id: 10, name: "Existing", cover: nil, movies: [])

        var imported = AppState()
        imported.moviesState.wishlist.insert(1) // overlap → not counted
        imported.moviesState.wishlist.insert(2) // new
        imported.moviesState.seenlist.insert(3)
        imported.peoplesState.fanClub.insert(7)
        imported.moviesState.customLists[10] = CustomList(id: 10, name: "Updated", cover: nil, movies: [99])
        imported.moviesState.customLists[11] = CustomList(id: 11, name: "New list", cover: nil, movies: [])

        let counts = AppDataImport.previewCounts(for: envelope(wrapping: imported), against: current)

        XCTAssertEqual(counts.wishlistAdded, 1)
        XCTAssertEqual(counts.seenlistAdded, 1)
        XCTAssertEqual(counts.fanClubAdded, 1)
        XCTAssertEqual(counts.customListsAdded, 1)
        XCTAssertEqual(counts.customListsUpdated, 1)
        XCTAssertTrue(counts.hasAnyChanges)
    }

    func testPreviewCountsHasNoChangesWhenImportIsASubset() {
        var current = AppState()
        current.moviesState.wishlist.insert(1)
        current.moviesState.wishlist.insert(2)
        current.peoplesState.fanClub.insert(7)

        var imported = AppState()
        imported.moviesState.wishlist.insert(1)
        imported.peoplesState.fanClub.insert(7)

        let counts = AppDataImport.previewCounts(for: envelope(wrapping: imported), against: current)
        XCTAssertFalse(counts.hasAnyChanges)
    }

    // MARK: - Merge semantics

    func testMergeUnionsWishlistSeenlistAndFanClub() {
        var current = AppState()
        current.moviesState.wishlist.insert(1)
        current.moviesState.seenlist.insert(2)
        current.peoplesState.fanClub.insert(5)

        var imported = AppState()
        imported.moviesState.wishlist.insert(3)
        imported.moviesState.seenlist.insert(4)
        imported.peoplesState.fanClub.insert(6)

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        XCTAssertEqual(merged.moviesState.wishlist, [1, 3])
        XCTAssertEqual(merged.moviesState.seenlist, [2, 4])
        XCTAssertEqual(merged.peoplesState.fanClub, [5, 6])
    }

    func testMergeImportedCustomListWinsOnConflict() {
        var current = AppState()
        current.moviesState.customLists[10] = CustomList(id: 10, name: "Old name", cover: 1, movies: [1])

        var imported = AppState()
        imported.moviesState.customLists[10] = CustomList(id: 10, name: "Exported name", cover: 2, movies: [2, 3])
        imported.moviesState.customLists[11] = CustomList(id: 11, name: "Brand new", cover: nil, movies: [])

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        XCTAssertEqual(merged.moviesState.customLists[10]?.name, "Exported name")
        XCTAssertEqual(merged.moviesState.customLists[10]?.movies, [2, 3])
        XCTAssertNotNil(merged.moviesState.customLists[11])
    }

    func testMergeKeepsCurrentReverseCacheEntriesOnConflict() {
        var current = AppState()
        // Current has a fresher entry — stash a marker we can verify
        // wasn't overwritten.
        current.moviesState.movies[42] = makeMovie(id: 42, title: "Fresh title")

        var imported = AppState()
        imported.moviesState.movies[42] = makeMovie(id: 42, title: "Stale title")
        imported.moviesState.movies[99] = makeMovie(id: 99)

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        XCTAssertEqual(merged.moviesState.movies[42]?.title, "Fresh title",
                       "Current cache entry should win on conflict")
        XCTAssertNotNil(merged.moviesState.movies[99],
                        "New cache entries from imported should be added")
    }

    func testMergeKeepsCurrentMovieUserMetaOnConflict() {
        var current = AppState()
        var currentMeta = MovieUserMeta()
        currentMeta.addedToList = Date(timeIntervalSince1970: 1000)
        current.moviesState.moviesUserMeta[1] = currentMeta

        var imported = AppState()
        var importedMeta = MovieUserMeta()
        importedMeta.addedToList = Date(timeIntervalSince1970: 999)
        imported.moviesState.moviesUserMeta[1] = importedMeta
        imported.moviesState.moviesUserMeta[2] = importedMeta

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        XCTAssertEqual(merged.moviesState.moviesUserMeta[1]?.addedToList,
                       Date(timeIntervalSince1970: 1000),
                       "Current meta should win on conflict")
        XCTAssertNotNil(merged.moviesState.moviesUserMeta[2],
                        "Imported meta for new ids should be added")
    }

    func testMergeAppendsNewSavedDiscoverFiltersAndDeduplicates() {
        let existingFilter = DiscoverFilter(
            year: 2000, startYear: nil, endYear: nil,
            sort: "popularity.desc", genre: nil, region: nil
        )
        let newFilter = DiscoverFilter(
            year: 2010, startYear: nil, endYear: nil,
            sort: "vote_average.desc", genre: 28, region: "US"
        )

        var current = AppState()
        current.moviesState.savedDiscoverFilters = [existingFilter]

        var imported = AppState()
        imported.moviesState.savedDiscoverFilters = [existingFilter, newFilter]

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        XCTAssertEqual(merged.moviesState.savedDiscoverFilters.count, 2,
                       "Duplicate filters should not be re-added")
        XCTAssertEqual(merged.moviesState.savedDiscoverFilters.last?.year, 2010)
    }

    // MARK: - Reducer integration

    func testAppActionsImportAppDataDispatchesIntoTheReducer() {
        var current = AppState()
        current.moviesState.wishlist.insert(1)

        var imported = AppState()
        imported.moviesState.wishlist.insert(2)
        imported.peoplesState.peoples[5] = makePeople(id: 5)
        imported.peoplesState.fanClub.insert(5)

        let action = AppActions.ImportAppData(envelope: envelope(wrapping: imported))
        let result = appReducerWithImports(state: current, action: action)

        XCTAssertEqual(result.moviesState.wishlist, [1, 2])
        XCTAssertTrue(result.peoplesState.fanClub.contains(5))
        XCTAssertNotNil(result.peoplesState.peoples[5])
    }
}

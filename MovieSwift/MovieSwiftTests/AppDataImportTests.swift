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

@Suite struct AppDataImportTests {

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
               profilePath: nil,
               knownForDepartment: nil,
               knownFor: nil,
               alsoKnownAs: nil,
               birthDay: nil,
               deathDay: nil,
               placeOfBirth: nil,
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

    @Test func decodeEnvelopeRoundTripsExportedData() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.wishlist.insert(1)

        let data = try AppDataExport.data(from: state)
        let decoded = try AppDataImport.decodeEnvelope(from: data)

        #expect(decoded.formatVersion == AppDataExportEnvelope.currentFormatVersion)
        #expect(decoded.snapshot.moviesState.wishlist.contains(1))
    }

    @Test func decodeEnvelopeRejectsUnsupportedFormatVersion() throws {
        // Build an envelope by hand with a future format version.
        let unsupported = AppDataExportEnvelope(
            formatVersion: AppDataExportEnvelope.currentFormatVersion + 1,
            exportDate: Date(),
            appVersion: "9.9",
            appBuild: "999",
            snapshot: AppState()
        )
        let data = try AppDataExport.data(from: unsupported)

        do {
            _ = try AppDataImport.decodeEnvelope(from: data)
            Issue.record("Expected unsupportedFormatVersion error, but no error was thrown")
        } catch {
            guard case AppDataImport.ImportError.unsupportedFormatVersion(let found, _) = error else {
                Issue.record("Expected unsupportedFormatVersion error, got \(error)")
                return
            }
            #expect(found == AppDataExportEnvelope.currentFormatVersion + 1)
        }
    }

    @Test func decodeEnvelopeWrapsCorruptDataInDecodeFailedError() {
        let bogus = Data("not actually json".utf8)

        do {
            _ = try AppDataImport.decodeEnvelope(from: bogus)
            Issue.record("Expected decodeFailed error, but no error was thrown")
        } catch {
            guard case AppDataImport.ImportError.decodeFailed = error else {
                Issue.record("Expected decodeFailed error, got \(error)")
                return
            }
        }
    }

    // MARK: - Preview counts

    @Test func previewCountsTrackOnlyAdditionsAndUpserts() {
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

        #expect(counts.wishlistAdded == 1)
        #expect(counts.seenlistAdded == 1)
        #expect(counts.fanClubAdded == 1)
        #expect(counts.customListsAdded == 1)
        #expect(counts.customListsUpdated == 1)
        #expect(counts.hasAnyChanges)
    }

    @Test func previewCountsHasNoChangesWhenImportIsASubset() {
        var current = AppState()
        current.moviesState.wishlist.insert(1)
        current.moviesState.wishlist.insert(2)
        current.peoplesState.fanClub.insert(7)

        var imported = AppState()
        imported.moviesState.wishlist.insert(1)
        imported.peoplesState.fanClub.insert(7)

        let counts = AppDataImport.previewCounts(for: envelope(wrapping: imported), against: current)
        #expect(!(counts.hasAnyChanges))
    }

    // MARK: - UI-test fixture

    /// Guards the fixture the Settings import UI test depends on: exporting
    /// `makeUITestImportFixtureState()` and merging it into the smoke state
    /// must add exactly the one custom list (id 99, "Imported List") the UI
    /// test then asserts appears in My Lists. Keeps the fixture honest
    /// without needing the full UI suite to catch a regression.
    @Test func uiTestImportFixtureAddsExactlyOneCustomListAbsentFromSmokeState() throws {
        let fixture = makeUITestImportFixtureState()
        #expect(fixture.moviesState.customLists[99]?.name == "Imported List")

        let data = try AppDataExport.data(from: fixture)
        let decoded = try AppDataImport.decodeEnvelope(from: data)
        #expect(decoded.snapshot.moviesState.customLists[99]?.name == "Imported List")

        let counts = AppDataImport.previewCounts(for: decoded, against: makeUISmokeTestState())
        #expect(counts.customListsAdded == 1)
    }

    // MARK: - Merge semantics

    @Test func mergeUnionsWishlistSeenlistAndFanClub() {
        var current = AppState()
        current.moviesState.wishlist.insert(1)
        current.moviesState.seenlist.insert(2)
        current.peoplesState.fanClub.insert(5)

        var imported = AppState()
        imported.moviesState.wishlist.insert(3)
        imported.moviesState.seenlist.insert(4)
        imported.peoplesState.fanClub.insert(6)

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        #expect(merged.moviesState.wishlist == [1, 3])
        #expect(merged.moviesState.seenlist == [2, 4])
        #expect(merged.peoplesState.fanClub == [5, 6])
    }

    @Test func mergeImportedCustomListWinsOnConflict() {
        var current = AppState()
        current.moviesState.customLists[10] = CustomList(id: 10, name: "Old name", cover: 1, movies: [1])

        var imported = AppState()
        imported.moviesState.customLists[10] = CustomList(id: 10, name: "Exported name", cover: 2, movies: [2, 3])
        imported.moviesState.customLists[11] = CustomList(id: 11, name: "Brand new", cover: nil, movies: [])

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        #expect(merged.moviesState.customLists[10]?.name == "Exported name")
        #expect(merged.moviesState.customLists[10]?.movies == [2, 3])
        #expect(merged.moviesState.customLists[11] != nil)
    }

    @Test func mergeKeepsCurrentReverseCacheEntriesOnConflict() {
        var current = AppState()
        // Current has a fresher entry — stash a marker we can verify
        // wasn't overwritten.
        current.moviesState.movies[42] = makeMovie(id: 42, title: "Fresh title")

        var imported = AppState()
        imported.moviesState.movies[42] = makeMovie(id: 42, title: "Stale title")
        imported.moviesState.movies[99] = makeMovie(id: 99)

        let merged = AppDataImport.merge(envelope: envelope(wrapping: imported), into: current)

        #expect(merged.moviesState.movies[42]?.title == "Fresh title",
                "Current cache entry should win on conflict")
        #expect(merged.moviesState.movies[99] != nil,
                "New cache entries from imported should be added")
    }

    @Test func mergeKeepsCurrentMovieUserMetaOnConflict() {
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

        #expect(merged.moviesState.moviesUserMeta[1]?.addedToList == Date(timeIntervalSince1970: 1000),
                "Current meta should win on conflict")
        #expect(merged.moviesState.moviesUserMeta[2] != nil,
                "Imported meta for new ids should be added")
    }

    @Test func mergeAppendsNewSavedDiscoverFiltersAndDeduplicates() {
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

        #expect(merged.moviesState.savedDiscoverFilters.count == 2,
                "Duplicate filters should not be re-added")
        #expect(merged.moviesState.savedDiscoverFilters.last?.year == 2010)
    }

    // MARK: - Reducer integration

    @Test func appActionsImportAppDataDispatchesIntoTheReducer() {
        var current = AppState()
        current.moviesState.wishlist.insert(1)

        var imported = AppState()
        imported.moviesState.wishlist.insert(2)
        imported.peoplesState.peoples[5] = makePeople(id: 5)
        imported.peoplesState.fanClub.insert(5)

        let action = AppActions.ImportAppData(envelope: envelope(wrapping: imported))
        let result = appReducerWithImports(state: current, action: action)

        #expect(result.moviesState.wishlist == [1, 2])
        #expect(result.peoplesState.fanClub.contains(5))
        #expect(result.peoplesState.peoples[5] != nil)
    }
}

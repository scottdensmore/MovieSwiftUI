import XCTest
import MovieSwiftFluxCore
#if os(tvOS)
@testable import MovieSwiftTV
#elseif os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class AppDataExportTests: XCTestCase {

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

    // MARK: - Envelope contents

    func testEnvelopeIncludesPersistentSnapshotOfUserLists() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.movies[3] = makeMovie(id: 3)
        state.moviesState.wishlist.insert(1)
        state.moviesState.seenlist.insert(2)
        state.moviesState.customLists[10] = CustomList(id: 10, name: "Favs", cover: 3, movies: [3])

        let envelope = AppDataExport.envelope(from: state,
                                              exportDate: Date(),
                                              appVersion: "1.0",
                                              appBuild: "1")

        XCTAssertTrue(envelope.snapshot.moviesState.wishlist.contains(1))
        XCTAssertTrue(envelope.snapshot.moviesState.seenlist.contains(2))
        XCTAssertEqual(envelope.snapshot.moviesState.customLists[10]?.name, "Favs")
        XCTAssertNotNil(envelope.snapshot.moviesState.movies[1])
        XCTAssertNotNil(envelope.snapshot.moviesState.movies[2])
        XCTAssertNotNil(envelope.snapshot.moviesState.movies[3])
    }

    func testEnvelopeStripsTransientCachesViaPersistentSnapshot() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist.insert(1)
        state.moviesState.moviesList[.popular] = [1, 99]
        state.moviesState.search["test"] = [99]
        state.moviesState.recommended[1] = [99]

        let envelope = AppDataExport.envelope(from: state,
                                              appVersion: "1.0",
                                              appBuild: "1")

        XCTAssertNotNil(envelope.snapshot.moviesState.movies[1])
        XCTAssertNil(envelope.snapshot.moviesState.movies[99],
                     "Movies that aren't in any user list shouldn't be exported")
        XCTAssertTrue(envelope.snapshot.moviesState.moviesList.isEmpty)
        XCTAssertTrue(envelope.snapshot.moviesState.search.isEmpty)
        XCTAssertTrue(envelope.snapshot.moviesState.recommended.isEmpty)
    }

    func testEnvelopeIncludesFanClubPeople() throws {
        var state = AppState()
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.peoples[6] = makePeople(id: 6)
        state.peoplesState.fanClub.insert(5)

        let envelope = AppDataExport.envelope(from: state,
                                              appVersion: "1.0",
                                              appBuild: "1")

        XCTAssertTrue(envelope.snapshot.peoplesState.fanClub.contains(5))
        XCTAssertNotNil(envelope.snapshot.peoplesState.peoples[5])
        XCTAssertNil(envelope.snapshot.peoplesState.peoples[6],
                     "Non-fan-club people shouldn't be exported")
    }

    // MARK: - Metadata

    func testEnvelopeStampsFormatVersionDateAndAppVersion() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let envelope = AppDataExport.envelope(from: AppState(),
                                              exportDate: date,
                                              appVersion: "2.3",
                                              appBuild: "42")

        XCTAssertEqual(envelope.formatVersion, AppDataExportEnvelope.currentFormatVersion)
        XCTAssertEqual(envelope.exportDate, date)
        XCTAssertEqual(envelope.appVersion, "2.3")
        XCTAssertEqual(envelope.appBuild, "42")
    }

    // MARK: - JSON encoding round-trip

    func testEncodedDataRoundTripsBackToTheSameUserLists() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.wishlist.insert(1)
        state.moviesState.seenlist.insert(2)
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.fanClub.insert(5)

        let data = try AppDataExport.data(from: state)

        let decoded = try AppDataExport.makeDecoder().decode(AppDataExportEnvelope.self, from: data)

        XCTAssertEqual(decoded.formatVersion, AppDataExportEnvelope.currentFormatVersion)
        XCTAssertTrue(decoded.snapshot.moviesState.wishlist.contains(1))
        XCTAssertTrue(decoded.snapshot.moviesState.seenlist.contains(2))
        XCTAssertTrue(decoded.snapshot.peoplesState.fanClub.contains(5))
    }

    func testEncodedDataIsPrettyPrintedJSON() throws {
        let data = try AppDataExport.data(from: AppState())

        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\n"),
                      "Expected pretty-printed JSON to contain newlines")
        XCTAssertTrue(json.contains("\"formatVersion\""),
                      "Expected formatVersion key in the encoded JSON")
        XCTAssertTrue(json.contains("\"snapshot\""),
                      "Expected snapshot key in the encoded JSON")
    }

    // MARK: - Filename

    func testSuggestedFilenameUsesISODate() {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 2
        components.hour = 9
        components.minute = 30

        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "UTC")!
        var calendarWithZone = calendar
        calendarWithZone.timeZone = timeZone
        let date = calendarWithZone.date(from: components)!

        let filename = AppDataExport.suggestedFilename(for: date,
                                                       calendar: calendarWithZone,
                                                       timeZone: timeZone)
        XCTAssertEqual(filename, "MovieSwift-Export-2026-05-02")
    }
}

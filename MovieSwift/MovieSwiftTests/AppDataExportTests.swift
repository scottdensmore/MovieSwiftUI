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

@Suite struct AppDataExportTests {

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

    @Test func envelopeIncludesPersistentSnapshotOfUserLists() throws {
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

        #expect(envelope.snapshot.moviesState.wishlist.contains(1))
        #expect(envelope.snapshot.moviesState.seenlist.contains(2))
        #expect(envelope.snapshot.moviesState.customLists[10]?.name == "Favs")
        #expect(envelope.snapshot.moviesState.movies[1] != nil)
        #expect(envelope.snapshot.moviesState.movies[2] != nil)
        #expect(envelope.snapshot.moviesState.movies[3] != nil)
    }

    @Test func envelopeStripsTransientCachesViaPersistentSnapshot() throws {
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

        #expect(envelope.snapshot.moviesState.movies[1] != nil)
        #expect(envelope.snapshot.moviesState.movies[99] == nil,
                "Movies that aren't in any user list shouldn't be exported")
        #expect(envelope.snapshot.moviesState.moviesList.isEmpty)
        #expect(envelope.snapshot.moviesState.search.isEmpty)
        #expect(envelope.snapshot.moviesState.recommended.isEmpty)
    }

    @Test func envelopeIncludesFanClubPeople() throws {
        var state = AppState()
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.peoples[6] = makePeople(id: 6)
        state.peoplesState.fanClub.insert(5)

        let envelope = AppDataExport.envelope(from: state,
                                              appVersion: "1.0",
                                              appBuild: "1")

        #expect(envelope.snapshot.peoplesState.fanClub.contains(5))
        #expect(envelope.snapshot.peoplesState.peoples[5] != nil)
        #expect(envelope.snapshot.peoplesState.peoples[6] == nil,
                "Non-fan-club people shouldn't be exported")
    }

    // MARK: - Metadata

    @Test func envelopeStampsFormatVersionDateAndAppVersion() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let envelope = AppDataExport.envelope(from: AppState(),
                                              exportDate: date,
                                              appVersion: "2.3",
                                              appBuild: "42")

        #expect(envelope.formatVersion == AppDataExportEnvelope.currentFormatVersion)
        #expect(envelope.exportDate == date)
        #expect(envelope.appVersion == "2.3")
        #expect(envelope.appBuild == "42")
    }

    // MARK: - JSON encoding round-trip

    @Test func encodedDataRoundTripsBackToTheSameUserLists() throws {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.movies[2] = makeMovie(id: 2)
        state.moviesState.wishlist.insert(1)
        state.moviesState.seenlist.insert(2)
        state.peoplesState.peoples[5] = makePeople(id: 5)
        state.peoplesState.fanClub.insert(5)

        let data = try AppDataExport.data(from: state)

        let decoded = try AppDataExport.makeDecoder().decode(AppDataExportEnvelope.self, from: data)

        #expect(decoded.formatVersion == AppDataExportEnvelope.currentFormatVersion)
        #expect(decoded.snapshot.moviesState.wishlist.contains(1))
        #expect(decoded.snapshot.moviesState.seenlist.contains(2))
        #expect(decoded.snapshot.peoplesState.fanClub.contains(5))
    }

    @Test func encodedDataIsPrettyPrintedJSON() throws {
        let data = try AppDataExport.data(from: AppState())

        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\n"),
                "Expected pretty-printed JSON to contain newlines")
        #expect(json.contains("\"formatVersion\""),
                "Expected formatVersion key in the encoded JSON")
        #expect(json.contains("\"snapshot\""),
                "Expected snapshot key in the encoded JSON")
    }

    // MARK: - Filename

    @Test func suggestedFilenameUsesISODate() {
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
        #expect(filename == "MovieSwift-Export-2026-05-02")
    }
}

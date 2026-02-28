import XCTest
@testable import MovieSwiftFluxCore

final class APIPayloadContractTests: XCTestCase {
    private func fixtureData(named name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: fixtureData(named: name))
    }

    func testMovieMenuPayloadDecodesExpectedShape() throws {
        let payload = try decodeFixture("movie_menu_response", as: PaginatedResponse<Movie>.self)

        XCTAssertEqual(payload.page, 3)
        XCTAssertEqual(payload.total_results, 10000)
        XCTAssertEqual(payload.total_pages, 500)
        XCTAssertEqual(payload.results.map(\.id), [101, 102])
        XCTAssertEqual(payload.results.first?.title, "Movie 101")
    }

    func testMovieDetailPayloadDecodesNestedContractFields() throws {
        let payload = try decodeFixture("movie_detail_response", as: Movie.self)

        XCTAssertEqual(payload.id, 205)
        XCTAssertEqual(payload.runtime, 134)
        XCTAssertEqual(payload.status, "Released")
        XCTAssertEqual(payload.genres?.map(\.id), [18, 12])
        XCTAssertEqual(payload.keywords?.keywords?.map(\.name), ["space", "future"])
        XCTAssertEqual(payload.images?.posters?.first?.file_path, "/poster-a.jpg")
        XCTAssertEqual(payload.images?.backdrops?.first?.width, 1920)
        XCTAssertEqual(payload.production_countries?.map(\.name), ["United States of America", "Canada"])
    }

    func testCastResponsePayloadDecodesCastAndCrewMetadata() throws {
        let payload = try decodeFixture("cast_response", as: CastResponse.self)

        XCTAssertEqual(payload.id, 205)
        XCTAssertEqual(payload.cast.first?.id, 301)
        XCTAssertEqual(payload.cast.first?.character, "Pilot")
        XCTAssertEqual(payload.cast.first?.known_for?.first?.id, 9001)
        XCTAssertEqual(payload.crew.first?.id, 302)
        XCTAssertEqual(payload.crew.first?.department, "Directing")
    }

    func testGenresResponsePayloadDecodesFetchGenresContract() throws {
        let payload = try decodeFixture("genres_response", as: MoviesActions.GenresResponse.self)

        XCTAssertEqual(payload.genres.map(\.id), [27, 35])
        XCTAssertEqual(payload.genres.map(\.name), ["Horror", "Comedy"])
    }
}

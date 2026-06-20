import Testing
import Foundation
@testable import MovieSwiftFluxCore

@Suite struct APIPayloadContractTests {
    private func fixtureData(named name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: fixtureData(named: name))
    }

    @Test func movieMenuPayloadDecodesExpectedShape() throws {
        let payload = try decodeFixture("movie_menu_response", as: PaginatedResponse<Movie>.self)

        #expect(payload.page == 3)
        #expect(payload.totalResults == 10000)
        #expect(payload.totalPages == 500)
        #expect(payload.results.map(\.id) == [101, 102])
        #expect(payload.results.first?.title == "Movie 101")
    }

    @Test func movieDetailPayloadDecodesNestedContractFields() throws {
        let payload = try decodeFixture("movie_detail_response", as: Movie.self)

        #expect(payload.id == 205)
        #expect(payload.runtime == 134)
        #expect(payload.status == "Released")
        #expect(payload.genres?.map(\.id) == [18, 12])
        #expect(payload.keywords?.keywords?.map(\.name) == ["space", "future"])
        #expect(payload.images?.posters?.first?.file_path == "/poster-a.jpg")
        #expect(payload.images?.backdrops?.first?.width == 1920)
        #expect(payload.production_countries?.map(\.name) == ["United States of America", "Canada"])
    }

    @Test func castResponsePayloadDecodesCastAndCrewMetadata() throws {
        let payload = try decodeFixture("cast_response", as: CastResponse.self)

        #expect(payload.id == 205)
        #expect(payload.cast.first?.id == 301)
        #expect(payload.cast.first?.character == "Pilot")
        #expect(payload.cast.first?.known_for?.first?.id == 9001)
        #expect(payload.crew.first?.id == 302)
        #expect(payload.crew.first?.department == "Directing")
    }

    @Test func genresResponsePayloadDecodesFetchGenresContract() throws {
        let payload = try decodeFixture("genres_response", as: MoviesActions.GenresResponse.self)

        #expect(payload.genres.map(\.id) == [27, 35])
        #expect(payload.genres.map(\.name) == ["Horror", "Comedy"])
    }
}

import XCTest
@testable import MovieSwift

final class MovieSwiftTests: XCTestCase {
    func testSampleMovieHasExpectedIdentifier() {
        XCTAssertEqual(sampleMovie.id, 0)
    }

    func testMoviesSortAPIMapping() {
        XCTAssertEqual(MoviesSort.byReleaseDate.sortByAPI(), "release_date.desc")
        XCTAssertEqual(MoviesSort.byAddedDate.sortByAPI(), "primary_release_date.desc")
        XCTAssertEqual(MoviesSort.byScore.sortByAPI(), "vote_average.desc")
        XCTAssertEqual(MoviesSort.byPopularity.sortByAPI(), "popularity.desc")
    }
}

import Testing
import MovieSwiftFluxCore

/// The Share action links to the public TMDB web page for a movie/person.
/// Pin the URL shapes so a typo doesn't ship a broken share link.
@Suite struct TMDBWebTests {
    @Test func movieURLPointsToTheMovieDatabaseMoviePage() {
        #expect(TMDBWeb.movieURL(id: 42).absoluteString == "https://www.themoviedb.org/movie/42")
    }

    @Test func personURLPointsToTheMovieDatabasePersonPage() {
        #expect(TMDBWeb.personURL(id: 7).absoluteString == "https://www.themoviedb.org/person/7")
    }
}

import Foundation
import Testing
@testable import MovieSwiftFluxCore

struct MoviesRegionTests {
    @Test("Only Now Playing and Upcoming are region-filtered by TMDB")
    func onlyNowPlayingAndUpcomingAreRegionFiltered() {
        #expect(MoviesMenu.nowPlaying.isRegionFiltered)
        #expect(MoviesMenu.upcoming.isRegionFiltered)
        #expect(!MoviesMenu.popular.isRegionFiltered)
        #expect(!MoviesMenu.topRated.isRegionFiltered)
        #expect(!MoviesMenu.trending.isRegionFiltered)
        #expect(!MoviesMenu.genres.isRegionFiltered)
    }

    @Test("regionCaption names the region with per-list phrasing")
    func regionCaptionNamesTheRegionPerList() {
        #expect(MoviesMenu.nowPlaying.regionCaption(regionName: "Albania").contains("Albania"))
        #expect(MoviesMenu.nowPlaying.regionCaption(regionName: "Albania")
            .localizedCaseInsensitiveContains("in theaters"))
        #expect(MoviesMenu.upcoming.regionCaption(regionName: "France")
            .localizedCaseInsensitiveContains("upcoming"))
        #expect(MoviesMenu.upcoming.regionCaption(regionName: "France").contains("France"))
        // The generic (non-region-filtered) branch still names the region.
        #expect(MoviesMenu.popular.regionCaption(regionName: "Germany").contains("Germany"))
    }

    @Test("Region codes resolve to localized names and fall back to the code")
    func regionDisplayNameResolvesCodesAndFallsBack() {
        // A real ISO code resolves to a localized name (≠ the raw code);
        // an unknown code falls back to the code itself so the UI is never blank.
        #expect(RegionPresentation.displayName(forRegionCode: "US") != "US")
        #expect(RegionPresentation.displayName(forRegionCode: "ZZZ") == "ZZZ")
    }
}

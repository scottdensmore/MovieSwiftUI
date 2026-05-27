import Testing
@testable import MovieSwiftFluxCore

/// Guards the localizability of the display-name helpers in this package.
///
/// These helpers (`MoviesMenu.title()`, `MoviesSort.title()`) used to
/// return bare `String` literals, which bypassed the String Catalog and
/// could never be translated. They now route through
/// `String(localized:bundle:.module)`. This suite pins the resolved
/// English ("en" is the package's source language) so a regression that
/// (a) drops the localization, (b) points at the wrong bundle, or
/// (c) changes a case's text is caught.
///
/// Note: with the package's source language being English, a missing
/// catalog entry would still resolve to the key itself — which for these
/// equals the English text — so this suite primarily guards the case
/// mapping and the presence of every case. The `bundle: .module`
/// correctness is exercised at runtime by the app (wrong-bundle lookups
/// would fall back to the key, which here is identical, so it stays safe
/// either way).
@Suite struct LocalizationTests {

    @Test func moviesMenuTitlesResolveForEveryCase() {
        let expected: [MoviesMenu: String] = [
            .popular: "Popular",
            .topRated: "Top Rated",
            .upcoming: "Upcoming",
            .nowPlaying: "Now Playing",
            .trending: "Trending",
            .genres: "Genres",
        ]
        // Every case must be covered, and each must produce a non-empty title.
        for menu in MoviesMenu.allCases {
            let title = menu.title()
            #expect(!title.isEmpty, "MoviesMenu.\(menu) produced an empty title")
            #expect(title == expected[menu],
                    "MoviesMenu.\(menu).title() should resolve to its English source string")
        }
        #expect(Set(MoviesMenu.allCases.map { $0.title() }).count == MoviesMenu.allCases.count,
                "Every MoviesMenu title should be distinct")
    }

    @Test func moviesSortTitlesResolveForEveryCase() {
        let cases: [(MoviesSort, String)] = [
            (.byReleaseDate, "by release date"),
            (.byAddedDate, "by added date"),
            (.byScore, "by rating"),
            (.byPopularity, "by popularity"),
        ]
        for (sort, expected) in cases {
            let title = sort.title()
            #expect(!title.isEmpty, "MoviesSort title was empty")
            #expect(title == expected,
                    "MoviesSort.\(sort).title() should resolve to its English source string")
        }
    }

    @Test func discoverFilterToTextLocalizesRandomFallback() {
        // A filter with no explicit year range renders the localized
        // "Random" token (rather than a bare literal). English source
        // resolves to "Random".
        let filter = DiscoverFilter(year: 2000, startYear: nil, endYear: nil,
                                    sort: "popularity.desc")
        let text = filter.toText(genres: [])
        #expect(text.contains("Random"),
                "DiscoverFilter.toText should include the localized Random token when no year range is set; got: \(text)")
    }
}

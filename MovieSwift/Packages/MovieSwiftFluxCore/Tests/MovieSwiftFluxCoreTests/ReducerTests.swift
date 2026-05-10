import XCTest
@testable import MovieSwiftFluxCore

final class ReducerTests: XCTestCase {
    func testMoviesReducerSetMovieMenuListPageOneReplacesList() {
        var state = MoviesState()
        state.moviesList[.popular] = [999]

        let response = paginated([makeMovie(id: 1), makeMovie(id: 2)])
        let action = MoviesActions.SetMovieMenuList(page: 1, list: .popular, response: response)

        let reduced = moviesStateReducer(state: state, action: action)

        XCTAssertEqual(reduced.moviesList[.popular] ?? [], [1, 2])
        XCTAssertEqual(reduced.movies[1]?.id, 1)
        XCTAssertEqual(reduced.movies[2]?.id, 2)
    }

    func testMoviesReducerSetMovieMenuListPageTwoAppendsList() {
        var state = MoviesState()
        state.moviesList[.trending] = [1]

        let response = paginated([makeMovie(id: 2), makeMovie(id: 3)])
        let action = MoviesActions.SetMovieMenuList(page: 2, list: .trending, response: response)

        let reduced = moviesStateReducer(state: state, action: action)

        XCTAssertEqual(reduced.moviesList[.trending] ?? [], [1, 2, 3])
    }

    func testMoviesReducerAddToWishlistMovesMovieAndAddsMetaTimestamp() {
        var state = MoviesState()
        state.seenlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddToWishlist(movie: 42))

        XCTAssertTrue(reduced.wishlist.contains(42))
        XCTAssertFalse(reduced.seenlist.contains(42))
        XCTAssertNotNil(reduced.moviesUserMeta[42]?.addedToList)
    }

    func testMoviesReducerSetRandomDiscoverPrependsWhenBelowLimit() {
        var state = MoviesState()
        state.discover = [100, 101]
        let filter = DiscoverFilter(year: 1990, startYear: nil, endYear: nil, sort: "popularity.desc", genre: 12, region: "US")
        let response = paginated([makeMovie(id: 1), makeMovie(id: 2)])

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetRandomDiscover(filter: filter, response: response)
        )

        XCTAssertEqual(reduced.discover, [1, 2, 100, 101])
        XCTAssertEqual(reduced.movies[1]?.id, 1)
        XCTAssertEqual(reduced.movies[2]?.id, 2)
        XCTAssertEqual(reduced.discoverFilter?.year, filter.year)
        XCTAssertEqual(reduced.discoverFilter?.sort, filter.sort)
        XCTAssertEqual(reduced.discoverFilter?.genre, filter.genre)
        XCTAssertEqual(reduced.discoverFilter?.region, filter.region)
    }

    func testMoviesReducerSetRandomDiscoverDoesNotPrependWhenAtLimit() {
        var state = MoviesState()
        state.discover = Array(1...10)
        let filter = DiscoverFilter(year: 1990, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)
        let response = paginated([makeMovie(id: 99)])

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetRandomDiscover(filter: filter, response: response)
        )

        XCTAssertEqual(reduced.discover, Array(1...10))
        XCTAssertEqual(reduced.movies[99]?.id, 99)
        XCTAssertEqual(reduced.discoverFilter?.year, 1990)
    }
    
    func testMoviesReducerSetActiveDiscoverFilterUpdatesFilterImmediately() {
        var state = MoviesState()
        state.discoverFilter = nil
        let filter = DiscoverFilter(year: 2001, startYear: 1990, endYear: 1999, sort: "popularity.desc", genre: 28, region: "US")
        
        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetActiveDiscoverFilter(filter: filter)
        )
        
        XCTAssertEqual(reduced.discoverFilter?.startYear, 1990)
        XCTAssertEqual(reduced.discoverFilter?.endYear, 1999)
        XCTAssertEqual(reduced.discoverFilter?.genre, 28)
        XCTAssertEqual(reduced.discoverFilter?.region, "US")
    }

    func testMoviesReducerSetGenresInsertsRandomGenreFirst() {
        let genres = [Genre(id: 7, name: "Drama"), Genre(id: 8, name: "Comedy")]

        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetGenres(genres: genres))

        XCTAssertEqual(reduced.genres.first?.id, -1)
        XCTAssertEqual(reduced.genres.first?.name, "Random")
        XCTAssertEqual(reduced.genres.dropFirst().map(\.id), [7, 8])
    }

    func testMoviesReducerAddMoviesToCustomListMergesIntoExistingList() {
        let existing = CustomList(id: 9, name: "Favorites", cover: nil, movies: [1, 2])
        var state = MoviesState()
        state.customLists[9] = existing

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.AddMoviesToCustomList(list: 9, movies: [2, 3, 4])
        )

        XCTAssertEqual(reduced.customLists[9]?.movies, Set([1, 2, 3, 4]))
    }

    func testMoviesReducerEditCustomListUpdatesOnlyProvidedFields() {
        let existing = CustomList(id: 4, name: "Weekend", cover: 7, movies: [7, 8])
        var state = MoviesState()
        state.customLists[4] = existing

        let renamed = moviesStateReducer(
            state: state,
            action: MoviesActions.EditCustomList(list: 4, title: "Weeknight", cover: nil)
        )
        XCTAssertEqual(renamed.customLists[4]?.name, "Weeknight")
        XCTAssertEqual(renamed.customLists[4]?.cover, 7)

        let recoved = moviesStateReducer(
            state: renamed,
            action: MoviesActions.EditCustomList(list: 4, title: nil, cover: 11)
        )
        XCTAssertEqual(recoved.customLists[4]?.name, "Weeknight")
        XCTAssertEqual(recoved.customLists[4]?.cover, 11)
    }

    func testPeopleReducerSetDetailPreservesExistingMetadataFields() {
        let knownFor = [People.KnownFor(id: 90, original_title: "Old", poster_path: "/old.jpg")]
        let images = [ImageData(aspect_ratio: 1.0, file_path: "/img.jpg", height: 10, width: 10)]

        var state = PeoplesState()
        state.peoples[5] = makePeople(id: 5, name: "Old Name", character: "Old Char", department: "Directing", knownFor: knownFor, images: images)

        let incoming = makePeople(id: 5, name: "New Name", character: nil, department: nil, knownFor: nil, images: nil)
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetDetail(person: incoming))

        XCTAssertEqual(reduced.peoples[5]?.name, "New Name")
        // SetDetail only preserves known_for and images from the existing record;
        // character and department come from the incoming person as-is.
        XCTAssertNil(reduced.peoples[5]?.character)
        XCTAssertNil(reduced.peoples[5]?.department)
        XCTAssertEqual(reduced.peoples[5]?.known_for?.first?.id, 90)
        XCTAssertEqual(reduced.peoples[5]?.images?.first?.file_path, "/img.jpg")
    }

    func testPeopleReducerSetMovieCastsMergesPeopleAndIndexesMovie() {
        let cast = makePeople(id: 1, name: "Cast Member")
        let crew = makePeople(id: 2, name: "Crew Member")
        let response = CastResponse(id: 100, cast: [cast], crew: [crew])

        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetMovieCasts(movie: 99, response: response))

        XCTAssertEqual(reduced.peoples[1]?.name, "Cast Member")
        XCTAssertEqual(reduced.peoples[2]?.name, "Crew Member")
        XCTAssertEqual(reduced.peoplesMovies[99], Set([1, 2]))
    }

    func testPeopleReducerSetPeopleCreditsStoresCharacterAndDepartmentMaps() {
        let castMovie = makeMovie(id: 10, character: "Hero", department: nil)
        let castMovieWithoutCharacter = makeMovie(id: 11, character: nil, department: nil)
        let crewMovie = makeMovie(id: 20, character: nil, department: "Directing")
        let crewMovieWithoutDepartment = makeMovie(id: 21, character: nil, department: nil)

        let response = PeopleActions.PeopleCreditsResponse(
            cast: [castMovie, castMovieWithoutCharacter],
            crew: [crewMovie, crewMovieWithoutDepartment]
        )

        let reduced = peoplesStateReducer(
            state: PeoplesState(),
            action: PeopleActions.SetPeopleCredits(people: 7, response: response)
        )

        XCTAssertEqual(reduced.casts[7]?[10], "Hero")
        XCTAssertNil(reduced.casts[7]?[11])
        XCTAssertEqual(reduced.crews[7]?[20], "Directing")
        XCTAssertNil(reduced.crews[7]?[21])
    }

    func testAppReducerRoutesMovieActionToMoviesState() {
        var state = AppState()
        state.moviesState.seenlist.insert(5)

        let reduced = appStateReducer(state: state, action: MoviesActions.AddToWishlist(movie: 5))

        XCTAssertTrue(reduced.moviesState.wishlist.contains(5))
        XCTAssertFalse(reduced.moviesState.seenlist.contains(5))
    }

    func testAppReducerRoutesPeopleActionToPeoplesState() {
        let reduced = appStateReducer(state: AppState(), action: PeopleActions.AddToFanClub(people: 55))

        XCTAssertTrue(reduced.peoplesState.fanClub.contains(55))
    }

    // MARK: - MoviesReducer: SetDetail

    func testMoviesReducerSetDetailStoresMovieAndMarksDetailed() {
        let movie = makeMovie(id: 42)
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetDetail(movie: 42, response: movie))

        XCTAssertEqual(reduced.movies[42]?.id, 42)
        XCTAssertTrue(reduced.detailed.contains(42))
    }

    // MARK: - MoviesReducer: SetRecommended / SetSimilar

    func testMoviesReducerSetRecommendedMergesMoviesAndMarksLoaded() {
        let response = paginated([makeMovie(id: 10), makeMovie(id: 11)])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetRecommended(movie: 5, response: response))

        XCTAssertEqual(reduced.recommended[5], [10, 11])
        XCTAssertTrue(reduced.recommendedLoaded.contains(5))
        XCTAssertNotNil(reduced.movies[10])
        XCTAssertNotNil(reduced.movies[11])
    }

    func testMoviesReducerSetSimilarMergesMoviesAndMarksLoaded() {
        let response = paginated([makeMovie(id: 20)])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetSimilar(movie: 6, response: response))

        XCTAssertEqual(reduced.similar[6], [20])
        XCTAssertTrue(reduced.similarLoaded.contains(6))
    }

    // MARK: - MoviesReducer: SetVideos

    func testMoviesReducerSetVideosStoresResultsAndMarksLoaded() {
        let video = Video(id: "v1", name: "Trailer", site: "YouTube", key: "abc", type: "Trailer")
        let response = PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [video])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetVideos(movie: 7, response: response))

        XCTAssertEqual(reduced.videos[7]?.first?.key, "abc")
        XCTAssertTrue(reduced.videosLoaded.contains(7))
    }

    // MARK: - MoviesReducer: SetSearch

    func testMoviesReducerSetSearchPageOneReplacesList() {
        var state = MoviesState()
        state.search["old"] = [999]

        let response = paginated([makeMovie(id: 1)])
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetSearch(query: "old", page: 1, response: response))

        XCTAssertEqual(reduced.search["old"], [1])
    }

    func testMoviesReducerSetSearchPageTwoAppendsList() {
        var state = MoviesState()
        state.search["q"] = [1]

        let response = paginated([makeMovie(id: 2)])
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetSearch(query: "q", page: 2, response: response))

        XCTAssertEqual(reduced.search["q"], [1, 2])
    }

    // MARK: - MoviesReducer: SetSearchKeyword

    func testMoviesReducerSetSearchKeywordStoresKeywords() {
        let keywords = [Keyword(id: 1, name: "neo-noir"), Keyword(id: 2, name: "heist")]
        let response = PaginatedResponse(page: 1, total_results: 2, total_pages: 1, results: keywords)
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetSearchKeyword(query: "noir", response: response))

        XCTAssertEqual(reduced.searchKeywords["noir"]?.count, 2)
        XCTAssertEqual(reduced.searchKeywords["noir"]?.first?.name, "neo-noir")
    }

    // MARK: - MoviesReducer: Wishlist / Seenlist

    func testMoviesReducerRemoveFromWishlistRemovesMovie() {
        var state = MoviesState()
        state.wishlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveFromWishlist(movie: 42))

        XCTAssertFalse(reduced.wishlist.contains(42))
    }

    func testMoviesReducerAddToSeenListMovesFromWishlistAndAddsTimestamp() {
        var state = MoviesState()
        state.wishlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddToSeenList(movie: 42))

        XCTAssertTrue(reduced.seenlist.contains(42))
        XCTAssertFalse(reduced.wishlist.contains(42))
        XCTAssertNotNil(reduced.moviesUserMeta[42]?.addedToList)
    }

    func testMoviesReducerRemoveFromSeenListRemovesMovie() {
        var state = MoviesState()
        state.seenlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveFromSeenList(movie: 42))

        XCTAssertFalse(reduced.seenlist.contains(42))
    }

    // MARK: - MoviesReducer: CustomList operations

    func testMoviesReducerAddMovieToCustomListInsertsMovie() {
        var state = MoviesState()
        state.customLists[1] = CustomList(id: 1, name: "Favorites", cover: nil, movies: [10])

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddMovieToCustomList(list: 1, movie: 20))

        XCTAssertTrue(reduced.customLists[1]?.movies.contains(20) == true)
        XCTAssertTrue(reduced.customLists[1]?.movies.contains(10) == true)
    }

    func testMoviesReducerRemoveMovieFromCustomListRemovesMovie() {
        var state = MoviesState()
        state.customLists[1] = CustomList(id: 1, name: "Favorites", cover: nil, movies: [10, 20])

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveMovieFromCustomList(list: 1, movie: 10))

        XCTAssertFalse(reduced.customLists[1]?.movies.contains(10) == true)
        XCTAssertTrue(reduced.customLists[1]?.movies.contains(20) == true)
    }

    func testMoviesReducerAddCustomListStoresList() {
        let list = CustomList(id: 5, name: "Watch Later", cover: nil, movies: [])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.AddCustomList(list: list))

        XCTAssertEqual(reduced.customLists[5]?.name, "Watch Later")
    }

    func testMoviesReducerRemoveCustomListNilifiesEntry() {
        var state = MoviesState()
        state.customLists[5] = CustomList(id: 5, name: "Old", cover: nil, movies: [])

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveCustomList(list: 5))

        XCTAssertNil(reduced.customLists[5])
    }

    // MARK: - MoviesReducer: Genre / Crew / Keyword movies

    func testMoviesReducerSetMovieForGenrePageOneReplacesList() {
        var state = MoviesState()
        state.withGenre[28] = [999]

        let genre = Genre(id: 28, name: "Action")
        let response = paginated([makeMovie(id: 1)])
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetMovieForGenre(genre: genre, page: 1, response: response))

        XCTAssertEqual(reduced.withGenre[28], [1])
    }

    func testMoviesReducerSetMovieForGenrePageTwoAppendsList() {
        var state = MoviesState()
        state.withGenre[28] = [1]

        let genre = Genre(id: 28, name: "Action")
        let response = paginated([makeMovie(id: 2)])
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetMovieForGenre(genre: genre, page: 2, response: response))

        XCTAssertEqual(reduced.withGenre[28], [1, 2])
    }

    func testMoviesReducerSetMovieWithCrewStoresResults() {
        let response = paginated([makeMovie(id: 10)])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetMovieWithCrew(crew: 15, response: response))

        XCTAssertEqual(reduced.withCrew[15], [10])
    }

    func testMoviesReducerSetMovieWithKeywordPageOneReplacesList() {
        var state = MoviesState()
        state.withKeywords[50] = [999]

        let response = paginated([makeMovie(id: 1)])
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetMovieWithKeyword(keyword: 50, page: 1, response: response))

        XCTAssertEqual(reduced.withKeywords[50], [1])
    }

    func testMoviesReducerSetMovieWithKeywordPageTwoAppendsList() {
        var state = MoviesState()
        state.withKeywords[50] = [1]

        let response = paginated([makeMovie(id: 2)])
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetMovieWithKeyword(keyword: 50, page: 2, response: response))

        XCTAssertEqual(reduced.withKeywords[50], [1, 2])
    }

    // MARK: - MoviesReducer: Reviews

    func testMoviesReducerSetMovieReviewsStoresResultsAndMarksLoaded() {
        let review = Review(id: "r1", author: "Critic", content: "Great")
        let response = PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [review])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetMovieReviews(movie: 8, response: response))

        XCTAssertEqual(reduced.reviews[8]?.first?.author, "Critic")
        XCTAssertTrue(reduced.reviewsLoaded.contains(8))
    }

    // MARK: - MoviesReducer: Discover operations

    func testMoviesReducerPopRandomDiscoverRemovesLastElement() {
        var state = MoviesState()
        state.discover = [1, 2, 3]

        let reduced = moviesStateReducer(state: state, action: MoviesActions.PopRandromDiscover())

        XCTAssertEqual(reduced.discover, [1, 2])
    }

    func testMoviesReducerPushRandomDiscoverAppendsMovie() {
        var state = MoviesState()
        state.discover = [1, 2]

        let reduced = moviesStateReducer(state: state, action: MoviesActions.PushRandomDiscover(movie: 3))

        XCTAssertEqual(reduced.discover, [1, 2, 3])
    }

    func testMoviesReducerResetRandomDiscoverClearsFilterAndList() {
        var state = MoviesState()
        state.discover = [1, 2, 3]
        state.discoverFilter = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.ResetRandomDiscover())

        XCTAssertTrue(reduced.discover.isEmpty)
        XCTAssertNil(reduced.discoverFilter)
    }

    func testMoviesReducerSaveDiscoverFilterAppendsFilter() {
        var state = MoviesState()
        let filter1 = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)
        state.savedDiscoverFilters = [filter1]

        let filter2 = DiscoverFilter(year: 2010, startYear: nil, endYear: nil, sort: "vote_average.desc", genre: 28, region: "US")
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SaveDiscoverFilter(filter: filter2))

        XCTAssertEqual(reduced.savedDiscoverFilters.count, 2)
        XCTAssertEqual(reduced.savedDiscoverFilters.last?.year, 2010)
    }

    func testMoviesReducerClearSavedDiscoverFiltersEmptiesArray() {
        var state = MoviesState()
        let filter = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)
        state.savedDiscoverFilters = [filter]

        let reduced = moviesStateReducer(state: state, action: MoviesActions.ClearSavedDiscoverFilters())

        XCTAssertTrue(reduced.savedDiscoverFilters.isEmpty)
    }

    // MARK: - MoviesReducer: Cross-reducer (PeopleCredits merges movies)

    func testMoviesReducerPeopleCreditsAlsoMergesMoviesIntoMoviesState() {
        let castMovie = makeMovie(id: 10)
        let crewMovie = makeMovie(id: 20)
        let response = PeopleActions.PeopleCreditsResponse(cast: [castMovie], crew: [crewMovie])

        let reduced = moviesStateReducer(state: MoviesState(), action: PeopleActions.SetPeopleCredits(people: 7, response: response))

        XCTAssertNotNil(reduced.movies[10])
        XCTAssertNotNil(reduced.movies[20])
    }

    // MARK: - PeopleReducer: Search

    func testPeopleReducerSetSearchPageOneReplacesList() {
        var state = PeoplesState()
        state.search["old"] = [999]

        let response = PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makePeople(id: 1, name: "A")])
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetSearch(query: "old", page: 1, response: response))

        XCTAssertEqual(reduced.search["old"], [1])
    }

    func testPeopleReducerSetSearchPageTwoAppendsList() {
        var state = PeoplesState()
        state.search["q"] = [1]

        let response = PaginatedResponse(page: 2, total_results: 2, total_pages: 2, results: [makePeople(id: 2, name: "B")])
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetSearch(query: "q", page: 2, response: response))

        XCTAssertEqual(reduced.search["q"], [1, 2])
    }

    // MARK: - PeopleReducer: Popular

    func testPeopleReducerSetPopularPageOneReplacesList() {
        var state = PeoplesState()
        state.popular = [999]
        state.popularLoading = true

        let response = PaginatedResponse(page: 1, total_results: 1, total_pages: 1, results: [makePeople(id: 1, name: "A")])
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetPopular(page: 1, response: response))

        XCTAssertEqual(reduced.popular, [1])
        XCTAssertFalse(reduced.popularLoading)
        XCTAssertTrue(reduced.popularInitialLoadCompleted)
    }

    func testPeopleReducerSetPopularPageTwoAppendsUnique() {
        var state = PeoplesState()
        state.popular = [1, 2]

        let response = PaginatedResponse(page: 2, total_results: 3, total_pages: 2, results: [makePeople(id: 2, name: "B"), makePeople(id: 3, name: "C")])
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetPopular(page: 2, response: response))

        XCTAssertEqual(reduced.popular, [1, 2, 3])
    }

    // MARK: - PeopleReducer: PopularRequestStarted / Failed

    func testPeopleReducerPopularRequestStartedSetsLoadingState() {
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.PopularRequestStarted(page: 1))

        XCTAssertTrue(reduced.popularLoading)
        XCTAssertFalse(reduced.popularLoadFailed)
        XCTAssertFalse(reduced.popularInitialLoadCompleted)
    }

    func testPeopleReducerPopularRequestFailedSetsFailedState() {
        var state = PeoplesState()
        state.popularLoading = true

        let reduced = peoplesStateReducer(state: state, action: PeopleActions.PopularRequestFailed(page: 1))

        XCTAssertFalse(reduced.popularLoading)
        XCTAssertTrue(reduced.popularLoadFailed)
        XCTAssertTrue(reduced.popularInitialLoadCompleted)
    }

    // MARK: - PeopleReducer: FanClub

    func testPeopleReducerAddToFanClubInsertsPeopleId() {
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.AddToFanClub(people: 55))

        XCTAssertTrue(reduced.fanClub.contains(55))
    }

    func testPeopleReducerRemoveFromFanClubRemovesPeopleId() {
        var state = PeoplesState()
        state.fanClub.insert(55)

        let reduced = peoplesStateReducer(state: state, action: PeopleActions.RemoveFromFanClub(people: 55))

        XCTAssertFalse(reduced.fanClub.contains(55))
    }

    // MARK: - PeopleReducer: SetImages

    func testPeopleReducerSetImagesStoresImagesAndMarksLoaded() {
        let images = [ImageData(aspect_ratio: 0.67, file_path: "/img.jpg", height: 300, width: 200)]
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetImages(people: 7, images: images))

        XCTAssertEqual(reduced.peoples[7]?.images?.first?.file_path, "/img.jpg")
        XCTAssertTrue(reduced.imagesLoaded.contains(7))
    }

    // MARK: - PeopleReducer: SetDetail new person

    func testPeopleReducerSetDetailNewPersonStoresDirectly() {
        let person = makePeople(id: 10, name: "New Person")
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetDetail(person: person))

        XCTAssertEqual(reduced.peoples[10]?.name, "New Person")
        XCTAssertTrue(reduced.detailed.contains(10))
    }

    private func paginated<T: Codable>(_ values: [T]) -> PaginatedResponse<T> {
        PaginatedResponse(page: 1, total_results: values.count, total_pages: 1, results: values)
    }

    private func makeMovie(id: Int, character: String? = nil, department: String? = nil) -> Movie {
        Movie(
            id: id,
            original_title: "Original \(id)",
            title: "Title \(id)",
            overview: "Overview \(id)",
            poster_path: nil,
            backdrop_path: nil,
            popularity: 1.0,
            vote_average: 2.0,
            vote_count: 3,
            release_date: "2020-01-01",
            genres: nil,
            runtime: nil,
            status: nil,
            video: false,
            keywords: nil,
            images: nil,
            production_countries: nil,
            character: character,
            department: department
        )
    }

    private func makePeople(
        id: Int,
        name: String,
        character: String? = nil,
        department: String? = nil,
        knownFor: [People.KnownFor]? = nil,
        images: [ImageData]? = nil
    ) -> People {
        People(
            id: id,
            name: name,
            character: character,
            department: department,
            profile_path: nil,
            known_for_department: nil,
            known_for: knownFor,
            also_known_as: nil,
            birthDay: nil,
            deathDay: nil,
            place_of_birth: nil,
            biography: nil,
            popularity: nil,
            images: images
        )
    }
}

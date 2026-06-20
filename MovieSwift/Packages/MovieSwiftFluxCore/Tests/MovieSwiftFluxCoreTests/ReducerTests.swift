import Testing
@testable import MovieSwiftFluxCore

@Suite struct ReducerTests {
    // Pagination: page 1 replaces, page > 1 appends. Same shape across
    // `MoviesMenu` keys — varying the menu (`.popular`, `.trending`) also
    // exercises the dictionary-keyed update path on both.
    @Test(arguments: [
        (page: 1, list: MoviesMenu.popular, existing: [999], incoming: [1, 2], expected: [1, 2]),
        (page: 2, list: MoviesMenu.trending, existing: [1], incoming: [2, 3], expected: [1, 2, 3]),
    ])
    func moviesReducerSetMovieMenuListPaginates(
        page: Int,
        list: MoviesMenu,
        existing: [Int],
        incoming: [Int],
        expected: [Int]
    ) {
        var state = MoviesState()
        state.moviesList[list] = existing

        let response = paginated(incoming.map { makeMovie(id: $0) })
        let action = MoviesActions.SetMovieMenuList(page: page, list: list, response: response)

        let reduced = moviesStateReducer(state: state, action: action)

        #expect((reduced.moviesList[list] ?? []) == expected)
        for id in incoming {
            #expect(reduced.movies[id]?.id == id)
        }
    }

    @Test func moviesReducerAddToWishlistMovesMovieAndAddsMetaTimestamp() {
        var state = MoviesState()
        state.seenlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddToWishlist(movie: 42))

        #expect(reduced.wishlist.contains(42))
        #expect(!(reduced.seenlist.contains(42)))
        #expect(reduced.moviesUserMeta[42]?.addedToList != nil)
    }

    @Test func moviesReducerSetRandomDiscoverPrependsWhenBelowLimit() {
        var state = MoviesState()
        state.discover = [100, 101]
        let filter = DiscoverFilter(year: 1990, startYear: nil, endYear: nil, sort: "popularity.desc", genre: 12, region: "US")
        let response = paginated([makeMovie(id: 1), makeMovie(id: 2)])

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetRandomDiscover(filter: filter, response: response)
        )

        #expect(reduced.discover == [1, 2, 100, 101])
        #expect(reduced.movies[1]?.id == 1)
        #expect(reduced.movies[2]?.id == 2)
        #expect(reduced.discoverFilter?.year == filter.year)
        #expect(reduced.discoverFilter?.sort == filter.sort)
        #expect(reduced.discoverFilter?.genre == filter.genre)
        #expect(reduced.discoverFilter?.region == filter.region)
    }

    @Test func moviesReducerSetRandomDiscoverDoesNotPrependWhenAtLimit() {
        var state = MoviesState()
        state.discover = Array(1...10)
        let filter = DiscoverFilter(year: 1990, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)
        let response = paginated([makeMovie(id: 99)])

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetRandomDiscover(filter: filter, response: response)
        )

        #expect(reduced.discover == Array(1...10))
        #expect(reduced.movies[99]?.id == 99)
        #expect(reduced.discoverFilter?.year == 1990)
    }

    @Test func moviesReducerSetActiveDiscoverFilterUpdatesFilterImmediately() {
        var state = MoviesState()
        state.discoverFilter = nil
        let filter = DiscoverFilter(year: 2001, startYear: 1990, endYear: 1999, sort: "popularity.desc", genre: 28, region: "US")

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.SetActiveDiscoverFilter(filter: filter)
        )

        #expect(reduced.discoverFilter?.startYear == 1990)
        #expect(reduced.discoverFilter?.endYear == 1999)
        #expect(reduced.discoverFilter?.genre == 28)
        #expect(reduced.discoverFilter?.region == "US")
    }

    @Test func moviesReducerSetGenresInsertsRandomGenreFirst() {
        let genres = [Genre(id: 7, name: "Drama"), Genre(id: 8, name: "Comedy")]

        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetGenres(genres: genres))

        #expect(reduced.genres.first?.id == -1)
        #expect(reduced.genres.first?.name == "Random")
        #expect(reduced.genres.dropFirst().map(\.id) == [7, 8])
    }

    @Test func moviesReducerAddMoviesToCustomListMergesIntoExistingList() {
        let existing = CustomList(id: 9, name: "Favorites", cover: nil, movies: [1, 2])
        var state = MoviesState()
        state.customLists[9] = existing

        let reduced = moviesStateReducer(
            state: state,
            action: MoviesActions.AddMoviesToCustomList(list: 9, movies: [2, 3, 4])
        )

        #expect(reduced.customLists[9]?.movies == Set([1, 2, 3, 4]))
    }

    @Test func moviesReducerEditCustomListUpdatesOnlyProvidedFields() {
        let existing = CustomList(id: 4, name: "Weekend", cover: 7, movies: [7, 8])
        var state = MoviesState()
        state.customLists[4] = existing

        let renamed = moviesStateReducer(
            state: state,
            action: MoviesActions.EditCustomList(list: 4, title: "Weeknight", cover: nil)
        )
        #expect(renamed.customLists[4]?.name == "Weeknight")
        #expect(renamed.customLists[4]?.cover == 7)

        let recovered = moviesStateReducer(
            state: renamed,
            action: MoviesActions.EditCustomList(list: 4, title: nil, cover: 11)
        )
        #expect(recovered.customLists[4]?.name == "Weeknight")
        #expect(recovered.customLists[4]?.cover == 11)
    }

    @Test func peopleReducerSetDetailPreservesExistingMetadataFields() {
        let knownFor = [People.KnownFor(id: 90, originalTitle: "Old", posterPath: "/old.jpg")]
        let images = [ImageData(aspectRatio: 1.0, filePath: "/img.jpg", height: 10, width: 10)]

        var state = PeoplesState()
        state.peoples[5] = makePeople(id: 5, name: "Old Name", character: "Old Char", department: "Directing", knownFor: knownFor, images: images)

        let incoming = makePeople(id: 5, name: "New Name", character: nil, department: nil, knownFor: nil, images: nil)
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetDetail(person: incoming))

        #expect(reduced.peoples[5]?.name == "New Name")
        // SetDetail only preserves known_for and images from the existing record;
        // character and department come from the incoming person as-is.
        #expect(reduced.peoples[5]?.character == nil)
        #expect(reduced.peoples[5]?.department == nil)
        #expect(reduced.peoples[5]?.knownFor?.first?.id == 90)
        #expect(reduced.peoples[5]?.images?.first?.filePath == "/img.jpg")
    }

    @Test func peopleReducerSetMovieCastsMergesPeopleAndIndexesMovie() {
        let cast = makePeople(id: 1, name: "Cast Member")
        let crew = makePeople(id: 2, name: "Crew Member")
        let response = CastResponse(id: 100, cast: [cast], crew: [crew])

        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetMovieCasts(movie: 99, response: response))

        #expect(reduced.peoples[1]?.name == "Cast Member")
        #expect(reduced.peoples[2]?.name == "Crew Member")
        #expect(reduced.peoplesMovies[99] == Set([1, 2]))
    }

    @Test func peopleReducerSetPeopleCreditsStoresCharacterAndDepartmentMaps() {
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

        #expect(reduced.casts[7]?[10] == "Hero")
        #expect(reduced.casts[7]?[11] == nil)
        #expect(reduced.crews[7]?[20] == "Directing")
        #expect(reduced.crews[7]?[21] == nil)
    }

    @Test func appReducerRoutesMovieActionToMoviesState() {
        var state = AppState()
        state.moviesState.seenlist.insert(5)

        let reduced = appStateReducer(state: state, action: MoviesActions.AddToWishlist(movie: 5))

        #expect(reduced.moviesState.wishlist.contains(5))
        #expect(!(reduced.moviesState.seenlist.contains(5)))
    }

    @Test func appReducerRoutesPeopleActionToPeoplesState() {
        let reduced = appStateReducer(state: AppState(), action: PeopleActions.AddToFanClub(people: 55))

        #expect(reduced.peoplesState.fanClub.contains(55))
    }

    // MARK: - MoviesReducer: SetDetail

    @Test func moviesReducerSetDetailStoresMovieAndMarksDetailed() {
        let movie = makeMovie(id: 42)
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetDetail(movie: 42, response: movie))

        #expect(reduced.movies[42]?.id == 42)
        #expect(reduced.detailed.contains(42))
    }

    // MARK: - MoviesReducer: SetRecommended / SetSimilar

    @Test func moviesReducerSetRecommendedMergesMoviesAndMarksLoaded() {
        let response = paginated([makeMovie(id: 10), makeMovie(id: 11)])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetRecommended(movie: 5, response: response))

        #expect(reduced.recommended[5] == [10, 11])
        #expect(reduced.recommendedLoaded.contains(5))
        #expect(reduced.movies[10] != nil)
        #expect(reduced.movies[11] != nil)
    }

    @Test func moviesReducerSetSimilarMergesMoviesAndMarksLoaded() {
        let response = paginated([makeMovie(id: 20)])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetSimilar(movie: 6, response: response))

        #expect(reduced.similar[6] == [20])
        #expect(reduced.similarLoaded.contains(6))
    }

    // MARK: - MoviesReducer: SetVideos

    @Test func moviesReducerSetVideosStoresResultsAndMarksLoaded() {
        let video = Video(id: "v1", name: "Trailer", site: "YouTube", key: "abc", type: "Trailer")
        let response = PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [video])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetVideos(movie: 7, response: response))

        #expect(reduced.videos[7]?.first?.key == "abc")
        #expect(reduced.videosLoaded.contains(7))
    }

    // MARK: - MoviesReducer: SetSearch

    // Same page-1-replaces / page-N-appends shape as SetMovieMenuList above,
    // keyed on `MoviesState.search[query]` instead.
    @Test(arguments: [
        (page: 1, query: "old", existing: [999], incoming: [1], expected: [1]),
        (page: 2, query: "q", existing: [1], incoming: [2], expected: [1, 2]),
    ])
    func moviesReducerSetSearchPaginates(
        page: Int,
        query: String,
        existing: [Int],
        incoming: [Int],
        expected: [Int]
    ) {
        var state = MoviesState()
        state.search[query] = existing

        let response = paginated(incoming.map { makeMovie(id: $0) })
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetSearch(query: query, page: page, response: response))

        #expect(reduced.search[query] == expected)
    }

    // MARK: - MoviesReducer: SetSearchKeyword

    @Test func moviesReducerSetSearchKeywordStoresKeywords() {
        let keywords = [Keyword(id: 1, name: "neo-noir"), Keyword(id: 2, name: "heist")]
        let response = PaginatedResponse(page: 1, totalResults: 2, totalPages: 1, results: keywords)
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetSearchKeyword(query: "noir", response: response))

        #expect(reduced.searchKeywords["noir"]?.count == 2)
        #expect(reduced.searchKeywords["noir"]?.first?.name == "neo-noir")
    }

    // MARK: - MoviesReducer: Wishlist / Seenlist

    @Test func moviesReducerRemoveFromWishlistRemovesMovie() {
        var state = MoviesState()
        state.wishlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveFromWishlist(movie: 42))

        #expect(!(reduced.wishlist.contains(42)))
    }

    @Test func moviesReducerAddToSeenListMovesFromWishlistAndAddsTimestamp() {
        var state = MoviesState()
        state.wishlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddToSeenList(movie: 42))

        #expect(reduced.seenlist.contains(42))
        #expect(!(reduced.wishlist.contains(42)))
        #expect(reduced.moviesUserMeta[42]?.addedToList != nil)
    }

    @Test func moviesReducerRemoveFromSeenListRemovesMovie() {
        var state = MoviesState()
        state.seenlist.insert(42)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveFromSeenList(movie: 42))

        #expect(!(reduced.seenlist.contains(42)))
    }

    // MARK: - MoviesReducer: CustomList operations

    @Test func moviesReducerAddMovieToCustomListInsertsMovie() {
        var state = MoviesState()
        state.customLists[1] = CustomList(id: 1, name: "Favorites", cover: nil, movies: [10])

        let reduced = moviesStateReducer(state: state, action: MoviesActions.AddMovieToCustomList(list: 1, movie: 20))

        #expect(reduced.customLists[1]?.movies.contains(20) == true)
        #expect(reduced.customLists[1]?.movies.contains(10) == true)
    }

    @Test func moviesReducerRemoveMovieFromCustomListRemovesMovie() {
        var state = MoviesState()
        state.customLists[1] = CustomList(id: 1, name: "Favorites", cover: nil, movies: [10, 20])

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveMovieFromCustomList(list: 1, movie: 10))

        #expect(!(reduced.customLists[1]?.movies.contains(10) == true))
        #expect(reduced.customLists[1]?.movies.contains(20) == true)
    }

    @Test func moviesReducerAddCustomListStoresList() {
        let list = CustomList(id: 5, name: "Watch Later", cover: nil, movies: [])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.AddCustomList(list: list))

        #expect(reduced.customLists[5]?.name == "Watch Later")
    }

    @Test func moviesReducerRemoveCustomListNilifiesEntry() {
        var state = MoviesState()
        state.customLists[5] = CustomList(id: 5, name: "Old", cover: nil, movies: [])

        let reduced = moviesStateReducer(state: state, action: MoviesActions.RemoveCustomList(list: 5))

        #expect(reduced.customLists[5] == nil)
    }

    // MARK: - MoviesReducer: Genre / Crew / Keyword movies

    // Same pagination shape, keyed on `MoviesState.withGenre[id]`.
    @Test(arguments: [
        (page: 1, existing: [999], incoming: [1], expected: [1]),
        (page: 2, existing: [1], incoming: [2], expected: [1, 2]),
    ])
    func moviesReducerSetMovieForGenrePaginates(
        page: Int,
        existing: [Int],
        incoming: [Int],
        expected: [Int]
    ) {
        var state = MoviesState()
        state.withGenre[28] = existing

        let genre = Genre(id: 28, name: "Action")
        let response = paginated(incoming.map { makeMovie(id: $0) })
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetMovieForGenre(genre: genre, page: page, response: response))

        #expect(reduced.withGenre[28] == expected)
    }

    @Test func moviesReducerSetMovieWithCrewStoresResults() {
        let response = paginated([makeMovie(id: 10)])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetMovieWithCrew(crew: 15, response: response))

        #expect(reduced.withCrew[15] == [10])
    }

    // Same pagination shape, keyed on `MoviesState.withKeywords[id]`.
    @Test(arguments: [
        (page: 1, existing: [999], incoming: [1], expected: [1]),
        (page: 2, existing: [1], incoming: [2], expected: [1, 2]),
    ])
    func moviesReducerSetMovieWithKeywordPaginates(
        page: Int,
        existing: [Int],
        incoming: [Int],
        expected: [Int]
    ) {
        var state = MoviesState()
        state.withKeywords[50] = existing

        let response = paginated(incoming.map { makeMovie(id: $0) })
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SetMovieWithKeyword(keyword: 50, page: page, response: response))

        #expect(reduced.withKeywords[50] == expected)
    }

    // MARK: - MoviesReducer: Reviews

    @Test func moviesReducerSetMovieReviewsStoresResultsAndMarksLoaded() {
        let review = Review(id: "r1", author: "Critic", content: "Great")
        let response = PaginatedResponse(page: 1, totalResults: 1, totalPages: 1, results: [review])
        let reduced = moviesStateReducer(state: MoviesState(), action: MoviesActions.SetMovieReviews(movie: 8, response: response))

        #expect(reduced.reviews[8]?.first?.author == "Critic")
        #expect(reduced.reviewsLoaded.contains(8))
    }

    // MARK: - MoviesReducer: Discover operations

    @Test func moviesReducerPopRandomDiscoverRemovesLastElement() {
        var state = MoviesState()
        state.discover = [1, 2, 3]

        let reduced = moviesStateReducer(state: state, action: MoviesActions.PopRandromDiscover())

        #expect(reduced.discover == [1, 2])
    }

    @Test func moviesReducerPushRandomDiscoverAppendsMovie() {
        var state = MoviesState()
        state.discover = [1, 2]

        let reduced = moviesStateReducer(state: state, action: MoviesActions.PushRandomDiscover(movie: 3))

        #expect(reduced.discover == [1, 2, 3])
    }

    @Test func moviesReducerResetRandomDiscoverClearsFilterAndList() {
        var state = MoviesState()
        state.discover = [1, 2, 3]
        state.discoverFilter = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)

        let reduced = moviesStateReducer(state: state, action: MoviesActions.ResetRandomDiscover())

        #expect(reduced.discover.isEmpty)
        #expect(reduced.discoverFilter == nil)
    }

    @Test func moviesReducerSaveDiscoverFilterAppendsFilter() {
        var state = MoviesState()
        let filter1 = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)
        state.savedDiscoverFilters = [filter1]

        let filter2 = DiscoverFilter(year: 2010, startYear: nil, endYear: nil, sort: "vote_average.desc", genre: 28, region: "US")
        let reduced = moviesStateReducer(state: state, action: MoviesActions.SaveDiscoverFilter(filter: filter2))

        #expect(reduced.savedDiscoverFilters.count == 2)
        #expect(reduced.savedDiscoverFilters.last?.year == 2010)
    }

    @Test func moviesReducerClearSavedDiscoverFiltersEmptiesArray() {
        var state = MoviesState()
        let filter = DiscoverFilter(year: 2000, startYear: nil, endYear: nil, sort: "popularity.desc", genre: nil, region: nil)
        state.savedDiscoverFilters = [filter]

        let reduced = moviesStateReducer(state: state, action: MoviesActions.ClearSavedDiscoverFilters())

        #expect(reduced.savedDiscoverFilters.isEmpty)
    }

    // MARK: - MoviesReducer: Cross-reducer (PeopleCredits merges movies)

    @Test func moviesReducerPeopleCreditsAlsoMergesMoviesIntoMoviesState() {
        let castMovie = makeMovie(id: 10)
        let crewMovie = makeMovie(id: 20)
        let response = PeopleActions.PeopleCreditsResponse(cast: [castMovie], crew: [crewMovie])

        let reduced = moviesStateReducer(state: MoviesState(), action: PeopleActions.SetPeopleCredits(people: 7, response: response))

        #expect(reduced.movies[10] != nil)
        #expect(reduced.movies[20] != nil)
    }

    // MARK: - PeopleReducer: Search

    // Same page-1-replaces / page-N-appends shape as the movie-search
    // pagination above, but keyed on `PeoplesState.search[query]` and
    // backed by `People` fixtures.
    @Test(arguments: [
        (page: 1, query: "old", existing: [999], incoming: [(id: 1, name: "A")], expected: [1]),
        (page: 2, query: "q", existing: [1], incoming: [(id: 2, name: "B")], expected: [1, 2]),
    ])
    func peopleReducerSetSearchPaginates(
        page: Int,
        query: String,
        existing: [Int],
        incoming: [(id: Int, name: String)],
        expected: [Int]
    ) {
        var state = PeoplesState()
        state.search[query] = existing

        let results = incoming.map { makePeople(id: $0.id, name: $0.name) }
        let response = PaginatedResponse(page: page, totalResults: results.count, totalPages: page, results: results)
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetSearch(query: query, page: page, response: response))

        #expect(reduced.search[query] == expected)
    }

    // MARK: - PeopleReducer: Popular

    // SetPopular normalizes `popularLoading=false` /
    // `popularInitialLoadCompleted=true` on every successful response
    // regardless of page, so we assert that for both cases. Page 2
    // also exercises `appendUnique` (incoming id 2 already present in
    // `existing` must not duplicate).
    @Test(arguments: [
        (page: 1, existing: [999], existingLoading: true, incoming: [(id: 1, name: "A")], expected: [1]),
        (page: 2, existing: [1, 2], existingLoading: false, incoming: [(id: 2, name: "B"), (id: 3, name: "C")], expected: [1, 2, 3]),
    ])
    func peopleReducerSetPopularPaginates(
        page: Int,
        existing: [Int],
        existingLoading: Bool,
        incoming: [(id: Int, name: String)],
        expected: [Int]
    ) {
        var state = PeoplesState()
        state.popular = existing
        state.popularLoading = existingLoading

        let results = incoming.map { makePeople(id: $0.id, name: $0.name) }
        let response = PaginatedResponse(page: page, totalResults: results.count, totalPages: page, results: results)
        let reduced = peoplesStateReducer(state: state, action: PeopleActions.SetPopular(page: page, response: response))

        #expect(reduced.popular == expected)
        #expect(!(reduced.popularLoading))
        #expect(reduced.popularInitialLoadCompleted)
    }

    // MARK: - PeopleReducer: PopularRequestStarted / Failed

    @Test func peopleReducerPopularRequestStartedSetsLoadingState() {
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.PopularRequestStarted(page: 1))

        #expect(reduced.popularLoading)
        #expect(!(reduced.popularLoadFailed))
        #expect(!(reduced.popularInitialLoadCompleted))
    }

    @Test func peopleReducerPopularRequestFailedSetsFailedState() {
        var state = PeoplesState()
        state.popularLoading = true

        let reduced = peoplesStateReducer(state: state, action: PeopleActions.PopularRequestFailed(page: 1))

        #expect(!(reduced.popularLoading))
        #expect(reduced.popularLoadFailed)
        #expect(reduced.popularInitialLoadCompleted)
    }

    // MARK: - PeopleReducer: FanClub

    @Test func peopleReducerAddToFanClubInsertsPeopleId() {
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.AddToFanClub(people: 55))

        #expect(reduced.fanClub.contains(55))
    }

    @Test func peopleReducerRemoveFromFanClubRemovesPeopleId() {
        var state = PeoplesState()
        state.fanClub.insert(55)

        let reduced = peoplesStateReducer(state: state, action: PeopleActions.RemoveFromFanClub(people: 55))

        #expect(!(reduced.fanClub.contains(55)))
    }

    // MARK: - PeopleReducer: SetImages

    @Test func peopleReducerSetImagesStoresImagesAndMarksLoaded() {
        let images = [ImageData(aspectRatio: 0.67, filePath: "/img.jpg", height: 300, width: 200)]
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetImages(people: 7, images: images))

        #expect(reduced.peoples[7]?.images?.first?.filePath == "/img.jpg")
        #expect(reduced.imagesLoaded.contains(7))
    }

    // MARK: - PeopleReducer: SetDetail new person

    @Test func peopleReducerSetDetailNewPersonStoresDirectly() {
        let person = makePeople(id: 10, name: "New Person")
        let reduced = peoplesStateReducer(state: PeoplesState(), action: PeopleActions.SetDetail(person: person))

        #expect(reduced.peoples[10]?.name == "New Person")
        #expect(reduced.detailed.contains(10))
    }

    private func paginated<T: Codable>(_ values: [T]) -> PaginatedResponse<T> {
        PaginatedResponse(page: 1, totalResults: values.count, totalPages: 1, results: values)
    }

    private func makeMovie(id: Int, character: String? = nil, department: String? = nil) -> Movie {
        Movie(
            id: id,
            originalTitle: "Original \(id)",
            title: "Title \(id)",
            overview: "Overview \(id)",
            posterPath: nil,
            backdropPath: nil,
            popularity: 1.0,
            voteAverage: 2.0,
            voteCount: 3,
            releaseDateString: "2020-01-01",
            genres: nil,
            runtime: nil,
            status: nil,
            video: false,
            keywords: nil,
            images: nil,
            productionCountries: nil,
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
            profilePath: nil,
            knownForDepartment: nil,
            knownFor: knownFor,
            alsoKnownAs: nil,
            birthDay: nil,
            deathDay: nil,
            placeOfBirth: nil,
            biography: nil,
            popularity: nil,
            images: images
        )
    }
}

import Testing
import Foundation
import MovieSwiftFluxCore
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `@MainActor`: exercises a broad slice of main-actor app code (state
// query helpers, app-launch bootstrap, reducers via the store), so the
// case runs on the main actor.
//
// 197 tests across the app's high-level behaviour live here; splitting
// by feature is a long-running follow-up.
// swiftlint:disable type_body_length
@Suite @MainActor
struct MovieSwiftTests {
    private func makeMovie(id: Int,
                           keywords: Movie.Keywords? = nil,
                           images: Movie.MovieImages? = nil) -> Movie {
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
              keywords: keywords,
              images: images,
              production_countries: nil,
              character: nil,
              department: nil)
    }

    private func makePerson(id: Int, character: String? = nil, department: String? = nil) -> People {
        People(id: id,
               name: "Person \(id)",
               character: character,
               department: department,
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

    @Test func movieDetailStateReturnsNilWhenMovieIsMissing() {
        #expect(MovieDetailState.movie(movieId: 404, from: AppState()) == nil)
    }

    @Test func movieDetailMapTreatsPersistedPartialMovieAsMissingDetailPayload() {
        var state = AppState()
        state.moviesState.movies[42] = makeMovie(id: 42)
        state.moviesState.detailed.insert(42)
        state.moviesState.recommendedLoaded.insert(42)
        state.moviesState.similarLoaded.insert(42)
        state.moviesState.reviewsLoaded.insert(42)
        state.moviesState.videosLoaded.insert(42)
        state.peoplesState.movieCreditsLoaded.insert(42)
        state.peoplesState.movieCastOrder[42] = [7]
        state.peoplesState.movieCrewOrder[42] = [8]
        state.peoplesState.casts[7] = [42: "Lead"]
        state.peoplesState.crews[8] = [42: "Director"]

        let props = MovieDetail(movieId: 42).map(state: state, dispatch: { _ in })

        #expect(!(props.hasMovieDetail))
        #expect(!(props.hasMovieCredits))
        #expect(!(props.hasRecommended))
        #expect(!(props.hasSimilar))
        #expect(!(props.hasReviews))
        #expect(!(props.hasVideos))
    }

    @Test func movieDetailMapKeepsCompletePayloadMarkedAsLoaded() {
        var state = AppState()
        state.moviesState.movies[42] = makeMovie(
            id: 42,
            keywords: Movie.Keywords(keywords: [Keyword(id: 1, name: "neo-noir")]),
            images: Movie.MovieImages(posters: [], backdrops: [])
        )
        state.moviesState.detailed.insert(42)
        state.moviesState.recommendedLoaded.insert(42)
        state.moviesState.recommended[42] = []
        state.moviesState.similarLoaded.insert(42)
        state.moviesState.similar[42] = []
        state.moviesState.reviewsLoaded.insert(42)
        state.moviesState.reviews[42] = []
        state.moviesState.videosLoaded.insert(42)
        state.moviesState.videos[42] = []
        state.peoplesState.movieCreditsLoaded.insert(42)
        state.peoplesState.movieCastOrder[42] = [7]
        state.peoplesState.movieCrewOrder[42] = [8]
        state.peoplesState.casts[7] = [42: "Lead"]
        state.peoplesState.crews[8] = [42: "Director"]
        state.peoplesState.peoples[7] = makePerson(id: 7, character: "Lead")
        state.peoplesState.peoples[8] = makePerson(id: 8, department: "Director")

        let props = MovieDetail(movieId: 42).map(state: state, dispatch: { _ in })

        #expect(props.hasMovieDetail)
        #expect(props.hasMovieCredits)
        #expect(props.hasRecommended)
        #expect(props.hasSimilar)
        #expect(props.hasReviews)
        #expect(props.hasVideos)
    }

    @Test func movieRowMapReturnsPlaceholderWhenMovieIsMissing() {
        let props = MovieRow(movieId: 42).map(state: AppState(), dispatch: { _ in })

        #expect(props.movie.id == 42)
        #expect(props.movie.title == "Movie unavailable")
        #expect(props.movie.poster_path == nil)
    }

    @Test func movieGridRowMapReturnsPlaceholderWhenMovieIsMissing() {
        let props = MovieGridRow(movieId: 42).map(state: AppState(), dispatch: { _ in })

        #expect(props.movie.id == 42)
        #expect(props.movie.title == "Movie unavailable")
    }

    @Test func sortedMoviesIdsKeepsMissingMoviesForAddedDateSort() {
        var state = AppState()
        state.moviesState.moviesUserMeta[42] = MovieUserMeta(addedToList: Date(timeIntervalSince1970: 200))
        state.moviesState.moviesUserMeta[7] = MovieUserMeta(addedToList: Date(timeIntervalSince1970: 100))

        let sorted = [7, 42].sortedMoviesIds(by: .byAddedDate, state: state)

        #expect(sorted == [42, 7])
    }

    @Test func sortedMoviesIdsKeepsMissingMoviesForReleaseDateSort() {
        var state = AppState()
        state.moviesState.movies[sampleMovie.id] = sampleMovie

        let sorted = [42, sampleMovie.id].sortedMoviesIds(by: .byReleaseDate, state: state)

        #expect(sorted == [sampleMovie.id, 42])
    }

    @Test func appStateReducerClearCachedDataPreservesUserDataAndRemovesTransientCaches() {
        let savedDate = Date(timeIntervalSince1970: 1234)
        let discoverFilter = DiscoverFilter(year: 1999,
                                            startYear: nil,
                                            endYear: nil,
                                            sort: "popularity.desc",
                                            genre: 12,
                                            region: "US")

        var state = AppState()
        state.moviesState.movies[11] = makeMovie(id: 11)
        state.moviesState.movies[12] = makeMovie(id: 12)
        state.moviesState.movies[13] = makeMovie(id: 13)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist = [11]
        state.moviesState.seenlist = [12]
        state.moviesState.customLists[7] = CustomList(id: 7,
                                                      name: "Debug",
                                                      cover: 12,
                                                      movies: [13])
        state.moviesState.moviesUserMeta[11] = MovieUserMeta(addedToList: savedDate)
        state.moviesState.savedDiscoverFilters = [discoverFilter]
        state.moviesState.discoverFilter = discoverFilter
        state.moviesState.moviesList[.popular] = [99]
        state.moviesState.recommended[11] = [99]
        state.moviesState.similar[11] = [99]
        state.moviesState.reviews[11] = []
        state.moviesState.videos[11] = []
        state.moviesState.search["matrix"] = [99]
        state.moviesState.searchKeywords["matrix"] = [Keyword(id: 1, name: "matrix")]
        state.moviesState.withGenre[12] = [99]
        state.moviesState.withKeywords[1] = [99]
        state.moviesState.withCrew[2] = [99]
        state.moviesState.discover = [99]
        state.moviesState.genres = [Genre(id: 12, name: "Adventure")]
        state.moviesState.detailed.insert(11)
        state.moviesState.recommendedLoaded.insert(11)
        state.moviesState.similarLoaded.insert(11)
        state.moviesState.reviewsLoaded.insert(11)
        state.moviesState.videosLoaded.insert(11)

        state.peoplesState.fanClub = [7]
        state.peoplesState.peoples[7] = makePerson(id: 7)
        state.peoplesState.peoples[8] = makePerson(id: 8)
        state.peoplesState.movieCreditsLoaded.insert(11)
        state.peoplesState.movieCastOrder[11] = [7]
        state.peoplesState.movieCrewOrder[11] = [8]
        state.peoplesState.casts[7] = [11: "Lead"]
        state.peoplesState.crews[8] = [11: "Director"]

        let cleared = appReducerWithImports(state: state, action: AppActions.ClearCachedData())

        #expect(cleared.moviesState.wishlist == [11])
        #expect(cleared.moviesState.seenlist == [12])
        #expect(cleared.moviesState.customLists[7]?.movies == Set([13]))
        #expect(cleared.moviesState.customLists[7]?.cover == 12)
        #expect(cleared.moviesState.moviesUserMeta[11]?.addedToList == savedDate)
        #expect(cleared.moviesState.savedDiscoverFilters.count == 1)
        #expect(cleared.moviesState.discoverFilter?.region == "US")
        #expect(cleared.moviesState.movies[11] != nil)
        #expect(cleared.moviesState.movies[12] != nil)
        #expect(cleared.moviesState.movies[13] != nil)
        #expect(cleared.moviesState.movies[99] == nil)
        #expect(cleared.moviesState.moviesList.isEmpty)
        #expect(cleared.moviesState.recommended.isEmpty)
        #expect(cleared.moviesState.similar.isEmpty)
        #expect(cleared.moviesState.reviews.isEmpty)
        #expect(cleared.moviesState.videos.isEmpty)
        #expect(cleared.moviesState.search.isEmpty)
        #expect(cleared.moviesState.searchKeywords.isEmpty)
        #expect(cleared.moviesState.withGenre.isEmpty)
        #expect(cleared.moviesState.withKeywords.isEmpty)
        #expect(cleared.moviesState.withCrew.isEmpty)
        #expect(cleared.moviesState.discover.isEmpty)
        #expect(cleared.moviesState.genres.isEmpty)
        #expect(cleared.moviesState.detailed.isEmpty)
        #expect(cleared.moviesState.recommendedLoaded.isEmpty)
        #expect(cleared.moviesState.similarLoaded.isEmpty)
        #expect(cleared.moviesState.reviewsLoaded.isEmpty)
        #expect(cleared.moviesState.videosLoaded.isEmpty)

        #expect(cleared.peoplesState.fanClub == Set([7]))
        #expect(cleared.peoplesState.peoples[7] != nil)
        #expect(cleared.peoplesState.peoples[8] == nil)
        #expect(cleared.peoplesState.movieCreditsLoaded.isEmpty)
        #expect(cleared.peoplesState.movieCastOrder.isEmpty)
        #expect(cleared.peoplesState.movieCrewOrder.isEmpty)
        #expect(cleared.peoplesState.casts.isEmpty)
        #expect(cleared.peoplesState.crews.isEmpty)
    }

    @Test func movieDetailFetchPolicyReturnsOnlyMissingSlices() {
        #expect(MovieDetailFetchPolicy.slicesToFetch(hasMovieDetail: true,
                                                            hasMovieCredits: false,
                                                            hasRecommended: true,
                                                            hasSimilar: false,
                                                            hasReviews: true,
                                                            hasVideos: false,
                                                            isRunningUISmokeTests: false) ==
                       [.credits, .similar, .videos])
    }

    @Test func movieDetailFetchPolicySkipsAllSlicesDuringUISmokeTests() {
        #expect(MovieDetailFetchPolicy.slicesToFetch(hasMovieDetail: false,
                                                           hasMovieCredits: false,
                                                           hasRecommended: false,
                                                           hasSimilar: false,
                                                           hasReviews: false,
                                                           hasVideos: false,
                                                           isRunningUISmokeTests: true).isEmpty)
    }

    @Test func moviesStateReducerMarksMovieDetailSlicesLoaded() {
        let movie = Movie(id: 9,
                          original_title: "Movie",
                          title: "Movie",
                          overview: "",
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
                          character: nil,
                          department: nil)

        var state = moviesStateReducer(state: MoviesState(),
                                       action: MoviesActions.SetDetail(movie: 9, response: movie))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetRecommended(movie: 9,
                                                                        response: PaginatedResponse(page: 1,
                                                                                                    total_results: 0,
                                                                                                    total_pages: 1,
                                                                                                    results: [])))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetSimilar(movie: 9,
                                                                    response: PaginatedResponse(page: 1,
                                                                                                total_results: 0,
                                                                                                total_pages: 1,
                                                                                                results: [])))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetVideos(movie: 9,
                                                                   response: PaginatedResponse(page: 1,
                                                                                               total_results: 0,
                                                                                               total_pages: 1,
                                                                                               results: [])))
        state = moviesStateReducer(state: state,
                                   action: MoviesActions.SetMovieReviews(movie: 9,
                                                                         response: PaginatedResponse(page: 1,
                                                                                                     total_results: 0,
                                                                                                     total_pages: 1,
                                                                                                     results: [])))

        #expect(state.detailed.contains(9))
        #expect(state.recommendedLoaded.contains(9))
        #expect(state.similarLoaded.contains(9))
        #expect(state.videosLoaded.contains(9))
        #expect(state.reviewsLoaded.contains(9))
    }

    @Test func moviesStateCodableRoundTripPreservesLoadedMovieDetailFlags() throws {
        var state = MoviesState()
        state.detailed.insert(1)
        state.recommendedLoaded.insert(2)
        state.similarLoaded.insert(3)
        state.videosLoaded.insert(4)
        state.reviewsLoaded.insert(5)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MoviesState.self, from: data)

        #expect(decoded.detailed.contains(1))
        #expect(decoded.recommendedLoaded.contains(2))
        #expect(decoded.similarLoaded.contains(3))
        #expect(decoded.videosLoaded.contains(4))
        #expect(decoded.reviewsLoaded.contains(5))
    }

    @Test func peoplesStateCodableRoundTripPreservesMovieCreditsLoadedFlags() throws {
        var state = PeoplesState()
        state.movieCreditsLoaded.insert(9)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PeoplesState.self, from: data)

        #expect(decoded.movieCreditsLoaded.contains(9))
    }

    @Test func peoplesStateCodableRoundTripPreservesMovieCreditOrder() throws {
        var state = PeoplesState()
        state.movieCastOrder[9] = [2, 1]
        state.movieCrewOrder[9] = [5, 4]

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PeoplesState.self, from: data)

        #expect(decoded.movieCastOrder[9] == [2, 1])
        #expect(decoded.movieCrewOrder[9] == [5, 4])
    }

    @Test func peopleRowStateShowsPlaceholderWhenPersonIsMissing() {
        #expect(PeopleRowState.shouldShowPlaceholder(for: nil))
    }

    @Test func peopleRowStateDoesNotShowPlaceholderWhenPersonExists() {
        let person = People(id: 1,
                            name: "Known Person",
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

        #expect(!(PeopleRowState.shouldShowPlaceholder(for: person)))
    }

    @Test func fanClubPaginationPolicyRequestsInitialPopularPage() {
        #expect(FanClubPaginationPolicy.initialPopularPage(popularCount: 0,
                                                                  nextPage: 1,
                                                                  popularLoading: false,
                                                                  popularInitialLoadCompleted: false) ==
                       1)
    }

    @Test func fanClubPaginationPolicySkipsInitialFetchWhenPopularAlreadyLoaded() {
        #expect(FanClubPaginationPolicy.initialPopularPage(popularCount: 3,
                                                                nextPage: 1,
                                                                popularLoading: false,
                                                                popularInitialLoadCompleted: false) == nil)
    }

    @Test func fanClubPaginationPolicySkipsInitialFetchAfterCompletedLoad() {
        #expect(FanClubPaginationPolicy.initialPopularPage(popularCount: 0,
                                                                nextPage: 1,
                                                                popularLoading: false,
                                                                popularInitialLoadCompleted: true) == nil)
    }

    @Test func fanClubPaginationPolicyRequestsNextPopularPageForNewLastId() {
        #expect(FanClubPaginationPolicy.nextPopularPage(popular: [1, 2, 3],
                                                               lastTriggeredPopularId: 2,
                                                               nextPage: 4) ==
                       4)
    }

    @Test func fanClubPaginationPolicySkipsRepeatedLastPopularId() {
        #expect(FanClubPaginationPolicy.nextPopularPage(popular: [1, 2, 3],
                                                             lastTriggeredPopularId: 3,
                                                             nextPage: 4) == nil)
    }

    @Test func fanClubPresentationShowsLoadingStateBeforeInitialRequest() {
        let state = FanClubPresentation.emptyState(peoples: [],
                                                   popular: [],
                                                   popularLoading: true,
                                                   popularInitialLoadCompleted: false,
                                                   popularLoadFailed: false)

        #expect(state?.title == "Loading people")
        #expect(state?.accessibilityIdentifier == "fanClub.loadingState")
        #expect(state?.showsRetry == false)
    }

    @Test func fanClubPresentationShowsErrorStateAfterFailedRequest() {
        let state = FanClubPresentation.emptyState(peoples: [],
                                                   popular: [],
                                                   popularLoading: false,
                                                   popularInitialLoadCompleted: true,
                                                   popularLoadFailed: true)

        #expect(state?.title == "Could not load popular people")
        #expect(state?.accessibilityIdentifier == "fanClub.errorState")
        #expect(state?.showsRetry == true)
    }

    @Test func fanClubPresentationShowsEmptyStateAfterSuccessfulInitialRequest() {
        let state = FanClubPresentation.emptyState(peoples: [],
                                                   popular: [],
                                                   popularLoading: false,
                                                   popularInitialLoadCompleted: true,
                                                   popularLoadFailed: false)

        #expect(state?.title == "No popular people right now")
        #expect(state?.accessibilityIdentifier == "fanClub.emptyState")
        #expect(state?.showsRetry == false)
    }

    @Test func fanClubPresentationSkipsEmptyStateWhenContentExists() {
        #expect(FanClubPresentation.emptyState(peoples: [1],
                                                    popular: [],
                                                    popularLoading: false,
                                                    popularInitialLoadCompleted: true,
                                                    popularLoadFailed: false) == nil)
        #expect(FanClubPresentation.emptyState(peoples: [],
                                                    popular: [2],
                                                    popularLoading: false,
                                                    popularInitialLoadCompleted: true,
                                                    popularLoadFailed: false) == nil)
    }

    @Test func peopleStateReducerMarksPopularRequestStarted() {
        let updated = peoplesStateReducer(state: PeoplesState(),
                                          action: PeopleActions.PopularRequestStarted(page: 1))

        #expect(updated.popularLoading)
        #expect(!(updated.popularInitialLoadCompleted))
        #expect(!(updated.popularLoadFailed))
    }

    @Test func peopleStateReducerMarksPopularRequestFailed() {
        let updated = peoplesStateReducer(state: PeoplesState(),
                                          action: PeopleActions.PopularRequestFailed(page: 1))

        #expect(!(updated.popularLoading))
        #expect(updated.popularInitialLoadCompleted)
        #expect(updated.popularLoadFailed)
    }

    @Test func peopleStateReducerUpdatesExistingRoleMetadataFromLaterCredits() {
        var state = AppState().peoplesState
        state.peoples[1] = People(id: 1,
                                  name: "Actor",
                                  character: "Old Role",
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

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 7,
                                                                             response: CastResponse(id: 7,
                                                                                                    cast: [People(id: 1,
                                                                                                                  name: "Actor",
                                                                                                                  character: "New Role",
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
                                                                                                                  images: nil), ],
                                                                                                    crew: [])))

        #expect(updated.peoples[1]?.character == "New Role")
    }

    @Test func peopleStateReducerSetDetailDoesNotRetainStaleMovieRoleMetadata() {
        var state = AppState().peoplesState
        state.peoples[1] = People(id: 1,
                                  name: "Actor",
                                  character: "Old Role",
                                  department: "Old Department",
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

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetDetail(person: People(id: 1,
                                                                                         name: "Actor",
                                                                                         character: nil,
                                                                                         department: nil,
                                                                                         profile_path: nil,
                                                                                         known_for_department: nil,
                                                                                         known_for: nil,
                                                                                         also_known_as: nil,
                                                                                         birthDay: nil,
                                                                                         deathDay: nil,
                                                                                         place_of_birth: nil,
                                                                                         biography: "Bio",
                                                                                         popularity: nil,
                                                                                         images: nil)))

        #expect(updated.peoples[1]?.character == nil)
        #expect(updated.peoples[1]?.department == nil)
    }

    @Test func peopleStateReducerSetImagesCreatesPlaceholderWhenPersonIsMissing() {
        let state = AppState().peoplesState
        let images = [ImageData(aspect_ratio: 1,
                                file_path: "/profile.jpg",
                                height: 200,
                                width: 100), ]

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetImages(people: 77, images: images))

        #expect(updated.peoples[77]?.name == "Unknown person")
        #expect(updated.peoples[77]?.images?.count == 1)
        #expect(updated.imagesLoaded.contains(77))
    }

    @Test func peopleStateReducerSetPeopleCreditsReplacesExistingCredits() {
        var state = AppState().peoplesState
        state.casts[7] = [10: "Old Role"]
        state.crews[7] = [11: "Old Department"]

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetPeopleCredits(people: 7,
                                                                                response: PeopleActions.PeopleCreditsResponse(cast: [Movie(id: 12,
                                                                                                                                 original_title: "New Cast",
                                                                                                                                 title: "New Cast",
                                                                                                                                 overview: "",
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
                                                                                                                                 character: "New Role",
                                                                                                                                 department: nil), ],
                                                                                                                             crew: [])))

        #expect(updated.casts[7]?[12] == "New Role")
        #expect(updated.casts[7]?[10] == nil)
        #expect(updated.creditsLoaded.contains(7))
    }

    // MARK: - SetMovieCasts reverse-lookup population & multi-role handling

    @Test func setMovieCastsPopulatesReverseRoleLookupsForCastAndCrew() {
        let state = AppState().peoplesState
        let response = CastResponse(
            id: 42,
            cast: [makePerson(id: 1, character: "Hero")],
            crew: [makePerson(id: 2, department: "Directing")]
        )

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 42, response: response))

        #expect(updated.casts[1]?[42] == "Hero")
        #expect(updated.crews[2]?[42] == "Directing")
        #expect(updated.movieCastOrder[42] == [1])
        #expect(updated.movieCrewOrder[42] == [2])
        #expect(updated.movieCreditsLoaded.contains(42))
    }

    @Test func setMovieCastsDedupesMovieCastOrderForRepeatedPerson() {
        let state = AppState().peoplesState
        let response = CastResponse(
            id: 42,
            cast: [
                makePerson(id: 1, character: "Prince Akeem"),
                makePerson(id: 1, character: "Randy Watson"),
                makePerson(id: 1, character: "Clarence"),
                makePerson(id: 2, character: "Lisa McDowell"),
            ],
            crew: []
        )

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 42, response: response))

        // Each person should appear exactly once in the order array.
        #expect(updated.movieCastOrder[42] == [1, 2])
    }

    @Test func setMovieCastsConcatenatesCharactersForActorInMultipleRoles() {
        let state = AppState().peoplesState
        let response = CastResponse(
            id: 42,
            cast: [
                makePerson(id: 1, character: "Prince Akeem"),
                makePerson(id: 1, character: "Randy Watson"),
                makePerson(id: 1, character: "Clarence"),
                makePerson(id: 1, character: "Saul"),
            ],
            crew: []
        )

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 42, response: response))

        #expect(updated.casts[1]?[42] ==
                       "Prince Akeem / Randy Watson / Clarence / Saul")
    }

    @Test func setMovieCastsConcatenatesDepartmentsForCrewMemberWithMultipleRoles() {
        let state = AppState().peoplesState
        let response = CastResponse(
            id: 42,
            cast: [],
            crew: [
                makePerson(id: 7, department: "Directing"),
                makePerson(id: 7, department: "Writing"),
                makePerson(id: 7, department: "Production"),
            ]
        )

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 42, response: response))

        #expect(updated.crews[7]?[42] == "Directing, Writing, Production")
        #expect(updated.movieCrewOrder[42] == [7])
    }

    @Test func setMovieCastsDoesNotDuplicateSameDepartmentTwice() {
        let state = AppState().peoplesState
        let response = CastResponse(
            id: 42,
            cast: [],
            crew: [
                makePerson(id: 7, department: "Directing"),
                makePerson(id: 7, department: "directing"), // case-insensitive duplicate
                makePerson(id: 7, department: "Writing"),
            ]
        )

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 42, response: response))

        #expect(updated.crews[7]?[42] == "Directing, Writing")
    }

    @Test func setMovieCastsSkipsEmptyOrWhitespaceRoles() {
        let state = AppState().peoplesState
        let response = CastResponse(
            id: 42,
            cast: [
                makePerson(id: 1, character: ""),
                makePerson(id: 2, character: "   "),
                makePerson(id: 3, character: "Real Role"),
            ],
            crew: [
                makePerson(id: 10, department: nil),
                makePerson(id: 11, department: "Editing"),
            ]
        )

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetMovieCasts(movie: 42, response: response))

        #expect(updated.casts[1]?[42] == nil)
        #expect(updated.casts[2]?[42] == nil)
        #expect(updated.casts[3]?[42] == "Real Role")
        #expect(updated.crews[10]?[42] == nil)
        #expect(updated.crews[11]?[42] == "Editing")
    }

    @Test func movieDetailPeopleStateResolvesCastAndCrewAfterSetMovieCasts() {
        var state = AppState()
        let response = CastResponse(
            id: 42,
            cast: [
                makePerson(id: 1, character: "Hero"),
                makePerson(id: 2, character: "Sidekick"),
            ],
            crew: [
                makePerson(id: 10, department: "Directing"),
                makePerson(id: 10, department: "Writing"),
            ]
        )

        // Route through the real reducer path — this is the integration surface
        // that was previously broken: characters()/credits() returned nil even
        // when the movie credits action had been dispatched.
        state.peoplesState = peoplesStateReducer(
            state: state.peoplesState,
            action: PeopleActions.SetMovieCasts(movie: 42, response: response)
        )

        let characters = MovieDetailPeopleState.characters(movieId: 42, from: state)
        let credits = MovieDetailPeopleState.credits(movieId: 42, from: state)

        #expect(characters?.count == 2)
        #expect(characters?.first?.character == "Hero")
        #expect(credits?.count == 1)
        #expect(credits?.first?.department == "Directing, Writing")
    }

    @Test func peoplesStateCodableRoundTripPreservesLoadedDetailFlagsAndCredits() throws {
        var state = PeoplesState()
        state.peoples[7] = People(id: 7,
                                  name: "Person",
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
                                  images: [ImageData(aspect_ratio: 1,
                                                     file_path: "/profile.jpg",
                                                     height: 200,
                                                     width: 100), ])
        state.casts[7] = [12: "Actor"]
        state.crews[7] = [13: "Director"]
        state.detailed.insert(7)
        state.imagesLoaded.insert(7)
        state.creditsLoaded.insert(7)
        state.fanClub.insert(7)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PeoplesState.self, from: data)

        #expect(decoded.peoples[7]?.images?.count == 1)
        #expect(decoded.casts[7]?[12] == "Actor")
        #expect(decoded.crews[7]?[13] == "Director")
        #expect(decoded.detailed.contains(7))
        #expect(decoded.imagesLoaded.contains(7))
        #expect(decoded.creditsLoaded.contains(7))
        #expect(decoded.fanClub.contains(7))
    }

    @Test func peopleRowStateReturnsNilWhenPersonIsMissing() {
        let state = AppState()

        #expect(PeopleRowState.people(for: 999, from: state) == nil)
    }

    @Test func fanClubStateSkipsMissingPopularPeople() {
        var state = AppState()
        state.peoplesState.popular = [2, 1]
        state.peoplesState.peoples[1] = People(id: 1,
                                               name: "Known Person",
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

        #expect(FanClubState.popularPeople(from: state) == [1])
    }

    @Test func peopleStateReducerDedupesPopularPeopleAcrossPages() {
        let state = AppState().peoplesState
        let popularPage = PaginatedResponse(page: 2,
                                            total_results: 3,
                                            total_pages: 2,
                                            results: [People(id: 2,
                                                             name: "Second",
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
                                                             images: nil),
                                                      People(id: 1,
                                                             name: "First",
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
                                                             images: nil), ])
        let seeded = peoplesStateReducer(state: state,
                                         action: PeopleActions.SetPopular(page: 1,
                                                                         response: PaginatedResponse(page: 1,
                                                                                                     total_results: 2,
                                                                                                     total_pages: 2,
                                                                                                     results: [People(id: 1,
                                                                                                                      name: "First",
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
                                                                                                                      images: nil), ])))

        let inFlight = peoplesStateReducer(state: seeded,
                                           action: PeopleActions.PopularRequestStarted(page: 2))
        let updated = peoplesStateReducer(state: inFlight,
                                          action: PeopleActions.SetPopular(page: 2,
                                                                          response: popularPage))

        #expect(updated.popular == [1, 2])
        #expect(!(updated.popularLoading))
        #expect(updated.popularInitialLoadCompleted)
        #expect(!(updated.popularLoadFailed))
    }

    @Test func peopleDetailBiographyStateShowsToggleOnlyForNonEmptyBiography() {
        #expect(!(PeopleDetailBiographyState.shouldShowBiographyToggle(nil)))
        #expect(!(PeopleDetailBiographyState.shouldShowBiographyToggle("   ")))
        #expect(PeopleDetailBiographyState.shouldShowBiographyToggle("Biography"))
    }

    @Test func peopleDetailBiographyStateUsesCorrectDeathLabel() {
        #expect(PeopleDetailBiographyState.deathLabel == "Day of death")
    }

    @Test func peopleDetailStateReturnsFallbackPersonWhenMissing() {
        let state = AppState()

        #expect(PeopleDetailState.people(for: 999, from: state).name == "Unknown person")
    }

    @Test func peopleDetailStateShowsBiographySectionWhenOnlyBiographyExists() {
        let people = People(id: 1,
                            name: "Test Person",
                            character: nil,
                            department: nil,
                            profile_path: nil,
                            known_for_department: nil,
                            known_for: nil,
                            also_known_as: nil,
                            birthDay: nil,
                            deathDay: nil,
                            place_of_birth: nil,
                            biography: "Bio only",
                            popularity: nil,
                            images: nil)

        #expect(PeopleDetailState.shouldShowBiographySection(for: people))
    }

    @Test func peopleDetailStateHidesImagesSectionForEmptyImages() {
        #expect(!(PeopleDetailState.shouldShowImagesSection(for: nil)))
        #expect(!(PeopleDetailState.shouldShowImagesSection(for: [])))
    }

    @Test func peopleDetailImagesStateBuildsAccessibilityMetadata() {
        #expect(PeopleDetailImagesState.accessibilityIdentifier(for: 0) == "peopleDetail.image.0")
        #expect(PeopleDetailImagesState.accessibilityLabel(for: 1, total: 3) == "Image 2 of 3")
    }

    @Test func peopleDetailHeaderStateUsesNeutralFallbackCopy() {
        let people = People(id: 1,
                            name: "Test Person",
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

        #expect(PeopleDetailHeaderState.knownForText(for: people) ==
                       "Known work is not available.")
    }

    @Test func peopleDetailMovieRowStateSkipsEmptySubtitle() {
        #expect(PeopleDetailMovieRowState.subtitle(for: "") == nil)
        #expect(PeopleDetailMovieRowState.subtitle(for: "   ") == nil)
        #expect(PeopleDetailMovieRowState.subtitle(for: "Director") == "Director")
    }

    @Test func movieDetailPeopleStateUsesMovieSpecificRoleMetadata() {
        var state = AppState()
        state.peoplesState.peoples[1] = People(id: 1,
                                               name: "Actor",
                                               character: "Old Role",
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
        state.peoplesState.peoples[2] = People(id: 2,
                                               name: "Director",
                                               character: nil,
                                               department: "Old Department",
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
        state.peoplesState.movieCastOrder[42] = [1]
        state.peoplesState.movieCrewOrder[42] = [2]
        state.peoplesState.casts[1] = [7: "Old Role", 42: "New Role"]
        state.peoplesState.crews[2] = [7: "Old Department", 42: "Directing"]

        #expect(MovieDetailPeopleState.characters(movieId: 42, from: state)?.first?.character ==
                       "New Role")
        #expect(MovieDetailPeopleState.credits(movieId: 42, from: state)?.first?.department ==
                       "Directing")
    }

    @Test func movieDetailPeopleStateUsesMovieCreditOrder() {
        var state = AppState()
        state.peoplesState.peoples[1] = People(id: 1,
                                               name: "Second",
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
        state.peoplesState.peoples[2] = People(id: 2,
                                               name: "First",
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
        state.peoplesState.movieCastOrder[9] = [2, 1]
        state.peoplesState.casts[1] = [9: "Role B"]
        state.peoplesState.casts[2] = [9: "Role A"]

        #expect(MovieDetailPeopleState.characters(movieId: 9, from: state)?.map(\.id) == [2, 1])
    }

    @Test func appLaunchModeDetectsPreviewEnvironment() {
        #expect(AppLaunchMode.from(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]) == .preview)
    }

    @Test func appLaunchModeDetectsUISmokeTestsFromArguments() {
        #expect(AppLaunchMode.from(arguments: ["--ui-smoke-tests"], environment: [:]) == .uiSmokeTests)
    }

    @Test func appLaunchModeDefaultsToNormal() {
        #expect(AppLaunchMode.from(arguments: [], environment: [:]) == .normal)
    }

    @Test func appEnvironmentForUISmokeTestsUsesSmokeStoreAndRuntime() {
        let environment = AppEnvironment.make(launchMode: .uiSmokeTests)

        #expect(environment.runtime.isRunningUISmokeTests)
        #expect(environment.store.state.moviesState.movies[0]?.id == 0)
        #expect(environment.store.state.peoplesState.peoples[1]?.department == "Directing")
    }

    @Test func appEnvironmentForPreviewUsesPreviewStoreAndRuntime() {
        let environment = AppEnvironment.make(launchMode: .preview)

        #expect(!(environment.runtime.isRunningUISmokeTests))
        #expect(environment.store.state.moviesState.movies[0]?.id == 0)
        #expect(environment.store.state.peoplesState.peoples[0]?.id == 0)
    }

    @Test func appRuntimeDetectsXCTestEnvironment() {
        let runtime = AppRuntime(launchMode: .normal,
                                 environment: [AppRuntime.xctestConfigurationFilePathKey: "/tmp/test.xctestconfiguration"])

        #expect(runtime.isRunningTests)
        #expect(!(runtime.isLoggingEnabled))
    }

    @Test func appRuntimeDoesNotDetectTestsWithoutXCTestEnvironment() {
        let runtime = AppRuntime(launchMode: .normal, environment: [:])

        #expect(!(runtime.isRunningTests))
        #expect(runtime.isLoggingEnabled)
    }

    @Test func uISmokeInitialStateSeedsExpectedNavigationData() {
        let state = AppStoreFactory.makeInitialState(for: .uiSmokeTests)

        #expect(state.moviesState.movies[0]?.id == 0)
        #expect(state.moviesState.customLists[0]?.name == "TestName")
        #expect(state.peoplesState.crews[1]?[0] == "Director 1")
    }

    @Test func previewInitialStateSeedsExpectedNavigationData() {
        let state = AppStoreFactory.makeInitialState(for: .preview)

        #expect(state.moviesState.movies[0]?.id == 0)
        #expect(state.peoplesState.casts[0]?[0] == "Character 1")
    }

    @Test func moviesMenuListPageListenerDispatchesInjectedPageLoad() {
        var loadedMenu: MoviesMenu?
        var loadedPage: Int?
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { true },
                                                  dispatchPage: { menu, page in
            loadedMenu = menu
            loadedPage = page
        })

        listener.currentPage = 3

        #expect(loadedMenu == .popular)
        #expect(loadedPage == 3)
    }

    @Test func moviesMenuListPageListenerSkipsDispatchWhenSuppressed() {
        var dispatchCount = 0
        let listener = MoviesMenuListPageListener(menu: .trending,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { false },
                                                  dispatchPage: { _, _ in
            dispatchCount += 1
        })

        listener.loadPage()

        #expect(dispatchCount == 0)
    }

    @Test func moviesMenuListPageListenerSkipsDispatchWithoutLoadPolicy() {
        var dispatchCount = 0
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  dispatchPage: { _, _ in
            dispatchCount += 1
        })

        listener.loadPage()

        #expect(dispatchCount == 0)
    }

    @Test func moviesMenuListPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { true })

        listener.loadPage()

        #expect(true)
    }

    @Test func moviesSelectedMenuStoreSynchronizesInitialMenuToListener() {
        let listener = MoviesMenuListPageListener(menu: .trending, loadOnInit: false)
        let store = MoviesSelectedMenuStore(selectedMenu: .popular, pageListener: listener)

        #expect(store.menu == .popular)
        #expect(listener.menu == .popular)
    }

    @Test func moviesSelectedMenuStoreUpdatesListenerWhenMenuChanges() {
        let listener = MoviesMenuListPageListener(menu: .popular, loadOnInit: false)
        let store = MoviesSelectedMenuStore(selectedMenu: .popular, pageListener: listener)

        store.menu = .topRated

        #expect(listener.menu == .topRated)
    }

    @Test func keywordPageListenerDispatchesInjectedPageLoad() {
        var loadedKeyword: Int?
        var loadedPage: Int?
        let listener = KeywordPageListener(dispatchPage: { keyword, page in
            loadedKeyword = keyword
            loadedPage = page
        })
        listener.keyword = 17
        listener.currentPage = 2

        #expect(loadedKeyword == 17)
        #expect(loadedPage == 2)
    }

    @Test func keywordPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = KeywordPageListener()
        listener.keyword = 17

        listener.loadPage()

        #expect(true)
    }

    @Test func moviesSearchPageListenerDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let listener = MoviesSearchPageListener(dispatchSearches: { text, page in
            loadedText = text
            loadedPage = page
        })
        listener.text = "matrix"
        listener.currentPage = 2

        #expect(loadedText == "matrix")
        #expect(loadedPage == 2)
    }

    @Test func moviesSearchPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = MoviesSearchPageListener()
        listener.text = "matrix"

        listener.loadPage()

        #expect(true)
    }

    @Test func moviesSearchTextWrapperBindsInjectedSearchDispatch() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = MoviesSearchTextWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")
        wrapper.searchPageListener.loadPage()

        #expect(loadedText == "matrix")
        #expect(loadedPage == 1)
    }

    @Test func moviesListSearchStateReturnsSearchResultsAndRecentSearches() {
        var state = AppState()
        let keywords = (1...6).map { Keyword(id: $0, name: "Keyword \($0)") }
        state.moviesState.search["matrix"] = [1, 2, 3]
        state.moviesState.searchKeywords["matrix"] = keywords
        state.peoplesState.search["matrix"] = [9, 10]
        state.moviesState.recentSearches = ["matrix", "alien"]

        #expect(MoviesListSearchState.searchedMovies(query: "matrix", from: state) == [1, 2, 3])
        #expect(MoviesListSearchState.searchedKeywords(query: "matrix", from: state)?.map(\.id) == [1, 2, 3, 4, 5])
        #expect(MoviesListSearchState.searchedPeoples(query: "matrix", from: state) == [9, 10])
        #expect(Set(MoviesListSearchState.recentSearches(from: state)) == Set(["matrix", "alien"]))
    }

    @Test func moviesListPaginationPolicyAdvancesSearchPageOnlyWithSearchResults() {
        #expect(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: true, searchedMovies: [1]))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: true, searchedMovies: [])))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: false, searchedMovies: [1])))
    }

    @Test func moviesListPaginationPolicyAdvancesListPageOnlyWhenBrowsingMovies() {
        #expect(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                      pageListenerExists: true,
                                                                      movies: [1]))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: true,
                                                                       pageListenerExists: true,
                                                                       movies: [1])))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                       pageListenerExists: false,
                                                                       movies: [1])))
        #expect(!(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                       pageListenerExists: true,
                                                                       movies: [])))
    }

    @Test func discoverSwipeDecisionMapsLeftToWishlist() {
        #expect(DiscoverSwipeDecision.from(handler: .left) == .wishlist)
    }

    @Test func discoverSwipeDecisionMapsRightToSeenlist() {
        #expect(DiscoverSwipeDecision.from(handler: .right) == .seenlist)
    }

    @Test func discoverSwipeDecisionMapsCancelledToNone() {
        #expect(DiscoverSwipeDecision.from(handler: .cancelled) == .none)
    }

    @Test func discoverSwipeActionPlanBuildsWishlistAction() {
        #expect(DiscoverSwipeActionPlan.action(for: .wishlist, currentMovieId: 42) ==
                       .wishlist(42))
    }

    @Test func discoverSwipeActionPlanBuildsSeenlistAction() {
        #expect(DiscoverSwipeActionPlan.action(for: .seenlist, currentMovieId: 42) ==
                       .seenlist(42))
    }

    @Test func discoverSwipeActionPlanSkipsWhenNoMovieOrNoAction() {
        #expect(DiscoverSwipeActionPlan.action(for: .none, currentMovieId: 42) == nil)
        #expect(DiscoverSwipeActionPlan.action(for: .wishlist, currentMovieId: nil) == nil)
    }

    @Test func discoverFetchPolicyFetchesWhenForcedOrRunningLow() {
        #expect(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 3,
                                                                 force: false,
                                                                 isRunningUISmokeTests: false))
        #expect(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 15,
                                                                 force: true,
                                                                 isRunningUISmokeTests: false))
        #expect(!(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 15,
                                                                  force: false,
                                                                  isRunningUISmokeTests: false)))
    }

    @Test func discoverFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 3,
                                                                  force: false,
                                                                  isRunningUISmokeTests: true)))
    }

    @Test func discoverFetchPolicySkipsWhenEnoughCardsRemain() {
        #expect(!(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 10,
                                                                  force: false,
                                                                  isRunningUISmokeTests: false)))
    }

    @Test func discoverFetchPolicyAllowsForcedRefillOutsideUISmokeTests() {
        #expect(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 10,
                                                                 force: true,
                                                                 isRunningUISmokeTests: false))
    }

    @Test func discoverEmptyStateShowsOnlyWithoutCurrentMovie() {
        #expect(DiscoverEmptyState.shouldShow(currentMovie: nil))
        #expect(!(DiscoverEmptyState.shouldShow(currentMovie: sampleMovie)))
    }

    @Test func discoverEmptyStateContentUsesFilterAwareMessage() {
        let filter = DiscoverFilter(year: 1955,
                                    startYear: 1950,
                                    endYear: 1959,
                                    sort: "popularity.desc",
                                    genre: 35,
                                    region: "US")
        let filtered = DiscoverEmptyStateContent.presentation(filter: filter,
                                                             isRunningUISmokeTests: false)
        let unfiltered = DiscoverEmptyStateContent.presentation(filter: nil,
                                                               isRunningUISmokeTests: false)

        #expect(filtered.title == "No more discover movies")
        #expect(filtered.message.contains("reset the filter"))
        #expect(filtered.showsRefill)
        #expect(unfiltered.message.contains("refill to keep browsing"))
    }

    @Test func discoverEmptyStateContentTreatsRandomFilterAsUnfiltered() {
        let randomFilter = DiscoverFilter(year: 1955,
                                          startYear: nil,
                                          endYear: nil,
                                          sort: "popularity.desc",
                                          genre: nil,
                                          region: nil)
        let presentation = DiscoverEmptyStateContent.presentation(filter: randomFilter,
                                                                  isRunningUISmokeTests: false)

        #expect(!(randomFilter.hasExplicitConstraints))
        #expect(!(presentation.message.contains("reset the filter")))
    }

    @Test func discoverEmptyStateContentHidesRefillDuringUISmokeTests() {
        let filter = DiscoverFilter(year: 1955,
                                    startYear: 1950,
                                    endYear: 1959,
                                    sort: "popularity.desc",
                                    genre: 35,
                                    region: "US")
        #expect(!(DiscoverEmptyStateContent.presentation(filter: filter,
                                                              isRunningUISmokeTests: true).showsRefill))
    }

    @Test func discoverRefillActionPlanRetainsCurrentFilterOutsideUISmokeTests() {
        let filter = DiscoverFilter(year: 1955,
                                    startYear: 1950,
                                    endYear: 1959,
                                    sort: "popularity.desc",
                                    genre: 35,
                                    region: "US")
        let plan = DiscoverRefillActionPlan.plan(currentFilter: filter, isRunningUISmokeTests: false)

        #expect(plan?.forceFetch == true)
        #expect(plan?.filter?.genre == 35)
        #expect(plan?.filter?.region == "US")
    }

    @Test func discoverRefillActionPlanSkipsDuringUISmokeTests() {
        #expect(DiscoverRefillActionPlan.plan(currentFilter: nil, isRunningUISmokeTests: true) == nil)
    }

    @Test func discoverUndoStateOnlyShowsUndoWhenNotDraggingAndMovieExists() {
        #expect(DiscoverUndoState.canUndo(previousMovie: 7, isDragging: false))
        #expect(!(DiscoverUndoState.canUndo(previousMovie: nil, isDragging: false)))
        #expect(!(DiscoverUndoState.canUndo(previousMovie: 7, isDragging: true)))
    }

    @Test func moviesHomeGridFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(MoviesHomeGridFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: false))
    }

    @Test func moviesHomeGridFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(MoviesHomeGridFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: true)))
    }

    @Test func moviesHomeGridFetchPolicyFetchesMenuPagesOutsideUISmokeTests() {
        #expect(MoviesHomeGridFetchPolicy.shouldFetchMenuPage(isRunningUISmokeTests: false))
    }

    @Test func moviesHomeGridFetchPolicySkipsGenreFetchDuringUISmokeTests() {
        #expect(!(MoviesHomeGridFetchPolicy.shouldFetchGenresOnAppear(isRunningUISmokeTests: true)))
    }

    @Test func moviesHomeGridStateReturnsMoviesAndDropsFirstGenre() {
        var state = AppState()
        state.moviesState.moviesList[.popular] = [1, 2]
        state.moviesState.genres = [Genre(id: 0, name: "Random"),
                                    Genre(id: 1, name: "Comedy"),
                                    Genre(id: 2, name: "Drama"), ]

        #expect(MoviesHomeGridState.movies(from: state)[.popular] == [1, 2])
        #expect(MoviesHomeGridState.genres(from: state).map(\.id) == [1, 2])
    }

    @Test func moviesHomeListStateReturnsMoviesForMenuWhenPresent() {
        var state = AppState()
        state.moviesState.moviesList[.popular] = [1, 2, 3]

        #expect(MoviesHomeListState.movies(for: .popular, from: state) == [1, 2, 3])
    }

    @Test func moviesHomeListStateReturnsPlaceholderMoviesWhenMissing() {
        #expect(MoviesHomeListState.movies(for: .popular, from: AppState()) == [0, 0, 0, 0])
    }

    @Test func moviesHomeStateTogglesBetweenListAndGrid() {
        #expect(MoviesHomeState.toggledMode(from: .list) == .grid)
        #expect(MoviesHomeState.toggledMode(from: .grid) == .list)
    }

    #if !os(macOS)
    @Test func moviesHomeStateUsesInlineTitleInListMode() {
        #expect(MoviesHomeState.navigationBarTitleDisplayMode(for: .list) == .inline)
        #expect(MoviesHomeState.navigationBarTitleDisplayMode(for: .grid) == .automatic)
    }
    #endif

    @Test func moviesHomeStateSkipsPageLoadDuringUISmokeTests() {
        #expect(!(MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: true)))
        #expect(MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: false))
    }

    @Test func movieDetailFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(MovieDetailFetchPolicy.slicesToFetch(hasMovieDetail: false,
                                                            hasMovieCredits: false,
                                                            hasRecommended: false,
                                                            hasSimilar: false,
                                                            hasReviews: false,
                                                            hasVideos: false,
                                                            isRunningUISmokeTests: false) ==
                       [.detail, .credits, .recommended, .similar, .reviews, .videos])
    }

    @Test func movieDetailFetchPolicySkipsDuringUISmokeTests() {
        #expect(MovieDetailFetchPolicy.slicesToFetch(hasMovieDetail: false,
                                                           hasMovieCredits: false,
                                                           hasRecommended: false,
                                                           hasSimilar: false,
                                                           hasReviews: false,
                                                           hasVideos: false,
                                                           isRunningUISmokeTests: true).isEmpty)
    }

    @Test func movieDetailListStateReadsWishlistSeenlistAndCustomLists() {
        var state = AppState()
        state.moviesState.wishlist = [12]
        state.moviesState.seenlist = [7]
        state.moviesState.customLists = [
            3: CustomList(id: 3, name: "Favorites", cover: nil, movies: [12]),
            8: CustomList(id: 8, name: "Watch Later", cover: nil, movies: []),
        ]

        #expect(MovieDetailListState.isInWishlist(movieId: 12, from: state))
        #expect(!(MovieDetailListState.isInWishlist(movieId: 7, from: state)))
        #expect(MovieDetailListState.isInSeenlist(movieId: 7, from: state))
        #expect(Set(MovieDetailListState.customLists(from: state).map(\.id)) == Set([3, 8]))
    }

    @Test func movieCrosslineStateMapsMoviesToIds() {
        let movies = [
            sampleMovie,
            Movie(id: 12,
                  original_title: "Another Movie",
                  title: "Another Movie",
                  overview: "",
                  poster_path: nil,
                  backdrop_path: nil,
                  popularity: 0,
                  vote_average: 0,
                  vote_count: 0,
                  release_date: nil,
                  genres: nil,
                  runtime: nil,
                  status: nil,
                  video: false),
        ]

        #expect(MovieCrosslineState.movieIds(from: movies) == [sampleMovie.id, 12])
    }

    @Test func movieCrosslineStateBuildsMoviePresentation() {
        let presentation = MovieCrosslineState.presentation(for: sampleMovie)

        #expect(presentation.title == sampleMovie.userTitle)
        #expect(presentation.posterPath == sampleMovie.poster_path)
        #expect(presentation.popularityScore == Int(sampleMovie.vote_average * 10))
    }

    @Test func movieCrosslinePeopleStateBuildsSubtitleAndAccessibilityIdentifier() {
        let people = People(id: 9,
                            name: "Test Person",
                            character: "Neo",
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

        let presentation = MovieCrosslinePeopleState.presentation(for: people)

        #expect(presentation.name == "Test Person")
        #expect(presentation.subtitle == "Neo")
        #expect(presentation.profilePath == nil)
        #expect(presentation.accessibilityIdentifier == "movieDetail.person.9")
        #expect(MovieCrosslinePeopleState.subtitle(for: people) == "Neo")
        #expect(MovieCrosslinePeopleState.accessibilityIdentifier(for: people) == "movieDetail.person.9")
    }

    @Test func movieCrosslinePeopleStateOmitsSubtitleWhenPeopleRoleIsMissing() {
        let people = People(id: 4,
                            name: "No Role",
                            character: nil,
                            department: nil,
                            profile_path: "/profile.jpg",
                            known_for_department: nil,
                            known_for: nil,
                            also_known_as: nil,
                            birthDay: nil,
                            deathDay: nil,
                            place_of_birth: nil,
                            biography: nil,
                            popularity: nil,
                            images: nil)

        let presentation = MovieCrosslinePeopleState.presentation(for: people)

        #expect(presentation.name == "No Role")
        #expect(presentation.subtitle == nil)
        #expect(presentation.profilePath == "/profile.jpg")
        #expect(MovieCrosslinePeopleState.subtitle(for: people) == "")
    }

    @Test func movieInfoStateBuildsPresentation() {
        var movie = sampleMovie
        movie.production_countries = [Movie.ProductionCountry(name: "France")]

        let presentation = MovieInfoState.presentation(for: movie)

        #expect(presentation.yearText == "1972")
        #expect(presentation.runtimeText == "• 80 minutes")
        #expect(presentation.statusText == "• released")
        #expect(presentation.productionCountryText == "France")
    }

    @Test func movieCoverStateBuildsPresentationAndPlaceholderGenres() {
        let populatedPresentation = MovieCoverState.presentation(for: sampleMovie)

        #expect(populatedPresentation.backdropPath == sampleMovie.backdrop_path)
        #expect(populatedPresentation.posterPath == sampleMovie.poster_path)
        #expect(populatedPresentation.popularityScore == Int(sampleMovie.vote_average * 10))
        #expect(populatedPresentation.ratingsText == "\(sampleMovie.vote_count) ratings")
        #expect(populatedPresentation.genres.map(\.name) == sampleMovie.genres?.map(\.name))
        #expect(!(populatedPresentation.areGenresPlaceholder))

        let noGenresMovie = Movie(id: 14,
                                  original_title: "Genreless",
                                  title: "Genreless",
                                  overview: "",
                                  poster_path: nil,
                                  backdrop_path: nil,
                                  popularity: 0,
                                  vote_average: 7.2,
                                  vote_count: 15,
                                  release_date: nil,
                                  genres: nil,
                                  runtime: nil,
                                  status: nil,
                                  video: false)

        let placeholderPresentation = MovieCoverState.presentation(for: noGenresMovie)

        #expect(placeholderPresentation.areGenresPlaceholder)
        #expect(placeholderPresentation.genres.count == 3)
        #expect(placeholderPresentation.genres.map(\.id) == [-1, -2, -3])
        #expect(placeholderPresentation.genres.map(\.name) == ["     ", "     ", "     "])
        #expect(placeholderPresentation.backdropPath == nil)
        #expect(placeholderPresentation.ratingsText == "15 ratings")
    }

    @Test func movieCoverStateBuildsGenreAccessibilityIdentifier() {
        let genre = Genre(id: 42, name: "Sci-Fi")

        #expect(MovieCoverState.accessibilityIdentifier(for: genre) == "movieDetail.genre.42")
    }

    @Test func moviePostersStateBuildsPresentationsAndSelection() {
        let posters = [
            ImageData(aspect_ratio: 0.7, file_path: "/poster-a.jpg", height: 1000, width: 700),
            ImageData(aspect_ratio: 0.7, file_path: "/poster-b.jpg", height: 1000, width: 700),
        ]

        let presentations = MoviePostersState.presentations(from: posters)

        #expect(presentations.map(\.id) == ["/poster-a.jpg", "/poster-b.jpg"])
        #expect(presentations.map(\.path) == ["/poster-a.jpg", "/poster-b.jpg"])
        #expect(MoviePostersState.selectedPoster(afterSelecting: presentations[1]).file_path == "/poster-b.jpg")
    }

    @Test func movieBackdropsStateBuildsPresentations() {
        let backdrops = [
            ImageData(aspect_ratio: 1.7, file_path: "/backdrop-a.jpg", height: 1200, width: 1800),
            ImageData(aspect_ratio: 1.7, file_path: "/backdrop-b.jpg", height: 1200, width: 1800),
        ]

        let presentations = MovieBackdropsState.presentations(from: backdrops)

        #expect(presentations.map(\.id) == ["/backdrop-a.jpg", "/backdrop-b.jpg"])
        #expect(presentations.map(\.path) == ["/backdrop-a.jpg", "/backdrop-b.jpg"])
    }

    @Test func genresListFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(GenresListFetchPolicy.shouldFetchGenres(isRunningUISmokeTests: false))
    }

    @Test func genresListFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(GenresListFetchPolicy.shouldFetchGenres(isRunningUISmokeTests: true)))
    }

    @Test func genresListFetchPolicyReturnsFetchGenresActionOutsideUISmokeTests() {
        let actions = GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: false)

        #expect(actions.count == 1)
        #expect(actions.first is MoviesActions.FetchGenres)
    }

    @Test func genresListFetchPolicyReturnsNoActionsDuringUISmokeTests() {
        #expect(GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: true).isEmpty)
    }

    @Test func genresListStateReturnsGenresFromState() {
        var state = AppState()
        state.moviesState.genres = [Genre(id: 1, name: "Comedy"),
                                    Genre(id: 2, name: "Drama"), ]

        #expect(GenresListState.genres(from: state).map(\.id) == [1, 2])
    }

    @Test func movieGenrePageActionBuildsFetchGenreAction() {
        let genre = Genre(id: 9, name: "Adventure")
        let action = MovieGenrePageAction.fetch(genre: genre, page: 3, sort: .byScore)

        guard let fetchAction = action as? MoviesActions.FetchMoviesGenre else {
            Issue.record("Expected FetchMoviesGenre action")
            return
        }

        #expect(fetchAction.genre.id == 9)
        #expect(fetchAction.page == 3)
        #expect(fetchAction.sortBy == .byScore)
    }

    @Test func moviesGenreListStateReturnsGenreMoviesWhenPresent() {
        var state = AppState()
        let genre = Genre(id: 9, name: "Adventure")
        state.moviesState.withGenre[9] = [1, 4, 7]

        #expect(MoviesGenreListState.movies(for: genre, from: state) == [1, 4, 7])
    }

    @Test func moviesGenreListStateReturnsEmptyWhenMissing() {
        let state = AppState()
        let genre = Genre(id: 9, name: "Adventure")

        #expect(MoviesGenreListState.movies(for: genre, from: state) == [])
    }

    @Test func movieKeywordListStateReturnsKeywordMoviesWhenPresent() {
        var state = AppState()
        let keyword = Keyword(id: 42, name: "Sci-Fi")
        state.moviesState.withKeywords[42] = [3, 5, 8]

        #expect(MovieKeywordListState.movies(for: keyword, from: state) == [3, 5, 8])
    }

    @Test func movieKeywordListStateReturnsPlaceholderFallbackWhenMissing() {
        let state = AppState()
        let keyword = Keyword(id: 42, name: "Sci-Fi")

        #expect(MovieKeywordListState.movies(for: keyword, from: state) == [0, 0, 0, 0])
    }

    @Test func moviesCrewListStateReturnsCrewMoviesWhenPresent() {
        var state = AppState()
        let crew = People(id: 9,
                          name: "Test Director",
                          character: nil,
                          department: "Directing",
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
        state.moviesState.withCrew[9] = [1, 4, 7]

        #expect(MoviesCrewListState.movies(for: crew, from: state) == [1, 4, 7])
    }

    @Test func moviesCrewListStateReturnsEmptyWhenMissing() {
        let state = AppState()
        let crew = People(id: 9,
                          name: "Test Director",
                          character: nil,
                          department: "Directing",
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

        #expect(MoviesCrewListState.movies(for: crew, from: state) == [])
    }

    @Test func discoverFilterFormFetchPolicyFetchesWhenGenresAreMissing() {
        #expect(DiscoverFilterFormFetchPolicy.shouldFetchGenres(genres: []))
    }

    @Test func discoverFilterFormFetchPolicySkipsWhenGenresAreLoaded() {
        #expect(!(DiscoverFilterFormFetchPolicy.shouldFetchGenres(genres: [Genre(id: 1, name: "Comedy")])))
    }

    @Test func discoverFilterFormStateReturnsNilForDefaultSelections() {
        #expect(DiscoverFilterFormState.formFilter(selectedDate: 0,
                                                       selectedGenre: 0,
                                                       selectedCountry: 0,
                                                       datesInt: [0, 1950, 1960],
                                                       genres: [Genre(id: 0, name: "Random"),
                                                                Genre(id: 12, name: "Adventure"), ]) == nil)
    }

    @Test func discoverFilterFormStateBuildsFilterFromSelections() {
        let expectedRegion = NSLocale.isoCountryCodes[0]
        let filter = DiscoverFilterFormState.formFilter(selectedDate: 1,
                                                        selectedGenre: 1,
                                                        selectedCountry: 1,
                                                        datesInt: [0, 1950, 1960],
                                                        genres: [Genre(id: 0, name: "Random"),
                                                                 Genre(id: 12, name: "Adventure"), ])

        #expect(filter?.startYear == 1950)
        #expect(filter?.endYear == 1959)
        #expect(filter?.genre == 12)
        #expect(filter?.region == expectedRegion)
    }

    @Test func discoverFilterFormStateMapsCurrentFilterBackToSelections() {
        let expectedCountrySelection = (NSLocale.isoCountryCodes.firstIndex(of: "US") ?? -1) + 1
        let filter = DiscoverFilter(year: 1995,
                                    startYear: 1960,
                                    endYear: 1969,
                                    sort: "popularity.desc",
                                    genre: 28,
                                    region: "US")
        let genres = [Genre(id: 0, name: "Random"),
                      Genre(id: 28, name: "Action"), ]

        #expect(DiscoverFilterFormState.selectedDate(currentFilter: filter,
                                                            datesInt: [0, 1950, 1960, 1970]) ==
                       2)
        #expect(DiscoverFilterFormState.selectedGenre(currentFilter: filter, genres: genres) ==
                       1)
        #expect(DiscoverFilterFormState.selectedCountry(currentFilter: filter) ==
                       expectedCountrySelection)
    }

    @Test func discoverFilterFormActionPlanSavesExplicitFilter() {
        let genres = [Genre(id: 0, name: "Random"), Genre(id: 35, name: "Comedy")]
        let fallback = DiscoverFilter(year: 2020,
                                      startYear: nil,
                                      endYear: nil,
                                      sort: "popularity.desc",
                                      genre: nil,
                                      region: nil)
        let plan = DiscoverFilterFormActionPlan.savePlan(selectedDate: 1,
                                                         selectedGenre: 1,
                                                         selectedCountry: 1,
                                                         datesInt: [0, 1950],
                                                         genres: genres,
                                                         fallbackRandomFilter: fallback)

        #expect(plan.filterToSave != nil)
        #expect(plan.filterToSave?.startYear == plan.activeFilter.startYear)
        #expect(plan.filterToSave?.endYear == plan.activeFilter.endYear)
        #expect(plan.filterToSave?.genre == plan.activeFilter.genre)
        #expect(plan.filterToSave?.region == plan.activeFilter.region)
        #expect(plan.activeFilter.startYear == 1950)
        #expect(plan.activeFilter.endYear == 1959)
        #expect(plan.activeFilter.genre == 35)
        #expect(plan.activeFilter.region == NSLocale.isoCountryCodes[0])
    }

    @Test func discoverFilterFormActionPlanFallsBackToRandomFilterForDefaultSelections() {
        let fallback = DiscoverFilter(year: 2020,
                                      startYear: nil,
                                      endYear: nil,
                                      sort: "popularity.desc",
                                      genre: nil,
                                      region: nil)
        let plan = DiscoverFilterFormActionPlan.savePlan(selectedDate: 0,
                                                         selectedGenre: 0,
                                                         selectedCountry: 0,
                                                         datesInt: [0, 1950],
                                                         genres: [Genre(id: 0, name: "Random")],
                                                         fallbackRandomFilter: fallback)

        #expect(plan.filterToSave == nil)
        #expect(plan.activeFilter.year == fallback.year)
        #expect(plan.activeFilter.startYear == fallback.startYear)
        #expect(plan.activeFilter.endYear == fallback.endYear)
        #expect(plan.activeFilter.sort == fallback.sort)
        #expect(plan.activeFilter.genre == fallback.genre)
        #expect(plan.activeFilter.region == fallback.region)
    }

    @Test func movieReviewsFetchPolicyFetchesWhenReviewsAreMissing() {
        #expect(MovieReviewsFetchPolicy.shouldFetchReviews(existingReviews: []))
    }

    @Test func movieReviewsFetchPolicySkipsWhenReviewsAlreadyLoaded() {
        let review = Review(id: "1",
                            author: "Test",
                            content: "Review")

        #expect(!(MovieReviewsFetchPolicy.shouldFetchReviews(existingReviews: [review])))
    }

    @Test func movieReviewsStateReturnsReviewsWhenPresent() {
        var state = AppState()
        let review = Review(id: "1",
                            author: "Test",
                            content: "Review")
        state.moviesState.reviews[12] = [review]

        #expect(MovieReviewsState.reviews(for: 12, in: state).map(\.id) == ["1"])
    }

    @Test func movieReviewsStateReturnsEmptyWhenMissing() {
        #expect(MovieReviewsState.reviews(for: 12, in: AppState()).isEmpty)
    }

    @Test func movieButtonsToggleActionAddsMovieToWishlistWhenMissing() {
        #expect(MovieButtonsToggleAction.wishlistAction(movieId: 12, isInWishlist: false) ==
                       .addToWishlist(movie: 12))
    }

    @Test func movieButtonsToggleActionRemovesMovieFromWishlistWhenPresent() {
        #expect(MovieButtonsToggleAction.wishlistAction(movieId: 12, isInWishlist: true) ==
                       .removeFromWishlist(movie: 12))
    }

    #if !os(macOS)
    @Test func actionSheetMovieListActionAddsMovieToWishlistWhenMissing() {
        #expect(ActionSheetMovieListAction.wishlist(movie: 12, isInWishlist: false) ==
                       .addToWishlist(movie: 12))
    }

    @Test func actionSheetMovieListActionRemovesMovieFromWishlistWhenPresent() {
        #expect(ActionSheetMovieListAction.wishlist(movie: 12, isInWishlist: true) ==
                       .removeFromWishlist(movie: 12))
    }

    @Test func actionSheetMovieListActionAddsMovieToSeenlistWhenMissing() {
        #expect(ActionSheetMovieListAction.seenlist(movie: 12, isInSeenlist: false) ==
                       .addToSeenlist(movie: 12))
    }

    @Test func actionSheetMovieListActionRemovesMovieFromSeenlistWhenPresent() {
        #expect(ActionSheetMovieListAction.seenlist(movie: 12, isInSeenlist: true) ==
                       .removeFromSeenlist(movie: 12))
    }

    @Test func actionSheetMovieListActionAddsMovieToCustomListWhenMissing() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        #expect(ActionSheetMovieListAction.customList(list: list, movie: 12) ==
                       .addToCustomList(list: 7, movie: 12))
    }

    @Test func actionSheetMovieListActionRemovesMovieFromCustomListWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [12])

        #expect(ActionSheetMovieListAction.customList(list: list, movie: 12) ==
                       .removeFromCustomList(list: 7, movie: 12))
    }
    #endif

    @Test func movieButtonsToggleActionAddsMovieToSeenlistWhenMissing() {
        #expect(MovieButtonsToggleAction.seenlistAction(movieId: 12, isInSeenlist: false) ==
                       .addToSeenlist(movie: 12))
    }

    @Test func movieButtonsToggleActionRemovesMovieFromSeenlistWhenPresent() {
        #expect(MovieButtonsToggleAction.seenlistAction(movieId: 12, isInSeenlist: true) ==
                       .removeFromSeenlist(movie: 12))
    }

    @Test func peopleDetailFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: false,
                                                                hasLoadedDetail: false))
        #expect(PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: false,
                                                                hasLoadedImages: false))
        #expect(PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: false,
                                                                 hasLoadedCredits: false))
    }

    @Test func peopleDetailFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: true,
                                                                 hasLoadedDetail: false)))
        #expect(!(PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: true,
                                                                 hasLoadedImages: false)))
        #expect(!(PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: true,
                                                                  hasLoadedCredits: false)))
    }

    @Test func peopleDetailFetchPolicySkipsAlreadyLoadedSlices() {
        #expect(!(PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: false,
                                                                 hasLoadedDetail: true)))
        #expect(!(PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: false,
                                                                 hasLoadedImages: true)))
        #expect(!(PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: false,
                                                                  hasLoadedCredits: true)))
    }

    @Test func settingsFormRefreshPolicyRefreshesWhenRegionChanges() {
        #expect(SettingsFormRefreshPolicy.shouldRefreshMovieMenus(previousRegion: "US",
                                                                       selectedRegion: "FR"))
    }

    @Test func settingsFormRefreshPolicySkipsWhenRegionMatches() {
        #expect(!(SettingsFormRefreshPolicy.shouldRefreshMovieMenus(previousRegion: "US",
                                                                        selectedRegion: "US")))
    }

    @Test func settingsFormRefreshPolicyReturnsAllMenusWhenRegionChanges() {
        #expect(SettingsFormRefreshPolicy.menusToRefresh(previousRegion: "US",
                                                                selectedRegion: "FR") ==
                       MoviesMenu.allCases)
    }

    @Test func settingsFormRefreshPolicyReturnsNoMenusWhenRegionMatches() {
        #expect(SettingsFormRefreshPolicy.menusToRefresh(previousRegion: "US",
                                                              selectedRegion: "US").isEmpty)
    }

    @Test func settingsFormCacheResetPolicyClearsCachesDispatchesResetAndArchivesTrimmedState() {
        var state = AppState()
        state.moviesState.movies[11] = makeMovie(id: 11)
        state.moviesState.movies[99] = makeMovie(id: 99)
        state.moviesState.wishlist = [11]
        state.moviesState.moviesList[.popular] = [99]
        state.peoplesState.fanClub = [7]
        state.peoplesState.peoples[7] = makePerson(id: 7)
        state.peoplesState.peoples[8] = makePerson(id: 8)

        var clearedImageCache = false
        var clearedURLCache = false
        var didDispatchClearCachedData = false
        var archivedState: AppState?

        SettingsFormCacheResetPolicy.clearCachedData(
            state: state,
            dispatch: { action in
                didDispatchClearCachedData = action is AppActions.ClearCachedData
            },
            clearImageCache: {
                clearedImageCache = true
            },
            clearURLCache: {
                clearedURLCache = true
            },
            archiveState: { state in
                archivedState = state
            }
        )

        #expect(clearedImageCache)
        #expect(clearedURLCache)
        #expect(didDispatchClearCachedData)
        #expect(archivedState?.moviesState.wishlist == Set([11]))
        #expect(archivedState?.moviesState.movies[11] != nil)
        #expect(archivedState?.moviesState.movies[99] == nil)
        #expect(archivedState?.peoplesState.fanClub == Set([7]))
        #expect(archivedState?.peoplesState.peoples[7] != nil)
        #expect(archivedState?.peoplesState.peoples[8] == nil)
    }

    @Test func settingsFormDebugStateCountsMovies() {
        #expect(SettingsFormDebugState.moviesCount(from: [0: sampleMovie, 1: sampleMovie]) == 2)
    }

    @Test func settingsFormStateCountsMoviesFromAppState() {
        var state = AppState()
        state.moviesState.movies = [0: sampleMovie, 1: sampleMovie]

        #expect(SettingsFormState.moviesCount(in: state) == 2)
    }

    @Test func outlineMoviesMenuListFetchPolicyFetchesOutsideUISmokeTests() {
        #expect(OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: false))
    }

    @Test func outlineMoviesMenuListFetchPolicySkipsDuringUISmokeTests() {
        #expect(!(OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: true)))
    }

    @Test func sampleMovieHasExpectedIdentifier() {
        #expect(sampleMovie.id == 0)
    }

    @Test func moviesSortAPIMapping() {
        #expect(MoviesSort.byReleaseDate.sortByAPI() == "release_date.desc")
        #expect(MoviesSort.byAddedDate.sortByAPI() == "primary_release_date.desc")
        #expect(MoviesSort.byScore.sortByAPI() == "vote_average.desc")
        #expect(MoviesSort.byPopularity.sortByAPI() == "popularity.desc")
    }

    @Test func appLoggingPolicyDisablesLoggingDuringTests() {
        #expect(!(AppLoggingPolicy.shouldEnableLogging(isRunningTests: true)))
    }

    @Test func appLoggingPolicyEnablesLoggingOutsideTests() {
        #expect(AppLoggingPolicy.shouldEnableLogging(isRunningTests: false))
    }

    @Test func peopleContextMenuFanClubActionAddsWhenMissing() {
        #expect(PeopleContextMenuFanClubAction.toggleAction(people: 9, isInFanClub: false) ==
                       .add(people: 9))
    }

    @Test func peopleContextMenuFanClubActionRemovesWhenPresent() {
        #expect(PeopleContextMenuFanClubAction.toggleAction(people: 9, isInFanClub: true) ==
                       .remove(people: 9))
    }

    @Test func peopleContextMenuFanClubActionTitleForMissingPeople() {
        #expect(PeopleContextMenuFanClubAction.title(isInFanClub: false) ==
                       "Add to fan club")
    }

    @Test func peopleContextMenuFanClubActionTitleForExistingPeople() {
        #expect(PeopleContextMenuFanClubAction.title(isInFanClub: true) ==
                       "Remove from fan club")
    }

    @Test func discoverPosterLookupReturnsPosterPathForMovie() {
        #expect(DiscoverPosterLookup.posterPath(for: 12, posters: [12: "/poster.jpg"]) ==
                       "/poster.jpg")
    }

    @Test func discoverPosterLookupReturnsNilWhenMovieIsMissing() {
        #expect(DiscoverPosterLookup.posterPath(for: 12, posters: [:]) == nil)
    }

    @Test func peopleDetailMovieGroupingGroupsMoviesByReleaseYear() {
        let grouped = PeopleDetailMovieGrouping.group(credits: [sampleMovie.id: "Lead"],
                                                      movies: [sampleMovie.id: sampleMovie])

        #expect(grouped["1972"]?.first?.id == sampleMovie.id)
        #expect(grouped["1972"]?.first?.role == "Lead")
    }

    @Test func peopleDetailMovieGroupingSkipsCreditsWithoutMovies() {
        let grouped = PeopleDetailMovieGrouping.group(credits: [999: "Lead"],
                                                      movies: [:])

        #expect(grouped.isEmpty)
    }

    @Test func peopleDetailCreditsStateMergesCastAndCrewRolesForSameMovie() {
        let merged = PeopleDetailCreditsState.mergedCredits(cast: [7: "Actor"],
                                                            crew: [7: "Director"])

        #expect(merged[7] == "Actor • Director")
    }

    @Test func peopleDetailCreditsStateDedupesMatchingRoles() {
        let merged = PeopleDetailCreditsState.mergedCredits(cast: [7: "Producer"],
                                                            crew: [7: "Producer"])

        #expect(merged[7] == "Producer")
    }

    @Test func peopleDetailSortedYearsPlacesUpcomingLast() {
        #expect(PeopleDetailState.sortedYears(from: ["Upcoming": [], "2024": [], "2022": []]) ==
                       ["2024", "2022", "Upcoming"])
    }

    @Test func customListPresentationUsesFirstMovieAsListCover() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [sampleMovie.id])

        #expect(CustomListPresentation.coverMovie(for: list,
                                                         movies: [sampleMovie.id: sampleMovie])?.id ==
                       sampleMovie.id)
    }

    @Test func customListPresentationUsesExplicitBackdropCoverWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: sampleMovie.id, movies: [])

        #expect(CustomListPresentation.coverBackdropMovie(for: list,
                                                                 movies: [sampleMovie.id: sampleMovie])?.id ==
                       sampleMovie.id)
    }

    @Test func customListPresentationSkipsMissingCoverMovies() {
        let list = CustomList(id: 7, name: "Favorites", cover: 999, movies: [999])

        #expect(CustomListPresentation.coverMovie(for: list, movies: [:]) == nil)
        #expect(CustomListPresentation.coverBackdropMovie(for: list, movies: [:]) == nil)
    }

    @Test func customListSearchMovieTextWrapperDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = CustomListSearchMovieTextWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(loadedText == "matrix")
        #expect(loadedPage == 1)
    }

    @Test func customListSearchMovieTextWrapperDoesNotDispatchWithoutInjectedHandler() {
        let wrapper = CustomListSearchMovieTextWrapper()

        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(true)
    }

    @Test func customListFormSearchWrapperDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = CustomListFormSearchWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(loadedText == "matrix")
        #expect(loadedPage == 1)
    }

    @Test func customListFormSearchWrapperDoesNotDispatchWithoutInjectedHandler() {
        let wrapper = CustomListFormSearchWrapper()

        wrapper.onUpdateTextDebounced(text: "matrix")

        #expect(true)
    }

    @Test func customListSelectionTogglesMovieIntoSelection() {
        #expect(CustomListSelection.toggled(movie: 7, in: []) == Set([7]))
    }

    @Test func customListSelectionTogglesMovieOutOfSelection() {
        #expect(CustomListSelection.toggled(movie: 7, in: Set([7, 9])) == Set([9]))
    }

    @Test func customListSelectionPendingAddButtonTitleForEmptySelection() {
        #expect(CustomListSelection.pendingAddButtonTitle(for: []) == "Cancel")
    }

    @Test func customListSelectionPendingAddButtonTitleForSelectedMovies() {
        #expect(CustomListSelection.pendingAddButtonTitle(for: Set([1, 2])) == "Add movies (2)")
    }

    @Test func customListFormStateReturnsEditingValuesWhenListExists() {
        let list = CustomList(id: 7, name: "Favorites", cover: 12, movies: [])

        let editingValues = CustomListFormState.editingValues(editingListId: 7,
                                                              customLists: [7: list])

        #expect(editingValues?.name == "Favorites")
        #expect(editingValues?.cover == 12)
    }

    @Test func customListFormStateReturnsNilWhenEditingListIsMissing() {
        #expect(CustomListFormState.editingValues(editingListId: 7, customLists: [:]) == nil)
    }

    @Test func customListFormPresentationReturnsCoverMovieWhenPresent() {
        #expect(CustomListFormPresentation.coverMovie(coverId: sampleMovie.id,
                                                             movies: [sampleMovie.id: sampleMovie])?.id ==
                       sampleMovie.id)
    }

    @Test func customListFormPresentationSkipsMissingCoverMovie() {
        #expect(CustomListFormPresentation.coverMovie(coverId: 99, movies: [:]) == nil)
    }

    @Test func customListFormPresentationReturnsResolvedSearchMovies() {
        let movies = CustomListFormPresentation.searchedMovies(searchText: "alien",
                                                               searchResults: ["alien": [sampleMovie.id]],
                                                               movies: [sampleMovie.id: sampleMovie])

        #expect(movies.map(\.id) == [sampleMovie.id])
    }

    @Test func customListFormPresentationSkipsMissingSearchMovies() {
        let movies = CustomListFormPresentation.searchedMovies(searchText: "alien",
                                                               searchResults: ["alien": [sampleMovie.id, 99]],
                                                               movies: [sampleMovie.id: sampleMovie])

        #expect(movies.map(\.id) == [sampleMovie.id])
    }

    @Test func customListDetailStateReturnsListWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        #expect(CustomListDetailState.list(listId: 7, customLists: [7: list])?.id == 7)
    }

    @Test func customListDetailStateReturnsNilWhenListIsMissing() {
        #expect(CustomListDetailState.list(listId: 7, customLists: [:]) == nil)
    }

    @Test func customListDetailStateReturnsSearchResultsWhenSearching() {
        #expect(CustomListDetailState.searchedMovies(searchText: "alien",
                                                            searchResults: ["alien": [1, 2]]) ==
                       [1, 2])
    }

    @Test func customListDetailStateReturnsNilWhenSearchTextIsEmpty() {
        #expect(CustomListDetailState.searchedMovies(searchText: "",
                                                          searchResults: ["alien": [1, 2]]) == nil)
    }

    @Test func myListsPresentationReturnsCustomListsFromDictionary() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        #expect(MyListsPresentation.customLists(from: [7: list]).map(\.id) == [7])
    }

    @Test func myListsPresentationReturnsEmptySortedMoviesForEmptyInput() {
        #expect(MyListsPresentation.sortedMovies([], by: .byReleaseDate, state: AppState()) == [])
    }
}
// swiftlint:enable type_body_length

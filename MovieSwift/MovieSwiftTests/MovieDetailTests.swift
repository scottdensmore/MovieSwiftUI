import Testing
import Foundation
import MovieSwiftFluxCore
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `@MainActor`: exercises main-actor app code (state query helpers,
// reducers via the store, presentation builders), so the suite runs on
// the main actor.
@Suite @MainActor
struct MovieDetailTests {
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
            ImageData(aspectRatio: 0.7, filePath: "/poster-a.jpg", height: 1000, width: 700),
            ImageData(aspectRatio: 0.7, filePath: "/poster-b.jpg", height: 1000, width: 700),
        ]

        let presentations = MoviePostersState.presentations(from: posters)

        #expect(presentations.map(\.id) == ["/poster-a.jpg", "/poster-b.jpg"])
        #expect(presentations.map(\.path) == ["/poster-a.jpg", "/poster-b.jpg"])
        #expect(MoviePostersState.selectedPoster(afterSelecting: presentations[1]).filePath == "/poster-b.jpg")
    }

    @Test func movieBackdropsStateBuildsPresentations() {
        let backdrops = [
            ImageData(aspectRatio: 1.7, filePath: "/backdrop-a.jpg", height: 1200, width: 1800),
            ImageData(aspectRatio: 1.7, filePath: "/backdrop-b.jpg", height: 1200, width: 1800),
        ]

        let presentations = MovieBackdropsState.presentations(from: backdrops)

        #expect(presentations.map(\.id) == ["/backdrop-a.jpg", "/backdrop-b.jpg"])
        #expect(presentations.map(\.path) == ["/backdrop-a.jpg", "/backdrop-b.jpg"])
    }

    @Test func movieVideosStateKeepsYouTubeTrailersFirst() {
        let videos = [
            Video(id: "1", name: "Teaser", site: "YouTube", key: "teaserKey", type: "Teaser"),
            Video(id: "2", name: "Official Trailer", site: "YouTube", key: "trailerKey", type: "Trailer"),
            Video(id: "3", name: "Vimeo Trailer", site: "Vimeo", key: "vimeoKey", type: "Trailer"),
            Video(id: "4", name: "Behind the scenes", site: "YouTube", key: "clipKey", type: "Featurette"),
        ]

        let presentations = MovieVideosState.presentations(from: videos)

        // Non-YouTube sources are dropped; Trailer is ordered before Teaser
        // before other types, preserving original order within a type.
        #expect(presentations.map(\.id) == ["2", "1", "4"])
        #expect(presentations.first?.name == "Official Trailer")
        #expect(presentations.first?.youtubeURL == URL(string: "https://www.youtube.com/watch?v=trailerKey"))
        #expect(presentations.first?.thumbnailURL == URL(string: "https://img.youtube.com/vi/trailerKey/hqdefault.jpg"))
        #expect(presentations.first?.accessibilityId == "movieDetail.video.2")
    }

    @Test func movieVideosStateReturnsEmptyForEmptyInput() {
        #expect(MovieVideosState.presentations(from: []).isEmpty)
    }

    @Test func movieVideosStateFiltersOutAllNonYouTubeVideos() {
        let videos = [
            Video(id: "1", name: "Vimeo Trailer", site: "Vimeo", key: "v1", type: "Trailer"),
            Video(id: "2", name: "Dailymotion Clip", site: "Dailymotion", key: "d1", type: "Clip"),
        ]

        #expect(MovieVideosState.presentations(from: videos).isEmpty)
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

    @Test func movieButtonsToggleActionAddsMovieToSeenlistWhenMissing() {
        #expect(MovieButtonsToggleAction.seenlistAction(movieId: 12, isInSeenlist: false) ==
                       .addToSeenlist(movie: 12))
    }

    @Test func movieButtonsToggleActionRemovesMovieFromSeenlistWhenPresent() {
        #expect(MovieButtonsToggleAction.seenlistAction(movieId: 12, isInSeenlist: true) ==
                       .removeFromSeenlist(movie: 12))
    }

    @Test func sampleMovieHasExpectedIdentifier() {
        #expect(sampleMovie.id == 0)
    }
}

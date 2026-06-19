import Testing
import MovieSwiftFluxCore
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

// `@MainActor`: exercises MovieDetailState query helpers and the
// MovieDetail view's nested presentation types, which are main-actor
// isolated (the MovieDetail view is a @MainActor SwiftUI view).
@Suite @MainActor
struct MovieDetailStateTests {

    private func makeMovie(id: Int,
                           keywords: Movie.Keywords? = nil,
                           images: Movie.MovieImages? = nil,
                           genres: [Genre]? = nil,
                           overview: String = "Overview") -> Movie {
        Movie(id: id,
              original_title: "Movie \(id)",
              title: "Movie \(id)",
              overview: overview,
              poster_path: nil,
              backdrop_path: nil,
              popularity: 0,
              vote_average: 0,
              vote_count: 0,
              release_date: nil,
              genres: genres,
              runtime: nil,
              status: nil,
              video: false,
              keywords: keywords,
              images: images,
              production_countries: nil,
              character: nil,
              department: nil)
    }

    private func makePeople(id: Int, name: String = "Person", character: String? = nil, department: String? = nil) -> People {
        People(id: id,
               name: name,
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

    // MARK: - MovieDetailState

    @Test func movieReturnsNilWhenMovieIsMissing() {
        #expect(MovieDetailState.movie(movieId: 404, from: AppState()) == nil)
    }

    @Test func movieReturnsMovieWhenPresent() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)

        #expect(MovieDetailState.movie(movieId: 1, from: state)?.id == 1)
    }

    @Test func hasLoadedDetailRequiresKeywordsAndImages() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.detailed.insert(1)

        #expect(!(MovieDetailState.hasLoadedDetail(movieId: 1, from: state)))

        state.moviesState.movies[1] = makeMovie(
            id: 1,
            keywords: Movie.Keywords(keywords: [Keyword(id: 1, name: "test")]),
            images: Movie.MovieImages(posters: [], backdrops: [])
        )

        #expect(MovieDetailState.hasLoadedDetail(movieId: 1, from: state))
    }

    @Test func hasLoadedDetailReturnsFalseWhenNotInDetailedSet() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(
            id: 1,
            keywords: Movie.Keywords(keywords: []),
            images: Movie.MovieImages(posters: [], backdrops: [])
        )

        #expect(!(MovieDetailState.hasLoadedDetail(movieId: 1, from: state)))
    }

    @Test func hasLoadedRecommendedRequiresBothSetAndEntry() {
        var state = AppState()

        #expect(!(MovieDetailState.hasLoadedRecommended(movieId: 1, from: state)))

        state.moviesState.recommendedLoaded.insert(1)
        #expect(!(MovieDetailState.hasLoadedRecommended(movieId: 1, from: state)))

        state.moviesState.recommended[1] = [10]
        #expect(MovieDetailState.hasLoadedRecommended(movieId: 1, from: state))
    }

    @Test func hasLoadedSimilarRequiresBothSetAndEntry() {
        var state = AppState()

        #expect(!(MovieDetailState.hasLoadedSimilar(movieId: 1, from: state)))

        state.moviesState.similarLoaded.insert(1)
        state.moviesState.similar[1] = []
        #expect(MovieDetailState.hasLoadedSimilar(movieId: 1, from: state))
    }

    @Test func hasLoadedReviewsRequiresBothSetAndEntry() {
        var state = AppState()

        #expect(!(MovieDetailState.hasLoadedReviews(movieId: 1, from: state)))

        state.moviesState.reviewsLoaded.insert(1)
        state.moviesState.reviews[1] = []
        #expect(MovieDetailState.hasLoadedReviews(movieId: 1, from: state))
    }

    @Test func hasLoadedVideosRequiresBothSetAndEntry() {
        var state = AppState()

        #expect(!(MovieDetailState.hasLoadedVideos(movieId: 1, from: state)))

        state.moviesState.videosLoaded.insert(1)
        state.moviesState.videos[1] = []
        #expect(MovieDetailState.hasLoadedVideos(movieId: 1, from: state))
    }

    // MARK: - MovieDetailListState

    @Test func isInWishlist() {
        var state = AppState()
        #expect(!(MovieDetailListState.isInWishlist(movieId: 1, from: state)))

        state.moviesState.wishlist.insert(1)
        #expect(MovieDetailListState.isInWishlist(movieId: 1, from: state))
    }

    @Test func isInSeenlist() {
        var state = AppState()
        #expect(!(MovieDetailListState.isInSeenlist(movieId: 1, from: state)))

        state.moviesState.seenlist.insert(1)
        #expect(MovieDetailListState.isInSeenlist(movieId: 1, from: state))
    }

    @Test func customListsReturnsAllLists() {
        var state = AppState()
        state.moviesState.customLists[1] = CustomList(id: 1, name: "A", cover: nil, movies: [])
        state.moviesState.customLists[2] = CustomList(id: 2, name: "B", cover: nil, movies: [])

        let lists = MovieDetailListState.customLists(from: state)
        #expect(lists.count == 2)
    }

    // MARK: - MovieDetailPeopleState

    @Test func charactersReturnsContextualPeopleWithCharacterRole() {
        var state = AppState()
        state.peoplesState.peoples[10] = makePeople(id: 10, name: "Actor A")
        state.peoplesState.movieCastOrder[1] = [10]
        state.peoplesState.casts[10] = [1: "Hero"]
        state.peoplesState.movieCreditsLoaded.insert(1)

        let characters = MovieDetailPeopleState.characters(movieId: 1, from: state)

        #expect(characters?.count == 1)
        #expect(characters?.first?.name == "Actor A")
        #expect(characters?.first?.character == "Hero")
        #expect(characters?.first?.department == nil)
    }

    @Test func creditsReturnsContextualPeopleWithDepartmentRole() {
        var state = AppState()
        state.peoplesState.peoples[20] = makePeople(id: 20, name: "Director B")
        state.peoplesState.movieCrewOrder[1] = [20]
        state.peoplesState.crews[20] = [1: "Directing"]
        state.peoplesState.movieCreditsLoaded.insert(1)

        let credits = MovieDetailPeopleState.credits(movieId: 1, from: state)

        #expect(credits?.count == 1)
        #expect(credits?.first?.name == "Director B")
        #expect(credits?.first?.department == "Directing")
        #expect(credits?.first?.character == nil)
    }

    @Test func hasLoadedCreditsRequiresResolvedPeople() {
        var state = AppState()

        #expect(!(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state)))

        state.peoplesState.movieCreditsLoaded.insert(1)
        state.peoplesState.movieCastOrder[1] = [10]
        state.peoplesState.movieCrewOrder[1] = [20]

        #expect(!(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state)))

        state.peoplesState.peoples[10] = makePeople(id: 10, name: "Actor")
        state.peoplesState.casts[10] = [1: "Role"]

        #expect(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state))
    }

    @Test func hasLoadedCreditsReturnsTrueWhenExplicitlyEmptyCredits() {
        var state = AppState()
        state.peoplesState.movieCreditsLoaded.insert(1)
        state.peoplesState.movieCastOrder[1] = []
        state.peoplesState.movieCrewOrder[1] = []

        #expect(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state))
    }

    @Test func charactersReturnsNilWhenNoPeopleResolved() {
        var state = AppState()
        state.peoplesState.movieCastOrder[1] = [10]

        let characters = MovieDetailPeopleState.characters(movieId: 1, from: state)
        #expect(characters == nil)
    }

    @Test func charactersSkipsPeopleWithEmptyRole() {
        var state = AppState()
        state.peoplesState.peoples[10] = makePeople(id: 10, name: "Actor")
        state.peoplesState.movieCastOrder[1] = [10]
        state.peoplesState.casts[10] = [1: "   "]

        let characters = MovieDetailPeopleState.characters(movieId: 1, from: state)
        #expect(characters == nil)
    }

    // MARK: - MovieDetail navigation presentation identity

    // These structs gate the See-all sheets. Their Equatable/Hashable must
    // only consider `id` so that repeat taps on the same button produce a
    // value SwiftUI treats as stable — otherwise the sheet re-mounts (or,
    // historically, triggers a body-invalidation loop on macOS 26).

    @Test func peopleListPresentationEqualsByIdOnly() {
        let a = MovieDetail.PeopleListPresentation(id: "same", title: "Cast", peopleIds: [1, 2, 3])
        let b = MovieDetail.PeopleListPresentation(id: "same", title: "Crew", peopleIds: [7, 8])
        let c = MovieDetail.PeopleListPresentation(id: "other", title: "Cast", peopleIds: [1, 2, 3])

        #expect(a == b, "Structs with the same id should be considered equal regardless of other fields")
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    @Test func crosslineMoviesPresentationEqualsByIdOnly() {
        let a = MovieDetail.CrosslineMoviesPresentation(id: "same", title: "Similar", movieIds: [1, 2])
        let b = MovieDetail.CrosslineMoviesPresentation(id: "same", title: "Recommended", movieIds: [5, 6, 7])
        let c = MovieDetail.CrosslineMoviesPresentation(id: "other", title: "Similar", movieIds: [1, 2])

        #expect(a == b, "Structs with the same id should be considered equal regardless of other fields")
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    // MARK: - MovieDetailFocusNavigation

    private static let focusSampleGroups: [[MovieDetailFocusTarget]] = [
        [.genre(1), .genre(2), .genre(3)],
        [.wishlistButton, .seenlistButton, .customListButton],
        [.reviewLink],
        [.topPerson(100)],
        [.readMoreButton],
        [.keyword(10), .keyword(11), .keyword(12)],
        [.castPerson(500), .castPerson(501), .castSeeAll],
        [.crewPerson(600), .crewPerson(601), .crewSeeAll],
        [.similarMovie(900), .similarMovie(901), .similarSeeAll],
        [.recommendedMovie(950), .recommendedMovie(951), .recommendedSeeAll],
        [.poster("/a.jpg"), .poster("/b.jpg"), .poster("/c.jpg")],
        [.backdrop("/bd1.jpg"), .backdrop("/bd2.jpg")],
    ]

    @Test func tabFromNilGoesToFirstGroupFirstItem() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: nil,
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .genre(1))
    }

    @Test func shiftTabFromNilGoesToLastGroupFirstItem() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: nil,
            in: Self.focusSampleGroups,
            forward: false)
        #expect(target == .backdrop("/bd1.jpg"))
    }

    @Test func tabFromCrewGoesToSimilarMovies() {
        // Regression: Tab on a crew person should jump OUT of the crew
        // row to the first similar movie, not walk through crew items.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .crewPerson(600),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .similarMovie(900))
    }

    @Test func tabFromSimilarGoesToRecommended() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .similarMovie(900),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .recommendedMovie(950))
    }

    @Test func tabFromRecommendedGoesToFirstPoster() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .recommendedMovie(950),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .poster("/a.jpg"))
    }

    @Test func tabFromPostersGoesToFirstBackdrop() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .poster("/b.jpg"),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .backdrop("/bd1.jpg"))
    }

    @Test func tabFromLastBackdropReturnsNil() {
        // Backdrops are the last group; Tab should consume with no move.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .backdrop("/bd2.jpg"),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == nil)
    }

    @Test func arrowWithinPostersMovesBetweenPosters() {
        let forward = MovieDetailFocusNavigation.adjacentInGroup(
            from: .poster("/a.jpg"),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(forward == .poster("/b.jpg"))

        let backward = MovieDetailFocusNavigation.adjacentInGroup(
            from: .poster("/b.jpg"),
            in: Self.focusSampleGroups,
            forward: false)
        #expect(backward == .poster("/a.jpg"))
    }

    @Test func tabLandsOnFirstItemOfNextGroupRegardlessOfPositionWithin() {
        // From the middle of the genres group → first action button.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .genre(2),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .wishlistButton)
    }

    @Test func tabFromLastItemOfGroupJumpsOverRemainingItemsInNextGroup() {
        // On the last cast item (castSeeAll) → first crew item.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .castSeeAll,
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .crewPerson(600))
    }

    @Test func tabFromRecommendedSeeAllJumpsToPosters() {
        // Recommended is no longer the last group — posters follow it.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .recommendedSeeAll,
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .poster("/a.jpg"))
    }

    @Test func shiftTabFromFirstGroupReturnsNil() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .genre(1),
            in: Self.focusSampleGroups,
            forward: false)
        #expect(target == nil)
    }

    @Test func arrowWithinGenresMovesToNextGenre() {
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .genre(2),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == .genre(3))
    }

    @Test func arrowAtLastGenreReturnsNilInsteadOfLeakingIntoActions() {
        // Tab should jump out of the genres group, but a right arrow
        // should stay put once we're on the last genre.
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .genre(3),
            in: Self.focusSampleGroups,
            forward: true)
        #expect(target == nil)
    }

    @Test func arrowOnSingleItemGroupReturnsNil() {
        #expect(MovieDetailFocusNavigation.adjacentInGroup(
            from: .readMoreButton,
            in: Self.focusSampleGroups,
            forward: true) == nil)
        #expect(MovieDetailFocusNavigation.adjacentInGroup(
            from: .readMoreButton,
            in: Self.focusSampleGroups,
            forward: false) == nil)
    }

    @Test func arrowBackwardsInKeywordsMovesToPreviousKeyword() {
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .keyword(11),
            in: Self.focusSampleGroups,
            forward: false)
        #expect(target == .keyword(10))
    }

    @Test func arrowFromCastSeeAllBacksIntoLastCastPerson() {
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .castSeeAll,
            in: Self.focusSampleGroups,
            forward: false)
        #expect(target == .castPerson(501))
    }

    // MARK: - MovieDetailFocusRow scroll anchors

    @Test func rowScrollIdMapsEveryTargetCaseToItsSection() {
        let assertions: [(MovieDetailFocusTarget, String)] = [
            (.genre(1), "row.cover"),
            (.wishlistButton, "row.buttons"),
            (.seenlistButton, "row.buttons"),
            (.customListButton, "row.buttons"),
            (.reviewLink, "row.review"),
            (.topPerson(10), "row.director"),
            (.readMoreButton, "row.overview"),
            (.keyword(42), "row.keywords"),
            (.castPerson(100), "row.cast"),
            (.castSeeAll, "row.cast"),
            (.crewPerson(200), "row.crew"),
            (.crewSeeAll, "row.crew"),
            (.similarMovie(300), "row.similar"),
            (.similarSeeAll, "row.similar"),
            (.recommendedMovie(400), "row.recommended"),
            (.recommendedSeeAll, "row.recommended"),
            (.poster("/a.jpg"), "row.posters"),
            (.backdrop("/b.jpg"), "row.backdrops"),
        ]

        for (target, expected) in assertions {
            #expect(MovieDetailFocusRow.scrollId(for: target) == expected,
                    "Unexpected scroll id for \(target)")
        }
    }

    #if !os(tvOS)
    // MARK: - MovieDetailFocusModel (detail-view focus-target assembly)

    /// With no movie or relations, the focus sequence is just the always-present
    /// action group, and focus defaults to its first button.
    @Test func focusModelWithNoRelationsHasOnlyTheActionGroup() {
        let model = MovieDetailFocusModel(movie: nil, characters: nil, credits: nil,
                                          similar: nil, recommended: nil, videos: nil,
                                          reviewsCount: nil, topPersonId: nil)
        #expect(model.focusGroups == [[.wishlistButton, .seenlistButton, .customListButton]])
        #expect(model.availableTopTargets == [.wishlistButton, .seenlistButton, .customListButton])
        #expect(model.preferredFocusTarget == .wishlistButton)
    }

    /// The single-item groups appear in the right Tab order (genres → actions →
    /// review → top person → read-more), and a present genre is preferred for
    /// initial focus. (`makeMovie` hardcodes a non-empty overview, so
    /// `readMoreButton` is part of the expected sequence here.)
    @Test func focusModelOrdersScalarGroupsAndPrefersFirstGenre() {
        let movie = makeMovie(id: 1, genres: [Genre(id: 35, name: "Comedy")])
        let model = MovieDetailFocusModel(movie: movie, characters: nil, credits: nil,
                                          similar: nil, recommended: nil, videos: nil,
                                          reviewsCount: 3, topPersonId: 9)
        #expect(model.focusGroups == [
            [.genre(35)],
            [.wishlistButton, .seenlistButton, .customListButton],
            [.reviewLink],
            [.topPerson(9)],
            [.readMoreButton],
        ])
        #expect(model.preferredFocusTarget == .genre(35))
    }

    /// Cast and crew groups append a trailing "see all" target, and with no
    /// genres focus defaults to the first action button.
    @Test func focusModelAppendsSeeAllToCastAndCrewGroups() {
        let model = MovieDetailFocusModel(movie: nil,
                                          characters: [makePeople(id: 0)],
                                          credits: [makePeople(id: 1)],
                                          similar: nil, recommended: nil, videos: nil,
                                          reviewsCount: nil, topPersonId: nil)
        #expect(model.castTargets == [.castPerson(0), .castSeeAll])
        #expect(model.crewTargets == [.crewPerson(1), .crewSeeAll])
        #expect(model.preferredFocusTarget == .wishlistButton)
    }

    /// A movie with a blank overview omits the read-more target entirely.
    @Test func focusModelOmitsReadMoreButtonWhenOverviewIsEmpty() {
        let movie = makeMovie(id: 1, overview: "")
        let model = MovieDetailFocusModel(movie: movie, characters: nil, credits: nil,
                                          similar: nil, recommended: nil, videos: nil,
                                          reviewsCount: nil, topPersonId: nil)
        #expect(model.readMoreTarget == nil)
        #expect(!model.availableTopTargets.contains(.readMoreButton))
    }

    /// Poster and backdrop image rows map to per-image focus targets keyed by
    /// file path.
    @Test func focusModelIncludesPosterAndBackdropTargets() {
        let images = Movie.MovieImages(
            posters: [ImageData(aspect_ratio: 0.7, file_path: "/p.jpg", height: 1000, width: 700)],
            backdrops: [ImageData(aspect_ratio: 1.7, file_path: "/b.jpg", height: 1200, width: 1800)]
        )
        let model = MovieDetailFocusModel(movie: makeMovie(id: 1, images: images),
                                          characters: nil, credits: nil,
                                          similar: nil, recommended: nil, videos: nil,
                                          reviewsCount: nil, topPersonId: nil)
        #expect(model.posterTargets == [.poster("/p.jpg")])
        #expect(model.backdropTargets == [.backdrop("/b.jpg")])
    }
    #endif
}

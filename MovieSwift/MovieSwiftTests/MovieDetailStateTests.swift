import XCTest
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class MovieDetailStateTests: XCTestCase {

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

    func testMovieReturnsNilWhenMovieIsMissing() {
        XCTAssertNil(MovieDetailState.movie(movieId: 404, from: AppState()))
    }

    func testMovieReturnsMovieWhenPresent() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)

        XCTAssertEqual(MovieDetailState.movie(movieId: 1, from: state)?.id, 1)
    }

    func testHasLoadedDetailRequiresKeywordsAndImages() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(id: 1)
        state.moviesState.detailed.insert(1)

        XCTAssertFalse(MovieDetailState.hasLoadedDetail(movieId: 1, from: state))

        state.moviesState.movies[1] = makeMovie(
            id: 1,
            keywords: Movie.Keywords(keywords: [Keyword(id: 1, name: "test")]),
            images: Movie.MovieImages(posters: [], backdrops: [])
        )

        XCTAssertTrue(MovieDetailState.hasLoadedDetail(movieId: 1, from: state))
    }

    func testHasLoadedDetailReturnsFalseWhenNotInDetailedSet() {
        var state = AppState()
        state.moviesState.movies[1] = makeMovie(
            id: 1,
            keywords: Movie.Keywords(keywords: []),
            images: Movie.MovieImages(posters: [], backdrops: [])
        )

        XCTAssertFalse(MovieDetailState.hasLoadedDetail(movieId: 1, from: state))
    }

    func testHasLoadedRecommendedRequiresBothSetAndEntry() {
        var state = AppState()

        XCTAssertFalse(MovieDetailState.hasLoadedRecommended(movieId: 1, from: state))

        state.moviesState.recommendedLoaded.insert(1)
        XCTAssertFalse(MovieDetailState.hasLoadedRecommended(movieId: 1, from: state))

        state.moviesState.recommended[1] = [10]
        XCTAssertTrue(MovieDetailState.hasLoadedRecommended(movieId: 1, from: state))
    }

    func testHasLoadedSimilarRequiresBothSetAndEntry() {
        var state = AppState()

        XCTAssertFalse(MovieDetailState.hasLoadedSimilar(movieId: 1, from: state))

        state.moviesState.similarLoaded.insert(1)
        state.moviesState.similar[1] = []
        XCTAssertTrue(MovieDetailState.hasLoadedSimilar(movieId: 1, from: state))
    }

    func testHasLoadedReviewsRequiresBothSetAndEntry() {
        var state = AppState()

        XCTAssertFalse(MovieDetailState.hasLoadedReviews(movieId: 1, from: state))

        state.moviesState.reviewsLoaded.insert(1)
        state.moviesState.reviews[1] = []
        XCTAssertTrue(MovieDetailState.hasLoadedReviews(movieId: 1, from: state))
    }

    func testHasLoadedVideosRequiresBothSetAndEntry() {
        var state = AppState()

        XCTAssertFalse(MovieDetailState.hasLoadedVideos(movieId: 1, from: state))

        state.moviesState.videosLoaded.insert(1)
        state.moviesState.videos[1] = []
        XCTAssertTrue(MovieDetailState.hasLoadedVideos(movieId: 1, from: state))
    }

    // MARK: - MovieDetailListState

    func testIsInWishlist() {
        var state = AppState()
        XCTAssertFalse(MovieDetailListState.isInWishlist(movieId: 1, from: state))

        state.moviesState.wishlist.insert(1)
        XCTAssertTrue(MovieDetailListState.isInWishlist(movieId: 1, from: state))
    }

    func testIsInSeenlist() {
        var state = AppState()
        XCTAssertFalse(MovieDetailListState.isInSeenlist(movieId: 1, from: state))

        state.moviesState.seenlist.insert(1)
        XCTAssertTrue(MovieDetailListState.isInSeenlist(movieId: 1, from: state))
    }

    func testCustomListsReturnsAllLists() {
        var state = AppState()
        state.moviesState.customLists[1] = CustomList(id: 1, name: "A", cover: nil, movies: [])
        state.moviesState.customLists[2] = CustomList(id: 2, name: "B", cover: nil, movies: [])

        let lists = MovieDetailListState.customLists(from: state)
        XCTAssertEqual(lists.count, 2)
    }

    // MARK: - MovieDetailPeopleState

    func testCharactersReturnsContextualPeopleWithCharacterRole() {
        var state = AppState()
        state.peoplesState.peoples[10] = makePeople(id: 10, name: "Actor A")
        state.peoplesState.movieCastOrder[1] = [10]
        state.peoplesState.casts[10] = [1: "Hero"]
        state.peoplesState.movieCreditsLoaded.insert(1)

        let characters = MovieDetailPeopleState.characters(movieId: 1, from: state)

        XCTAssertEqual(characters?.count, 1)
        XCTAssertEqual(characters?.first?.name, "Actor A")
        XCTAssertEqual(characters?.first?.character, "Hero")
        XCTAssertNil(characters?.first?.department)
    }

    func testCreditsReturnsContextualPeopleWithDepartmentRole() {
        var state = AppState()
        state.peoplesState.peoples[20] = makePeople(id: 20, name: "Director B")
        state.peoplesState.movieCrewOrder[1] = [20]
        state.peoplesState.crews[20] = [1: "Directing"]
        state.peoplesState.movieCreditsLoaded.insert(1)

        let credits = MovieDetailPeopleState.credits(movieId: 1, from: state)

        XCTAssertEqual(credits?.count, 1)
        XCTAssertEqual(credits?.first?.name, "Director B")
        XCTAssertEqual(credits?.first?.department, "Directing")
        XCTAssertNil(credits?.first?.character)
    }

    func testHasLoadedCreditsRequiresResolvedPeople() {
        var state = AppState()

        XCTAssertFalse(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state))

        state.peoplesState.movieCreditsLoaded.insert(1)
        state.peoplesState.movieCastOrder[1] = [10]
        state.peoplesState.movieCrewOrder[1] = [20]

        XCTAssertFalse(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state))

        state.peoplesState.peoples[10] = makePeople(id: 10, name: "Actor")
        state.peoplesState.casts[10] = [1: "Role"]

        XCTAssertTrue(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state))
    }

    func testHasLoadedCreditsReturnsTrueWhenExplicitlyEmptyCredits() {
        var state = AppState()
        state.peoplesState.movieCreditsLoaded.insert(1)
        state.peoplesState.movieCastOrder[1] = []
        state.peoplesState.movieCrewOrder[1] = []

        XCTAssertTrue(MovieDetailPeopleState.hasLoadedMovieCredits(movieId: 1, from: state))
    }

    func testCharactersReturnsNilWhenNoPeopleResolved() {
        var state = AppState()
        state.peoplesState.movieCastOrder[1] = [10]

        let characters = MovieDetailPeopleState.characters(movieId: 1, from: state)
        XCTAssertNil(characters)
    }

    func testCharactersSkipsPeopleWithEmptyRole() {
        var state = AppState()
        state.peoplesState.peoples[10] = makePeople(id: 10, name: "Actor")
        state.peoplesState.movieCastOrder[1] = [10]
        state.peoplesState.casts[10] = [1: "   "]

        let characters = MovieDetailPeopleState.characters(movieId: 1, from: state)
        XCTAssertNil(characters)
    }

    // MARK: - MovieDetail navigation presentation identity

    // These structs gate the See-all sheets. Their Equatable/Hashable must
    // only consider `id` so that repeat taps on the same button produce a
    // value SwiftUI treats as stable — otherwise the sheet re-mounts (or,
    // historically, triggers a body-invalidation loop on macOS 26).

    func testPeopleListPresentationEqualsByIdOnly() {
        let a = MovieDetail.PeopleListPresentation(id: "same", title: "Cast", peopleIds: [1, 2, 3])
        let b = MovieDetail.PeopleListPresentation(id: "same", title: "Crew", peopleIds: [7, 8])
        let c = MovieDetail.PeopleListPresentation(id: "other", title: "Cast", peopleIds: [1, 2, 3])

        XCTAssertEqual(a, b, "Structs with the same id should be considered equal regardless of other fields")
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testCrosslineMoviesPresentationEqualsByIdOnly() {
        let a = MovieDetail.CrosslineMoviesPresentation(id: "same", title: "Similar", movieIds: [1, 2])
        let b = MovieDetail.CrosslineMoviesPresentation(id: "same", title: "Recommended", movieIds: [5, 6, 7])
        let c = MovieDetail.CrosslineMoviesPresentation(id: "other", title: "Similar", movieIds: [1, 2])

        XCTAssertEqual(a, b, "Structs with the same id should be considered equal regardless of other fields")
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a.hashValue, b.hashValue)
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
        [.crewPerson(600), .crewPerson(601), .crewSeeAll]
    ]

    func testTabFromNilGoesToFirstGroupFirstItem() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: nil,
            in: Self.focusSampleGroups,
            forward: true)
        XCTAssertEqual(target, .genre(1))
    }

    func testShiftTabFromNilGoesToLastGroupFirstItem() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: nil,
            in: Self.focusSampleGroups,
            forward: false)
        XCTAssertEqual(target, .crewPerson(600))
    }

    func testTabLandsOnFirstItemOfNextGroupRegardlessOfPositionWithin() {
        // From the middle of the genres group → first action button.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .genre(2),
            in: Self.focusSampleGroups,
            forward: true)
        XCTAssertEqual(target, .wishlistButton)
    }

    func testTabFromLastItemOfGroupJumpsOverRemainingItemsInNextGroup() {
        // On the last cast item (castSeeAll) → first crew item.
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .castSeeAll,
            in: Self.focusSampleGroups,
            forward: true)
        XCTAssertEqual(target, .crewPerson(600))
    }

    func testTabFromLastGroupReturnsNil() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .crewSeeAll,
            in: Self.focusSampleGroups,
            forward: true)
        XCTAssertNil(target)
    }

    func testShiftTabFromFirstGroupReturnsNil() {
        let target = MovieDetailFocusNavigation.nextGroupStart(
            from: .genre(1),
            in: Self.focusSampleGroups,
            forward: false)
        XCTAssertNil(target)
    }

    func testArrowWithinGenresMovesToNextGenre() {
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .genre(2),
            in: Self.focusSampleGroups,
            forward: true)
        XCTAssertEqual(target, .genre(3))
    }

    func testArrowAtLastGenreReturnsNilInsteadOfLeakingIntoActions() {
        // Tab should jump out of the genres group, but a right arrow
        // should stay put once we're on the last genre.
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .genre(3),
            in: Self.focusSampleGroups,
            forward: true)
        XCTAssertNil(target)
    }

    func testArrowOnSingleItemGroupReturnsNil() {
        XCTAssertNil(MovieDetailFocusNavigation.adjacentInGroup(
            from: .readMoreButton,
            in: Self.focusSampleGroups,
            forward: true))
        XCTAssertNil(MovieDetailFocusNavigation.adjacentInGroup(
            from: .readMoreButton,
            in: Self.focusSampleGroups,
            forward: false))
    }

    func testArrowBackwardsInKeywordsMovesToPreviousKeyword() {
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .keyword(11),
            in: Self.focusSampleGroups,
            forward: false)
        XCTAssertEqual(target, .keyword(10))
    }

    func testArrowFromCastSeeAllBacksIntoLastCastPerson() {
        let target = MovieDetailFocusNavigation.adjacentInGroup(
            from: .castSeeAll,
            in: Self.focusSampleGroups,
            forward: false)
        XCTAssertEqual(target, .castPerson(501))
    }
}

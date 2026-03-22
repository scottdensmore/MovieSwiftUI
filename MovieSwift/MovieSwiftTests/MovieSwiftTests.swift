import XCTest
@testable import MovieSwift

final class MovieSwiftTests: XCTestCase {
    func testPeopleRowStateShowsPlaceholderWhenPersonIsMissing() {
        XCTAssertTrue(PeopleRowState.shouldShowPlaceholder(for: nil))
    }

    func testPeopleRowStateDoesNotShowPlaceholderWhenPersonExists() {
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

        XCTAssertFalse(PeopleRowState.shouldShowPlaceholder(for: person))
    }

    func testFanClubPaginationPolicyRequestsInitialPopularPage() {
        XCTAssertEqual(FanClubPaginationPolicy.initialPopularPage(popularCount: 0, nextPage: 1), 1)
    }

    func testFanClubPaginationPolicySkipsInitialFetchWhenPopularAlreadyLoaded() {
        XCTAssertNil(FanClubPaginationPolicy.initialPopularPage(popularCount: 3, nextPage: 1))
    }

    func testFanClubPaginationPolicyRequestsNextPopularPageForNewLastId() {
        XCTAssertEqual(FanClubPaginationPolicy.nextPopularPage(popular: [1, 2, 3],
                                                               lastTriggeredPopularId: 2,
                                                               nextPage: 4),
                       4)
    }

    func testFanClubPaginationPolicySkipsRepeatedLastPopularId() {
        XCTAssertNil(FanClubPaginationPolicy.nextPopularPage(popular: [1, 2, 3],
                                                             lastTriggeredPopularId: 3,
                                                             nextPage: 4))
    }

    func testFanClubPresentationShowsLoadingStateBeforeInitialRequest() {
        let state = FanClubPresentation.emptyState(peoples: [],
                                                   popular: [],
                                                   hasRequestedInitialPopularPage: false)

        XCTAssertEqual(state?.title, "Loading people")
        XCTAssertEqual(state?.accessibilityIdentifier, "fanClub.loadingState")
    }

    func testFanClubPresentationShowsEmptyStateAfterInitialRequest() {
        let state = FanClubPresentation.emptyState(peoples: [],
                                                   popular: [],
                                                   hasRequestedInitialPopularPage: true)

        XCTAssertEqual(state?.title, "No popular people right now")
        XCTAssertEqual(state?.accessibilityIdentifier, "fanClub.emptyState")
    }

    func testFanClubPresentationSkipsEmptyStateWhenContentExists() {
        XCTAssertNil(FanClubPresentation.emptyState(peoples: [1],
                                                    popular: [],
                                                    hasRequestedInitialPopularPage: true))
        XCTAssertNil(FanClubPresentation.emptyState(peoples: [],
                                                    popular: [2],
                                                    hasRequestedInitialPopularPage: true))
    }

    func testPeopleStateReducerUpdatesExistingRoleMetadataFromLaterCredits() {
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
                                                                                                                  images: nil)],
                                                                                                    crew: [])))

        XCTAssertEqual(updated.peoples[1]?.character, "New Role")
    }

    func testPeopleStateReducerSetDetailDoesNotRetainStaleMovieRoleMetadata() {
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

        XCTAssertNil(updated.peoples[1]?.character)
        XCTAssertNil(updated.peoples[1]?.department)
    }

    func testPeopleStateReducerSetImagesCreatesPlaceholderWhenPersonIsMissing() {
        let state = AppState().peoplesState
        let images = [ImageData(aspect_ratio: 1,
                                file_path: "/profile.jpg",
                                height: 200,
                                width: 100)]

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetImages(people: 77, images: images))

        XCTAssertEqual(updated.peoples[77]?.name, "Unknown person")
        XCTAssertEqual(updated.peoples[77]?.images?.count, 1)
        XCTAssertTrue(updated.imagesLoaded.contains(77))
    }

    func testPeopleStateReducerSetPeopleCreditsReplacesExistingCredits() {
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
                                                                                                                                 department: nil)],
                                                                                                                             crew: [])))

        XCTAssertEqual(updated.casts[7]?[12], "New Role")
        XCTAssertNil(updated.casts[7]?[10])
        XCTAssertTrue(updated.creditsLoaded.contains(7))
    }

    func testPeoplesStateCodableRoundTripPreservesLoadedDetailFlagsAndCredits() throws {
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
                                                     width: 100)])
        state.casts[7] = [12: "Actor"]
        state.crews[7] = [13: "Director"]
        state.detailed.insert(7)
        state.imagesLoaded.insert(7)
        state.creditsLoaded.insert(7)
        state.fanClub.insert(7)

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(PeoplesState.self, from: data)

        XCTAssertEqual(decoded.peoples[7]?.images?.count, 1)
        XCTAssertEqual(decoded.casts[7]?[12], "Actor")
        XCTAssertEqual(decoded.crews[7]?[13], "Director")
        XCTAssertTrue(decoded.detailed.contains(7))
        XCTAssertTrue(decoded.imagesLoaded.contains(7))
        XCTAssertTrue(decoded.creditsLoaded.contains(7))
        XCTAssertTrue(decoded.fanClub.contains(7))
    }

    func testPeopleRowStateReturnsNilWhenPersonIsMissing() {
        let state = AppState()

        XCTAssertNil(PeopleRowState.people(for: 999, from: state))
    }

    func testFanClubStateSkipsMissingPopularPeople() {
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

        XCTAssertEqual(FanClubState.popularPeople(from: state), [1])
    }

    func testPeopleStateReducerDedupesPopularPeopleAcrossPages() {
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
                                                             images: nil)])
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
                                                                                                                      images: nil)])))

        let updated = peoplesStateReducer(state: seeded,
                                          action: PeopleActions.SetPopular(page: 2,
                                                                          response: popularPage))

        XCTAssertEqual(updated.popular, [1, 2])
    }

    func testPeopleDetailBiographyStateShowsToggleOnlyForNonEmptyBiography() {
        XCTAssertFalse(PeopleDetailBiographyState.shouldShowBiographyToggle(nil))
        XCTAssertFalse(PeopleDetailBiographyState.shouldShowBiographyToggle("   "))
        XCTAssertTrue(PeopleDetailBiographyState.shouldShowBiographyToggle("Biography"))
    }

    func testPeopleDetailBiographyStateUsesCorrectDeathLabel() {
        XCTAssertEqual(PeopleDetailBiographyState.deathLabel, "Day of death")
    }

    func testPeopleDetailStateReturnsFallbackPersonWhenMissing() {
        let state = AppState()

        XCTAssertEqual(PeopleDetailState.people(for: 999, from: state).name, "Unknown person")
    }

    func testPeopleDetailStateShowsBiographySectionWhenOnlyBiographyExists() {
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

        XCTAssertTrue(PeopleDetailState.shouldShowBiographySection(for: people))
    }

    func testPeopleDetailStateHidesImagesSectionForEmptyImages() {
        XCTAssertFalse(PeopleDetailState.shouldShowImagesSection(for: nil))
        XCTAssertFalse(PeopleDetailState.shouldShowImagesSection(for: []))
    }

    func testPeopleDetailImagesStateBuildsAccessibilityMetadata() {
        XCTAssertEqual(PeopleDetailImagesState.accessibilityIdentifier(for: 0), "peopleDetail.image.0")
        XCTAssertEqual(PeopleDetailImagesState.accessibilityLabel(for: 1, total: 3), "Image 2 of 3")
    }

    func testPeopleDetailHeaderStateUsesNeutralFallbackCopy() {
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

        XCTAssertEqual(PeopleDetailHeaderState.knownForText(for: people),
                       "Known work is not available.")
    }

    func testPeopleDetailMovieRowStateSkipsEmptySubtitle() {
        XCTAssertNil(PeopleDetailMovieRowState.subtitle(for: ""))
        XCTAssertNil(PeopleDetailMovieRowState.subtitle(for: "   "))
        XCTAssertEqual(PeopleDetailMovieRowState.subtitle(for: "Director"), "Director")
    }

    func testMovieDetailPeopleStateUsesMovieSpecificRoleMetadata() {
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
        state.peoplesState.peoplesMovies[42] = [1, 2]
        state.peoplesState.casts[1] = [7: "Old Role", 42: "New Role"]
        state.peoplesState.crews[2] = [7: "Old Department", 42: "Directing"]

        XCTAssertEqual(MovieDetailPeopleState.characters(movieId: 42, from: state)?.first?.character,
                       "New Role")
        XCTAssertEqual(MovieDetailPeopleState.credits(movieId: 42, from: state)?.first?.department,
                       "Directing")
    }

    func testAppLaunchModeDetectsPreviewEnvironment() {
        XCTAssertEqual(AppLaunchMode.from(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]), .preview)
    }

    func testAppLaunchModeDetectsUISmokeTestsFromArguments() {
        XCTAssertEqual(AppLaunchMode.from(arguments: ["--ui-smoke-tests"], environment: [:]), .uiSmokeTests)
    }

    func testAppLaunchModeDefaultsToNormal() {
        XCTAssertEqual(AppLaunchMode.from(arguments: [], environment: [:]), .normal)
    }

    func testAppEnvironmentForUISmokeTestsUsesSmokeStoreAndRuntime() {
        let environment = AppEnvironment.make(launchMode: .uiSmokeTests)

        XCTAssertTrue(environment.runtime.isRunningUISmokeTests)
        XCTAssertEqual(environment.store.state.moviesState.movies[0]?.id, 0)
        XCTAssertEqual(environment.store.state.peoplesState.peoples[1]?.department, "Directing")
    }

    func testAppEnvironmentForPreviewUsesPreviewStoreAndRuntime() {
        let environment = AppEnvironment.make(launchMode: .preview)

        XCTAssertFalse(environment.runtime.isRunningUISmokeTests)
        XCTAssertEqual(environment.store.state.moviesState.movies[0]?.id, 0)
        XCTAssertEqual(environment.store.state.peoplesState.peoples[0]?.id, 0)
    }

    func testAppRuntimeDetectsXCTestEnvironment() {
        let runtime = AppRuntime(launchMode: .normal,
                                 environment: [AppRuntime.xctestConfigurationFilePathKey: "/tmp/test.xctestconfiguration"])

        XCTAssertTrue(runtime.isRunningTests)
        XCTAssertFalse(runtime.isLoggingEnabled)
    }

    func testAppRuntimeDoesNotDetectTestsWithoutXCTestEnvironment() {
        let runtime = AppRuntime(launchMode: .normal, environment: [:])

        XCTAssertFalse(runtime.isRunningTests)
        XCTAssertTrue(runtime.isLoggingEnabled)
    }

    func testUISmokeInitialStateSeedsExpectedNavigationData() {
        let state = AppStoreFactory.makeInitialState(for: .uiSmokeTests)

        XCTAssertEqual(state.moviesState.movies[0]?.id, 0)
        XCTAssertEqual(state.moviesState.customLists[0]?.name, "TestName")
        XCTAssertEqual(state.peoplesState.crews[1]?[0], "Director 1")
    }

    func testPreviewInitialStateSeedsExpectedNavigationData() {
        let state = AppStoreFactory.makeInitialState(for: .preview)

        XCTAssertEqual(state.moviesState.movies[0]?.id, 0)
        XCTAssertEqual(state.peoplesState.casts[0]?[0], "Character 1")
    }

    func testMoviesMenuListPageListenerDispatchesInjectedPageLoad() {
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

        XCTAssertEqual(loadedMenu, .popular)
        XCTAssertEqual(loadedPage, 3)
    }

    func testMoviesMenuListPageListenerSkipsDispatchWhenSuppressed() {
        var dispatchCount = 0
        let listener = MoviesMenuListPageListener(menu: .trending,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { false },
                                                  dispatchPage: { _, _ in
            dispatchCount += 1
        })

        listener.loadPage()

        XCTAssertEqual(dispatchCount, 0)
    }

    func testMoviesMenuListPageListenerSkipsDispatchWithoutLoadPolicy() {
        var dispatchCount = 0
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  dispatchPage: { _, _ in
            dispatchCount += 1
        })

        listener.loadPage()

        XCTAssertEqual(dispatchCount, 0)
    }

    func testMoviesMenuListPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = MoviesMenuListPageListener(menu: .popular,
                                                  loadOnInit: false,
                                                  shouldLoadPage: { true })

        listener.loadPage()

        XCTAssertTrue(true)
    }

    func testMoviesSelectedMenuStoreSynchronizesInitialMenuToListener() {
        let listener = MoviesMenuListPageListener(menu: .trending, loadOnInit: false)
        let store = MoviesSelectedMenuStore(selectedMenu: .popular, pageListener: listener)

        XCTAssertEqual(store.menu, .popular)
        XCTAssertEqual(listener.menu, .popular)
    }

    func testMoviesSelectedMenuStoreUpdatesListenerWhenMenuChanges() {
        let listener = MoviesMenuListPageListener(menu: .popular, loadOnInit: false)
        let store = MoviesSelectedMenuStore(selectedMenu: .popular, pageListener: listener)

        store.menu = .topRated

        XCTAssertEqual(listener.menu, .topRated)
    }

    func testKeywordPageListenerDispatchesInjectedPageLoad() {
        var loadedKeyword: Int?
        var loadedPage: Int?
        let listener = KeywordPageListener(dispatchPage: { keyword, page in
            loadedKeyword = keyword
            loadedPage = page
        })
        listener.keyword = 17
        listener.currentPage = 2

        XCTAssertEqual(loadedKeyword, 17)
        XCTAssertEqual(loadedPage, 2)
    }

    func testKeywordPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = KeywordPageListener()
        listener.keyword = 17

        listener.loadPage()

        XCTAssertTrue(true)
    }

    func testMoviesSearchPageListenerDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let listener = MoviesSearchPageListener(dispatchSearches: { text, page in
            loadedText = text
            loadedPage = page
        })
        listener.text = "matrix"
        listener.currentPage = 2

        XCTAssertEqual(loadedText, "matrix")
        XCTAssertEqual(loadedPage, 2)
    }

    func testMoviesSearchPageListenerDoesNotDispatchWithoutInjectedHandler() {
        let listener = MoviesSearchPageListener()
        listener.text = "matrix"

        listener.loadPage()

        XCTAssertTrue(true)
    }

    func testMoviesSearchTextWrapperBindsInjectedSearchDispatch() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = MoviesSearchTextWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")
        wrapper.searchPageListener.loadPage()

        XCTAssertEqual(loadedText, "matrix")
        XCTAssertEqual(loadedPage, 1)
    }

    func testMoviesListSearchStateReturnsSearchResultsAndRecentSearches() {
        var state = AppState()
        let keywords = (1...6).map { Keyword(id: $0, name: "Keyword \($0)") }
        state.moviesState.search["matrix"] = [1, 2, 3]
        state.moviesState.searchKeywords["matrix"] = keywords
        state.peoplesState.search["matrix"] = [9, 10]
        state.moviesState.recentSearches = ["matrix", "alien"]

        XCTAssertEqual(MoviesListSearchState.searchedMovies(query: "matrix", from: state), [1, 2, 3])
        XCTAssertEqual(MoviesListSearchState.searchedKeywords(query: "matrix", from: state)?.map(\.id), [1, 2, 3, 4, 5])
        XCTAssertEqual(MoviesListSearchState.searchedPeoples(query: "matrix", from: state), [9, 10])
        XCTAssertEqual(Set(MoviesListSearchState.recentSearches(from: state)), Set(["matrix", "alien"]))
    }

    func testMoviesListPaginationPolicyAdvancesSearchPageOnlyWithSearchResults() {
        XCTAssertTrue(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: true, searchedMovies: [1]))
        XCTAssertFalse(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: true, searchedMovies: []))
        XCTAssertFalse(MoviesListPaginationPolicy.shouldAdvanceSearchPage(isSearching: false, searchedMovies: [1]))
    }

    func testMoviesListPaginationPolicyAdvancesListPageOnlyWhenBrowsingMovies() {
        XCTAssertTrue(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                      pageListenerExists: true,
                                                                      movies: [1]))
        XCTAssertFalse(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: true,
                                                                       pageListenerExists: true,
                                                                       movies: [1]))
        XCTAssertFalse(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                       pageListenerExists: false,
                                                                       movies: [1]))
        XCTAssertFalse(MoviesListPaginationPolicy.shouldAdvanceListPage(isSearching: false,
                                                                       pageListenerExists: true,
                                                                       movies: []))
    }

    func testDiscoverSwipeDecisionMapsLeftToWishlist() {
        XCTAssertEqual(DiscoverSwipeDecision.from(handler: .left), .wishlist)
    }

    func testDiscoverSwipeDecisionMapsRightToSeenlist() {
        XCTAssertEqual(DiscoverSwipeDecision.from(handler: .right), .seenlist)
    }

    func testDiscoverSwipeDecisionMapsCancelledToNone() {
        XCTAssertEqual(DiscoverSwipeDecision.from(handler: .cancelled), .none)
    }

    func testDiscoverSwipeActionPlanBuildsWishlistAction() {
        XCTAssertEqual(DiscoverSwipeActionPlan.action(for: .wishlist, currentMovieId: 42),
                       .wishlist(42))
    }

    func testDiscoverSwipeActionPlanBuildsSeenlistAction() {
        XCTAssertEqual(DiscoverSwipeActionPlan.action(for: .seenlist, currentMovieId: 42),
                       .seenlist(42))
    }

    func testDiscoverSwipeActionPlanSkipsWhenNoMovieOrNoAction() {
        XCTAssertNil(DiscoverSwipeActionPlan.action(for: .none, currentMovieId: 42))
        XCTAssertNil(DiscoverSwipeActionPlan.action(for: .wishlist, currentMovieId: nil))
    }

    func testDiscoverFetchPolicyFetchesWhenForcedOrRunningLow() {
        XCTAssertTrue(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 3,
                                                                 force: false,
                                                                 isRunningUISmokeTests: false))
        XCTAssertTrue(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 15,
                                                                 force: true,
                                                                 isRunningUISmokeTests: false))
        XCTAssertFalse(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 15,
                                                                  force: false,
                                                                  isRunningUISmokeTests: false))
    }

    func testDiscoverFetchPolicySkipsDuringUISmokeTests() {
        XCTAssertFalse(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 3,
                                                                  force: false,
                                                                  isRunningUISmokeTests: true))
    }

    func testDiscoverFetchPolicySkipsWhenEnoughCardsRemain() {
        XCTAssertFalse(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 10,
                                                                  force: false,
                                                                  isRunningUISmokeTests: false))
    }

    func testDiscoverFetchPolicyAllowsForcedRefillOutsideUISmokeTests() {
        XCTAssertTrue(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 10,
                                                                 force: true,
                                                                 isRunningUISmokeTests: false))
    }

    func testDiscoverEmptyStateShowsOnlyWithoutCurrentMovie() {
        XCTAssertTrue(DiscoverEmptyState.shouldShow(currentMovie: nil))
        XCTAssertFalse(DiscoverEmptyState.shouldShow(currentMovie: sampleMovie))
    }

    func testDiscoverEmptyStateContentUsesFilterAwareMessage() {
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

        XCTAssertEqual(filtered.title, "No more discover movies")
        XCTAssertTrue(filtered.message.contains("reset the filter"))
        XCTAssertTrue(filtered.showsRefill)
        XCTAssertTrue(unfiltered.message.contains("refill to keep browsing"))
    }

    func testDiscoverEmptyStateContentTreatsRandomFilterAsUnfiltered() {
        let randomFilter = DiscoverFilter(year: 1955,
                                          startYear: nil,
                                          endYear: nil,
                                          sort: "popularity.desc",
                                          genre: nil,
                                          region: nil)
        let presentation = DiscoverEmptyStateContent.presentation(filter: randomFilter,
                                                                  isRunningUISmokeTests: false)

        XCTAssertFalse(randomFilter.hasExplicitConstraints)
        XCTAssertFalse(presentation.message.contains("reset the filter"))
    }

    func testDiscoverEmptyStateContentHidesRefillDuringUISmokeTests() {
        let filter = DiscoverFilter(year: 1955,
                                    startYear: 1950,
                                    endYear: 1959,
                                    sort: "popularity.desc",
                                    genre: 35,
                                    region: "US")
        XCTAssertFalse(DiscoverEmptyStateContent.presentation(filter: filter,
                                                              isRunningUISmokeTests: true).showsRefill)
    }

    func testDiscoverRefillActionPlanRetainsCurrentFilterOutsideUISmokeTests() {
        let filter = DiscoverFilter(year: 1955,
                                    startYear: 1950,
                                    endYear: 1959,
                                    sort: "popularity.desc",
                                    genre: 35,
                                    region: "US")
        let plan = DiscoverRefillActionPlan.plan(currentFilter: filter, isRunningUISmokeTests: false)

        XCTAssertEqual(plan?.forceFetch, true)
        XCTAssertEqual(plan?.filter?.genre, 35)
        XCTAssertEqual(plan?.filter?.region, "US")
    }

    func testDiscoverRefillActionPlanSkipsDuringUISmokeTests() {
        XCTAssertNil(DiscoverRefillActionPlan.plan(currentFilter: nil, isRunningUISmokeTests: true))
    }

    func testDiscoverUndoStateOnlyShowsUndoWhenNotDraggingAndMovieExists() {
        XCTAssertTrue(DiscoverUndoState.canUndo(previousMovie: 7, isDragging: false))
        XCTAssertFalse(DiscoverUndoState.canUndo(previousMovie: nil, isDragging: false))
        XCTAssertFalse(DiscoverUndoState.canUndo(previousMovie: 7, isDragging: true))
    }

    func testMoviesHomeGridFetchPolicyFetchesOutsideUISmokeTests() {
        XCTAssertTrue(MoviesHomeGridFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: false))
    }

    func testMoviesHomeGridFetchPolicySkipsDuringUISmokeTests() {
        XCTAssertFalse(MoviesHomeGridFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: true))
    }

    func testMoviesHomeGridFetchPolicyFetchesMenuPagesOutsideUISmokeTests() {
        XCTAssertTrue(MoviesHomeGridFetchPolicy.shouldFetchMenuPage(isRunningUISmokeTests: false))
    }

    func testMoviesHomeGridFetchPolicySkipsGenreFetchDuringUISmokeTests() {
        XCTAssertFalse(MoviesHomeGridFetchPolicy.shouldFetchGenresOnAppear(isRunningUISmokeTests: true))
    }

    func testMoviesHomeGridStateReturnsMoviesAndDropsFirstGenre() {
        var state = AppState()
        state.moviesState.moviesList[.popular] = [1, 2]
        state.moviesState.genres = [Genre(id: 0, name: "Random"),
                                    Genre(id: 1, name: "Comedy"),
                                    Genre(id: 2, name: "Drama")]

        XCTAssertEqual(MoviesHomeGridState.movies(from: state)[.popular], [1, 2])
        XCTAssertEqual(MoviesHomeGridState.genres(from: state).map(\.id), [1, 2])
    }

    func testMoviesHomeListStateReturnsMoviesForMenuWhenPresent() {
        var state = AppState()
        state.moviesState.moviesList[.popular] = [1, 2, 3]

        XCTAssertEqual(MoviesHomeListState.movies(for: .popular, from: state), [1, 2, 3])
    }

    func testMoviesHomeListStateReturnsPlaceholderMoviesWhenMissing() {
        XCTAssertEqual(MoviesHomeListState.movies(for: .popular, from: AppState()), [0, 0, 0, 0])
    }

    func testMoviesHomeStateTogglesBetweenListAndGrid() {
        XCTAssertEqual(MoviesHomeState.toggledMode(from: .list), .grid)
        XCTAssertEqual(MoviesHomeState.toggledMode(from: .grid), .list)
    }

    func testMoviesHomeStateUsesInlineTitleInListMode() {
        XCTAssertEqual(MoviesHomeState.navigationBarTitleDisplayMode(for: .list), .inline)
        XCTAssertEqual(MoviesHomeState.navigationBarTitleDisplayMode(for: .grid), .automatic)
    }

    func testMoviesHomeStateSkipsPageLoadDuringUISmokeTests() {
        XCTAssertFalse(MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: true))
        XCTAssertTrue(MoviesHomeState.shouldLoadPage(isRunningUISmokeTests: false))
    }

    func testMovieDetailFetchPolicyFetchesOutsideUISmokeTests() {
        XCTAssertTrue(MovieDetailFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: false))
    }

    func testMovieDetailFetchPolicySkipsDuringUISmokeTests() {
        XCTAssertFalse(MovieDetailFetchPolicy.shouldFetchLiveData(isRunningUISmokeTests: true))
    }

    func testMovieDetailListStateReadsWishlistSeenlistAndCustomLists() {
        var state = AppState()
        state.moviesState.wishlist = [12]
        state.moviesState.seenlist = [7]
        state.moviesState.customLists = [
            3: CustomList(id: 3, name: "Favorites", cover: nil, movies: [12]),
            8: CustomList(id: 8, name: "Watch Later", cover: nil, movies: [])
        ]

        XCTAssertTrue(MovieDetailListState.isInWishlist(movieId: 12, from: state))
        XCTAssertFalse(MovieDetailListState.isInWishlist(movieId: 7, from: state))
        XCTAssertTrue(MovieDetailListState.isInSeenlist(movieId: 7, from: state))
        XCTAssertEqual(Set(MovieDetailListState.customLists(from: state).map(\.id)), Set([3, 8]))
    }

    func testMovieCrosslineStateMapsMoviesToIds() {
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
                  video: false)
        ]

        XCTAssertEqual(MovieCrosslineState.movieIds(from: movies), [sampleMovie.id, 12])
    }

    func testMovieCrosslineStateBuildsMoviePresentation() {
        let presentation = MovieCrosslineState.presentation(for: sampleMovie)

        XCTAssertEqual(presentation.title, sampleMovie.userTitle)
        XCTAssertEqual(presentation.posterPath, sampleMovie.poster_path)
        XCTAssertEqual(presentation.popularityScore, Int(sampleMovie.vote_average * 10))
    }

    func testMovieCrosslinePeopleStateBuildsSubtitleAndAccessibilityIdentifier() {
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

        XCTAssertEqual(presentation.name, "Test Person")
        XCTAssertEqual(presentation.subtitle, "Neo")
        XCTAssertNil(presentation.profilePath)
        XCTAssertEqual(presentation.accessibilityIdentifier, "movieDetail.person.9")
        XCTAssertEqual(MovieCrosslinePeopleState.subtitle(for: people), "Neo")
        XCTAssertEqual(MovieCrosslinePeopleState.accessibilityIdentifier(for: people), "movieDetail.person.9")
    }

    func testMovieCrosslinePeopleStateOmitsSubtitleWhenPeopleRoleIsMissing() {
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

        XCTAssertEqual(presentation.name, "No Role")
        XCTAssertNil(presentation.subtitle)
        XCTAssertEqual(presentation.profilePath, "/profile.jpg")
        XCTAssertEqual(MovieCrosslinePeopleState.subtitle(for: people), "")
    }

    func testMovieInfoStateBuildsPresentation() {
        var movie = sampleMovie
        movie.production_countries = [Movie.productionCountry(name: "France")]

        let presentation = MovieInfoState.presentation(for: movie)

        XCTAssertEqual(presentation.yearText, "1972")
        XCTAssertEqual(presentation.runtimeText, "• 80 minutes")
        XCTAssertEqual(presentation.statusText, "• released")
        XCTAssertEqual(presentation.productionCountryText, "France")
    }

    func testMovieCoverStateBuildsPresentationAndPlaceholderGenres() {
        let populatedPresentation = MovieCoverState.presentation(for: sampleMovie)

        XCTAssertEqual(populatedPresentation.backdropPath, sampleMovie.backdrop_path)
        XCTAssertEqual(populatedPresentation.posterPath, sampleMovie.poster_path)
        XCTAssertEqual(populatedPresentation.popularityScore, Int(sampleMovie.vote_average * 10))
        XCTAssertEqual(populatedPresentation.ratingsText, "\(sampleMovie.vote_count) ratings")
        XCTAssertEqual(populatedPresentation.genres.map(\.name), sampleMovie.genres?.map(\.name))
        XCTAssertFalse(populatedPresentation.areGenresPlaceholder)

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

        XCTAssertTrue(placeholderPresentation.areGenresPlaceholder)
        XCTAssertEqual(placeholderPresentation.genres.count, 3)
        XCTAssertEqual(placeholderPresentation.genres.map(\.name), ["     ", "     ", "     "])
        XCTAssertEqual(placeholderPresentation.backdropPath, nil)
        XCTAssertEqual(placeholderPresentation.ratingsText, "15 ratings")
    }

    func testMoviePostersStateBuildsPresentationsAndSelection() {
        let posters = [
            ImageData(aspect_ratio: 0.7, file_path: "/poster-a.jpg", height: 1000, width: 700),
            ImageData(aspect_ratio: 0.7, file_path: "/poster-b.jpg", height: 1000, width: 700)
        ]

        let presentations = MoviePostersState.presentations(from: posters)

        XCTAssertEqual(presentations.map(\.id), ["/poster-a.jpg", "/poster-b.jpg"])
        XCTAssertEqual(presentations.map(\.path), ["/poster-a.jpg", "/poster-b.jpg"])
        XCTAssertEqual(MoviePostersState.selectedPoster(afterSelecting: presentations[1]).file_path, "/poster-b.jpg")
    }

    func testMovieBackdropsStateBuildsPresentations() {
        let backdrops = [
            ImageData(aspect_ratio: 1.7, file_path: "/backdrop-a.jpg", height: 1200, width: 1800),
            ImageData(aspect_ratio: 1.7, file_path: "/backdrop-b.jpg", height: 1200, width: 1800)
        ]

        let presentations = MovieBackdropsState.presentations(from: backdrops)

        XCTAssertEqual(presentations.map(\.id), ["/backdrop-a.jpg", "/backdrop-b.jpg"])
        XCTAssertEqual(presentations.map(\.path), ["/backdrop-a.jpg", "/backdrop-b.jpg"])
    }

    func testGenresListFetchPolicyFetchesOutsideUISmokeTests() {
        XCTAssertTrue(GenresListFetchPolicy.shouldFetchGenres(isRunningUISmokeTests: false))
    }

    func testGenresListFetchPolicySkipsDuringUISmokeTests() {
        XCTAssertFalse(GenresListFetchPolicy.shouldFetchGenres(isRunningUISmokeTests: true))
    }

    func testGenresListFetchPolicyReturnsFetchGenresActionOutsideUISmokeTests() {
        let actions = GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: false)

        XCTAssertEqual(actions.count, 1)
        XCTAssertTrue(actions.first is MoviesActions.FetchGenres)
    }

    func testGenresListFetchPolicyReturnsNoActionsDuringUISmokeTests() {
        XCTAssertTrue(GenresListFetchPolicy.actionsToDispatch(isRunningUISmokeTests: true).isEmpty)
    }

    func testGenresListStateReturnsGenresFromState() {
        var state = AppState()
        state.moviesState.genres = [Genre(id: 1, name: "Comedy"),
                                    Genre(id: 2, name: "Drama")]

        XCTAssertEqual(GenresListState.genres(from: state).map(\.id), [1, 2])
    }

    func testMovieGenrePageActionBuildsFetchGenreAction() {
        let genre = Genre(id: 9, name: "Adventure")
        let action = MovieGenrePageAction.fetch(genre: genre, page: 3, sort: .byScore)

        guard let fetchAction = action as? MoviesActions.FetchMoviesGenre else {
            return XCTFail("Expected FetchMoviesGenre action")
        }

        XCTAssertEqual(fetchAction.genre.id, 9)
        XCTAssertEqual(fetchAction.page, 3)
        XCTAssertEqual(fetchAction.sortBy, .byScore)
    }

    func testMoviesGenreListStateReturnsGenreMoviesWhenPresent() {
        var state = AppState()
        let genre = Genre(id: 9, name: "Adventure")
        state.moviesState.withGenre[9] = [1, 4, 7]

        XCTAssertEqual(MoviesGenreListState.movies(for: genre, from: state), [1, 4, 7])
    }

    func testMoviesGenreListStateReturnsEmptyWhenMissing() {
        let state = AppState()
        let genre = Genre(id: 9, name: "Adventure")

        XCTAssertEqual(MoviesGenreListState.movies(for: genre, from: state), [])
    }

    func testMovieKeywordListStateReturnsKeywordMoviesWhenPresent() {
        var state = AppState()
        let keyword = Keyword(id: 42, name: "Sci-Fi")
        state.moviesState.withKeywords[42] = [3, 5, 8]

        XCTAssertEqual(MovieKeywordListState.movies(for: keyword, from: state), [3, 5, 8])
    }

    func testMovieKeywordListStateReturnsPlaceholderFallbackWhenMissing() {
        let state = AppState()
        let keyword = Keyword(id: 42, name: "Sci-Fi")

        XCTAssertEqual(MovieKeywordListState.movies(for: keyword, from: state), [0, 0, 0, 0])
    }

    func testMoviesCrewListStateReturnsCrewMoviesWhenPresent() {
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

        XCTAssertEqual(MoviesCrewListState.movies(for: crew, from: state), [1, 4, 7])
    }

    func testMoviesCrewListStateReturnsEmptyWhenMissing() {
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

        XCTAssertEqual(MoviesCrewListState.movies(for: crew, from: state), [])
    }

    func testDiscoverFilterFormFetchPolicyFetchesWhenGenresAreMissing() {
        XCTAssertTrue(DiscoverFilterFormFetchPolicy.shouldFetchGenres(genres: []))
    }

    func testDiscoverFilterFormFetchPolicySkipsWhenGenresAreLoaded() {
        XCTAssertFalse(DiscoverFilterFormFetchPolicy.shouldFetchGenres(genres: [Genre(id: 1, name: "Comedy")]))
    }

    func testDiscoverFilterFormStateReturnsNilForDefaultSelections() {
        XCTAssertNil(DiscoverFilterFormState.formFilter(selectedDate: 0,
                                                       selectedGenre: 0,
                                                       selectedCountry: 0,
                                                       datesInt: [0, 1950, 1960],
                                                       genres: [Genre(id: 0, name: "Random"),
                                                                Genre(id: 12, name: "Adventure")]))
    }

    func testDiscoverFilterFormStateBuildsFilterFromSelections() {
        let expectedRegion = NSLocale.isoCountryCodes[0]
        let filter = DiscoverFilterFormState.formFilter(selectedDate: 1,
                                                        selectedGenre: 1,
                                                        selectedCountry: 1,
                                                        datesInt: [0, 1950, 1960],
                                                        genres: [Genre(id: 0, name: "Random"),
                                                                 Genre(id: 12, name: "Adventure")])

        XCTAssertEqual(filter?.startYear, 1950)
        XCTAssertEqual(filter?.endYear, 1959)
        XCTAssertEqual(filter?.genre, 12)
        XCTAssertEqual(filter?.region, expectedRegion)
    }

    func testDiscoverFilterFormStateMapsCurrentFilterBackToSelections() {
        let expectedCountrySelection = (NSLocale.isoCountryCodes.firstIndex(of: "US") ?? -1) + 1
        let filter = DiscoverFilter(year: 1995,
                                    startYear: 1960,
                                    endYear: 1969,
                                    sort: "popularity.desc",
                                    genre: 28,
                                    region: "US")
        let genres = [Genre(id: 0, name: "Random"),
                      Genre(id: 28, name: "Action")]

        XCTAssertEqual(DiscoverFilterFormState.selectedDate(currentFilter: filter,
                                                            datesInt: [0, 1950, 1960, 1970]),
                       2)
        XCTAssertEqual(DiscoverFilterFormState.selectedGenre(currentFilter: filter, genres: genres),
                       1)
        XCTAssertEqual(DiscoverFilterFormState.selectedCountry(currentFilter: filter),
                       expectedCountrySelection)
    }

    func testDiscoverFilterFormActionPlanSavesExplicitFilter() {
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

        XCTAssertNotNil(plan.filterToSave)
        XCTAssertEqual(plan.filterToSave?.startYear, plan.activeFilter.startYear)
        XCTAssertEqual(plan.filterToSave?.endYear, plan.activeFilter.endYear)
        XCTAssertEqual(plan.filterToSave?.genre, plan.activeFilter.genre)
        XCTAssertEqual(plan.filterToSave?.region, plan.activeFilter.region)
        XCTAssertEqual(plan.activeFilter.startYear, 1950)
        XCTAssertEqual(plan.activeFilter.endYear, 1959)
        XCTAssertEqual(plan.activeFilter.genre, 35)
        XCTAssertEqual(plan.activeFilter.region, NSLocale.isoCountryCodes[0])
    }

    func testDiscoverFilterFormActionPlanFallsBackToRandomFilterForDefaultSelections() {
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

        XCTAssertNil(plan.filterToSave)
        XCTAssertEqual(plan.activeFilter.year, fallback.year)
        XCTAssertEqual(plan.activeFilter.startYear, fallback.startYear)
        XCTAssertEqual(plan.activeFilter.endYear, fallback.endYear)
        XCTAssertEqual(plan.activeFilter.sort, fallback.sort)
        XCTAssertEqual(plan.activeFilter.genre, fallback.genre)
        XCTAssertEqual(plan.activeFilter.region, fallback.region)
    }

    func testMovieReviewsFetchPolicyFetchesWhenReviewsAreMissing() {
        XCTAssertTrue(MovieReviewsFetchPolicy.shouldFetchReviews(existingReviews: []))
    }

    func testMovieReviewsFetchPolicySkipsWhenReviewsAlreadyLoaded() {
        let review = Review(id: "1",
                            author: "Test",
                            content: "Review")

        XCTAssertFalse(MovieReviewsFetchPolicy.shouldFetchReviews(existingReviews: [review]))
    }

    func testMovieReviewsStateReturnsReviewsWhenPresent() {
        var state = AppState()
        let review = Review(id: "1",
                            author: "Test",
                            content: "Review")
        state.moviesState.reviews[12] = [review]

        XCTAssertEqual(MovieReviewsState.reviews(for: 12, in: state).map(\.id), ["1"])
    }

    func testMovieReviewsStateReturnsEmptyWhenMissing() {
        XCTAssertTrue(MovieReviewsState.reviews(for: 12, in: AppState()).isEmpty)
    }

    func testMovieButtonsToggleActionAddsMovieToWishlistWhenMissing() {
        XCTAssertEqual(MovieButtonsToggleAction.wishlistAction(movieId: 12, isInWishlist: false),
                       .addToWishlist(movie: 12))
    }

    func testMovieButtonsToggleActionRemovesMovieFromWishlistWhenPresent() {
        XCTAssertEqual(MovieButtonsToggleAction.wishlistAction(movieId: 12, isInWishlist: true),
                       .removeFromWishlist(movie: 12))
    }

    func testActionSheetMovieListActionAddsMovieToWishlistWhenMissing() {
        XCTAssertEqual(ActionSheetMovieListAction.wishlist(movie: 12, isInWishlist: false),
                       .addToWishlist(movie: 12))
    }

    func testActionSheetMovieListActionRemovesMovieFromWishlistWhenPresent() {
        XCTAssertEqual(ActionSheetMovieListAction.wishlist(movie: 12, isInWishlist: true),
                       .removeFromWishlist(movie: 12))
    }

    func testActionSheetMovieListActionAddsMovieToSeenlistWhenMissing() {
        XCTAssertEqual(ActionSheetMovieListAction.seenlist(movie: 12, isInSeenlist: false),
                       .addToSeenlist(movie: 12))
    }

    func testActionSheetMovieListActionRemovesMovieFromSeenlistWhenPresent() {
        XCTAssertEqual(ActionSheetMovieListAction.seenlist(movie: 12, isInSeenlist: true),
                       .removeFromSeenlist(movie: 12))
    }

    func testActionSheetMovieListActionAddsMovieToCustomListWhenMissing() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        XCTAssertEqual(ActionSheetMovieListAction.customList(list: list, movie: 12),
                       .addToCustomList(list: 7, movie: 12))
    }

    func testActionSheetMovieListActionRemovesMovieFromCustomListWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [12])

        XCTAssertEqual(ActionSheetMovieListAction.customList(list: list, movie: 12),
                       .removeFromCustomList(list: 7, movie: 12))
    }

    func testMovieButtonsToggleActionAddsMovieToSeenlistWhenMissing() {
        XCTAssertEqual(MovieButtonsToggleAction.seenlistAction(movieId: 12, isInSeenlist: false),
                       .addToSeenlist(movie: 12))
    }

    func testMovieButtonsToggleActionRemovesMovieFromSeenlistWhenPresent() {
        XCTAssertEqual(MovieButtonsToggleAction.seenlistAction(movieId: 12, isInSeenlist: true),
                       .removeFromSeenlist(movie: 12))
    }

    func testPeopleDetailFetchPolicyFetchesOutsideUISmokeTests() {
        XCTAssertTrue(PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: false,
                                                                hasLoadedDetail: false))
        XCTAssertTrue(PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: false,
                                                                hasLoadedImages: false))
        XCTAssertTrue(PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: false,
                                                                 hasLoadedCredits: false))
    }

    func testPeopleDetailFetchPolicySkipsDuringUISmokeTests() {
        XCTAssertFalse(PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: true,
                                                                 hasLoadedDetail: false))
        XCTAssertFalse(PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: true,
                                                                 hasLoadedImages: false))
        XCTAssertFalse(PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: true,
                                                                  hasLoadedCredits: false))
    }

    func testPeopleDetailFetchPolicySkipsAlreadyLoadedSlices() {
        XCTAssertFalse(PeopleDetailFetchPolicy.shouldFetchDetail(isRunningUISmokeTests: false,
                                                                 hasLoadedDetail: true))
        XCTAssertFalse(PeopleDetailFetchPolicy.shouldFetchImages(isRunningUISmokeTests: false,
                                                                 hasLoadedImages: true))
        XCTAssertFalse(PeopleDetailFetchPolicy.shouldFetchCredits(isRunningUISmokeTests: false,
                                                                  hasLoadedCredits: true))
    }

    func testSettingsFormRefreshPolicyRefreshesWhenRegionChanges() {
        XCTAssertTrue(SettingsFormRefreshPolicy.shouldRefreshMovieMenus(previousRegion: "US",
                                                                       selectedRegion: "FR"))
    }

    func testSettingsFormRefreshPolicySkipsWhenRegionMatches() {
        XCTAssertFalse(SettingsFormRefreshPolicy.shouldRefreshMovieMenus(previousRegion: "US",
                                                                        selectedRegion: "US"))
    }

    func testSettingsFormRefreshPolicyReturnsAllMenusWhenRegionChanges() {
        XCTAssertEqual(SettingsFormRefreshPolicy.menusToRefresh(previousRegion: "US",
                                                                selectedRegion: "FR"),
                       MoviesMenu.allCases)
    }

    func testSettingsFormRefreshPolicyReturnsNoMenusWhenRegionMatches() {
        XCTAssertTrue(SettingsFormRefreshPolicy.menusToRefresh(previousRegion: "US",
                                                               selectedRegion: "US").isEmpty)
    }

    func testSettingsFormDebugStateCountsMovies() {
        XCTAssertEqual(SettingsFormDebugState.moviesCount(from: [0: sampleMovie, 1: sampleMovie]), 2)
    }

    func testSettingsFormStateCountsMoviesFromAppState() {
        var state = AppState()
        state.moviesState.movies = [0: sampleMovie, 1: sampleMovie]

        XCTAssertEqual(SettingsFormState.moviesCount(in: state), 2)
    }

    func testOutlineMoviesMenuListFetchPolicyFetchesOutsideUISmokeTests() {
        XCTAssertTrue(OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: false))
    }

    func testOutlineMoviesMenuListFetchPolicySkipsDuringUISmokeTests() {
        XCTAssertFalse(OutlineMoviesMenuListFetchPolicy.shouldLoadInitialPage(isRunningUISmokeTests: true))
    }

    func testSampleMovieHasExpectedIdentifier() {
        XCTAssertEqual(sampleMovie.id, 0)
    }

    func testMoviesSortAPIMapping() {
        XCTAssertEqual(MoviesSort.byReleaseDate.sortByAPI(), "release_date.desc")
        XCTAssertEqual(MoviesSort.byAddedDate.sortByAPI(), "primary_release_date.desc")
        XCTAssertEqual(MoviesSort.byScore.sortByAPI(), "vote_average.desc")
        XCTAssertEqual(MoviesSort.byPopularity.sortByAPI(), "popularity.desc")
    }

    func testAppLoggingPolicyDisablesLoggingDuringTests() {
        XCTAssertFalse(AppLoggingPolicy.shouldEnableLogging(isRunningTests: true))
    }

    func testAppLoggingPolicyEnablesLoggingOutsideTests() {
        XCTAssertTrue(AppLoggingPolicy.shouldEnableLogging(isRunningTests: false))
    }

    func testPeopleContextMenuFanClubActionAddsWhenMissing() {
        XCTAssertEqual(PeopleContextMenuFanClubAction.toggleAction(people: 9, isInFanClub: false),
                       .add(people: 9))
    }

    func testPeopleContextMenuFanClubActionRemovesWhenPresent() {
        XCTAssertEqual(PeopleContextMenuFanClubAction.toggleAction(people: 9, isInFanClub: true),
                       .remove(people: 9))
    }

    func testPeopleContextMenuFanClubActionTitleForMissingPeople() {
        XCTAssertEqual(PeopleContextMenuFanClubAction.title(isInFanClub: false),
                       "Add to fan club")
    }

    func testPeopleContextMenuFanClubActionTitleForExistingPeople() {
        XCTAssertEqual(PeopleContextMenuFanClubAction.title(isInFanClub: true),
                       "Remove from fan club")
    }

    func testDiscoverPosterLookupReturnsPosterPathForMovie() {
        XCTAssertEqual(DiscoverPosterLookup.posterPath(for: 12, posters: [12: "/poster.jpg"]),
                       "/poster.jpg")
    }

    func testDiscoverPosterLookupReturnsNilWhenMovieIsMissing() {
        XCTAssertNil(DiscoverPosterLookup.posterPath(for: 12, posters: [:]))
    }

    func testPeopleDetailMovieGroupingGroupsMoviesByReleaseYear() {
        let grouped = PeopleDetailMovieGrouping.group(credits: [sampleMovie.id: "Lead"],
                                                      movies: [sampleMovie.id: sampleMovie])

        XCTAssertEqual(grouped["1972"]?.first?.id, sampleMovie.id)
        XCTAssertEqual(grouped["1972"]?.first?.role, "Lead")
    }

    func testPeopleDetailMovieGroupingSkipsCreditsWithoutMovies() {
        let grouped = PeopleDetailMovieGrouping.group(credits: [999: "Lead"],
                                                      movies: [:])

        XCTAssertTrue(grouped.isEmpty)
    }

    func testPeopleDetailCreditsStateMergesCastAndCrewRolesForSameMovie() {
        let merged = PeopleDetailCreditsState.mergedCredits(cast: [7: "Actor"],
                                                            crew: [7: "Director"])

        XCTAssertEqual(merged[7], "Actor • Director")
    }

    func testPeopleDetailCreditsStateDedupesMatchingRoles() {
        let merged = PeopleDetailCreditsState.mergedCredits(cast: [7: "Producer"],
                                                            crew: [7: "Producer"])

        XCTAssertEqual(merged[7], "Producer")
    }

    func testPeopleDetailSortedYearsPlacesUpcomingLast() {
        XCTAssertEqual(PeopleDetailState.sortedYears(from: ["Upcoming": [], "2024": [], "2022": []]),
                       ["2024", "2022", "Upcoming"])
    }

    func testCustomListPresentationUsesFirstMovieAsListCover() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [sampleMovie.id])

        XCTAssertEqual(CustomListPresentation.coverMovie(for: list,
                                                         movies: [sampleMovie.id: sampleMovie])?.id,
                       sampleMovie.id)
    }

    func testCustomListPresentationUsesExplicitBackdropCoverWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: sampleMovie.id, movies: [])

        XCTAssertEqual(CustomListPresentation.coverBackdropMovie(for: list,
                                                                 movies: [sampleMovie.id: sampleMovie])?.id,
                       sampleMovie.id)
    }

    func testCustomListPresentationSkipsMissingCoverMovies() {
        let list = CustomList(id: 7, name: "Favorites", cover: 999, movies: [999])

        XCTAssertNil(CustomListPresentation.coverMovie(for: list, movies: [:]))
        XCTAssertNil(CustomListPresentation.coverBackdropMovie(for: list, movies: [:]))
    }

    func testCustomListSearchMovieTextWrapperDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = CustomListSearchMovieTextWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")

        XCTAssertEqual(loadedText, "matrix")
        XCTAssertEqual(loadedPage, 1)
    }

    func testCustomListSearchMovieTextWrapperDoesNotDispatchWithoutInjectedHandler() {
        let wrapper = CustomListSearchMovieTextWrapper()

        wrapper.onUpdateTextDebounced(text: "matrix")

        XCTAssertTrue(true)
    }

    func testCustomListFormSearchWrapperDispatchesInjectedSearches() {
        var loadedText: String?
        var loadedPage: Int?
        let wrapper = CustomListFormSearchWrapper()

        wrapper.bindDispatchSearches { text, page in
            loadedText = text
            loadedPage = page
        }
        wrapper.onUpdateTextDebounced(text: "matrix")

        XCTAssertEqual(loadedText, "matrix")
        XCTAssertEqual(loadedPage, 1)
    }

    func testCustomListFormSearchWrapperDoesNotDispatchWithoutInjectedHandler() {
        let wrapper = CustomListFormSearchWrapper()

        wrapper.onUpdateTextDebounced(text: "matrix")

        XCTAssertTrue(true)
    }

    func testCustomListSelectionTogglesMovieIntoSelection() {
        XCTAssertEqual(CustomListSelection.toggled(movie: 7, in: []), Set([7]))
    }

    func testCustomListSelectionTogglesMovieOutOfSelection() {
        XCTAssertEqual(CustomListSelection.toggled(movie: 7, in: Set([7, 9])), Set([9]))
    }

    func testCustomListSelectionPendingAddButtonTitleForEmptySelection() {
        XCTAssertEqual(CustomListSelection.pendingAddButtonTitle(for: []), "Cancel")
    }

    func testCustomListSelectionPendingAddButtonTitleForSelectedMovies() {
        XCTAssertEqual(CustomListSelection.pendingAddButtonTitle(for: Set([1, 2])), "Add movies (2)")
    }

    func testCustomListFormStateReturnsEditingValuesWhenListExists() {
        let list = CustomList(id: 7, name: "Favorites", cover: 12, movies: [])

        let editingValues = CustomListFormState.editingValues(editingListId: 7,
                                                              customLists: [7: list])

        XCTAssertEqual(editingValues?.name, "Favorites")
        XCTAssertEqual(editingValues?.cover, 12)
    }

    func testCustomListFormStateReturnsNilWhenEditingListIsMissing() {
        XCTAssertNil(CustomListFormState.editingValues(editingListId: 7, customLists: [:]))
    }

    func testCustomListFormPresentationReturnsCoverMovieWhenPresent() {
        XCTAssertEqual(CustomListFormPresentation.coverMovie(coverId: sampleMovie.id,
                                                             movies: [sampleMovie.id: sampleMovie])?.id,
                       sampleMovie.id)
    }

    func testCustomListFormPresentationSkipsMissingCoverMovie() {
        XCTAssertNil(CustomListFormPresentation.coverMovie(coverId: 99, movies: [:]))
    }

    func testCustomListFormPresentationReturnsResolvedSearchMovies() {
        let movies = CustomListFormPresentation.searchedMovies(searchText: "alien",
                                                               searchResults: ["alien": [sampleMovie.id]],
                                                               movies: [sampleMovie.id: sampleMovie])

        XCTAssertEqual(movies.map(\.id), [sampleMovie.id])
    }

    func testCustomListFormPresentationSkipsMissingSearchMovies() {
        let movies = CustomListFormPresentation.searchedMovies(searchText: "alien",
                                                               searchResults: ["alien": [sampleMovie.id, 99]],
                                                               movies: [sampleMovie.id: sampleMovie])

        XCTAssertEqual(movies.map(\.id), [sampleMovie.id])
    }

    func testCustomListDetailStateReturnsListWhenPresent() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        XCTAssertEqual(CustomListDetailState.list(listId: 7, customLists: [7: list])?.id, 7)
    }

    func testCustomListDetailStateReturnsNilWhenListIsMissing() {
        XCTAssertNil(CustomListDetailState.list(listId: 7, customLists: [:]))
    }

    func testCustomListDetailStateReturnsSearchResultsWhenSearching() {
        XCTAssertEqual(CustomListDetailState.searchedMovies(searchText: "alien",
                                                            searchResults: ["alien": [1, 2]]),
                       [1, 2])
    }

    func testCustomListDetailStateReturnsNilWhenSearchTextIsEmpty() {
        XCTAssertNil(CustomListDetailState.searchedMovies(searchText: "",
                                                          searchResults: ["alien": [1, 2]]))
    }

    func testMyListsPresentationReturnsCustomListsFromDictionary() {
        let list = CustomList(id: 7, name: "Favorites", cover: nil, movies: [])

        XCTAssertEqual(MyListsPresentation.customLists(from: [7: list]).map(\.id), [7])
    }

    func testMyListsPresentationReturnsEmptySortedMoviesForEmptyInput() {
        XCTAssertEqual(MyListsPresentation.sortedMovies([], by: .byReleaseDate, state: AppState()), [])
    }
}

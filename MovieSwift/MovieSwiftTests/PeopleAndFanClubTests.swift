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
struct PeopleAndFanClubTests {
    // NOTE: the `setMovieCasts*` tests also exercise `peoplesStateReducer`
    // (reverse role-lookup population), but live in `MovieDetailTests`
    // because they share the movie-detail people-resolution context.
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
                            profilePath: nil,
                            knownForDepartment: nil,
                            knownFor: nil,
                            alsoKnownAs: nil,
                            birthDay: nil,
                            deathDay: nil,
                            placeOfBirth: nil,
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
                                  profilePath: nil,
                                  knownForDepartment: nil,
                                  knownFor: nil,
                                  alsoKnownAs: nil,
                                  birthDay: nil,
                                  deathDay: nil,
                                  placeOfBirth: nil,
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
                                                                                                                  profilePath: nil,
                                                                                                                  knownForDepartment: nil,
                                                                                                                  knownFor: nil,
                                                                                                                  alsoKnownAs: nil,
                                                                                                                  birthDay: nil,
                                                                                                                  deathDay: nil,
                                                                                                                  placeOfBirth: nil,
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
                                  profilePath: nil,
                                  knownForDepartment: nil,
                                  knownFor: nil,
                                  alsoKnownAs: nil,
                                  birthDay: nil,
                                  deathDay: nil,
                                  placeOfBirth: nil,
                                  biography: nil,
                                  popularity: nil,
                                  images: nil)

        let updated = peoplesStateReducer(state: state,
                                          action: PeopleActions.SetDetail(person: People(id: 1,
                                                                                         name: "Actor",
                                                                                         character: nil,
                                                                                         department: nil,
                                                                                         profilePath: nil,
                                                                                         knownForDepartment: nil,
                                                                                         knownFor: nil,
                                                                                         alsoKnownAs: nil,
                                                                                         birthDay: nil,
                                                                                         deathDay: nil,
                                                                                         placeOfBirth: nil,
                                                                                         biography: "Bio",
                                                                                         popularity: nil,
                                                                                         images: nil)))

        #expect(updated.peoples[1]?.character == nil)
        #expect(updated.peoples[1]?.department == nil)
    }

    @Test func peopleStateReducerSetImagesCreatesPlaceholderWhenPersonIsMissing() {
        let state = AppState().peoplesState
        let images = [ImageData(aspectRatio: 1,
                                filePath: "/profile.jpg",
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
                                                                                                                                 originalTitle: "New Cast",
                                                                                                                                 title: "New Cast",
                                                                                                                                 overview: "",
                                                                                                                                 posterPath: nil,
                                                                                                                                 backdropPath: nil,
                                                                                                                                 popularity: 0,
                                                                                                                                 voteAverage: 0,
                                                                                                                                 voteCount: 0,
                                                                                                                                 releaseDateString: nil,
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

    @Test func peoplesStateCodableRoundTripPreservesLoadedDetailFlagsAndCredits() throws {
        var state = PeoplesState()
        state.peoples[7] = People(id: 7,
                                  name: "Person",
                                  character: nil,
                                  department: nil,
                                  profilePath: nil,
                                  knownForDepartment: nil,
                                  knownFor: nil,
                                  alsoKnownAs: nil,
                                  birthDay: nil,
                                  deathDay: nil,
                                  placeOfBirth: nil,
                                  biography: nil,
                                  popularity: nil,
                                  images: [ImageData(aspectRatio: 1,
                                                     filePath: "/profile.jpg",
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
                                               profilePath: nil,
                                               knownForDepartment: nil,
                                               knownFor: nil,
                                               alsoKnownAs: nil,
                                               birthDay: nil,
                                               deathDay: nil,
                                               placeOfBirth: nil,
                                               biography: nil,
                                               popularity: nil,
                                               images: nil)

        #expect(FanClubState.popularPeople(from: state) == [1])
    }

    @Test func peopleStateReducerDedupesPopularPeopleAcrossPages() {
        let state = AppState().peoplesState
        let popularPage = PaginatedResponse(page: 2,
                                            totalResults: 3,
                                            totalPages: 2,
                                            results: [People(id: 2,
                                                             name: "Second",
                                                             character: nil,
                                                             department: nil,
                                                             profilePath: nil,
                                                             knownForDepartment: nil,
                                                             knownFor: nil,
                                                             alsoKnownAs: nil,
                                                             birthDay: nil,
                                                             deathDay: nil,
                                                             placeOfBirth: nil,
                                                             biography: nil,
                                                             popularity: nil,
                                                             images: nil),
                                                      People(id: 1,
                                                             name: "First",
                                                             character: nil,
                                                             department: nil,
                                                             profilePath: nil,
                                                             knownForDepartment: nil,
                                                             knownFor: nil,
                                                             alsoKnownAs: nil,
                                                             birthDay: nil,
                                                             deathDay: nil,
                                                             placeOfBirth: nil,
                                                             biography: nil,
                                                             popularity: nil,
                                                             images: nil), ])
        let seeded = peoplesStateReducer(state: state,
                                         action: PeopleActions.SetPopular(page: 1,
                                                                         response: PaginatedResponse(page: 1,
                                                                                                     totalResults: 2,
                                                                                                     totalPages: 2,
                                                                                                     results: [People(id: 1,
                                                                                                                      name: "First",
                                                                                                                      character: nil,
                                                                                                                      department: nil,
                                                                                                                      profilePath: nil,
                                                                                                                      knownForDepartment: nil,
                                                                                                                      knownFor: nil,
                                                                                                                      alsoKnownAs: nil,
                                                                                                                      birthDay: nil,
                                                                                                                      deathDay: nil,
                                                                                                                      placeOfBirth: nil,
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
                            profilePath: nil,
                            knownForDepartment: nil,
                            knownFor: nil,
                            alsoKnownAs: nil,
                            birthDay: nil,
                            deathDay: nil,
                            placeOfBirth: nil,
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
                            profilePath: nil,
                            knownForDepartment: nil,
                            knownFor: nil,
                            alsoKnownAs: nil,
                            birthDay: nil,
                            deathDay: nil,
                            placeOfBirth: nil,
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
}

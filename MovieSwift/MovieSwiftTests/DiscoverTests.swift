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
struct DiscoverTests {
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
        // The auto-refill path forces a fetch; the smoke-test gate must still win.
        #expect(!(DiscoverFetchPolicy.shouldFetchRandomMovies(currentMovieCount: 3,
                                                                  force: true,
                                                                  isRunningUISmokeTests: true)))
    }

    @Test func discoverAutoRefillPolicyRefillsOnlyWhenEmptyWithoutFailure() {
        #expect(DiscoverAutoRefillPolicy.shouldAutoRefill(movies: [],
                                                          loadingFailure: nil,
                                                          isRunningUISmokeTests: false))
        // Not empty → no refill.
        #expect(!(DiscoverAutoRefillPolicy.shouldAutoRefill(movies: [1],
                                                            loadingFailure: nil,
                                                            isRunningUISmokeTests: false)))
        // A pending failure stops the auto-refetch loop (manual retry instead).
        let failure = MoviesListLoadFailure(kind: .other, message: "Try again")
        #expect(!(DiscoverAutoRefillPolicy.shouldAutoRefill(movies: [],
                                                            loadingFailure: failure,
                                                            isRunningUISmokeTests: false)))
        // Disabled under UI smoke tests.
        #expect(!(DiscoverAutoRefillPolicy.shouldAutoRefill(movies: [],
                                                            loadingFailure: nil,
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
        #expect(DiscoverUndoState.canUndo(previousMovie: 7, isGestureActive: false))
        #expect(!(DiscoverUndoState.canUndo(previousMovie: nil, isGestureActive: false)))
        #expect(!(DiscoverUndoState.canUndo(previousMovie: 7, isGestureActive: true)))
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

    @Test func discoverPosterLookupReturnsPosterPathForMovie() {
        #expect(DiscoverPosterLookup.posterPath(for: 12, posters: [12: "/poster.jpg"]) ==
                       "/poster.jpg")
    }

    @Test func discoverPosterLookupReturnsNilWhenMovieIsMissing() {
        #expect(DiscoverPosterLookup.posterPath(for: 12, posters: [:]) == nil)
    }
}

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
struct AppCompositionTests {
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

    @Test func appLaunchModeDetectsPreviewEnvironment() {
        #expect(AppLaunchMode.from(arguments: [], environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]) == .preview)
    }

    @Test func appLaunchModeDetectsUISmokeTestsFromArguments() {
        #expect(AppLaunchMode.from(arguments: [UITestEnv.Argument.smokeTests], environment: [:]) == .uiSmokeTests)
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

    @Test func appLoggingPolicyDisablesLoggingDuringTests() {
        #expect(!(AppLoggingPolicy.shouldEnableLogging(isRunningTests: true)))
    }

    @Test func appLoggingPolicyEnablesLoggingOutsideTests() {
        #expect(AppLoggingPolicy.shouldEnableLogging(isRunningTests: false))
    }
}

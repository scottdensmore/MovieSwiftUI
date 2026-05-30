import Foundation

#if DEBUG
private let uiSmokeTestFanClubFailureKey = "UI_SMOKE_TEST_FAN_CLUB_FAILURE"
private let sampleCustomList = CustomList(id: 0,
                                          name: "TestName",
                                          cover: 0,
                                          movies: [0])
private let sampleDiscoverGenres = [Genre(id: -1, name: "Random"),
                                    Genre(id: 35, name: "Comedy"), ]
private let sampleDiscoverFilter = DiscoverFilter(year: 1955,
                                                  startYear: 1950,
                                                  endYear: 1959,
                                                  sort: "popularity.desc",
                                                  genre: 35,
                                                  region: "US")
private let sampleMoviesMenuState = Dictionary(uniqueKeysWithValues: MoviesMenu.allCases.map { ($0, [0]) })
private let samplePrimaryCast = sampleCasts.first!
private let sampleSecondaryCast = sampleCasts[1]
private let sampleDirector: People = {
    var people = sampleSecondaryCast
    people.department = "Directing"
    return people
}()

public func makePreviewSampleState() -> AppState {
    AppState(moviesState:
                MoviesState(movies: [0: sampleMovie],
                            moviesList: sampleMoviesMenuState,
                            recommended: [0: [0]],
                            similar: [0: [0]],
                            discover: [0],
                            discoverFilter: sampleDiscoverFilter,
                            customLists: [0: sampleCustomList],
                            genres: sampleDiscoverGenres),
             peoplesState: PeoplesState(peoples: [samplePrimaryCast.id: samplePrimaryCast,
                                                  sampleDirector.id: sampleDirector, ],
                                        peoplesMovies: [0: Set([samplePrimaryCast.id,
                                                                sampleDirector.id, ]), ],
                                        search: [:],
                                        casts: [samplePrimaryCast.id: [0: "Character 1"]],
                                        crews: [sampleDirector.id: [0: "Director 1"]],
                                        movieCastOrder: [0: [samplePrimaryCast.id]],
                                        movieCrewOrder: [0: [sampleDirector.id]]))
}

public func makeUISmokeTestState() -> AppState {
    let environment = ProcessInfo.processInfo.environment
    let smokeTestList = CustomList(id: 0,
                                   name: "TestName",
                                   cover: 0,
                                   movies: [0])
    let smokeTestMoviesMenuState = Dictionary(uniqueKeysWithValues: MoviesMenu.allCases.map { ($0, [0]) })
    let smokeTestPrimaryCast = sampleCasts.first!
    var smokeTestDirector = sampleCasts[1]
    smokeTestDirector.department = "Directing"

    var peoplesState = PeoplesState(peoples: [smokeTestPrimaryCast.id: smokeTestPrimaryCast,
                                              smokeTestDirector.id: smokeTestDirector, ],
                                    peoplesMovies: [0: Set([smokeTestPrimaryCast.id,
                                                            smokeTestDirector.id, ]), ],
                                    search: [:],
                                    casts: [smokeTestPrimaryCast.id: [0: "Character 1"]],
                                    crews: [smokeTestDirector.id: [0: "Director 1"]],
                                    movieCastOrder: [0: [smokeTestPrimaryCast.id]],
                                    movieCrewOrder: [0: [smokeTestDirector.id]])

    if environment[uiSmokeTestFanClubFailureKey] == "1" {
        // Simulate a failed load with no popular data → shows error state
        peoplesState.popularInitialLoadCompleted = true
        peoplesState.popularLoadFailed = true
    } else {
        // Populate popular people so Fan Club view shows content
        peoplesState.popular = [smokeTestPrimaryCast.id, smokeTestDirector.id]
        peoplesState.popularInitialLoadCompleted = true
    }

    // Pre-seed search results so the UI test for the search journey can
    // type a known query into the SearchField and find a movie row in
    // the results section. The FetchSearch action that the typed query
    // dispatches fails in smoke-test mode (no network), but the UI
    // reads from `moviesState.search[query]` which is already populated
    // here, so the journey doesn't depend on the network.
    let smokeTestSearchSeed: [String: [Int]] = ["uitestsearch": [0]]

    return AppState(moviesState:
                        MoviesState(movies: [0: sampleMovie],
                                    moviesList: smokeTestMoviesMenuState,
                                    recommended: [0: [0]],
                                    similar: [0: [0]],
                                    search: smokeTestSearchSeed,
                                    discover: [0],
                                    discoverFilter: sampleDiscoverFilter,
                                    wishlist: Set([0]),
                                    seenlist: Set([0]),
                                    customLists: [0: smokeTestList],
                                    genres: sampleDiscoverGenres),
                    peoplesState: peoplesState)
}
#endif

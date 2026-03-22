//
//  AppStateFixtures.swift
//  MovieSwift
//

#if DEBUG
private let uiSmokeTestFanClubFailureKey = "UI_SMOKE_TEST_FAN_CLUB_FAILURE"
private let sampleCustomList = CustomList(id: 0,
                                          name: "TestName",
                                          cover: 0,
                                          movies: [0])
private let sampleDiscoverGenres = [Genre(id: -1, name: "Random"),
                                    Genre(id: 35, name: "Comedy")]
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

func makePreviewSampleState() -> AppState {
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
                                                  sampleDirector.id: sampleDirector],
                                        peoplesMovies: [0: Set([samplePrimaryCast.id,
                                                                sampleDirector.id])],
                                        search: [:],
                                        casts: [samplePrimaryCast.id: [0: "Character 1"]],
                                        crews: [sampleDirector.id: [0: "Director 1"]]))
}

func makeUISmokeTestState() -> AppState {
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
                                              smokeTestDirector.id: smokeTestDirector],
                                    peoplesMovies: [0: Set([smokeTestPrimaryCast.id,
                                                            smokeTestDirector.id])],
                                    search: [:],
                                    casts: [smokeTestPrimaryCast.id: [0: "Character 1"]],
                                    crews: [smokeTestDirector.id: [0: "Director 1"]])

    if environment[uiSmokeTestFanClubFailureKey] == "1" {
        peoplesState.popularInitialLoadCompleted = true
        peoplesState.popularLoadFailed = true
    }

    return AppState(moviesState:
                        MoviesState(movies: [0: sampleMovie],
                                    moviesList: smokeTestMoviesMenuState,
                                    recommended: [0: [0]],
                                    similar: [0: [0]],
                                    discover: [0],
                                    discoverFilter: sampleDiscoverFilter,
                                    customLists: [0: smokeTestList],
                                    genres: sampleDiscoverGenres),
                    peoplesState: peoplesState)
}
#endif

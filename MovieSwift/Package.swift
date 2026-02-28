// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MovieSwiftFluxCore",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "MovieSwiftFluxCore", targets: ["MovieSwiftFluxCore"])
    ],
    dependencies: [
        .package(path: "Packages/Backend")
    ],
    targets: [
        .target(
            name: "SwiftUIFlux",
            path: "PackageSupport/SwiftUIFlux"
        ),
        .target(
            name: "MovieSwiftFluxCore",
            dependencies: [
                "SwiftUIFlux",
                .product(name: "Backend", package: "Backend")
            ],
            path: "Shared",
            exclude: [
                "extensions",
                "fonts",
                "flux/actions/PeopleActions.swift",
                "flux/state/AppState.swift",
                "views/MoviePosterImage.swift",
                "views/modifiers"
            ],
            sources: [
                "flux/actions/MoviesActions.swift",
                "flux/middlewares/LoggingMiddleware.swift",
                "flux/models/CastResponse.swift",
                "flux/models/CustomList.swift",
                "flux/models/DiscoverFilter.swift",
                "flux/models/Genre.swift",
                "flux/models/Image.swift",
                "flux/models/Keyword.swift",
                "flux/models/Movie.swift",
                "flux/models/MovieUserMeta.swift",
                "flux/models/PaginatedResponse.swift",
                "flux/models/People.swift",
                "flux/models/Review.swift",
                "flux/models/Video.swift",
                "flux/reducers/AppReducer.swift",
                "flux/reducers/MoviesReducer.swift",
                "flux/reducers/PeopleReducer.swift",
                "flux/state/MoviesState.swift",
                "flux/state/PeoplesState.swift",
                "flux/testing/ActionStubs.swift",
                "flux/testing/AppStateStub.swift",
                "flux/testing/MoviesSortStub.swift",
                "views/MoviesMenu.swift"
            ]
        ),
        .testTarget(
            name: "MovieSwiftFluxCoreTests",
            dependencies: ["MovieSwiftFluxCore"]
        )
    ],
    swiftLanguageModes: [
        .v5
    ]
)

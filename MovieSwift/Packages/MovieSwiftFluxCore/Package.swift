// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MovieSwiftFluxCore",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .tvOS("26.0"),
    ],
    products: [
        .library(name: "MovieSwiftFluxCore", targets: ["MovieSwiftFluxCore"]),
    ],
    dependencies: [
        .package(path: "../Backend"),
        .package(path: "../Flux"),
    ],
    targets: [
        .target(
            name: "MovieSwiftFluxCore",
            dependencies: [
                .product(name: "Backend", package: "Backend"),
                .product(name: "Flux", package: "Flux"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MovieSwiftFluxCoreTests",
            dependencies: ["MovieSwiftFluxCore"],
            resources: [.process("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

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
        .package(url: "https://github.com/Dimillian/SwiftUIFlux.git", from: "0.5.1"),
    ],
    targets: [
        .target(
            name: "MovieSwiftFluxCore",
            dependencies: [
                .product(name: "Backend", package: "Backend"),
                .product(name: "SwiftUIFlux", package: "SwiftUIFlux"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MovieSwiftFluxCoreTests",
            dependencies: ["MovieSwiftFluxCore"],
            resources: [.process("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)

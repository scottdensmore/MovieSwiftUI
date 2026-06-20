// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flux",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .tvOS("26.0"),
    ],
    products: [
        .library(name: "Flux", targets: ["Flux"]),
    ],
    targets: [
        .target(name: "Flux"),
        .testTarget(
            name: "FluxTests",
            dependencies: ["Flux"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

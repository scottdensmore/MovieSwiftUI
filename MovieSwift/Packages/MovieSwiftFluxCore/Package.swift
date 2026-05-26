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
        // Pin to the post-0.5.1 master commit that updates Package.swift's
        // swiftLanguageVersions to `.version("5")` instead of `.v5_1`. The
        // tagged 0.5.1 release (Feb 2020) was never re-cut, so the fix
        // lives only on master. Swift 6+ toolchains (macos-26 runner)
        // reject `-swift-version 5.1` and the build fails without this pin.
        .package(url: "https://github.com/Dimillian/SwiftUIFlux.git",
                 revision: "05e3e07a752a513bc160bcc589004ebf1bc6c1dc"),
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
    swiftLanguageModes: [.v6]
)

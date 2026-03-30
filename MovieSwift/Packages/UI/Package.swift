// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UI",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
        .tvOS("26.0"),
        .watchOS("26.0")
    ],
    products: [
        .library(name: "UI", targets: ["UI"]),
    ],
    targets: [
        .target(name: "UI", dependencies: [], path: "Sources")
    ],
    swiftLanguageModes: [
        .v5
    ]
)

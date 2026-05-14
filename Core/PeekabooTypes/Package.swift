// swift-tools-version: 6.2

import PackageDescription

let approachableConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let package = Package(
    name: "PeekabooTypes",
    products: [
        .library(
            name: "PeekabooTypes",
            targets: ["PeekabooTypes"]),
    ],
    targets: [
        .target(
            name: "PeekabooTypes",
            swiftSettings: approachableConcurrencySettings),
        .testTarget(
            name: "PeekabooTypesTests",
            dependencies: ["PeekabooTypes"],
            swiftSettings: approachableConcurrencySettings + [
                .enableExperimentalFeature("SwiftTesting"),
            ]),
    ],
    swiftLanguageModes: [.v6])


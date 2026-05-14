// swift-tools-version: 6.2

import PackageDescription

let concurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
]

let testingSettings = concurrencySettings + [
    .enableExperimentalFeature("SwiftTesting"),
]

let package = Package(
    name: "peekaboo-linux",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "peekaboo-linux",
            targets: ["peekaboo-linux"]),
        .library(
            name: "PeekabooLinuxCore",
            targets: ["PeekabooLinuxCore"]),
        .library(
            name: "PeekabooLinuxCLI",
            targets: ["PeekabooLinuxCLI"]),
    ],
    dependencies: [
        .package(path: "../../Core/PeekabooTypes"),
    ],
    targets: [
        .target(
            name: "PeekabooLinuxCore",
            dependencies: [
                .product(name: "PeekabooTypes", package: "PeekabooTypes"),
            ],
            swiftSettings: concurrencySettings),
        .target(
            name: "PeekabooLinuxCLI",
            dependencies: [
                "PeekabooLinuxCore",
                .product(name: "PeekabooTypes", package: "PeekabooTypes"),
            ],
            swiftSettings: concurrencySettings),
        .executableTarget(
            name: "peekaboo-linux",
            dependencies: [
                "PeekabooLinuxCLI",
                "PeekabooLinuxCore",
            ],
            path: "Sources/PeekabooLinuxExec",
            swiftSettings: concurrencySettings),
        .testTarget(
            name: "PeekabooLinuxCoreTests",
            dependencies: [
                "PeekabooLinuxCore",
                .product(name: "PeekabooTypes", package: "PeekabooTypes"),
            ],
            swiftSettings: testingSettings),
        .testTarget(
            name: "PeekabooLinuxCLITests",
            dependencies: [
                "PeekabooLinuxCLI",
                "PeekabooLinuxCore",
            ],
            swiftSettings: testingSettings),
    ],
    swiftLanguageModes: [.v6])

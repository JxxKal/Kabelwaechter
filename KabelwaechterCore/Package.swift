// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KabelwaechterCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "KabelwaechterCore",
            targets: ["KabelwaechterCore"]
        ),
        .library(
            name: "KabelwaechterPersistence",
            targets: ["KabelwaechterPersistence"]
        )
    ],
    targets: [
        .target(name: "KabelwaechterCore"),
        .target(
            name: "KabelwaechterPersistence",
            dependencies: ["KabelwaechterCore"]
        ),
        .testTarget(
            name: "KabelwaechterCoreTests",
            dependencies: ["KabelwaechterCore"]
        ),
        .testTarget(
            name: "KabelwaechterPersistenceTests",
            dependencies: ["KabelwaechterPersistence"]
        )
    ]
)

// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KabelwaechterCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "KabelwaechterCore",
            targets: ["KabelwaechterCore"]
        ),
    ],
    targets: [
        .target(name: "KabelwaechterCore"),
        .testTarget(
            name: "KabelwaechterCoreTests",
            dependencies: ["KabelwaechterCore"]
        ),
    ]
)

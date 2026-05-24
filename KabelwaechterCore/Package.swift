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
        ),
        .library(
            name: "KabelwaechterUI",
            targets: ["KabelwaechterUI"]
        )
    ],
    targets: [
        .target(name: "KabelwaechterCore"),
        .target(
            name: "KabelwaechterPersistence",
            dependencies: ["KabelwaechterCore"]
        ),
        // Reines Präsentations-Designsystem (SwiftUI) — keine Core/Persistence-
        // Abhängigkeit. Tokens, Modifiers, Primitives + Tunnel-Visualisierung.
        // Colors.xcassets als Resource → benannte Farben (KW/cyan …) via
        // Bundle.module, designer-editierbar ohne Recompile.
        .target(
            name: "KabelwaechterUI",
            resources: [.process("Colors.xcassets")]
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

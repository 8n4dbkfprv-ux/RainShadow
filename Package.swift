// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RainShadowCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "RainShadowCore", targets: ["RainShadowCore"])
    ],
    targets: [
        .target(
            name: "RainShadowCore",
            path: "RainShadow Shared/Gameplay/Navigation",
            // Finder "Name 2.swift" duplicates break the target with redeclarations.
            exclude: ["DialogueStateModels 2.swift"]
        ),
        .target(
            name: "RainShadowPersistence",
            path: "RainShadow Shared/Core/Persistence"
        ),
        .testTarget(
            name: "RainShadowCoreTests",
            dependencies: ["RainShadowCore", "RainShadowPersistence"],
            path: "Tests/RainShadowCoreTests",
            exclude: ["DialogueStateModelsTests 2.swift"]
        )
    ]
)

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
            // Shipped dialogue packages (also under RainShadow Shared/Resources/Dialogue for the app).
            resources: [
                .copy("../../Resources/Dialogue"),
                .copy("../../Resources/Items")
            ]
        ),
        .target(
            name: "RainShadowPersistence",
            path: "RainShadow Shared/Core/Persistence"
        ),
        .testTarget(
            name: "RainShadowCoreTests",
            dependencies: ["RainShadowCore", "RainShadowPersistence"],
            path: "Tests/RainShadowCoreTests",
            // Loaded via filesystem path in DialogueGraphLoaderTests (#filePath).
            exclude: ["Fixtures"]
        )
    ]
)

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
            // Shipped content packages (also under RainShadow Shared/Resources for the app).
            resources: [
                .copy("../../Resources/Dialogue"),
                .copy("../../Resources/Items"),
                .copy("../../Resources/Areas"),
                // BG:EE gradient tables read by IEGradientTables (Art/IE/pal*.bin).
                .copy("../../Resources/Art/IE")
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

import CoreGraphics
import Foundation
import ImageIO
import Testing

struct LootUIAssetTests {
    private struct Contract {
        let relativePath: String
        let width: Int
        let height: Int
    }

    private let contracts = [
        Contract(
            relativePath: "RainShadow Shared/Resources/Art/UI/HUD/hud_loot_container_panel_v02.png",
            width: 1_600,
            height: 320
        ),
        Contract(
            relativePath: "RainShadow Shared/Resources/Art/UI/HUD/hud_loot_take_all_v03.png",
            width: 256,
            height: 256
        ),
        Contract(
            relativePath: "RainShadow Shared/Resources/Art/UI/Inventory/inventory_section_bag_v06.png",
            width: 1_680,
            height: 190
        )
    ]

    @Test func generatedLootChromeMatchesRuntimePNGContracts() throws {
        for contract in contracts {
            let decoded = try decode(repositoryRoot().appendingPathComponent(contract.relativePath))
            #expect(decoded.width == contract.width, "Wrong width for \(contract.relativePath)")
            #expect(decoded.height == contract.height, "Wrong height for \(contract.relativePath)")

            let cornerOffsets = [
                3,
                (decoded.width - 1) * 4 + 3,
                ((decoded.height - 1) * decoded.width) * 4 + 3,
                (decoded.width * decoded.height - 1) * 4 + 3
            ]
            for offset in cornerOffsets {
                #expect(decoded.rgba[offset] <= 16, "Opaque corner in \(contract.relativePath)")
            }

            var visiblePixels = 0
            var residualChromaPixels = 0
            for index in stride(from: 0, to: decoded.rgba.count, by: 4) {
                let red = decoded.rgba[index]
                let green = decoded.rgba[index + 1]
                let blue = decoded.rgba[index + 2]
                let alpha = decoded.rgba[index + 3]
                if alpha > 16 {
                    visiblePixels += 1
                    if green > 240 && red < 32 && blue < 32 {
                        residualChromaPixels += 1
                    }
                }
            }
            #expect(visiblePixels > decoded.width * decoded.height / 10)
            #expect(residualChromaPixels == 0, "Residual chroma in \(contract.relativePath)")
        }
    }

    @Test func newAssetsArePreloadedAndIncludedInBothAppTargets() throws {
        let root = repositoryRoot()
        let preload = try String(
            contentsOf: root.appendingPathComponent("RainShadow Shared/Core/Assets/GameArt.swift"),
            encoding: .utf8
        )
        #expect(preload.contains("\"hud_loot_container_panel_v02\""))
        #expect(preload.contains("\"hud_loot_take_all_v03\""))
        #expect(preload.contains("\"inventory_section_bag_v06\""))
        #expect(!preload.contains("\"hud_loot_container_panel_v01\""))
        #expect(!preload.contains("\"hud_loot_take_all_v02\""))
        #expect(!preload.contains("\"hud_loot_take_all_v01\""))
        #expect(!preload.contains("\"inventory_section_nearby_v05\""))
        #expect(!preload.contains("\"inventory_section_bag_v05\""))

        let project = try String(
            contentsOf: root.appendingPathComponent("RainShadow.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        for path in [
            "Resources/Art/UI/HUD/hud_loot_container_panel_v02.png",
            "Resources/Art/UI/HUD/hud_loot_take_all_v03.png",
            "Resources/Art/UI/Inventory/inventory_section_bag_v06.png",
            "UI/LootContainerPanelNode.swift"
        ] {
            #expect(project.components(separatedBy: path).count - 1 == 2, "Target membership missing for \(path)")
        }
        #expect(!project.contains("Resources/Art/UI/HUD/hud_loot_container_panel_v01.png"))
        #expect(!project.contains("Resources/Art/UI/HUD/hud_loot_take_all_v02.png"))
        #expect(!project.contains("Resources/Art/UI/HUD/hud_loot_take_all_v01.png"))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func decode(_ url: URL) throws -> (rgba: [UInt8], width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        #expect(image.alphaInfo != .none)
        #expect(image.alphaInfo != .noneSkipFirst)
        #expect(image.alphaInfo != .noneSkipLast)

        let width = image.width
        let height = image.height
        var premultiplied = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &premultiplied,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var straight = premultiplied
        for index in stride(from: 0, to: straight.count, by: 4) {
            let alpha = premultiplied[index + 3]
            guard alpha > 0, alpha < 255 else { continue }
            for channel in 0..<3 {
                straight[index + channel] = UInt8(min(
                    255,
                    (Int(premultiplied[index + channel]) * 255 + Int(alpha) / 2) / Int(alpha)
                ))
            }
        }
        return (straight, width, height)
    }
}

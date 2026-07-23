import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

struct HotspotHoverHighlightTests {
    private let desk = HotspotHoverHighlight.Target(
        id: "office.desk",
        hitArea: CGRect(x: 100, y: 200, width: 200, height: 150)
    )
    private let window = HotspotHoverHighlight.Target(
        id: "office.window",
        hitArea: CGRect(x: 0, y: 400, width: 80, height: 120)
    )
    private let phone = HotspotHoverHighlight.Target(
        id: "office.phone",
        hitArea: CGRect(x: 250, y: 280, width: 60, height: 40)
    )

    private var targets: [HotspotHoverHighlight.Target] { [desk, window, phone] }

    @Test func selectedIDUsesTheFirstContainingHotspot() {
        #expect(HotspotHoverHighlight.selectedID(
            at: CGPoint(x: 150, y: 250), among: targets
        ) == "office.desk")
        #expect(HotspotHoverHighlight.selectedID(
            at: CGPoint(x: 280, y: 300), among: [phone, desk]
        ) == "office.phone")
        #expect(HotspotHoverHighlight.selectedID(
            at: CGPoint(x: 10, y: 10), among: targets
        ) == nil)
    }

    @Test func presentationIsVisibleOnlyForAnUnblockedHit() {
        let hit = HotspotHoverHighlight.presentation(
            at: CGPoint(x: 40, y: 450),
            among: targets,
            worldInteractionBlocked: false
        )
        #expect(hit == .init(isVisible: true, hotspotID: "office.window"))

        #expect(HotspotHoverHighlight.presentation(
            at: CGPoint(x: 40, y: 450),
            among: targets,
            worldInteractionBlocked: true
        ) == .hidden)
        #expect(HotspotHoverHighlight.presentation(
            at: nil,
            among: targets,
            worldInteractionBlocked: false
        ) == .hidden)
    }

    @Test func authoredOfficeHotspotsRemainSelectable() {
        let targets = HotspotHoverHighlight.targets(
            from: OfficeNavigationLayout.authoredHotspots.map {
                (id: $0.id, hitArea: OfficeInteriorScale.mapRect($0.hitArea))
            }
        )
        for id in ["office.desk", "office.window", "office.door", "office.phone", "office.files"] {
            guard let target = targets.first(where: { $0.id == id }) else {
                #expect(Bool(false), "Missing authored hotspot \(id)")
                continue
            }
            let midpoint = CGPoint(x: target.hitArea.midX, y: target.hitArea.midY)
            #expect(HotspotHoverHighlight.selectedID(at: midpoint, among: targets) != nil)
        }
    }

    @Test func officeSceneUsesOnlyPrebakedHoverTextureSwaps() throws {
        let source = try officeSceneSource()
        #expect(source.contains("GameArt.standaloneTexture(named: \"\\(assetName)_hover\")"))
        #expect(source.contains("entry.sprite.texture = entry.hoverTexture"))
        #expect(source.contains("entry.sprite.texture = entry.normalTexture"))

        for forbidden in [
            "SKShader", ".shader =", "colorBlendFactor", "hoverEdgeTextureCache",
            "makeCyanEdge", "cyanEdgeTexture", "applyHoverWashAndEdgeOverlay",
            "CGImageSource"
        ] {
            #expect(!source.contains(forbidden), "Runtime hover rendering remains: \(forbidden)")
        }
    }

    @Test func deskRegistersEveryDeskLayerButNoLooseDeskObjects() throws {
        let source = try officeSceneSource()
        #expect(source.contains("registerHoverSprite(deskBare, for: \"office.desk\")"))
        #expect(source.contains("registerHoverSprite(deskActorOccluder, for: \"office.desk\")"))
        #expect(source.contains("registerHoverSprite(deskFrontOccluder, for: \"office.desk\")"))
        #expect(source.contains("registerHoverSprite(window, for: \"office.window\")"))
        #expect(source.contains("registerHoverSprite(officeDoor, for: \"office.door\")"))

        for line in source.components(separatedBy: .newlines)
        where line.contains("registerHoverSprite") && line.contains("office.desk") {
            for looseObject in ["chair", "papers", "files", "lamp", "phone", "mug", "ashtray"] {
                #expect(!line.contains(looseObject), "Loose object joined desk hover: \(line)")
            }
        }
    }

    @Test func everyOfficeHoverPNGMatchesItsSourceAndContainsTheBakedEffect() throws {
        let root = repositoryRoot()
        let art = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Props/Office"
        )
        let names = [
            "office_window", "office_door_leaf", "office_desk_bare",
            "office_desk_actor_occluder", "office_desk_front_occluder_v04",
            "office_desk_phone", "office_desk_files"
        ]

        for name in names {
            let normal = try loadStraightRGBA(from: art.appendingPathComponent("\(name).png"))
            let hover = try loadStraightRGBA(from: art.appendingPathComponent("\(name)_hover.png"))
            #expect(normal.width == hover.width, "Width mismatch for \(name)")
            #expect(normal.height == hover.height, "Height mismatch for \(name)")

            var cyanPixels = 0
            var washedBodyPixels = 0
            for index in stride(from: 0, to: hover.rgba.count, by: 4) {
                let cyan = hover.rgba[index] <= 15
                    && hover.rgba[index + 1] >= 240
                    && hover.rgba[index + 2] >= 240
                    && hover.rgba[index + 3] >= 46
                if cyan { cyanPixels += 1 }

                let sourceIsBody = normal.rgba[index + 3] >= 46
                let difference = abs(Int(normal.rgba[index]) - Int(hover.rgba[index]))
                    + abs(Int(normal.rgba[index + 1]) - Int(hover.rgba[index + 1]))
                    + abs(Int(normal.rgba[index + 2]) - Int(hover.rgba[index + 2]))
                if sourceIsBody && !cyan && difference >= 10 { washedBodyPixels += 1 }
            }
            #expect(cyanPixels > 20, "Missing cyan silhouette rim in \(name)_hover")
            #expect(washedBodyPixels > 100, "Missing teal body treatment in \(name)_hover")
        }
    }

    private func officeSceneSource() throws -> String {
        let url = repositoryRoot().appendingPathComponent(
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadStraightRGBA(from url: URL) throws -> (rgba: [UInt8], width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let width = image.width
        let height = image.height
        var premultiplied = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &premultiplied,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
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

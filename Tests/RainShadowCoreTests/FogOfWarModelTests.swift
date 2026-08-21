import Foundation
import Testing
@testable import RainShadowCore

/// Fog keeps two bitmaps, the way an Infinity Engine area does.
///
/// `Map::UpdateFog` refills `VisibleBitmap` from the party's line of sight every
/// frame and leaves `ExploredBitmap` alone; the area draws their combination in
/// three states — opaque where never seen, partial where seen but not in sight,
/// clear where in sight. RainShadow drew two of those three until this landed,
/// and the office actively un-explored ground it had already shown, which the
/// engine never does.
///
/// Source-text assertions because the renderer and the node live in the app
/// target, beside `BaseGameScene`, where a unit test cannot reach them — the
/// same reason `LootPanelIntegrationTests` reads its subjects as text.
struct FogOfWarModelTests {
    private static let renderer = "RainShadow Shared/Core/Scene/FogMaskRenderer.swift"
    private static let node = "RainShadow Shared/Core/Scene/FogOfWarNode.swift"
    private static let scenes = [
        "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift",
        "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
    ]

    /// The remembered layer is painted once and reused; the live pool is cut
    /// through a copy of it. Rebuilding memory on every step instead would make
    /// walking cost more the longer you had walked.
    @Test func memoryAndSightArePaintedSeparately() throws {
        let source = try read(Self.renderer)

        #expect(source.contains("func makeExploredMask(remembering reveals: [Reveal]) -> CGImage?"))
        #expect(source.contains("func makeTexture(exploredMask: CGImage?, seeing visible: Reveal?)"))
        #expect(source.contains("var exploredDimming: CGFloat"))
    }

    /// Remembered ground is lifted to exactly `exploredDimming` by painting the
    /// dimming *under* what the erase left, so the four overlapping feather
    /// rings cannot compound into some other value.
    @Test func rememberedGroundIsLiftedRatherThanErasedPartway() throws {
        let source = try read(Self.renderer)
        let mask = try #require(source.range(of: "func makeExploredMask"))
        let end = try #require(source.range(of: "\n    }\n", range: mask.upperBound..<source.endIndex))
        let body = source[mask.upperBound..<end.lowerBound]

        #expect(body.contains(".destinationOver"))
        #expect(body.contains("style.exploredDimming"))
        // The pools themselves still erase to nothing; the dimming is a separate
        // pass. Scaling their alphas instead is the mistake this guards.
        #expect(!body.contains("layer.alpha * "))
    }

    /// The live pool erases to full transparency through whatever memory holds,
    /// so sight that has run ahead of the last remembered pool is lit rather
    /// than clipped back to it.
    @Test func sightCutsThroughMemoryRatherThanBeingBoundedByIt() throws {
        let source = try read(Self.renderer)
        let make = try #require(source.range(of: "func makeTexture(exploredMask:"))
        let end = try #require(source.range(of: "\n    }\n", range: make.upperBound..<source.endIndex))
        let body = source[make.upperBound..<end.lowerBound]

        #expect(body.contains(".destinationOut"))
        #expect(body.contains("erasePool(visible"))
    }

    /// An area never un-explores. The office used to: it kept the last eight
    /// places Voss stood and dropped the rest, so a room he had crossed went
    /// black again behind him.
    @Test func memoryOnlyEverGrows() throws {
        let source = try read(Self.node)

        #expect(source.contains("private(set) var rememberedPoints: [CGPoint] = []"))
        #expect(source.contains("rememberedPoints.append("))
        for shrink in ["rememberedPoints.removeFirst", "rememberedPoints.removeAll",
                       "rememberedPoints.removeLast", "rememberedPoints = ["] {
            #expect(!source.contains(shrink), "\(shrink) would let an area forget")
        }
        // Its reveals are kept in step, or the mask would disagree with the list
        // the caller persists.
        #expect(source.contains("rememberedReveals.append("))
        #expect(!source.contains("rememberedReveals.removeFirst"))
    }

    /// Both areas run the one fog node. They were two classes because the office
    /// was faking memory with a trail; with a real remembered layer the only
    /// difference left is whether the caller writes the points to the save.
    @Test func bothAreasShareOneFogImplementation() throws {
        for path in Self.scenes {
            let scene = try read(path)
            #expect(scene.contains("FogOfWarNode"))
            #expect(!scene.contains("class OfficeFogOfWarNode"))
            #expect(!scene.contains("class CityFogOfWarNode"))
            #expect(!scene.contains("pointCapacity"))
            #expect(!scene.contains("func updateFogTexture"))
        }

        // A district persists what it remembers; a room does not.
        let city = try read(Self.scenes[1])
        #expect(city.contains("cityFogRevealPoints(for: district.id)"))
        #expect(city.contains("recordCityFogReveal"))
    }

    /// The other half of what two bitmaps are for: the engine skips *drawing* a
    /// creature outside `VisibleBitmap` and changes nothing else about it.
    @Test func creaturesAreGatedOnSightRatherThanRemovedFromTheWorld() throws {
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")
        let node = try read(Self.node)

        #expect(node.contains("func isVisible(_ worldPoint: CGPoint) -> Bool"))
        #expect(node.contains("func isExplored(_ worldPoint: CGPoint) -> Bool"))
        #expect(base.contains("func addFogGated(_ actor: SKNode, to parent: SKNode) -> SKNode"))
        #expect(base.contains("func updateFogGating(_ fog: FogOfWarNode?)"))

        // The gate is a parent, not a flag on the creature. Setting `isHidden`
        // would fight `ClientActorNode`, which owns it, and would corrupt the
        // three places the office reads it to mean "she is in the room".
        let gate = try #require(base.range(of: "func updateFogGating"))
        let end = try #require(base.range(of: "\n    }\n", range: gate.upperBound..<base.endIndex))
        let body = base[gate.upperBound..<end.lowerBound]
        #expect(body.contains("gate.isHidden"))
        #expect(!body.contains("actor.isHidden"))
    }

    /// The office registers its NPC and gates nothing else — least of all the
    /// player, who is what sight is measured from.
    @Test func theOfficeGatesItsClientAndNotItsPlayer() throws {
        let office = try read(Self.scenes[0])

        #expect(office.contains("addFogGated(client, to: depthWorldRoot)"))
        #expect(office.contains("updateFogGating(fogOfWar)"))
        #expect(!office.contains("addFogGated(detective"))

        // Fog must never be the thing that writes the creature's own flag.
        for assignment in ["client.isHidden = !", "client.isHidden = fog", "client.isHidden = isVisible"] {
            #expect(!office.contains(assignment))
        }
    }

    private func read(_ relativePath: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

import Foundation
import Testing
@testable import RainShadowCore

/// Fog keeps two bitmaps, the way an Infinity Engine area does.
///
/// `Map::UpdateFog` refills `VisibleBitmap` from the party's line of sight and
/// leaves `ExploredBitmap` alone; the area draws their combination in three
/// states — opaque where never seen, partial where seen but not in sight, clear
/// where in sight.
///
/// The grid and the mask themselves are unit-tested in `FogGridTests`, which is
/// possible because `FogGrid` lives in this target. These are source-text
/// assertions because the renderer and the node live in the app target, beside
/// `BaseGameScene`, where a unit test cannot reach them — the same reason
/// `LootPanelIntegrationTests` reads its subjects as text.
struct FogOfWarModelTests {
    private static let renderer = "RainShadow Shared/Core/Scene/FogMaskRenderer.swift"
    private static let node = "RainShadow Shared/Core/Scene/FogOfWarNode.swift"
    private static let scenes = [
        "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift",
        "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
    ]

    /// The texture is the FOGOWAR compositor: cell interiors plus BG:EE corner
    /// fans. Nothing paints a pool, feathers a ring, or blurs a clip.
    @Test func theMaskIsRasterisedFromCellsRatherThanPainted() throws {
        let source = try read(Self.renderer)

        #expect(source.contains("func makeTexture(explored: Set<FogCell>, visible: Set<FogCell>)"))
        #expect(source.contains("grid.displayMask(explored: explored, visible: visible)"))
        for painted in [
            "featherLayers", "edgeHarmonics", "revealRadius", "segmentCount",
            "erasePool", "edgePath", "applyingGaussianBlur", "CIContext",
            "setBlendMode(.destinationOut)", "setBlendMode(.destinationOver)"
        ] {
            #expect(!source.contains(painted), "\(painted) is painting the fog again")
        }
    }

    /// The edge is BG:EE per-corner Gouraud at 32 px/cell, sampled nearest.
    /// Linear filtering was the blob that made indoor fog a spotlight.
    @Test func theEdgeIsAutotiledRatherThanAFilterRamp() throws {
        let source = try read(Self.renderer)
        let grid = try read("RainShadow Shared/Gameplay/Navigation/FogGrid.swift")
        let edges = try read("RainShadow Shared/Gameplay/Navigation/FogEdgeMask.swift")

        #expect(source.contains("filteringMode = .nearest"))
        #expect(source.contains("premultipliedLast"))
        #expect(grid.contains("cellPixelSize = 32"))
        #expect(grid.contains("texturePixelsPerCell = 8"))
        #expect(edges.contains("BltFogOWar3d"))
        #expect(edges.contains("func fanSample"))
        #expect(!source.contains("filteringMode = .linear"))
        #expect(!edges.contains("static let referenceFalloff"))
    }

    /// An area never un-explores. Memory only ever unions.
    @Test func memoryOnlyEverGrows() throws {
        let source = try read(Self.node)

        #expect(source.contains("private(set) var exploredCells: Set<FogCell>"))
        #expect(source.contains("exploredCells.formUnion("))
        for shrink in [
            "exploredCells.subtract", "exploredCells.removeAll",
            "exploredCells.remove(", "exploredCells = []"
        ] {
            #expect(!source.contains(shrink), "\(shrink) would let an area forget")
        }
        // The old point-trail representation is gone, along with the spacing
        // constant that existed only to keep it affordable.
        for stale in ["rememberedPoints", "rememberedReveals", "memorySpacing", "sightStep"] {
            #expect(!source.contains(stale))
        }
    }

    /// Sight is a creature stat, not a consequence of how big the artist drew
    /// the lit pool.
    @Test func sightRangeComesFromTheAreaRecord() throws {
        let node = try read(Self.node)
        #expect(node.contains("visualRangeInCells"))
        #expect(node.contains("SearchMapExplore.searchRadius"))
        #expect(!node.contains("visibilityRadiusInCells"))

        for path in Self.scenes {
            let scene = try read(path)
            #expect(scene.contains("visualRangeInCells: area.agentProfile.visualRangeInCells"))
        }

        // And the record's own default is the engine's stat #262.
        #expect(AreaAgentProfile.defaultVisualRangeInCells == 14)
        #expect(AreaAgentProfile.visualRangeBounds == 0...15)
        #expect(SearchMapExplore.searchRadius(visualRangeInFogTiles: AreaAgentProfile.defaultVisualRangeInCells) == 30)
        #expect(AreaAgentProfile(halfWidth: 1, halfHeight: 1, visualRangeInCells: 99)
            .visualRangeInCells == 15)
    }

    /// A door changes what can be seen without anyone moving, so the office
    /// refills sight when the leaf swings rather than waiting for a step.
    @Test func aSwingingDoorRefillsSight() throws {
        let node = try read(Self.node)
        let office = try read(Self.scenes[0])

        #expect(node.contains("func invalidateSight(from worldPoint: CGPoint)"))
        #expect(office.contains("private func setEntranceDoorBlocking(_ blocking: Bool)"))
        #expect(office.contains("fog.invalidateSight(from: detective.position)"))
        // Every door call site goes through the wrapper, or one of them will
        // eventually swing a door past a fog that never hears about it.
        #expect(office.range(of: "navigation.setEntranceDoorBlocking(") != nil)
        #expect(
            office.components(separatedBy: "navigation.setEntranceDoorBlocking(").count - 1 == 1,
            "a door call site bypasses the fog-aware wrapper"
        )
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

        // The gate is a parent, not a flag on the creature. Drawing uses the
        // sprite AABB so a body on the fog edge is clipped by the overlay.
        let gate = try #require(base.range(of: "func updateFogGating"))
        let end = try #require(base.range(of: "\n    }\n", range: gate.upperBound..<base.endIndex))
        let body = base[gate.upperBound..<end.lowerBound]
        #expect(body.contains("gate.isHidden"))
        #expect(body.contains("intersectsVisible"))
        #expect(!body.contains("actor.isHidden"))
        #expect(node.contains("func intersectsVisible(_ worldRect: CGRect)"))
    }

    @Test func theOfficeFloodsRoomsAndTheCityDoesNot() throws {
        let office = try read(Self.scenes[0])
        let city = try read(Self.scenes[1])
        let node = try read(Self.node)
        let gameArea = try read("RainShadow Shared/Core/Scene/GameAreaScene.swift")

        #expect(node.contains("fillsEnclosedRooms"))
        #expect(node.contains("outdoorDoorShroud"))
        #expect(office.contains("fillsEnclosedRooms: true"))
        #expect(!city.contains("fillsEnclosedRooms: true"))
        #expect(city.contains("outdoorDoorShroud: outdoorDoorShroud"))
        #expect(city.contains("cityDay"))
        #expect(gameArea.contains("class GameAreaScene"))
        #expect(gameArea.contains("setExtendedNight"))
        #expect(gameArea.contains("toggleDoorOutlineHighlight"))
        #expect(!office.contains("addShellVignette"))
        #expect(!office.contains("office_shadow_vignette"))
    }

    /// The office registers its NPC and gates nothing else — least of all the
    /// player, who is what sight is measured from.
    @Test func theOfficeGatesItsClientAndNotItsPlayer() throws {
        let office = try read(Self.scenes[0])

        #expect(office.contains("addFogGated(client, to: depthWorldRoot)"))
        #expect(office.contains("updateFogGating(fogOfWar)"))
        #expect(!office.contains("addFogGated(detective"))

        for assignment in ["client.isHidden = !", "client.isHidden = fog", "client.isHidden = isVisible"] {
            #expect(!office.contains(assignment))
        }
    }

    /// Both areas run the one fog node, and part company only over whether the
    /// caller keeps what was explored.
    @Test func bothAreasShareOneFogImplementation() throws {
        for path in Self.scenes {
            let scene = try read(path)
            #expect(scene.contains("FogOfWarNode"))
            #expect(!scene.contains("class OfficeFogOfWarNode"))
            #expect(!scene.contains("class CityFogOfWarNode"))
            #expect(!scene.contains("func updateFogTexture"))
        }

        // Both now persist, and both key it the way the engine does — by area,
        // not by district. The office having nowhere to store its bitmask is
        // what made Voss's own room start black on every single entry.
        for path in Self.scenes {
            let scene = try read(path)
            #expect(scene.contains("context.session.exploredFogCells(for: area.id, on: grid)"))
            #expect(scene.contains("context.session.recordExploredFog("))
            #expect(!scene.contains("cityExploredFogCells"))
            #expect(!scene.contains("recordCityFogExplored"))
        }
    }

    /// An area you have walked is still drawn when you come back to it. The
    /// bitmask goes to the save, which is where BG keeps it.
    @Test func exploredGroundOutlivesTheVisitAndTheSession() throws {
        let session = try read("RainShadow Shared/App/GameBootstrap.swift")
        let store = try read("RainShadow Shared/Core/Persistence/SaveStore.swift")

        #expect(session.contains("private var fogByArea: [AreaID: FogBitmask]"))
        #expect(session.contains("func exploredFogCells(for areaID: AreaID, on grid: FogGrid)"))
        #expect(session.contains("func recordExploredFog(_ areaID: AreaID, cells: Set<FogCell>, on grid: FogGrid)"))
        #expect(session.contains("func flushPendingFogPersist()"))
        #expect(session.contains("scheduleFogPersist"))
        // Keyed by area, so an interior is not a special case.
        #expect(!session.contains("cityFogByDistrict"))
        #expect(!session.contains("[CityDistrictID: Set<FogCell>]"))

        #expect(store.contains("var exploredFog: [String: PersistedExploredFog]"))
        #expect(store.contains("struct PersistedExploredFog"))
        // Additive with a default, so a save written before this loads with
        // nothing explored instead of failing.
        #expect(store.contains("var exploredFog: [String: PersistedExploredFog] = [:]"))
    }

    /// The area map draws the same explored bitmap rather than computing its own
    /// exploration from a radius, which is how it used to disagree with the world.
    @Test func theAreaMapDrawsTheExploredBitmap() throws {
        let overlay = try read("RainShadow Shared/UI/AreaMapOverlay.swift")
        let node = try read(Self.node)

        #expect(node.contains("func exploredMapTexture() -> SKTexture?"))
        #expect(overlay.contains("func updateExploredFog(_ texture: SKTexture?)"))
        for stale in ["revealRadius", "revealedPoints", "updateExploredPoints", "revealPath"] {
            #expect(!overlay.contains(stale), "the map is still drawing its own reveal")
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

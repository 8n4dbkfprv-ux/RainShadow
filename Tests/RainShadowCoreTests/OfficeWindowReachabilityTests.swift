import CoreGraphics
import Testing
@testable import RainShadowCore

struct OfficeWindowReachabilityTests {
    // Measured on the installed 4096×2304 suite painting, y down. These
    // points follow the clear floor 50 px in front of the two window bays.
    // They deliberately do not derive from the room's inscribed plan diamond.
    static let windowFloor = [
        CGPoint(x: 1300, y: 1205), CGPoint(x: 1400, y: 1140),
        CGPoint(x: 1500, y: 1075), CGPoint(x: 1600, y: 1010),
    ]

    static func world(_ pixel: CGPoint) -> CGPoint {
        OfficeInteriorScale.mapPoint(CGPoint(x: pixel.x, y: 2304 - pixel.y))
    }

    @Test func bothWindowBaysAreExactlyReachableFromTheApartmentEntrance() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let map = area.makeNavigationMap()
        let start = try #require(area.spawnPoint(entrance: "from.city"))
        for pixel in Self.windowFloor {
            let target = Self.world(pixel)
            #expect(map.isOrderableFloor(target), "Visible window floor is blocked: \(pixel)")
            #expect(map.reachesExactly(from: start, to: target), "Window floor cannot be reached: \(pixel)")
        }
    }

    @Test func theWindowWallAndFlankingRadiatorsStayBlocked() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let map = area.makeNavigationMap()
        // Wall below each sill, plus the floor footprints of both radiators.
        for pixel in [CGPoint(x: 1300, y: 1100), CGPoint(x: 1570, y: 925),
                      CGPoint(x: 1160, y: 1230), CGPoint(x: 1780, y: 820)] {
            #expect(!map.isOrderableFloor(Self.world(pixel)), "Fixture/wall became walkable: \(pixel)")
        }
    }

    @Test func gemrbSightRevealsBothWindowFacesAndStopsBeyondTheWall() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let map = area.makeNavigationMap().searchMap
        let radius = SearchMapExplore.searchRadius(
            visualRangeInFogTiles: area.agentProfile.visualRangeInCells
        )
        // Corners inset into the independently registered painted apertures.
        let windowPixels = [
            [CGPoint(x: 1250, y: 1050), CGPoint(x: 1250, y: 935),
             CGPoint(x: 1330, y: 890), CGPoint(x: 1330, y: 1005)],
            [CGPoint(x: 1530, y: 875), CGPoint(x: 1530, y: 745),
             CGPoint(x: 1605, y: 705), CGPoint(x: 1605, y: 830)],
        ]
        for (standing, windows) in zip([Self.windowFloor[0], Self.windowFloor[3]], windowPixels) {
            // The literal ExploreMapChunk port alone must reveal the wall;
            // neither enclosedFloor nor fog-grid wall expansion is used here.
            let visible = map.visibleCells(from: Self.world(standing), radiusInCells: radius)
            for pixel in windows {
                let cell = map.cell(for: Self.world(pixel))
                #expect(map.terrain(at: cell) == .wall, "Window is not SIDEWALL: \(pixel)")
                #expect(visible.contains(cell), "GemRB sight stopped below window: \(pixel)")
                #expect(!map.isPassable(at: Self.world(pixel), radius: 3))
            }
            for pixel in [CGPoint(x: 1300, y: 600), CGPoint(x: 1600, y: 390)] {
                #expect(!visible.contains(map.cell(for: Self.world(pixel))),
                        "Sight escaped past the painted wall into the void: \(pixel)")
            }
        }
    }
}

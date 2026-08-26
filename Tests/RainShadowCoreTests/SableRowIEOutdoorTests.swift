import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Sable Row Infinity Engine outdoor contract (day plate, Extended Night hook,
/// fog-only street doors, roofs as search type 13).
struct SableRowIEOutdoorTests {
    @Test func sableRowAuthorsADayPlateAndNightPlaceholder() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        #expect(area.kind == .exterior)
        #expect(area.plateTextureName == "city_sable_row_day_v01")
        #expect(area.nightPlateTextureName == "city_sable_row_night_placeholder_v01")
        #expect(area.props.isEmpty, "doors and lots belong in the plate, not overlays")
    }

    @Test func sableRowDoorIsFogOnlyWhenClosedAndClearsWhenOpen() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        let door = try #require(area.doors.first { $0.id == "portal.office" })
        #expect(door.startsClosed)
        #expect(door.blocksSight)
        #expect(!door.approachPoints.isEmpty)

        let closed = area.makeNavigationMap()
        let approach = try #require(area.spawnPoint(entrance: "from.office"))
        let closedSight = closed.searchMap.exploreMapChunk(
            from: approach,
            radiusInCells: 20,
            outdoorDoorShroud: true
        )
        #expect(!closedSight.exploredOnly.isEmpty, "closed outdoor door must shroud beyond")
        #expect(closedSight.exploredOnly.isDisjoint(with: closedSight.visible))

        closed.setActiveDoorObstacles([])
        let openSight = closed.searchMap.exploreMapChunk(
            from: approach,
            radiusInCells: 20,
            outdoorDoorShroud: true
        )
        #expect(openSight.exploredOnly.isEmpty, "open outdoor door is LOS, not a room flood")
        #expect(openSight.visible.count >= closedSight.visible.count)
    }

    @Test func sableRowSearchMapKeepsRoofCells() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        let map = area.makeNavigationMap().searchMap
        let roofs = map.terrainHistogram[.roof] ?? 0
        #expect(roofs > 0, "roofs must stay search type 13")
        #expect(!(SearchMapTerrain.roof.isWalkable))
        #expect(SearchMapTerrain.roof.isSeeThrough)
    }

    @Test func sableRowWallPolygonsCoverTheLattice() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        #expect(area.wallPolygons.count == CityBlockGrid.all.count)
        #expect(area.wallPolygons.allSatisfy(\.coversActors))
    }

    @Test func otherWardsStillCarryModularFacades() {
        for id in CityDistrictID.allCases where id != .sableRow {
            let sprites = CityDistrictCatalog.definition(for: id).visualSprites
            #expect(!sprites.isEmpty, "\(id) lost its modular art")
        }
    }
}

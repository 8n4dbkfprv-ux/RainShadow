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

    /// `Map::ExploreMapChunk` shrouds beyond a closed door only for
    /// `AT_OUTDOOR && !AT_CITY` — GemRB excludes cities "to avoid unnecessary
    /// shrouding". Sable Row is Outdoor|City, so its street door is a hard sight
    /// stop: there is no space behind it to remember, only the next area.
    @Test func sableRowDoorStopsSightRatherThanShroudingBecauseItIsACity() throws {
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
            outdoorDoorShroud: area.areaType.shroudsBeyondClosedDoors
        )
        #expect(area.areaType.contains(.city))
        #expect(!area.areaType.shroudsBeyondClosedDoors, "a ward must not shroud")
        #expect(closedSight.exploredOnly.isEmpty, "a city ward's closed door stops sight")
        #expect(closedSight.exploredOnly.isDisjoint(with: closedSight.visible))

        closed.setActiveDoorObstacles([])
        let openSight = closed.searchMap.exploreMapChunk(
            from: approach,
            radiusInCells: 20,
            outdoorDoorShroud: area.areaType.shroudsBeyondClosedDoors
        )
        #expect(openSight.exploredOnly.isEmpty, "open outdoor door is LOS, not a room flood")
        #expect(openSight.visible.count >= closedSight.visible.count)
    }

    /// The gate itself, in both directions — a rule that only ever answers "no"
    /// would pass every ward test while being wrong about the wilderness.
    @Test func theShroudGateIsOutdoorAndNotCity() {
        #expect(AreaType.outdoor.shroudsBeyondClosedDoors, "a wilderness road shrouds")
        #expect(!AreaType([.outdoor, .city]).shroudsBeyondClosedDoors, "a ward does not")
        #expect(!AreaType([]).shroudsBeyondClosedDoors, "an interior does not")
        #expect(!AreaType.city.shroudsBeyondClosedDoors)
        #expect(AreaType([.outdoor, .forest]).shroudsBeyondClosedDoors)
    }

    /// Bit values are the engine's (GemRB `Map.h`), so a record written here can
    /// be read against `AREATYPE.IDS` without a translation table.
    @Test func areaTypeBitsAreTheEnginesOwn() {
        #expect(AreaType.outdoor.rawValue == 1)
        #expect(AreaType.city.rawValue == 8)
        #expect(AreaType.forest.rawValue == 0x10)
        #expect(AreaType.dungeon.rawValue == 0x20)
        #expect(AreaType.extendedNight.rawValue == 0x40)
        #expect(AreaType.canRestIndoors.rawValue == 0x80)
    }

    /// A record authored before the field existed still reads sensibly.
    @Test func areaTypeDefaultsFromKindAndRoundTrips() throws {
        #expect(AreaType(defaultingFor: .exterior) == .outdoor)
        #expect(AreaType(defaultingFor: .interior) == [])

        let value: AreaType = [.outdoor, .city, .extendedNight]
        let data = try JSONEncoder().encode(value)
        #expect(String(decoding: data, as: UTF8.self) == #"["city","extendedNight","outdoor"]"#)
        #expect(try JSONDecoder().decode(AreaType.self, from: data) == value)
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
        #expect(area.wallPolygons.count == CityStreetPlan.all.count)
        #expect(area.wallPolygons.allSatisfy { $0.coversActors })
    }

    @Test func otherWardsStillCarryModularFacades() {
        for id in CityDistrictID.allCases where id != .sableRow {
            let sprites = CityDistrictCatalog.definition(for: id).visualSprites
            #expect(!sprites.isEmpty, "\(id) lost its modular art")
        }
    }
}

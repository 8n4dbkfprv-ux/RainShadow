import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Guards the crossing from Swift-authored geometry to authored area files.
///
/// **Transitional, and deliberately so.** While both representations exist, one
/// of them is going to drift — that is what happened to
/// `compose_city_district_preview.py`, which spent two refactors and a
/// world-size change rendering a layout nobody shipped, and it is why
/// `CityLayoutDumpTests` exists at all. These tests make the drift a red suite
/// instead of a silent divergence: change `CityDistrictCatalog` without
/// re-running `AreaExportTests` and this fails.
///
/// Delete this file at Phase 5, when the runtime reads areas directly and the
/// Swift catalogs become the offline authoring DSL that produces the JSON.
struct AreaParityTests {

    private static func loadedArea(_ id: AreaID) throws -> AreaDefinition {
        try AreaCatalogLoader.load(id)
    }

    /// The four corners a rect region is authored from.
    ///
    /// Compared instead of `boundingBox`, which is a *derived* rect: recovering
    /// `width` as `maxX - minX` is not bit-identical to the authored width when
    /// `maxX` was itself computed as `minX + width`, so a `CGRect` equality here
    /// fails on a one-ulp size difference while the outline is unchanged. The
    /// corners are what the region actually stores, and they round-trip exactly.
    private static func outline(of rect: CGRect) -> [AreaPoint] {
        let r = rect.standardized
        return [
            AreaPoint(x: r.minX, y: r.minY),
            AreaPoint(x: r.maxX, y: r.minY),
            AreaPoint(x: r.maxX, y: r.maxY),
            AreaPoint(x: r.minX, y: r.maxY)
        ]
    }

    // MARK: - Districts

    @Test(arguments: CityDistrictID.allCases)
    func theWrittenDistrictFileMatchesTheSwiftCatalog(_ district: CityDistrictID) throws {
        let projected = CityDistrictAreaAdapter.area(for: district)
        let loaded = try Self.loadedArea(projected.id)
        // Whole-record equality rather than a field list: a new section added to
        // `AreaDefinition` is then covered the day it is added, instead of the
        // day someone remembers to extend this test.
        #expect(
            loaded == projected,
            "'\(projected.id)' on disk differs from the catalog — re-run AreaExportTests"
        )
    }

    /// The numbers that pathfinding depends on must survive the JSON round trip
    /// exactly. `AGENTS.md` records three city spawns that failed re-validation
    /// purely because tidy numbers were substituted for computed ones, so an
    /// approximate match here would be worse than no test.
    @Test(arguments: CityDistrictID.allCases)
    func spawnAndApproachCoordinatesRoundTripWithoutRounding(
        _ district: CityDistrictID
    ) throws {
        let definition = CityDistrictCatalog.definition(for: district)
        let loaded = try Self.loadedArea(CityDistrictAreaAdapter.areaID(for: district))

        for (key, point) in definition.spawnByArrivalKey {
            let entrance = try #require(loaded.entrance(named: key))
            #expect(entrance.point.cgPoint == point, "entrance '\(key)' moved")
        }

        #expect(
            loaded.spawnPoint(entrance: nil) == definition.actorStart,
            "'\(district.slug)' default arrival moved off actorStart"
        )

        for portal in definition.portals {
            let region = try #require(loaded.region(id: portal.id))
            #expect(
                region.approachPoint?.cgPoint == portal.approachPoint,
                "portal '\(portal.id)' approach moved"
            )
            #expect(
                region.polygon == Self.outline(of: portal.hitArea),
                "portal '\(portal.id)' outline changed"
            )
        }
    }

    @Test(arguments: CityDistrictID.allCases)
    func obstaclesAndPropsSurviveInFull(_ district: CityDistrictID) throws {
        let definition = CityDistrictCatalog.definition(for: district)
        let loaded = try Self.loadedArea(CityDistrictAreaAdapter.areaID(for: district))

        #expect(
            loaded.obstacles.count == definition.obstacles.count,
            "'\(district.slug)' obstacle count changed"
        )
        #expect(
            loaded.obstacles.map(\.cgRect) == definition.obstacles.map(\.standardized),
            "'\(district.slug)' obstacle geometry changed"
        )
        #expect(
            loaded.props.map(\.textureName) == definition.runtimeVisualSprites.map(\.textureName),
            "'\(district.slug)' prop set changed"
        )
    }

    @Test(arguments: CityInteriorID.allCases)
    func theWrittenCityInteriorMatchesItsAreaRecord(_ interior: CityInteriorID) throws {
        let projected = CityInteriorAreaAdapter.area(for: interior)
        let loaded = try Self.loadedArea(interior.areaID)
        #expect(
            loaded == projected,
            "'\(interior.areaID)' on disk differs from its authored interior record"
        )
    }

    /// Runtime districts use their authored SR bitmap. The rectangle fallback
    /// is deliberately coarser: an IE search map can distinguish roofs, deep
    /// water and world-map exits that an obstacle AABB cannot represent.
    @Test(arguments: CityDistrictID.allCases)
    func theAreaFileUsesItsPaintedSearchMap(
        _ district: CityDistrictID
    ) throws {
        let area = try Self.loadedArea(CityDistrictAreaAdapter.areaID(for: district))
        #expect(area.searchMapName == "city_\(district.slug).sr")
        let runtime = area.makeNavigationMap().searchMap
        let expected = area.searchMapGridSize
        #expect(runtime.columns == expected.columns)
        #expect(runtime.rows == expected.rows)
    }

    // MARK: - Office

    @Test func theWrittenOfficeFileMatchesTheSwiftLayout() throws {
        let projected = OfficeAreaAdapter.area()
        let loaded = try Self.loadedArea(HarborpointAreas.office)
        #expect(
            loaded == projected,
            "office_suite on disk differs from OfficeNavigationLayout — re-run AreaExportTests"
        )
    }

    /// The office is the one area whose world does not start at the origin. If
    /// that is lost the search map is framed wrongly and every cell index shifts.
    @Test func theOfficeKeepsItsOffsetWorldFrame() throws {
        let loaded = try Self.loadedArea(HarborpointAreas.office)
        #expect(loaded.worldBounds == OfficeNavigationLayout.navigationWorldBounds)
        #expect(loaded.worldOrigin.cgPoint != .zero, "the office frame is not origin-anchored")
        #expect(
            loaded.cameraClampBounds == OfficeInteriorScale.paintedRoomBounds,
            "the office camera clamp fell back to the letterboxed plate"
        )
    }

    @Test func everyOfficeHotspotBecameARegisteredRegionWithItsApproach() throws {
        let loaded = try Self.loadedArea(HarborpointAreas.office)
        for hotspot in OfficeNavigationLayout.authoredHotspots {
            let region = try #require(loaded.region(id: hotspot.id))
            if hotspot.id == "office.door" {
                #expect(region.kind == .travel)
                #expect(region.travel == AreaTravel(
                    destination: HarborpointAreas.sableRow,
                    entrance: "from.office"
                ))
            } else {
                #expect(region.kind == .info)
            }
            #expect(region.label == hotspot.name)
            #expect(region.observation == hotspot.observation)
            #expect(
                region.approachPoint?.cgPoint == OfficeNavigationLayout.approachPoints[hotspot.id],
                "hotspot '\(hotspot.id)' approach moved"
            )
            #expect(
                region.polygon == Self.outline(of: OfficeInteriorScale.mapRect(hotspot.hitArea)),
                "hotspot '\(hotspot.id)' outline changed"
            )
        }
        #expect(loaded.region(id: "office.exit") == nil)
    }

    @Test func theOfficeCarriesItsLootContainersAndItsDoor() throws {
        let loaded = try Self.loadedArea(HarborpointAreas.office)
        for container in OfficeNavigationLayout.lootContainers {
            let carried = loaded.containers.first { $0.id == container.id }
            #expect(carried?.loot == container, "office lost container '\(container.id)'")
        }
        let door = try #require(loaded.doors.first)
        #expect(door.closedObstacle.cgRect == OfficeNavigationLayout.doorObstacle.standardized)
        #expect(door.startsClosed)
        #expect(door.textureName == nil)
        #expect(door.visual == nil, "the V19 baked door leaked back into a live texture")
    }

    /// The office used to carry a path budget three times the engine default,
    /// because the search was capped by an expanded-node count and the room with
    /// the most obstacles exhausted it. `PathFinder::FindPath` has no node
    /// budget — it is bounded by wall clock — so the field is gone, and this
    /// asserts it cannot come back by accident.
    @Test func noAreaCarriesAPathNodeBudget() throws {
        let office = try Self.loadedArea(HarborpointAreas.office)
        #expect(office.makeNavigationMap().searchMap.cellCount > 0)
        for district in CityDistrictID.allCases {
            let loaded = try Self.loadedArea(CityDistrictAreaAdapter.areaID(for: district))
            #expect(loaded.makeNavigationMap().searchMap.cellCount > 0)
        }
    }

    @Test func theOfficeSearchMapMatchesTheShippedGrid() throws {
        let fromLayout = OfficeNavigationLayout.makeGrid()
        let fromArea = try Self.loadedArea(HarborpointAreas.office).makeNavigationMap()
        #expect(fromArea.searchMap.columns == fromLayout.searchMap.columns)
        #expect(fromArea.searchMap.rows == fromLayout.searchMap.rows)
        #expect(
            fromArea.impassableCellCount == fromLayout.impassableCellCount,
            "the office blocks a different number of cells when built from its area file"
        )
    }

    // MARK: - The world hangs together

    /// The office and Sable Row must agree about the door between them: the city
    /// portal arrives at an office entrance, and the office exit arrives back at
    /// a Sable Row entrance. This is the pair that `SceneRouter` currently
    /// cannot express, because `showOffice` discards its arrival key.
    @Test func theOfficeAndSableRowAgreeAboutTheDoorBetweenThem() throws {
        let catalog = try AreaCatalogLoader.load(HarborpointAreas.shippedIDs)
        let sableRow = try #require(catalog.area(for: HarborpointAreas.sableRow))
        let office = try #require(catalog.area(for: HarborpointAreas.office))

        let intoOffice = try #require(sableRow.travelRegions.first { $0.travel?.destination == HarborpointAreas.office })
        #expect(office.entrance(named: intoOffice.travel?.entrance) != nil)

        let ontoTheStreet = try #require(office.travelRegions.first { $0.travel?.destination == HarborpointAreas.sableRow })
        #expect(sableRow.entrance(named: ontoTheStreet.travel?.entrance) != nil)
    }
}

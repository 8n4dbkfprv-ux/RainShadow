import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Wall polygons: the Infinity Engine's answer to scenery standing in front of
/// the floor, and the reason an `.ARE` needs no props section.
struct AreaWallPolygonTests {

    @Test func aCoverOutlineContainsItsInteriorAndExcludesTheOutside() {
        let wall = AreaWallPolygon(id: "w", rect: CGRect(x: 100, y: 200, width: 60, height: 40))
        #expect(wall.contains(CGPoint(x: 130, y: 220)))
        #expect(!wall.contains(CGPoint(x: 99, y: 220)))
        #expect(!wall.contains(CGPoint(x: 130, y: 241)))
        #expect(wall.boundingBox == CGRect(x: 100, y: 200, width: 60, height: 40))
    }

    /// The same reason regions are polygons: Harborpoint's geometry runs on the
    /// BG:EE ground axes, so a diagonal facade is not an AABB.
    @Test func aDiagonalCoverExcludesTheCornersItsBoundingBoxWouldClaim() {
        let wall = AreaWallPolygon(
            id: "diamond",
            polygon: [
                AreaPoint(x: 100, y: 0),
                AreaPoint(x: 200, y: 75),
                AreaPoint(x: 100, y: 150),
                AreaPoint(x: 0, y: 75)
            ]
        )
        #expect(wall.contains(CGPoint(x: 100, y: 75)))
        #expect(!wall.contains(CGPoint(x: 5, y: 5)))
    }

    /// A polygon can exist for shading without covering, which is WED flag bit 0
    /// without bits 2–3. `isCovered` must honour that rather than treating every
    /// wall as an occluder.
    @Test func aWallThatDoesNotCoverIsIgnoredByTheCoverQuery() throws {
        let inside = CGPoint(x: 50, y: 50)
        let area = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .interior,
            worldSize: AreaSize(w: 200, h: 200),
            plateTextureName: "p",
            agentProfile: AreaAgentProfile(.point),
            entrances: [AreaEntrance(name: "default", point: AreaPoint(x: 10, y: 10))],
            wallPolygons: [
                AreaWallPolygon(
                    id: "shade-only",
                    rect: CGRect(x: 0, y: 0, width: 100, height: 100),
                    coversActors: false,
                    shadesBothSides: true
                )
            ]
        )
        #expect(!area.isCovered(inside), "a shade-only wall covered an actor")

        var covering = area
        covering.wallPolygons = [
            AreaWallPolygon(id: "cover", rect: CGRect(x: 0, y: 0, width: 100, height: 100))
        ]
        #expect(covering.isCovered(inside))
    }

    @Test func aLowWallDoesNotCoverAStandingAdult() {
        let wall = AreaWallPolygon(
            id: "kerb",
            rect: CGRect(x: 0, y: 0, width: 40, height: 40),
            height: 12
        )
        let adult = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        #expect(!wall.coversActor(at: CGPoint(x: 20, y: 20), height: adult))
        #expect(wall.coversActor(at: CGPoint(x: 20, y: 20), height: 10))
    }

    @Test func anAreaSpawnIsNotCoveredByItsWalls() throws {
        for id in HarborpointAreas.shippedIDs {
            let area = try AreaCatalogLoader.load(id)
            guard let spawn = area.spawnPoint(entrance: nil) else { continue }
            #expect(
                !area.isCovered(spawn),
                "'\(id)' covers the spawn — the player would load in as a silhouette"
            )
        }
    }

    // MARK: - The office

    /// V18 repairs the fireplace to wall/floor pixels and paints the radiators
    /// inside the shell boundary, so neither fixture may ghost an actor. Tall
    /// records furniture is the WED cover set; the desk keeps its hand-tuned
    /// apron ordering.
    @Test func bakedRadiatorOfficeNeedsNoActorCover() throws {
        let office = OfficeAreaAdapter.area()
        #expect(office.wallPolygons.allSatisfy { !$0.id.contains("radiator") })
        #expect(office.wallPolygons.allSatisfy { !$0.id.contains("fireplace") })
        #expect(office.wallPolygons.contains { $0.id == "office.bookshelf" })
        #expect(office.wallPolygons.contains { $0.id == "office.filingCabinet" })
        #expect(!office.wallPolygons.contains { $0.id.contains("desk") })
    }

    @Test func everyDistrictAuthorsOneCoverMassPerStreetPlan() throws {
        let expected = Set(CityStreetPlan.all.map(\.id))
        for id in CityDistrictID.allCases {
            let area = CityDistrictAreaAdapter.area(for: id)
            let authored = Set(area.wallPolygons.map(\.id))
            #expect(authored == expected, "'\(id.slug)' cover set drifted from the street plan")
            for wall in area.wallPolygons {
                #expect(wall.coversActors)
                #expect(wall.polygon.count == 4)
                #expect(wall.height == AreaCoverAuthoring.buildingHeight)
            }
        }
    }
}

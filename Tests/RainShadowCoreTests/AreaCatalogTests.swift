import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Content validation for the shipped area files, in the spirit of
/// `ShippedDialogueCatalogTests` and `ItemCatalogTests`: the catalog is authored
/// data, so the suite is what stops a bad area shipping.
struct AreaCatalogTests {

    // MARK: - Shipped content

    @Test func everyShippedAreaLoadsFromItsResource() throws {
        let catalog = try AreaCatalogLoader.load(HarborpointAreas.shippedIDs)
        #expect(catalog.count == HarborpointAreas.shippedIDs.count)
        for id in HarborpointAreas.shippedIDs {
            let area = catalog.area(for: id)
            #expect(area != nil, "no area loaded for '\(id)'")
            #expect(area?.id == id, "area file for '\(id)' declares a different id")
        }
    }

    /// The file basename is the id. `ProjectStructure.md` §7 makes that a rule
    /// for shipped JSON, and the loader relies on it to resolve a resource.
    @Test func everyAreaFileIsNamedForItsID() throws {
        for id in HarborpointAreas.shippedIDs {
            let area = try AreaCatalogLoader.load(id)
            #expect(area.id == id)
        }
    }

    @Test func everyAreaAuthorsAnEntranceSoSomethingCanArriveInIt() throws {
        for area in try AreaCatalogLoader.load(HarborpointAreas.shippedIDs).allAreas {
            #expect(!area.entrances.isEmpty, "'\(area.id)' authors no entrance")
            #expect(
                area.spawnPoint(entrance: nil) != nil,
                "'\(area.id)' cannot answer where an unnamed arrival lands"
            )
        }
    }

    /// The check that makes travel honest: a region naming a destination and an
    /// entrance must find both. Without it, a renamed entrance is a transition
    /// that silently drops the player at whatever the fallback happens to be.
    @Test func everyTravelRegionResolvesToARealEntrance() throws {
        let catalog = try AreaCatalogLoader.load(HarborpointAreas.shippedIDs)
        var checked = 0
        for area in catalog.allAreas {
            for region in area.travelRegions {
                let travel = try #require(region.travel)
                let destination = try #require(catalog.area(for: travel.destination))
                #expect(
                    destination.entrance(named: travel.entrance) != nil,
                    "'\(area.id)' region '\(region.id)' arrives at '\(travel.entrance)', which '\(travel.destination)' does not author"
                )
                checked += 1
            }
        }
        #expect(checked > 0, "no travel regions were checked; the world has no doors")
    }

    @Test func everyRegionOutlineIsAPolygonRatherThanAPointOrALine() throws {
        for area in try AreaCatalogLoader.load(HarborpointAreas.shippedIDs).allAreas {
            for region in area.regions {
                #expect(
                    region.polygon.count >= 3,
                    "'\(area.id)' region '\(region.id)' has \(region.polygon.count) vertices"
                )
                #expect(
                    !region.boundingBox.isEmpty,
                    "'\(area.id)' region '\(region.id)' encloses no area"
                )
            }
        }
    }

    @Test func regionAndEntranceIDsAreUniqueWithinAnArea() throws {
        for area in try AreaCatalogLoader.load(HarborpointAreas.shippedIDs).allAreas {
            let regionIDs = area.regions.map(\.id)
            #expect(
                Set(regionIDs).count == regionIDs.count,
                "'\(area.id)' authors a duplicate region id"
            )
            let entranceNames = area.entrances.map(\.name)
            #expect(
                Set(entranceNames).count == entranceNames.count,
                "'\(area.id)' authors a duplicate entrance name"
            )
        }
    }

    /// Every area's plate has to be a real texture name, or the area loads and
    /// then draws nothing.
    @Test func everyAreaNamesAPlate() throws {
        for area in try AreaCatalogLoader.load(HarborpointAreas.shippedIDs).allAreas {
            #expect(!area.plateTextureName.isEmpty, "'\(area.id)' names no plate")
            #expect(
                area.worldSize.w > 0 && area.worldSize.h > 0,
                "'\(area.id)' has an empty world"
            )
        }
    }

    /// Every shipped area must be one the router can actually present.
    ///
    /// `AreaSceneKind` lives in the app target and cannot be reached from here,
    /// but it decides what an area is by exactly this predicate: the exterior,
    /// the office, or an id that resolves to a district. Adding an area file
    /// without wiring a scene behind it would otherwise be a runtime
    /// `assertionFailure` on the transition rather than a red suite.
    @Test func everyShippedAreaResolvesToSomethingTheRouterCanBuild() {
        for id in HarborpointAreas.shippedIDs {
            let resolvable = id == HarborpointAreas.openingExterior
                || id == HarborpointAreas.office
                || CityDistrictAreaAdapter.district(for: id) != nil
            #expect(resolvable, "'\(id)' ships but no scene kind claims it")
        }
    }

    /// And the reverse: a district the catalog knows must have an area file, or
    /// travelling to it would trap on a missing resource.
    @Test func everyDistrictHasAShippedAreaFile() {
        for district in CityDistrictID.allCases {
            let id = CityDistrictAreaAdapter.areaID(for: district)
            #expect(
                HarborpointAreas.shippedIDs.contains(id),
                "district '\(district.slug)' has no shipped area file"
            )
        }
    }

    // MARK: - Schema

    @Test func rejectsANewerSchemaRatherThanGuessingAtIt() throws {
        let area = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .interior,
            worldSize: AreaSize(w: 10, h: 10),
            plateTextureName: "probe_plate",
            agentProfile: AreaAgentProfile(.point),
            entrances: [AreaEntrance(name: "default", point: AreaPoint(x: 1, y: 1))]
        )
        var document = AreaDocument(area: area)
        document.schemaVersion = AreaDocument.currentSchemaVersion + 1
        let data = try JSONEncoder().encode(document)

        #expect(throws: AreaCatalogError.self) {
            try AreaCatalogLoader.decodeArea(data)
        }
    }

    @Test func absentSectionsDecodeAsEmptyRatherThanFailing() throws {
        // A small interior should author a small file. Everything but the
        // header and one entrance is optional.
        let json = """
        {
          "schemaVersion": 1,
          "area": {
            "id": "probe",
            "displayName": "Probe",
            "kind": "interior",
            "worldSize": { "w": 100, "h": 80 },
            "plateTextureName": "probe_plate",
            "agentProfile": { "halfWidth": 0, "halfHeight": 0 },
            "entrances": [{ "name": "default", "point": { "x": 5, "y": 5 } }]
          }
        }
        """
        let area = try AreaCatalogLoader.decodeArea(Data(json.utf8))
        #expect(area.regions.isEmpty)
        #expect(area.props.isEmpty)
        #expect(area.obstacles.isEmpty)
        #expect(area.worldOrigin == AreaPoint(x: 0, y: 0))
        #expect(area.cameraClampBounds == area.worldBounds)
        #expect(area.spawnPoint(entrance: nil) == CGPoint(x: 5, y: 5))
    }

    @Test func anAreaWithNoEntranceIsRejected() throws {
        let area = AreaDefinition(
            id: AreaID("sealed"),
            displayName: "Sealed",
            kind: .interior,
            worldSize: AreaSize(w: 10, h: 10),
            plateTextureName: "sealed_plate",
            agentProfile: AreaAgentProfile(.point)
        )
        #expect(throws: AreaCatalogError.areaWithoutEntrance(AreaID("sealed"))) {
            _ = try AreaCatalogLoader.validate([area])
        }
    }

    @Test func aTravelRegionPointingAtAnUnauthoredEntranceIsRejected() throws {
        let entrance = AreaEntrance(name: "default", point: AreaPoint(x: 1, y: 1))
        let source = AreaDefinition(
            id: AreaID("source"),
            displayName: "Source",
            kind: .interior,
            worldSize: AreaSize(w: 10, h: 10),
            plateTextureName: "p",
            agentProfile: AreaAgentProfile(.point),
            entrances: [entrance],
            regions: [
                AreaRegion(
                    id: "exit",
                    kind: .travel,
                    rect: CGRect(x: 0, y: 0, width: 2, height: 2),
                    travel: AreaTravel(destination: AreaID("target"), entrance: "side.door")
                )
            ]
        )
        let target = AreaDefinition(
            id: AreaID("target"),
            displayName: "Target",
            kind: .interior,
            worldSize: AreaSize(w: 10, h: 10),
            plateTextureName: "p",
            agentProfile: AreaAgentProfile(.point),
            entrances: [entrance]
        )
        #expect(throws: AreaCatalogError.self) {
            _ = try AreaCatalogLoader.validate([source, target])
        }
    }

    // MARK: - Region geometry

    @Test func aRectRegionContainsItsInteriorAndExcludesTheOutside() {
        let region = AreaRegion(
            id: "probe",
            kind: .info,
            rect: CGRect(x: 10, y: 20, width: 40, height: 30)
        )
        #expect(region.contains(CGPoint(x: 30, y: 35)))
        #expect(!region.contains(CGPoint(x: 9, y: 35)))
        #expect(!region.contains(CGPoint(x: 30, y: 51)))
        #expect(region.boundingBox == CGRect(x: 10, y: 20, width: 40, height: 30))
    }

    /// The reason regions are polygons and not rects: Harborpoint's streets run
    /// on the BG:EE ground axes, so a diagonal kerb is not expressible as an
    /// AABB without either eating pavement or claiming roadway.
    @Test func aDiagonalRegionExcludesTheCornersItsBoundingBoxWouldClaim() {
        let diamond = AreaRegion(
            id: "diamond",
            kind: .info,
            polygon: [
                AreaPoint(x: 100, y: 0),
                AreaPoint(x: 200, y: 75),
                AreaPoint(x: 100, y: 150),
                AreaPoint(x: 0, y: 75)
            ]
        )
        #expect(diamond.contains(CGPoint(x: 100, y: 75)))
        // Inside the bounding box, outside the diamond.
        #expect(!diamond.contains(CGPoint(x: 5, y: 5)))
        #expect(!diamond.contains(CGPoint(x: 195, y: 145)))
        #expect(diamond.boundingBox == CGRect(x: 0, y: 0, width: 200, height: 150))
    }
}

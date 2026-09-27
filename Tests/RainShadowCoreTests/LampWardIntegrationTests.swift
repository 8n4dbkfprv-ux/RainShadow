import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

@Suite(.serialized)
struct LampWardIntegrationTests {
    struct Receipt: Decodable {
        let anchors: [String: AreaPoint]
        let witnesses: [String: AreaPoint]
        let adultWorldHeight: Double
        let pixelsPerWorldUnit: Double
    }
    func receipt(_ id: AreaID) throws -> Receipt {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/LampWard/\(id.rawValue).validation.json")
        return try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: url))
    }

    @Test(arguments: [LampWardAreas.exteriorID, LampWardAreas.interiorID])
    func exportedApproachesAreReachedByTheActualMovementEngine(_ id: AreaID) throws {
        let area = try AreaCatalogLoader.load(id)
        let report = try receipt(id)
        let map = area.makeNavigationMap()
        let start = try #require(area.spawnPoint(entrance: nil))
        let flood = AreaReachabilityTests.reachableCells(map, from: start, radius: area.agentProfile.navigationProfile.radius)
        print("Lamp Ward measured flood \(id): \(flood.count)")
        #expect(abs(report.adultWorldHeight / Double(OfficeInteriorScale.standingAdultBodyHeight) - 1) < 0.01)
        #expect(report.pixelsPerWorldUnit >= 2.18)
        for (name, target) in report.anchors.sorted(by: { $0.key < $1.key }) {
            #expect(flood.contains(map.searchMap.cell(for: target.cgPoint)), "Unreachable \(id) \(name)")
            if map.searchMap.cell(for: start) == map.searchMap.cell(for: target.cgPoint) { continue }
            var walker = Movable(map: map, identity: "lamp.qa", position: start,
                                 circleSize: map.circleSize, blocksSearchMap: false)
            walker.walkTo(target.cgPoint, ticks: 1)
            for tick in 2..<6000 {
                let step = walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
                if step.arrived || step.abandoned || !walker.isMoving { break }
            }
            #expect(map.searchMap.cell(for: walker.position) == map.searchMap.cell(for: target.cgPoint), "Failed walk \(id) \(name): \(walker.position)")
        }
        if id == LampWardAreas.interiorID {
            for (name, point) in report.witnesses {
                #expect(!flood.contains(map.searchMap.cell(for: point.cgPoint)), "Closed cell or counter became accessible: \(name)")
            }
        }
    }

    @Test func entranceAndReturnUseTheNewAreasAndPreserveLegacySaveIdentity() throws {
        let street = LampWardAreas.exterior
        let room = LampWardAreas.interior
        let entry = try #require(street.region(id: "portal.lamphouseEntrance")?.travel)
        let exit = try #require(room.region(id: "portal.return")?.travel)
        #expect(entry.destination == room.id)
        #expect(room.entrance(named: entry.entrance) != nil)
        #expect(exit.destination == street.id)
        #expect(street.entrance(named: exit.entrance) != nil)
        #expect(CityInteriorID.policeStation.areaID == room.id)
        #expect(CityDistrictAreaAdapter.areaID(for: .harborpointPD) == street.id)
        #expect(street.entrance(named: "from.portal.pdEntrance") != nil)
        #expect(street.nightPlateTextureName == "lamp_ward_v12_night")
    }

    @Test func evaluatedBuildingsBlockMovementAndProjectedCoverBakesWithinTheCap() throws {
        let area = LampWardAreas.exterior
        let report = try receipt(area.id)
        let search = area.makeNavigationMap().searchMap
        for name in ["civic_hall", "lodging"] {
            let point = try #require(report.witnesses[name]).cgPoint
            #expect(!search.terrain(at: point).isWalkable)
            // BG index 10 admits sight into a sidewall run, then stops the ray
            // on leaving it. It is not index 0's NO_SEE terrain.
            #expect(search.terrain(at: point).isSightSidewall)
        }
        #expect(search.terrain(at: try #require(report.witnesses["forecourt"]).cgPoint).isWalkable)
        for area in [LampWardAreas.exterior, LampWardAreas.interior] {
            let start = Date()
            let mask = area.makeWallStencil()
            #expect(!mask.isEmpty)
            #expect(max(mask.columns, mask.rows) <= AreaWallStencil.maximumMaskDimension)
            #expect(Date().timeIntervalSince(start) < 5)
            // Actual projected faces may cover a walking cell: a tree crown or
            // the face of a wall is above its ground footprint, as in a WED.
            #expect(area.wallPolygons.allSatisfy { $0.id.hasPrefix("blender.cover.") })
        }
    }
}

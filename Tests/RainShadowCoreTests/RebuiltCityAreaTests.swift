import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

@MainActor @Suite(.serialized)
struct RebuiltCityAreaTests {
    nonisolated static let ids = ["city_sable_row", "city_wharf_ladder", "city_riverside",
                      "interior_shipping_office", "interior_iron_stairs"]

    @Test(arguments: ids)
    func restoredEntrancesAndInteractionsAreReachable(_ name: String) throws {
        let area = try AreaCatalogLoader.load(AreaID(name))
        let map = area.makeNavigationMap()
        let start = try #require(area.spawnPoint(entrance: nil))
        let flood = AreaReachabilityTests.reachableCells(map, from: start, radius: map.agentProfile.radius)
        print("Restored area \(name): \(flood.count) reachable cells; \(area.wallPolygons.count) cover faces")
        let points = area.entrances.map { ($0.name, $0.point.cgPoint) }
            + area.regions.compactMap { r in r.approachPoint.map { (r.id, $0.cgPoint) } }
        for (label, point) in points {
            #expect(flood.contains(map.searchMap.cell(for: point)), "\(name): \(label) is sealed")
            if map.searchMap.cell(for: start) == map.searchMap.cell(for: point) { continue }
            var walker = Movable(map: map, identity: "restore.qa", position: start,
                                 circleSize: map.circleSize, blocksSearchMap: false)
            walker.walkTo(point, ticks: 1)
            for tick in 2..<12000 {
                let step = walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
                if step.arrived || step.abandoned || !walker.isMoving { break }
            }
            #expect(map.searchMap.cell(for: walker.position) == map.searchMap.cell(for: point), "\(name): \(label) failed actual movement")
        }
        let savedArrival = try #require(SaveStore.rebuiltAreaArrivals[name])
        #expect(start == CGPoint(x: savedArrival.x, y: savedArrival.y))
        let mask = area.makeWallStencil()
        #expect(!mask.isEmpty)
        #expect(max(mask.columns, mask.rows) <= AreaWallStencil.maximumMaskDimension)
        #expect(area.wallPolygons.allSatisfy { $0.polygon.count >= 3 })
    }

    @Test func reviewedPlatesAndWorldMapUseStableIdentities() throws {
        let expected: [(CityDistrictID, String)] = [(.sableRow, "sable_noir_day"),
            (.wharfLadder, "wharf_v19_day"), (.riverside, "riverside_v08_day")]
        for (district, plate) in expected {
            let area = CityDistrictAreaAdapter.area(for: district)
            #expect(area.plateTextureName == plate)
            #expect(CityDistrictCatalog.definition(for: district).groundTextureName == plate)
            for edge in CityMapEdge.allCases {
                let p = RebuiltCityAreas.exitApproach(district, edge)
                #expect(area.entrance(named: edge.arrivalKey)?.point.cgPoint == p)
                #expect(RebuiltCityAreas.exitHitArea(district, edge).contains(p))
            }
            for region in area.travelRegions {
                let travel = try #require(region.travel)
                let destination = try AreaCatalogLoader.load(travel.destination)
                #expect(destination.entrance(named: travel.entrance) != nil)
                #expect(destination.travelRegions.contains { $0.travel?.destination == area.id })
            }
        }
        let sable = CityDistrictAreaAdapter.area(for: .sableRow)
        #expect(sable.nightLightMapName == "sable_noir_dusk.lm")
        #expect(try AreaCatalogLoader.decodeArea(JSONEncoder().encode(AreaDocument(area: sable))).nightLightMapName == sable.nightLightMapName)
        #expect(CityDistrictAreaAdapter.area(for: .harborpointPD).id == LampWardAreas.exteriorID)
    }

    @Test func recoverySiteRecordsOnlyTheAuthoredObservation() {
        let ids: Set<String> = ["riverside.coat-stones"]
        let notes = EmptyCoatJournalContent.caseSections(inspectedHotspotIDs: ids)
            .flatMap(\.entries).filter { $0.id == "note.riverside.coat-stones" }
        #expect(notes.count == 1)
        #expect(notes.first?.summary.contains("police custody") == true)
        #expect(!EmptyCoatJournalContent.chronologySections(inspectedHotspotIDs: ids)
            .flatMap(\.entries).contains { $0.id == "log.office" })
    }

    @MainActor @Test func oldSpatialSaveMigratesOnceWithoutLosingProgress() throws {
        let suite = "RainShadow.RestoreQA.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var original = SaveSnapshot(hasSeenOpening: true, hasCompletedOfficeCaseIntro: true,
            walletPence: 337, carriedItems: [.init(id: "key", quantity: 1)],
            groundPiles: ["city_riverside": [.init(id: "letter", quantity: 2, x: 100, y: 100)],
                          "city_lamp_ward": [.init(id: "coin", quantity: 1, x: 77, y: 88)]],
            caseFlags: ["retained"], caseEvidenceIDs: ["letter"],
            caseJournalFragments: [.init(id: "found", kind: "chronology", text: "Found.")],
            exploredFog: ["city_riverside": .init(columns: 1, rows: 1, bytes: Data([1])),
                          "city_lamp_ward": .init(columns: 1, rows: 1, bytes: Data([2]))])
        let encoded = try JSONEncoder().encode(original)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "cityLayoutRevision")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        defaults.set(legacy, forKey: "save")
        let store = SaveStore(defaults: defaults, key: "save", resetsOnLaunch: false)
        let migrated = store.load()
        original.exploredFog.removeValue(forKey: "city_riverside")
        original.groundPiles["city_riverside"]![0].x = 1592
        original.groundPiles["city_riverside"]![0].y = 1902
        original.groundPiles = Dictionary(uniqueKeysWithValues: original.groundPiles.map { (AreaResourceID.canonical($0.key), $0.value) })
        original.exploredFog = Dictionary(uniqueKeysWithValues: original.exploredFog.map { (AreaResourceID.canonical($0.key), $0.value) })
        #expect(migrated == original)
        #expect(store.load() == migrated)
        #expect(defaults.data(forKey: "save.BeforeCityLayoutV1") == legacy)
    }
}

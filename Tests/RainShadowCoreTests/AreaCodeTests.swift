import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

@Suite struct AreaCodeTests {
    @Test func everyRegisteredCodeLoadsAndKeepsItsResourceBinding() throws {
        #expect(Set(AreaResourceID.codes.values).count == AreaResourceID.codes.count)
        for (legacy, code) in AreaResourceID.codes {
            #expect(code.count == 6 && code.hasPrefix("RS"))
            let id = AreaID(code.lowercased())
            #expect(id.rawValue == code)
            #expect(AreaID(legacy) == id)
            #expect(id.resourceName == legacy)
            let area = try AreaCatalogLoader.load(id)
            #expect(area.id == id)
            #expect(try JSONDecoder().decode(AreaID.self, from: JSONEncoder().encode(id)) == id)
            for travel in area.travelRegions.compactMap(\.travel) {
                let destination = try AreaCatalogLoader.load(travel.destination)
                #expect(destination.entrance(named: travel.entrance) != nil)
                #expect(AreaResourceID.codes.values.contains(travel.destination.rawValue))
            }
        }
    }

    @MainActor @Test func aliasesMigrateAllAreaStateAndMergeWithoutRepeatedItems() throws {
        let suite = "RainShadow.AreaCodes.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SaveStore(defaults: defaults, key: "save", resetsOnLaunch: false)
        let legacy = SaveSnapshot(walletPence: 321,
            groundPiles: ["office_suite": [.init(id: "letter", quantity: 2, x: 44, y: 55)],
                          "RS0101": [.init(id: "key", quantity: 1, x: 66, y: 77)]],
            areaVariables: ["office_suite/VISITED": .init(kind: "integer", integer: 1),
                            "RS0101/VISITED": .init(kind: "integer", integer: 2),
                            "GLOBAL/CASE": .init(kind: "integer", integer: 3)],
            exploredFog: ["office_suite": .init(columns: 8, rows: 1, bytes: Data([1])),
                          "RS0101": .init(columns: 8, rows: 1, bytes: Data([2]))],
            areaDoorOpen: ["office_suite": ["door": false, "other": true], "RS0101": ["door": true]],
            areaUnlockedDoors: ["office_suite": ["a"], "RS0101": ["b"]],
            areaSpentTriggers: ["office_suite": ["intro"], "RS0101": ["visit"]])
        store.save(legacy)
        let original = defaults.data(forKey: "save")
        let result = store.load()
        #expect(result.walletPence == 321)
        #expect(result.groundPiles["RS0101"]?.map(\.quantity) == [2, 1])
        #expect(result.groundPiles["RS0101"]?.first?.x == 44)
        #expect(result.groundPiles["office_suite"] == nil)
        #expect(result.areaVariables["RS0101/VISITED"]?.integer == 2)
        #expect(result.areaVariables["GLOBAL/CASE"]?.integer == 3)
        #expect(result.areaVariables["office_suite/VISITED"] == nil)
        #expect(result.exploredFog["RS0101"]?.bytes == Data([3]))
        #expect(result.areaDoorOpen == ["RS0101": ["door": true, "other": true]])
        #expect(result.areaUnlockedDoors == ["RS0101": ["a", "b"]])
        #expect(result.areaSpentTriggers == ["RS0101": ["intro", "visit"]])
        #expect(store.load() == result)
        #expect(defaults.data(forKey: "save.BeforeAreaCodesV1") == original)
        #expect(AreaID("GLOBAL").rawValue == "GLOBAL")
        #expect(AreaID("custom_area").rawValue == "custom_area")
    }
}

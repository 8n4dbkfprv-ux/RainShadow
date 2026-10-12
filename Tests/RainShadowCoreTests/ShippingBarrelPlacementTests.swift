import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct ShippingBarrelPlacementTests {
    @Test func areaSceneryIsSeededWithoutCombatantsAndKeepsTheDoorReachable() throws {
        for id in [WharfLadderStory.exterior, WharfLadderStory.interior] {
            let area = try AreaCatalogLoader.load(id), map = area.makeNavigationMap()
            let barrels = CombatNavigation.areaBarrels(in: id, map: map)
            #expect(barrels.count == (id == WharfLadderStory.exterior ? 2 : 1))
            let start = try #require(area.spawnPoint(entrance: nil))
            let target = try #require(area.travelRegions.first?.approachPoint?.cgPoint)
            for barrel in barrels {
                map.occupancy.register(OccupyingActor(id: barrel.id, kind: .npc, position: barrel.position,
                    radius: 20, isBumpable: false, isMoving: false, personalSpaceCells: 3))
            }
            let path = map.pathAvoidingActors(from: start, to: target)
            #expect(map.searchMap.cell(for: path.destination ?? .zero) == map.searchMap.cell(for: target))
        }
    }
    @MainActor private func fixture() throws -> (NavigationMap, [Combatant]) {
        let map = try AreaCatalogLoader.load(WharfLadderStory.interior).makeNavigationMap()
        let origin = CGPoint(x: 487, y: 364)
        map.registerActor(id: TacticalCombat.playerID, kind: .player, at: origin)
        let crew = WharfLadderStaging.positions(near: origin, count: 3, navigation: map, ignoringActorID: TacticalCombat.playerID)
        let points = [origin] + crew
        return (map, points.enumerated().map { index, point in
            Combatant(id: index == 0 ? TacticalCombat.playerID : "crew.\(index)", name: "Test", player: index == 0,
                position: point, hp: 12, maximumHP: 12, defence: 10, attackBonus: 2,
                damageMin: 1, damageMax: 3, initiativeBonus: index == 0 ? 100 : 0)
        })
    }
    @MainActor @Test func authoredFloorHasClearanceAndTacticalReach() throws {
        let (map, actors) = try fixture()
        let barrel = try #require(CombatNavigation.shippingBarrels(in: map, actors: actors).first)
        #expect(barrel.position == CGPoint(x: 430, y: 410))
        for point in CombatNavigation.shippingBarrelSeats {
            #expect(map.searchMap.blockedInRadiusTile(at: point, size: 2).contains(.passable))
            let path = map.pathAvoidingActors(from: actors[0].position, to: point, identity: TacticalCombat.playerID)
            #expect(map.searchMap.cell(for: path.destination ?? .zero) == map.searchMap.cell(for: point))
        }
        #expect(actors.allSatisfy { CombatNavigation.distance(barrel.position, $0.position) >= 65 })
        #expect(actors.contains { !$0.player && CombatNavigation.distance(barrel.position, $0.position) < CombatBarrel.blastRadius })
        #expect(CombatNavigation.clearLine(in: map, from: actors[0].position, to: barrel.position, excluding: [TacticalCombat.playerID]))
        let exit = try #require(AreaCatalogLoader.load(WharfLadderStory.interior).spawnPoint(entrance: nil))
        map.occupancy.register(OccupyingActor(id: barrel.id, kind: .npc, position: barrel.position,
            radius: 20, isBumpable: false, isMoving: false, personalSpaceCells: 3))
        let escape = map.pathAvoidingActors(from: actors[0].position, to: exit, identity: TacticalCombat.playerID)
        #expect(map.searchMap.cell(for: escape.destination ?? .zero) == map.searchMap.cell(for: exit))
    }
    @MainActor @Test func repairsOldIntactBarrelsWithoutChangingCombatOrBrokenRemains() throws {
        let (map, actors) = try fixture()
        var remains = CombatBarrel(id: "broken", position: CGPoint(x: 600, y: 285))
        remains.broken = true; remains.exploded = true
        remains.fireCells = [CGPoint(x: 608, y: 282)]; remains.fireExpiresRound = 3
        var model = TacticalCombat(encounterID: "clockroom", areaID: WharfLadderStory.interior.rawValue,
            actors: actors, seed: 42, barrels: [CombatBarrel(id: "intact", position: CGPoint(x: 590, y: 300)), remains])
        let before = model
        model.repairShippingBarrelPlacement(in: map)
        #expect(model.barrels?.first?.position == CGPoint(x: 430, y: 410))
        #expect(model.barrels?.last == remains)
        #expect(model.actors == before.actors && model.budget == before.budget && model.randomState == before.randomState)
        let once = model
        model.repairShippingBarrelPlacement(in: map)
        #expect(model == once)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && restored.isValid)
        var exterior = before; exterior.areaID = WharfLadderStory.exterior.rawValue
        let unchanged = exterior
        exterior.repairShippingBarrelPlacement(in: map)
        #expect(exterior == unchanged)
    }
}

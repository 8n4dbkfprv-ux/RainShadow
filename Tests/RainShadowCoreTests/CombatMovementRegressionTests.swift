import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct CombatMovementRegressionTests {
    private func actor(_ id: String, _ point: CGPoint, player: Bool = false) -> Combatant {
        Combatant(id: id, name: id, player: player, position: point, hp: 7, maximumHP: 7,
            defence: 11, attackBonus: 2, damageMin: 1, damageMax: 3, initiativeBonus: player ? 100 : -100)
    }
    @MainActor @Test func savedLanePositionCanLeaveThroughOpenStreet() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior)
        let map = area.makeNavigationMap()
        let player = actor(TacticalCombat.playerID, CGPoint(x: 1849, y: 1935), player: true)
        let crew = [actor("crew.0", CGPoint(x: 1912, y: 1938)), actor("crew.1", CGPoint(x: 1848, y: 1986))]
        for actor in [player] + crew { map.registerActor(id: actor.id, kind: actor.player ? .player : .npc, at: actor.position) }
        let goal = CGPoint(x: 1689, y: 1935)
        #expect(CombatNavigation.route(in: map, actor: player, to: goal) == nil)
        let before = map.occupancy.actors
        let repaired = WharfLadderStaging.repairCrowdedPositions(playerID: player.id, crewIDs: crew.map(\.id), navigation: map)
        #expect(!repaired.isEmpty)
        #expect(map.occupancy.actors == before)
        for (id, point) in repaired {
            #expect(CombatNavigation.distance(before[id]!.position, point) <= 32)
            map.updateActor(id: id, position: point, isMoving: false)
        }
        map.occupancy.restampAll()
        #expect(map.occupancy.actors[player.id]?.position == player.position)
        for delta in [CGPoint(x: -160, y: 0), CGPoint(x: 0, y: -120), CGPoint(x: -120, y: -90)] {
            let end = CGPoint(x: player.position.x + delta.x, y: player.position.y + delta.y)
            let path = try #require(CombatNavigation.route(in: map, actor: player, to: end))
            #expect(CombatNavigation.length(path, from: player.position) <= 240)
        }
        #expect(WharfLadderStaging.repairCrowdedPositions(playerID: player.id, crewIDs: crew.map(\.id), navigation: map).isEmpty)
        // Enemies remain real obstacles after repair.
        let occupied = map.occupancy.actors[crew[0].id]!.position
        #expect(CombatNavigation.route(in: map, actor: player, to: occupied) == nil)
    }
    @MainActor @Test func stagingPreservesEveryActorsRasterClearance() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior)
        for origin in [CGPoint(x: 1849, y: 1935), CGPoint(x: 2000, y: 1947)] {
            let map = area.makeNavigationMap()
            map.registerActor(id: TacticalCombat.playerID, kind: .player, at: origin)
            let before = map.occupancy.actors
            let positions = WharfLadderStaging.positions(near: origin, count: 2, navigation: map, ignoringActorID: TacticalCombat.playerID)
            #expect(positions.count == 2 && map.occupancy.actors == before)
            for (i, position) in positions.enumerated() { map.registerActor(id: "crew.\(i)", kind: .npc, at: position) }
            map.occupancy.restampAll()
            for body in map.occupancy.actors.values {
                let clear = map.occupancy.withStampLifted(id: body.id) {
                    map.searchMap.blockedInRadiusTile(at: body.position, size: map.circleSize).contains(.passable)
                }
                #expect(clear)
            }
        }
    }
}

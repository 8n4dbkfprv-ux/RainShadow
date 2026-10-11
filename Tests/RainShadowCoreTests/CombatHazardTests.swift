import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct CombatHazardTests {
    private func actor(_ id: String, player: Bool, point: CGPoint, initiative: Int = 0) -> Combatant {
        Combatant(id: player ? TacticalCombat.playerID : id, name: id, player: player,
            position: point, hp: 100, maximumHP: 100, defence: 12, attackBonus: 4,
            damageMin: 2, damageMax: 4, initiativeBonus: initiative,
            rangedWeapon: .bow, fireArrows: 3,
            shoveProfile: .init(strength: 14, athletics: player ? 30 : 0, acrobatics: 0, weight: 80))
    }
    private func fight(barrels: [CombatBarrel] = [], enemyFirst: Bool = false) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            actor("Voss", player: true, point: CGPoint(x: 100, y: 150), initiative: enemyFirst ? -100 : 100),
            actor("crew", player: false, point: CGPoint(x: 180, y: 150), initiative: enemyFirst ? 100 : -100)
        ], seed: 42, barrels: barrels)
    }
    private func fire(at point: CGPoint) -> CombatBarrel {
        CombatBarrel(id: "oil", position: point, exploded: true, fireCells: [point], fireExpiresRound: 4)
    }
    @Test func crossingFireBetweenSparsePathNodesBurnsButDoesNotSpendHealthImmediately() throws {
        var game = fight(barrels: [fire(at: CGPoint(x: 140, y: 150))])
        let moved = game.move(along: Path(points: [CGPoint(x: 220, y: 150)], from: game.current.position))
        #expect(moved)
        #expect(game.current.isBurning && game.current.hp == 100 && !game.isInFire(game.current.position))
        let before = game.current.hp
        _ = game.endTurn()
        let player = try #require(game.actors.first { $0.player })
        #expect((1...4).contains(before - player.hp) && player.burningTurns == 1)
        let copy = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(game))
        #expect(copy == game && copy.isValid)
    }
    @Test func rejectedMovementAndResistedShoveDoNotIgniteAnyone() {
        var game = fight(barrels: [fire(at: CGPoint(x: 140, y: 150))]); let before = game
        let moved = game.move(along: Path(points: [CGPoint(x: 1000, y: 150)], from: game.current.position))
        #expect(!moved)
        #expect(game == before)
        var actors = before.actors
        actors[1].shoveProfile = .init(strength: 14, athletics: 30, acrobatics: 0, weight: 80)
        actors[0].shoveProfile = .init(strength: 14, athletics: -5, acrobatics: 0, weight: 80)
        var resisted = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: actors, seed: 42,
            barrels: [fire(at: CGPoint(x: 260, y: 150))])
        let attempt = resisted.shove(target: "crew", clearLine: true, destination: CGPoint(x: 260, y: 150))
        #expect(attempt?.succeeded == false)
        #expect(!resisted.actors[1].isBurning && resisted.actors[1].overboard != true)
    }
    @Test func fireShoveReignitesUntilSurfaceExpiresAndRequiresLeavingBeforeExtinguishing() throws {
        var game = fight(barrels: [fire(at: CGPoint(x: 260, y: 150))])
        let attempt = game.shove(target: "crew", clearLine: true, destination: CGPoint(x: 260, y: 150))
        #expect(attempt?.succeeded == true)
        #expect(game.actors.first { $0.id == "crew" }?.burningTurns == 2)
        _ = game.endTurn()
        #expect(game.current.id == "crew" && !game.canExtinguish)
        _ = game.endTurn(); _ = game.endTurn(); _ = game.endTurn()
        #expect(game.round == 3 && game.burningBarrels.count == 1)
        _ = game.endTurn(); _ = game.endTurn()
        #expect(game.round == 4 && game.burningBarrels.isEmpty)
        _ = game.endTurn()
        #expect(game.current.isBurning && game.canExtinguish)
        let extinguished = game.extinguish()
        #expect(extinguished && !game.current.isBurning)
    }
    @Test func ignitionBakesFloorCellsAndPreservesOccupancy() throws {
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 640, height: 480),
            obstacles: [CGRect(x: 320, y: 0, width: 16, height: 480)])
        let barrel = CombatBarrel(id: "oil", position: CGPoint(x: 290, y: 150))
        var game = fight(barrels: [barrel])
        for actor in game.actors { map.registerActor(id: actor.id, kind: .npc, at: actor.position) }
        map.registerActor(id: barrel.id, kind: .npc, at: barrel.position)
        let before = map.occupancy.actors
        let cells = CombatNavigation.fireCells(in: map, barrel: barrel)
        #expect(!cells.isEmpty && cells.allSatisfy { $0.x < 320 })
        #expect(map.occupancy.actors == before)
        let blasts = game.igniteBarrel("oil", clearShot: true, fireCells: { _ in cells }, visible: { _, _ in true })
        #expect(blasts?.count == 1 && game.burningBarrels.count == 1)
        #expect(game.burningBarrels.first?.fireExpiresRound == 4 && game.isValid)
    }
    private func waterfront(railing: Bool = false) -> NavigationMap {
        var terrain = [UInt8](repeating: 7, count: 40 * 40)
        for row in 0..<40 { for col in 15..<40 { terrain[row * 40 + col] = 12 } }
        if railing { for row in 0..<40 { terrain[row * 40 + 14] = 8 } }
        return NavigationMap(searchMap: SearchMap(worldBounds: CGRect(x: 0, y: 0, width: 640, height: 480),
            terrainIndices: terrain, columns: 40, rows: 40))
    }
    @Test func waterfrontDropIsOptInAndCannotCrossRailingsOrBecomeWalkingTerrain() throws {
        let game = fight(), target = game.actors[1]
        for railing in [false, true] {
            let map = waterfront(railing: railing)
            for actor in game.actors { map.registerActor(id: actor.id, kind: .npc, at: actor.position) }
            let occupancy = map.occupancy.actors
            let normal = CombatNavigation.knockbackDestination(in: map, actor: target, awayFrom: game.current.position,
                actors: game.actors, destroyedBarrels: [])
            let drop = CombatNavigation.knockbackDestination(in: map, actor: target, awayFrom: game.current.position,
                actors: game.actors, destroyedBarrels: [], allowWaterDrop: true)
            #expect(normal.x < 240)
            #expect((map.searchMap.terrain(at: drop) == .waterImpassable) == !railing)
            #expect(map.occupancy.actors == occupancy)
            #expect(CombatNavigation.route(in: map, actor: target, to: CGPoint(x: 260, y: 150)) == nil)
        }
    }
    @Test func waterShoveRemovesTargetFromFightAndPersistsDryRecoveryPoint() throws {
        var game = fight()
        let attempt = game.shove(target: "crew", clearLine: true, destination: CGPoint(x: 240, y: 150), intoWater: true)
        #expect(attempt?.overboard == true)
        #expect(game.outcome == .won && game.actors[1].hp == 0 && game.actors[1].overboardOrigin == CGPoint(x: 180, y: 150))
        let copy = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(game))
        #expect(copy == game && copy.isValid)
        var room = fight(); room.areaID = "interior_shipping_office"; let before = room
        let rejected = room.shove(target: "crew", clearLine: true, destination: CGPoint(x: 240, y: 150), intoWater: true)
        #expect(rejected == nil)
        #expect(room == before)
    }
    @Test func enemiesPreferARealWaterDropAndLeaveBurningOil() throws {
        var actors = fight(enemyFirst: true).actors
        actors[0].shoveProfile = .init(strength: 14, athletics: 30, acrobatics: 0, weight: 80)
        actors[1].shoveProfile = .crew
        actors[0].position = CGPoint(x: 100, y: 150)
        actors[1].position = CGPoint(x: 180, y: 150)
        let game = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: actors, seed: 42)
        let map = waterfront()
        for actor in actors { map.registerActor(id: actor.id, kind: .npc, at: actor.position) }
        if case .shove(let id) = EnemyTactics.choose(combat: game, map: map).action { #expect(id == TacticalCombat.playerID) }
        else { Issue.record("Enemy should choose the visible water drop") }
        let open = NavigationMap(worldBounds: CGRect(x: -600, y: -600, width: 1800, height: 1800), obstacles: [])
        var burning = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: actors, seed: 42,
            barrels: [fire(at: actors[0].position)])
        _ = burning.castBladeWard()
        for actor in actors { open.registerActor(id: actor.id, kind: .npc, at: actor.position) }
        if case .move(let path) = EnemyTactics.choose(combat: burning, map: open).action {
            #expect(!burning.isInFire(try #require(path.destination)))
        } else { Issue.record("An enemy with movement remaining should leave the burning floor") }
    }
    @Test func shippedAreasHaveFireSitesAndTheWharfHasAnUnguardedDrop() throws {
        for id in ["city_wharf_ladder", "interior_shipping_office"] {
            let area = try AreaCatalogLoader.load(AreaID(id)), map = area.makeNavigationMap()
            let spawn = try #require(area.spawnPoint(entrance: nil))
            let player = actor("Voss", player: true, point: spawn)
            let barrels = CombatNavigation.gateBarrels(in: map, actors: [player])
            #expect(!barrels.isEmpty, "No certified barrel site in \(id)")
            for barrel in barrels { #expect(!CombatNavigation.fireCells(in: map, barrel: barrel).isEmpty) }
            if id == "city_wharf_ladder" {
                var found = false
                outer: for row in 0..<map.searchMap.rows { for col in 0..<map.searchMap.columns {
                    let point = map.searchMap.center(of: SearchMapCell(column: col, row: row))
                    guard map.searchMap.blockedInRadiusTile(at: point, size: map.circleSize).contains(.passable) else { continue }
                    for (dx, dy) in [(1.0, 0.0), (-1, 0), (0, 0.75), (0, -0.75)] {
                        let wet = CGPoint(x: point.x + dx * 64, y: point.y + dy * 64)
                        guard map.searchMap.terrain(at: wet) == .waterImpassable else { continue }
                        let source = CGPoint(x: point.x - dx * 80, y: point.y - dy * 80)
                        guard map.searchMap.blockedInRadiusTile(at: source, size: map.circleSize).contains(.passable),
                            CombatNavigation.clearLine(in: map, from: source, to: point) else { continue }
                        let target = actor("crew", player: false, point: point)
                        let end = CombatNavigation.knockbackDestination(in: map, actor: target, awayFrom: source,
                            actors: [target], destroyedBarrels: [], allowWaterDrop: true)
                        if map.searchMap.terrain(at: end) == .waterImpassable {
                            found = true; break outer
                        }
                    }
                } }
                #expect(found, "Wharf needs an actual reachable water edge, not merely water elsewhere in the raster")
            }
        }
    }

    @Test func waterFallClearsTheEdgeAndDropsBeforeFading() {
        let from = CGPoint(x: 100, y: 200), to = CGPoint(x: 100, y: 140)
        #expect(CombatWaterFallMotion.position(from: from, to: to, elapsed: 0) == from)
        #expect(CombatWaterFallMotion.position(from: from, to: to, elapsed: 0.5) == to)
        #expect(CombatWaterFallMotion.height(elapsed: 0) == 0)
        #expect(CombatWaterFallMotion.height(elapsed: 0.6) < -35)
        #expect(CombatWaterFallMotion.alpha(elapsed: 0.6) == 1)
        #expect(CombatWaterFallMotion.height(elapsed: 0.8) == -96)
        #expect(CombatWaterFallMotion.alpha(elapsed: 1.2) == 0)
        #expect(CombatWaterFallMotion.height(elapsed: 1.2) < -150)
        #expect(CombatWaterFallMotion.phase(elapsed: 1.2) == 5)
    }

}

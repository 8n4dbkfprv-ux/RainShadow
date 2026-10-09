import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct ExplosiveBarrelTests {
    private func actor(_ id: String, player: Bool = false, x: Double, hp: Int = 20) -> Combatant {
        Combatant(id: id, name: id, player: player, position: CGPoint(x: x, y: 100), hp: hp,
            maximumHP: hp, defence: 10, attackBonus: 2, damageMin: 1, damageMax: 3,
            initiativeBonus: player ? 100 : 0, rangedWeapon: .bow, fireArrows: 3)
    }
    private func fight(playerX: Double = 0, hp: Int = 20) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            actor(TacticalCombat.playerID, player: true, x: playerX, hp: hp),
            actor("near", x: 220), actor("far", x: 600)
        ], seed: 42, barrels: [CombatBarrel(id: "a", position: CGPoint(x: 200, y: 100)),
                              CombatBarrel(id: "b", position: CGPoint(x: 300, y: 100))])
    }
    @Test func fireChainsOnceAndConsumesOneAction() throws {
        var model = fight()
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let events = try #require(result)
        #expect(events.map(\.barrel.id) == ["a", "b"])
        #expect(events.flatMap(\.hits).allSatisfy { $0.target == "near" && (3...5).contains($0.damage) })
        #expect(events.flatMap(\.hits).count == 2)
        #expect(model.liveBarrels.isEmpty && !model.budget.canAttack)
        #expect(model.budget.availableMovement(speed: model.current.speed) == 240)
        let accepted = model
        #expect(model.igniteBarrel("a", clearShot: true, visible: { _, _ in true }) == nil)
        #expect(model == accepted)
    }
    @Test func rejectionDoesNotSpendOrRoll() {
        for (x, clear, id) in [(0.0, false, "a"), (190, true, "a"), (-600, true, "a"), (0, true, "missing")] {
            var model = fight(playerX: x); let before = model
            #expect(model.igniteBarrel(id, clearShot: clear, visible: { _, _ in true }) == nil)
            #expect(model == before)
        }
    }
    @Test func playerBowCanTargetAnEnemyButBearCannotShoot() {
        var human = fight()
        #expect(human.attack(target: "near", clearLine: true, ranged: true) != nil)
        #expect(!human.budget.canAttack)
        var bear = fight()
        _ = bear.transformToBear(hasClearance: true)
        repeat { _ = bear.endTurn() } while !bear.isPlayerTurn
        let before = bear
        #expect(bear.attack(target: "near", clearLine: true, ranged: true) == nil)
        #expect(bear.igniteBarrel("a", clearShot: true, visible: { _, _ in true }) == nil)
        #expect(bear == before)
    }
    @Test func wallsStopChainsAndBlastDamage() throws {
        var model = fight()
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in false })
        let events = try #require(result)
        #expect(events.count == 1 && events[0].hits.isEmpty)
        #expect(model.liveBarrels.map(\.id) == ["b"])
        #expect(model.actors.allSatisfy { $0.hp == $0.maximumHP })
    }
    @Test func blastCanKnockOutShooterAndPreservesValidTurn() throws {
        var model = fight(playerX: 90, hp: 1)
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let events = try #require(result)
        #expect(events[0].hits.contains { $0.target == TacticalCombat.playerID && $0.knockedOut })
        #expect(model.outcome == .lost && model.isValid)
    }
    @Test func everyFactionTakesBlastDamage() throws {
        var model = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            actor(TacticalCombat.playerID, player: true, x: 200), actor("shooter", x: 0), actor("ally", x: 240)
        ], seed: 1, barrels: [.init(id: "a", position: CGPoint(x: 230, y: 100))])
        while model.current.player { _ = model.endTurn() }
        if model.current.id != "shooter" { _ = model.endTurn() }
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let events = try #require(result)
        #expect(Set(events[0].hits.map(\.target)) == [TacticalCombat.playerID, "ally"])
    }
    @Test func acceptedExplosionReloadsWithoutRearming() throws {
        var model = fight()
        _ = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && restored.isValid && restored.liveBarrels.isEmpty)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fight())) as? [String: Any])
        json.removeValue(forKey: "barrels")
        let legacy = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.isValid && legacy.liveBarrels.isEmpty)
    }
    @Test func blastsUseBearEnduranceBeforeHumanHealth() throws {
        var model = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            actor(TacticalCombat.playerID, player: true, x: 250), actor("shooter", x: 0)
        ], seed: 42, barrels: [.init(id: "a", position: CGPoint(x: 200, y: 100)),
                              .init(id: "b", position: CGPoint(x: 300, y: 100))])
        _ = model.transformToBear(hasClearance: true); _ = model.endTurn()
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let events = try #require(result)
        let damage = events.flatMap(\.hits).filter { $0.target == TacticalCombat.playerID }.reduce(0) { $0 + $1.damage }
        let player = try #require(model.actors.first { $0.player })
        #expect(player.hp + (model.bearForm?.temporaryHP ?? 0) == 28 - damage)
        #expect(model.isBear == (damage < 8))
    }
    @Test func physicalStrikeSpillsOilAndLaterFireIgnitesIt() throws {
        var model = fight(playerX: 120)
        let rng = model.randomState
        let broken = model.breakBarrel("a", clearLine: true)
        #expect(broken)
        #expect(model.liveBarrels.first?.isBroken == true)
        #expect(model.liveBarrels.first?.exploded == false)
        #expect(model.randomState == rng && !model.budget.canAttack)
        let saved = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(saved == model)
        let before = model
        let repeated = model.breakBarrel("a", clearLine: true)
        #expect(!repeated)
        #expect(before == model)
        repeat { _ = model.endTurn() } while !model.isPlayerTurn
        model.reconcilePosition(id: TacticalCombat.playerID, point: CGPoint(x: 0, y: 100))
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        #expect(result?.count == 2 && model.liveBarrels.isEmpty)
    }
    @Test func failedPhysicalStrikeIsAtomic() {
        for (x, clear) in [(0.0, true), (120, false)] {
            var model = fight(playerX: x); let before = model
            let broken = model.breakBarrel("a", clearLine: clear)
            #expect(!broken)
            #expect(model == before)
        }
    }
    @Test func survivorsPushOnceWithoutSpendingMovementAndSaveAtEndpoint() throws {
        var model = fight()
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let events = try #require(result)
        let budget = model.budget
        let moves = model.applyExplosionKnockback(events) { actor, _, _ in
            CGPoint(x: actor.position.x + 80, y: actor.position.y)
        }
        #expect(moves.count == 1 && moves[0].id == "near")
        #expect(moves[0].from.x == 220 && moves[0].to.x == 300)
        #expect(model.budget == budget && model.actors.first { $0.id == "near" }!.conscious)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && restored.actors.first { $0.id == "near" }!.position.x == 300)
    }
    @Test func unconsciousActorsAreNotPushed() throws {
        var model = fight(playerX: 90, hp: 1)
        let result = model.igniteBarrel("a", clearShot: true, visible: { _, _ in true })
        let moves = model.applyExplosionKnockback(try #require(result)) { actor, _, _ in
            CGPoint(x: actor.position.x + 80, y: actor.position.y)
        }
        #expect(!moves.contains { $0.id == TacticalCombat.playerID })
    }
    @Test func pushStopsAtRasterWallAndRestoresOccupancy() {
        let target = actor("pushed", x: 200)
        for wall in [false, true] {
            let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 600, height: 400),
                obstacles: wall ? [CGRect(x: 250, y: 0, width: 16, height: 400)] : [])
            map.registerActor(id: target.id, kind: .npc, at: target.position)
            map.registerActor(id: "oil", kind: .npc, at: CGPoint(x: 180, y: 100))
            let records = map.occupancy.actors
            let end = CombatNavigation.knockbackDestination(in: map, actor: target,
                awayFrom: CGPoint(x: 100, y: 100), actors: [target], destroyedBarrels: ["oil"])
            #expect(wall ? (end.x > 200 && end.x < 250) : end.x == 280)
            #expect(end.y == 100 && map.occupancy.actors == records)
        }
    }
    @Test func pushStopsAtOtherActorsAndMapEdgeAndUsesProjectedDistance() {
        let target = actor("pushed", x: 200)
        let other = actor("blocking", x: 260)
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 500, height: 400), obstacles: [])
        map.registerActor(id: target.id, kind: .npc, at: target.position)
        map.registerActor(id: other.id, kind: .npc, at: other.position)
        let end = CombatNavigation.knockbackDestination(in: map, actor: target,
            awayFrom: CGPoint(x: 100, y: 100), actors: [target, other], destroyedBarrels: [])
        #expect(end.x < other.position.x && end.x >= target.position.x)
        let vertical = CombatNavigation.knockbackDestination(in: map, actor: target,
            awayFrom: CGPoint(x: 200, y: 50), actors: [target, other], destroyedBarrels: [])
        #expect(vertical == CGPoint(x: 200, y: 160))
        let edge = actor("edge", x: 480)
        let boundary = CombatNavigation.knockbackDestination(in: map, actor: edge,
            awayFrom: CGPoint(x: 400, y: 100), actors: [edge], destroyedBarrels: [], bear: true)
        #expect(boundary.x < 500)
    }

    @Test func aCharacterStandingInTheSpillIsNotShieldedByAnEmptyLineWalk() {
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 400, height: 300), obstacles: [])
        let point = CGPoint(x: 200, y: 100)
        map.registerActor(id: "standing", kind: .npc, at: point)
        #expect(CombatNavigation.clearLine(in: map, from: point, to: point, excluding: ["standing"]))
        #expect(!CombatNavigation.clearLine(in: map, from: point, to: point))
    }

}

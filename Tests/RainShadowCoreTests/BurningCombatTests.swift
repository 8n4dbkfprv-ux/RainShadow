import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct BurningCombatTests {
    private func fight(seed: UInt64 = 1, playerBurn: Int? = nil, enemyBurn: Int? = nil,
                       enemyHP: Int = 40) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            .init(id: TacticalCombat.playerID, name: "Voss", player: true, position: .init(x: 100, y: 100),
                  hp: 40, maximumHP: 40, defence: 12, attackBonus: 100, damageMin: 2, damageMax: 2,
                  initiativeBonus: 100, rangedWeapon: .bow, burningTurns: playerBurn),
            .init(id: "crew", name: "Crew", player: false, position: .init(x: 300, y: 100),
                  hp: enemyHP, maximumHP: 40, defence: 12, attackBonus: 100, damageMin: 2, damageMax: 2,
                  initiativeBonus: -100, rangedWeapon: .bow, burningTurns: enemyBurn)
        ], seed: seed)
    }
    @Test func onlySuccessfulFireArrowsIgniteAndDamageWaitsForTargetTurnEnd() throws {
        var hits = 0, misses = 0
        for seed in 1...60 {
            var combat = fight(seed: UInt64(seed))
            let strike = try #require({ combat.attack(target: "crew", clearLine: true, ranged: true) }())
            #expect(strike.fireArrow)
            let victim = combat.actors.first { $0.id == "crew" }!
            #expect(victim.hp == 40 - strike.damage)
            #expect(victim.isBurning == (strike.damage > 0))
            if strike.damage > 0 {
                hits += 1
                #expect(victim.burningTurns == 2)
                _ = combat.endTurn()
                #expect(combat.current.hp == victim.hp && combat.current.burningTurns == 2)
            } else { misses += 1 }
        }
        #expect(hits > 0 && misses > 0)
        for move in [CombatManeuver.aimedShot, .pinningShot] {
            var combat = fight()
            let strike = try #require({ combat.attack(target: "crew", clearLine: true, ranged: true, maneuver: move) }())
            #expect(!strike.fireArrow && !combat.actors[1].isBurning)
        }
        var sneak = fight()
        #expect({ sneak.hide(observed: false) }())
        let strike = try #require({ sneak.attack(target: "crew", clearLine: true, ranged: true, requireSneakAttack: true) }())
        #expect(!strike.fireArrow && !sneak.actors[1].isBurning)
    }
    @Test func burnTicksTwiceAndExpiredSaveDoesNotReplay() throws {
        var combat = fight(playerBurn: 2)
        var total = 0
        for remaining in [1, 0] {
            let hp = combat.current.hp
            var result: TacticalCombat.Strike?
            #expect({ combat.endTurn(burningHit: { result = $0 }) }())
            let hit = try #require(result)
            #expect((1...4).contains(hit.damage)); total += hit.damage
            #expect(combat.actors.first { $0.player }!.hp == hp - hit.damage)
            #expect((combat.actors.first { $0.player }!.burningTurns ?? 0) == remaining)
            _ = combat.endTurn()
        }
        var restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(combat))
        #expect(restored == combat && restored.isValid)
        _ = restored.endTurn()
        #expect(restored.actors.first { $0.player }!.hp == 40 - total)
    }
    @Test func extinguishCostsOneStandardActionAndInvalidRequestsAreAtomic() {
        var combat = fight(playerBurn: 2)
        #expect(!combat.canHide)
        #expect({ combat.extinguish() }())
        #expect(!combat.current.isBurning && !combat.budget.canAttack)
        #expect(combat.budget.availableMovement(speed: 240) == 240)
        let after = combat
        #expect({ !combat.extinguish() }()); #expect(combat == after)
        _ = combat.endTurn(); _ = combat.endTurn()
        #expect(combat.current.hp == 40)
        var spent = fight(playerBurn: 2)
        #expect({ spent.castBladeWard() }())
        let before = spent
        #expect({ !spent.extinguish() }()); #expect(spent == before)
        var blocked = fight()
        let original = blocked
        #expect({ blocked.attack(target: "crew", clearLine: false, ranged: true) == nil }())
        #expect(blocked == original)
    }
    @Test func reapplicationRefreshesWithoutStackingOrImmediateBurnDamage() throws {
        var tested = false
        for seed in 1...30 {
            var combat = fight(seed: UInt64(seed), enemyBurn: 1)
            let hit = try #require({ combat.attack(target: "crew", clearLine: true, ranged: true) }())
            guard hit.damage > 0 else { continue }
            #expect(combat.actors[1].burningTurns == 2 && combat.actors[1].hp == 38)
            tested = true; break
        }
        #expect(tested)
    }
    @Test func burnUsesBearEnduranceAndCanForceReversionWithoutDoubleDamage() throws {
        var combat = fight(playerBurn: 2)
        #expect({ combat.transformToBear(hasClearance: true) }())
        var burn: TacticalCombat.Strike?
        _ = combat.endTurn(burningHit: { burn = $0 })
        let hit = try #require(burn)
        #expect(combat.actors.first { $0.player }!.hp == 40)
        #expect(combat.bearForm?.temporaryHP == BearFormState().temporaryHP - hit.damage)
        // A saved nearly exhausted form must absorb only what remains.
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(combat)) as? [String: Any])
        var form = try #require(object["bearForm"] as? [String: Any]); form["temporaryHP"] = 1; object["bearForm"] = form
        combat = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        _ = combat.endTurn()
        _ = combat.endTurn(burningHit: { burn = $0 })
        #expect(!combat.isBear)
        #expect(combat.actors.first { $0.player }!.hp == 40 - max(0, burn!.damage - 1))
    }
    @Test func burnKnockoutFinishesCombatAndNeverSelectsAnUnconsciousTurn() {
        var combat = fight(enemyBurn: 2, enemyHP: 1)
        _ = combat.endTurn()
        #expect(!combat.current.player)
        #expect({ combat.endTurn() }())
        #expect(combat.outcome == .won && combat.isValid)
        #expect(combat.current.hp == 0 && !combat.current.isBurning)
        let after = combat
        #expect({ !combat.endTurn() }()); #expect(combat == after)
    }
    @Test func checkpointsPreserveBurnAndRandomnessAndRejectInvalidDurations() throws {
        let original = fight(playerBurn: 2)
        var restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(original))
        var uninterrupted = original
        _ = restored.endTurn(); _ = uninterrupted.endTurn()
        #expect(restored == uninterrupted)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var actors = try #require(object["actors"] as? [[String: Any]])
        actors[0].removeValue(forKey: "burningTurns"); object["actors"] = actors
        let legacy = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.isValid && !legacy.current.isBurning)
        for invalid in [-1, 0, 3, Int.max] {
            actors[0]["burningTurns"] = invalid; object["actors"] = actors
            let corrupt = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
            #expect(!corrupt.isValid)
        }
    }
}

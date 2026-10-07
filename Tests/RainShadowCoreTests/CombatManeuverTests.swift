import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct CombatManeuverTests {
    private func fight(ranged: Bool = false, seed: UInt64 = 1, defence: Int = 12,
                       bonus: Int = 8, hp: Int = 60, conditions: CombatConditions? = nil) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: .init(x: 100, y: 100),
                hp: 60, maximumHP: 60, defence: 12, attackBonus: bonus, damageMin: 8, damageMax: 8,
                initiativeBonus: 100, rangedWeapon: .bow),
            Combatant(id: "crew", name: "Crew", player: false, position: .init(x: ranged ? 300 : 180, y: 100),
                hp: hp, maximumHP: 60, defence: defence, attackBonus: 8, damageMin: 4, damageMax: 4,
                initiativeBonus: -100, conditions: conditions)
        ], seed: seed)
    }
    @Test func invalidTechniquesAreAtomicAndRequireTheirWeaponAndMode() {
        for maneuver in CombatManeuver.allCases {
            var combat = fight(ranged: maneuver.ranged)
            let before = combat
            let operation21 = combat.attack(target: "crew", clearLine: false, ranged: maneuver.ranged, maneuver: maneuver, hasSword: true) == nil
            #expect(operation21)
            let operation22 = combat.attack(target: "crew", clearLine: true, ranged: !maneuver.ranged, maneuver: maneuver, hasSword: true) == nil
            #expect(operation22)
            let operation23 = combat.attack(target: TacticalCombat.playerID, clearLine: true, ranged: maneuver.ranged, maneuver: maneuver, hasSword: true) == nil
            #expect(operation23)
            if !maneuver.ranged {
                let operation25 = combat.attack(target: "crew", clearLine: true, maneuver: maneuver) == nil
                #expect(operation25)
            }
            #expect(combat == before)
        }
        var bear = fight()
        let operation30 = bear.transformToBear(hasClearance: true)
        #expect(operation30)
        _ = bear.endTurn(); _ = bear.endTurn()
        for maneuver in CombatManeuver.allCases { #expect(!bear.canUse(maneuver, hasSword: true)) }
    }
    @Test func techniquesChangeDamageAccuracyAndRespectNaturalRolls() throws {
        var sawPowerTradeoff = false, sawAimBenefit = false, sawMiss = false, sawNaturalTwenty = false
        for seed in 1...120 {
            var normal = fight(seed: UInt64(seed))
            var power = normal
            let operation39 = normal.attack(target: "crew", clearLine: true)
            let base = try #require(operation39)
            let operation40 = power.attack(target: "crew", clearLine: true, maneuver: .powerStrike, hasSword: true)
            let heavy = try #require(operation40)
            #expect(base.roll == heavy.roll)
            if base.damage > 0 && heavy.damage == 0 { sawPowerTradeoff = true }
            if heavy.damage > 0 { #expect(heavy.damage == 11) }
            if heavy.roll == 1 { #expect(heavy.damage == 0); sawMiss = true }
            if heavy.roll == 20 { #expect(heavy.damage == 11); sawNaturalTwenty = true }
            var shot = fight(ranged: true, seed: UInt64(seed), defence: 19)
            var aimed = shot
            let operation48 = shot.attack(target: "crew", clearLine: true, ranged: true)
            let ordinary = try #require(operation48)
            let operation49 = aimed.attack(target: "crew", clearLine: true, ranged: true, maneuver: .aimedShot)
            let precise = try #require(operation49)
            if ordinary.damage == 0 && precise.damage > 0 { sawAimBenefit = true }
            #expect(precise.damage == 0 || precise.damage == 8)
        }
        #expect(sawPowerTradeoff && sawAimBenefit && sawMiss && sawNaturalTwenty)
    }
    @Test func fullTurnShotPreventsMovementAndCannotFollowMovement() throws {
        var combat = fight(ranged: true)
        let operation57 = combat.attack(target: "crew", clearLine: true, ranged: true, maneuver: .aimedShot) != nil
        #expect(operation57)
        #expect(!combat.budget.canAttack)
        #expect(combat.budget.availableMovement(speed: 240) == 0)
        var moved = fight(ranged: true)
        let path = Path(points: [CGPoint(x: 116, y: 100)], from: moved.current.position)
        let operation62 = moved.move(along: path)
        #expect(operation62)
        let before = moved
        #expect(!moved.canUse(.aimedShot))
        let operation65 = moved.attack(target: "crew", clearLine: true, ranged: true, maneuver: .aimedShot) == nil
        #expect(operation65)
        #expect(moved == before)
        let operation67 = moved.attack(target: "crew", clearLine: true, ranged: true, maneuver: .pinningShot) != nil
        #expect(operation67)
    }
    @Test func conditionsLastThroughAffectedTurnThenExpireAndSavesKeepUses() throws {
        for maneuver in [CombatManeuver.feintingCut, .pinningShot] {
            var combat = fight(ranged: maneuver.ranged, bonus: 100)
            // Find a non-natural-one outcome without relying on one magic seed.
            for seed in 1...30 {
                var trial = fight(ranged: maneuver.ranged, seed: UInt64(seed), bonus: 100)
                if trial.attack(target: "crew", clearLine: true, ranged: maneuver.ranged, maneuver: maneuver, hasSword: true)?.damage == 4 {
                    combat = trial; break
                }
            }
            let victim = try #require(combat.actors.first { $0.id == "crew" })
            #expect(victim.hp == 56)
            #expect(combat.current.usedManeuvers == [maneuver])
            #expect(victim.conditions?.weakened == (maneuver == .feintingCut))
            #expect(victim.conditions?.slowed == (maneuver == .pinningShot))
            var restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(combat))
            #expect(restored.isValid && restored == combat)
            let operation86 = restored.endTurn()
            #expect(operation86)
            #expect(restored.current.conditions == victim.conditions)
            #expect(restored.movementSpeed(for: restored.current) == (maneuver == .pinningShot ? 120 : 240))
            #expect(restored.attackBonus(for: restored.current) == (maneuver == .feintingCut ? 5 : 8))
            let operation90 = restored.endTurn()
            #expect(operation90)
            #expect(restored.actors.first { $0.id == "crew" }?.conditions == nil)
            #expect(!restored.canUse(maneuver, hasSword: true))
            let before = restored
            let operation94 = restored.attack(target: "crew", clearLine: true, ranged: maneuver.ranged, maneuver: maneuver, hasSword: true) == nil
            #expect(operation94)
            #expect(before == restored)
        }
    }
    @Test func missedTechniqueStillSpendsUseButDoesNotApplyACondition() throws {
        for maneuver in CombatManeuver.allCases {
            var combat = fight(ranged: maneuver.ranged, defence: 1000, bonus: -100)
            // Seed 1 is checked below rather than assuming this was a miss.
            let operation102 = combat.attack(target: "crew", clearLine: true, ranged: maneuver.ranged, maneuver: maneuver, hasSword: true)
            let result = try #require(operation102)
            #expect(result.damage == 0)
            #expect(combat.current.usedManeuvers == [maneuver])
            #expect(combat.actors.first { $0.id == "crew" }?.conditions == nil)
        }
    }
    @Test func oldCheckpointHasNoUsesOrConditions() throws {
        let data = try JSONEncoder().encode(fight())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var actors = try #require(object["actors"] as? [[String: Any]])
        for i in actors.indices { actors[i].removeValue(forKey: "usedManeuvers"); actors[i].removeValue(forKey: "conditions") }
        object["actors"] = actors
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.isValid && restored.canUse(.powerStrike, hasSword: true))
    }
    @Test func aiChoosesUsefulTechniquesAndPreservesFinishingDamage() throws {
        func choose(_ combat: TacticalCombat, ranged: Bool = false) -> CombatManeuver? {
            combat.preferredManeuver(target: combat.actors.first { $0.id == "crew" }!, ranged: ranged, hasSword: true)
        }
        #expect(choose(fight(defence: 9)) == .powerStrike)
        #expect(choose(fight(defence: 17)) == .feintingCut)
        #expect(choose(fight(defence: 17, conditions: .init(weakened: true))) == nil)
        #expect(choose(fight(hp: 4)) == nil)
        #expect(choose(fight(ranged: true, defence: 20), ranged: true) == .aimedShot)
        #expect(choose(fight(ranged: true, defence: 9), ranged: true) == .pinningShot)
        #expect(choose(fight(ranged: true, defence: 9, conditions: .init(slowed: true)), ranged: true) == nil)
        var combat = fight(defence: 9)
        _ = combat.attack(target: "crew", clearLine: true, maneuver: .powerStrike, hasSword: true)
        _ = combat.endTurn(); _ = combat.endTurn()
        #expect(choose(combat) == .feintingCut)
        _ = combat.attack(target: "crew", clearLine: true, maneuver: .feintingCut, hasSword: true)
        _ = combat.endTurn(); _ = combat.endTurn()
        #expect(choose(combat) == nil)
    }
}

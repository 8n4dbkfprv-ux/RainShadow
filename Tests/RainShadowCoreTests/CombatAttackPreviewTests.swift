import Testing
import Foundation
@testable import RainShadowCore

struct CombatAttackPreviewTests {
    private func fight(seed: UInt64 = 1, ranged: Bool = false, bonus: Int = 4,
                       condition: CombatConditions? = nil, ward: Bool = false) -> TacticalCombat {
        TacticalCombat(encounterID: "preview", areaID: "qa", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: .zero,
                hp: 100, maximumHP: 100, defence: 12, attackBonus: bonus, damageMin: 5, damageMax: 9,
                initiativeBonus: 100, rangedWeapon: .bow, conditions: condition),
            Combatant(id: "enemy", name: "Enemy", player: false, position: .init(x: ranged ? 300 : 80, y: 0),
                hp: 100, maximumHP: 100, defence: 15, attackBonus: 4, damageMin: 2, damageMax: 6,
                initiativeBonus: -100, bladeWardTurns: ward ? 2 : nil)
        ], seed: seed)
    }
    @Test func exactChancesRespectNaturalRollsAndBothEdges() {
        for (edge, expected) in [(0, 0.5), (1, 0.75), (-1, 0.25)] {
            let condition = CombatConditions(attackAdvantage: edge > 0, attackDisadvantage: edge < 0)
            let model = fight(condition: condition)
            let preview = model.attackPreview(target: model.actors.first { !$0.player }!, clearLine: true)
            #expect(abs(preview.hitChance - expected) < 0.00001)
        }
        for (bonus, expected) in [(-100, 0.05), (100, 0.95)] {
            let model = fight(bonus: bonus)
            #expect(model.attackPreview(target: model.actors.first { !$0.player }!, clearLine: true).hitChance == expected)
        }
        let cancelled = fight(condition: CombatConditions(attackAdvantage: true, attackDisadvantage: true))
        #expect(cancelled.attackPreview(target: cancelled.actors.first { !$0.player }!, clearLine: true).edge == 0)
    }
    @Test func forecastsMatchResolvedDamageWithoutConsumingRandomness() throws {
        for maneuver in [nil] + CombatManeuver.allCases.map(Optional.some) {
            for ward in [false, true] {
                for seed in 1...80 {
                    var model = fight(seed: UInt64(seed), ranged: maneuver?.ranged == true,
                                      condition: CombatConditions(attackAdvantage: true), ward: ward)
                    let original = model
                    let target = model.actors.first { !$0.player }!
                    let preview = model.attackPreview(target: target, clearLine: true, ranged: maneuver?.ranged == true,
                        maneuver: maneuver, hasSword: true)
                    #expect(model == original)
                    #expect(preview.unavailableReason == nil)
                    let result = model.attack(target: target.id, clearLine: true, ranged: maneuver?.ranged == true, maneuver: maneuver, hasSword: true)
                    let strike = try #require(result)
                    if strike.landed {
                        #expect((strike.roll == 20 ? preview.criticalDamage : preview.damage).contains(strike.damage))
                    } else { #expect(strike.damage == 0) }
                }
            }
        }
    }
    @Test func blockedEligibilityMatchesResolver() throws {
        for maneuver in [nil] + CombatManeuver.allCases.map(Optional.some) {
            for ranged in [true, false] {
                for line in [true, false] {
                    for sword in [true, false] {
                        var model = fight(ranged: ranged)
                        let target = model.actors.first { !$0.player }!
                        let preview = model.attackPreview(target: target, clearLine: line, ranged: ranged, maneuver: maneuver, hasSword: sword)
                        let result = model.attack(target: target.id, clearLine: line, ranged: ranged, maneuver: maneuver, hasSword: sword)
                        #expect((preview.unavailableReason == nil) == (result != nil))
                    }
                }
            }
        }
        var model = fight(ranged: true)
        let target = model.actors.first { !$0.player }!
        #expect(model.attackPreview(target: target, clearLine: true).unavailableReason?.contains("reach") == true)
        _ = model.dash()
        #expect(model.attackPreview(target: target, clearLine: true, ranged: true).unavailableReason == "No standard action remains.")
    }
    @Test func sneakAndWardRangesExplainCriticalAndMinimumRounding() {
        let model = fight(condition: CombatConditions(attackAdvantage: true), ward: true)
        let preview = model.attackPreview(target: model.actors.first { !$0.player }!, clearLine: true, hasSword: true)
        #expect(preview.damage == 3...7)
        #expect(preview.criticalDamage == 3...10)
        #expect(preview.sneakDice == 1)
    }
    @Test func bearUsesItsOwnDamageAndForbidsBow() {
        var model = fight()
        _ = model.transformToBear(hasClearance: true)
        _ = model.endTurn(); _ = model.endTurn()
        let target = model.actors.first { !$0.player }!
        let preview = model.attackPreview(target: target, clearLine: true)
        #expect(preview.damage == BearFormRules.damageMin...BearFormRules.damageMax)
        #expect(preview.sneakDice == 0)
        #expect(model.attackPreview(target: target, clearLine: true, ranged: true).unavailableReason != nil)
    }
}

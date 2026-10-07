import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct SneakAttackTests {
    private func fight(seed: UInt64 = 1, ranged: Bool = false, disadvantage: Bool = false,
                       enemyRogue: Bool = false, ally: Bool = false) -> TacticalCombat {
        var player = Combatant(id: TacticalCombat.playerID, name: "Voss", player: true,
            position: .init(x: 100, y: 100), hp: 100, maximumHP: 100, defence: 10,
            attackBonus: 100, damageMin: 8, damageMax: 8, initiativeBonus: enemyRogue ? -100 : 100,
            rangedWeapon: .bow)
        player.conditions = .init(attackDisadvantage: disadvantage ? true : nil)
        let rogue = Combatant(id: "rogue", name: "Rogue", player: false,
            position: .init(x: ranged ? 310 : 180, y: 100), hp: 100, maximumHP: 100, defence: 10,
            attackBonus: 100, damageMin: 8, damageMax: 8, initiativeBonus: enemyRogue ? 100 : -100,
            sneakDice: enemyRogue ? 1 : 0)
        var actors = [player, rogue]
        if ally { actors.append(Combatant(id: "ally", name: "Ally", player: false,
            position: .init(x: 100, y: 140), hp: 20, maximumHP: 20, defence: 10,
            attackBonus: 2, damageMin: 1, damageMax: 2, initiativeBonus: -100)) }
        return TacticalCombat(encounterID: "sneak", areaID: "city_wharf_ladder", actors: actors, seed: seed)
    }
    @Test func hiddenMeleeAndBowRollWithAdvantageAndAddSeparateDamage() throws {
        for ranged in [false, true] {
            var model = fight(ranged: ranged)
            let hidden = model.hide(observed: false)
            #expect(hidden && model.budget.state == 4)
            let operation = model.attack(target: "rogue", clearLine: true, ranged: ranged,
                hasSword: !ranged, requireSneakAttack: true)
            let hit = try #require(operation)
            #expect(hit.attackRolls.count == 2 && hit.roll == hit.attackRolls.max())
            #expect(hit.sneakDamage > 0 && hit.damage == 8 + hit.sneakDamage)
            #expect(model.current.sneakSpent == true && model.current.hidden != true)
            #expect(!model.budget.canAttack && model.budget.availableMovement(speed: 240) == 240 && hit.requestedSneakAttack)
        }
    }
    @Test func rejectedHideAndSneakSpendNeitherActionsNorRandomness() {
        var model = fight(); let original = model
        let hide = model.hide(observed: true)
        #expect(!hide && model == original)
        let rejected = model.attack(target: "rogue", clearLine: true, hasSword: true, requireSneakAttack: true)
        #expect(rejected == nil && model == original)
        _ = model.hide(observed: false); let hidden = model
        for (line, sword) in [(false, true), (true, false)] {
            let attempt = model.attack(target: "rogue", clearLine: line, hasSword: sword, requireSneakAttack: true)
            #expect(attempt == nil && model == hidden)
        }
        let secondHide = model.hide(observed: false)
        #expect(!secondHide && model == hidden)
    }
    @Test func aMissRevealsTheAttackerButDoesNotSpendSneakDamage() throws {
        var found = false
        for seed in 1...1000 {
            var model = fight(seed: UInt64(seed)); _ = model.hide(observed: false)
            let attempt = model.attack(target: "rogue", clearLine: true, hasSword: true, requireSneakAttack: true)
            let hit = try #require(attempt)
            if hit.damage == 0 {
                #expect(hit.roll == 1 && hit.sneakDamage == 0)
                #expect(model.current.sneakSpent != true && model.current.hidden != true)
                #expect(!model.budget.canAttack); found = true; break
            }
        }
        #expect(found)
    }
    @Test func nearbyConsciousAllyEnablesSneakWithoutAdvantageButWallsPreventIt() throws {
        var model = fight(enemyRogue: true, ally: true)
        let player = try #require(model.actors.first { $0.player })
        #expect(model.sneakAttackReason(target: player, ranged: false, hasSword: true, clearLine: true) == nil)
        #expect(model.sneakAttackReason(target: player, ranged: false, hasSword: true, clearLine: true,
            allyLine: { _, _ in false }) != nil)
        let attempt = model.attack(target: player.id, clearLine: true, hasSword: true, requireSneakAttack: true)
        let hit = try #require(attempt)
        #expect(hit.attackRolls.count == 1 && hit.sneakDamage > 0)
        var deadAlly = fight(enemyRogue: true, ally: true)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(deadAlly)) as? [String: Any])
        var actors = try #require(json["actors"] as? [[String: Any]])
        for i in actors.indices where actors[i]["id"] as? String == "ally" { actors[i]["hp"] = 0 }
        json["actors"] = actors
        deadAlly = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(deadAlly.sneakAttackReason(target: player, ranged: false, hasSword: true, clearLine: true) != nil)
    }
    @Test func disadvantageCancelsHiddenAdvantageAndCloseEnemiesHinderBows() throws {
        var model = fight(disadvantage: true); _ = model.hide(observed: false)
        #expect(model.attackEdge(ranged: false, allyLine: { _, _ in true }) == 0)
        let before = model
        let rejected = model.attack(target: "rogue", clearLine: true, hasSword: true, requireSneakAttack: true)
        #expect(rejected == nil && model == before)
        let ordinary = model.attack(target: "rogue", clearLine: true, hasSword: true)
        #expect(ordinary?.attackRolls.count == 1 && ordinary?.sneakDamage == 0)
        let bow = fight(ranged: true, ally: true)
        #expect(bow.attackEdge(ranged: true, allyLine: { _, _ in true }) == -1)
        #expect(bow.attackEdge(ranged: true, allyLine: { _, _ in false }) == 0)
    }
    @Test func criticalSneakRollsAdditionalDiceAndTechniquesKeepTheBonus() throws {
        var sawCriticalAboveSix = false
        for seed in 1...100 {
            var model = fight(seed: UInt64(seed)); _ = model.hide(observed: false)
            let attempt = model.attack(target: "rogue", clearLine: true, maneuver: .feintingCut, hasSword: true)
            let hit = try #require(attempt)
            if hit.damage > 0 { #expect(hit.damage == 4 + hit.sneakDamage) }
            if hit.roll == 20 {
                #expect((2...12).contains(hit.sneakDamage))
                sawCriticalAboveSix = sawCriticalAboveSix || hit.sneakDamage > 6
            } else if hit.damage > 0 { #expect((1...6).contains(hit.sneakDamage)) }
        }
        #expect(sawCriticalAboveSix)
    }
    @Test func saveLoadKeepsHiddenAndSpentStateAndTurnEndRefreshesDamage() throws {
        var model = fight(); _ = model.hide(observed: false)
        var saved = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(saved == model && saved.isValid && saved.current.hidden == true)
        _ = saved.attack(target: "rogue", clearLine: true, hasSword: true, requireSneakAttack: true)
        model = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(saved))
        #expect(model == saved && model.current.sneakSpent == true)
        _ = model.endTurn()
        #expect(model.actors.first { $0.player }?.sneakSpent != true)
        _ = model.endTurn()
        #expect(model.canHide && model.current.hideUsed != true)
    }
    @Test func legacyCheckpointsDecodeWithoutStealthFieldsAndCorruptOnesFailValidation() throws {
        let model = fight()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any])
        var actors = try #require(json["actors"] as? [[String: Any]])
        for i in actors.indices {
            for key in ["sneakDice", "sneakSpent", "hidden", "hideUsed", "lastSeenPosition", "combatFacing"] { actors[i].removeValue(forKey: key) }
        }
        json["actors"] = actors
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.isValid && restored.current.sneakDamageDice == 1 && restored.current.hidden != true)
        actors[0]["hidden"] = true; actors[0]["sneakDice"] = -1; json["actors"] = actors
        let corrupt = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!corrupt.isValid)
    }
    @Test func sightUsesFacingAndProjectedDistanceAndBearCannotSneak() throws {
        var model = fight()
        var observer = model.current; observer.combatFacing = ActorFacing.east.rawValue
        #expect(TacticalCombat.insideSightCone(observer: observer, point: .init(x: 200, y: 100)))
        #expect(!TacticalCombat.insideSightCone(observer: observer, point: .init(x: 0, y: 100)))
        #expect(!TacticalCombat.insideSightCone(observer: observer, point: .init(x: 900, y: 100)))
        observer.combatFacing = ActorFacing.north.rawValue
        #expect(TacticalCombat.insideSightCone(observer: observer, point: .init(x: 100, y: 400)))
        _ = model.hide(observed: false); _ = model.transformToBear(hasClearance: true)
        #expect(model.isBear && !model.canHide && model.current.hidden != true)
        let target = try #require(model.actors.first { !$0.player })
        #expect(model.sneakAttackReason(target: target, ranged: false, hasSword: true, clearLine: true) != nil)
    }
    @Test func concealedTargetsCannotBeDirectlyAttackedAndOrdinaryEnemiesCannotHide() {
        var model = fight(); _ = model.hide(observed: false); _ = model.endTurn()
        #expect(!model.canHide)
        let before = model
        let attempt = model.attack(target: TacticalCombat.playerID, clearLine: true, hasSword: true)
        #expect(attempt == nil && model == before)
        model.reveal(TacticalCombat.playerID)
        let visibleAttack = model.attack(target: TacticalCombat.playerID, clearLine: true, hasSword: true)
        #expect(visibleAttack != nil && visibleAttack?.sneakDamage == 0)
    }

}

import Foundation
import CoreGraphics
import simd
import Testing
@testable import RainShadowCore

struct CombatDiceTests {
    private func fight(seed: UInt64, condition: CombatConditions? = nil) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: .init(x: 100, y: 100),
                hp: 30, maximumHP: 30, defence: 12, attackBonus: 5, damageMin: 2, damageMax: 7, initiativeBonus: 100, conditions: condition),
            Combatant(id: "crew", name: "Crew", player: false, position: .init(x: 150, y: 100),
                hp: 100, maximumHP: 100, defence: 14, attackBonus: 3, damageMin: 1, damageMax: 3, initiativeBonus: 0)
        ], seed: seed)
    }
    @Test func recordedFacesMatchExistingRNGWithoutAdditionalDraws() throws {
        var seenHit = false, seenMiss = false, seenCritical = false
        for seed in UInt64(1)...200 {
            var combat = fight(seed: seed)
            var rng = combat.randomState
            func next(_ sides: Int) -> Int {
                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                return Int((rng >> 32) % UInt64(sides)) + 1
            }
            let expectedAttack = next(20)
            let hit = expectedAttack == 20 || (expectedAttack != 1 && expectedAttack + 5 >= 14)
            let expectedDamage = hit ? next(6) : 0
            let attack = combat.attack(target: "crew", clearLine: true)
            let result = try #require(attack)
            #expect(result.attackRolls == [expectedAttack])
            #expect(result.damageDice == (hit ? [CombatDie(sides: 6, value: expectedDamage)] : []))
            #expect(result.damage == (hit ? expectedDamage + 1 : 0))
            #expect(combat.randomState == rng)
            #expect(result.dicePresentation.count == (hit ? 2 : 1))
            #expect(combat.displayedLog.contains { $0.hasPrefix("Roll · Attack:") })
            seenHit = seenHit || hit; seenMiss = seenMiss || !hit; seenCritical = seenCritical || expectedAttack == 20
        }
        #expect(seenHit && seenMiss && seenCritical)
    }
    @Test func advantageDisadvantageAndCriticalSneakKeepEveryActualDraw() throws {
        var sawCriticalSneak = false
        for edge in [-1, 1] {
            for seed in UInt64(1)...200 {
                var combat = fight(seed: seed, condition: CombatConditions(attackAdvantage: edge > 0, attackDisadvantage: edge < 0))
                var state = combat.randomState
                func next(_ sides: Int) -> Int {
                    state = state &* 6364136223846793005 &+ 1442695040888963407
                    return Int((state >> 32) % UInt64(sides)) + 1
                }
                let attacks = [next(20), next(20)]
                let selected = edge > 0 ? attacks.max()! : attacks.min()!
                let hit = selected == 20 || (selected != 1 && selected + 5 >= 14)
                let sneakCount = hit && edge > 0 ? (selected == 20 ? 2 : 1) : 0
                let damage = hit ? (0..<(1 + sneakCount)).map { _ in CombatDie(sides: 6, value: next(6)) } : []
                let operation = combat.attack(target: "crew", clearLine: true, hasSword: true)
                let strike = try #require(operation)
                #expect(strike.attackRolls == attacks && strike.roll == selected)
                #expect(strike.damageDice == damage)
                #expect(strike.sneakDamage == damage.dropFirst().reduce(0) { $0 + $1.value })
                #expect(combat.randomState == state)
                #expect(strike.dicePresentation.first?.critical == (hit && selected == 20))
                sawCriticalSneak = sawCriticalSneak || sneakCount == 2
            }
        }
        #expect(sawCriticalSneak)
    }
    @Test func fastSkipAndCockedRetryCannotChangeAcceptedSaveOrNextAttack() throws {
        var combat = fight(seed: 88)
        let attack = combat.attack(target: "crew", clearLine: true)
        let result = try #require(attack)
        let accepted = combat
        for speed in CombatDiceSpeed.allCases {
            var motion = TabletopDiceMotion(faceNormal: SIMD3<Float>(1, 0, 0), restingHeight: 0.7, index: 0, count: 1)
            motion.advance(delta: 0.2); motion.retryCocked()
            if speed == .skip { motion.settle() }
            else { for _ in 0..<400 { motion.advance(delta: (1.0 / 120) * speed.multiplier) } }
            #expect(motion.finished)
            #expect(TabletopDiceMotion.upperFace(normals: [SIMD3<Float>(1, 0, 0), SIMD3<Float>(-1, 0, 0)], orientation: motion.orientation) == 0)
            #expect(combat == accepted)
            var restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(combat))
            var original = combat
            _ = restored.endTurn(); _ = original.endTurn()
            let resumedStrike = restored.attack(target: TacticalCombat.playerID, clearLine: true)
            let uninterruptedStrike = original.attack(target: TacticalCombat.playerID, clearLine: true)
            #expect(resumedStrike == uninterruptedStrike)
            #expect(restored == original)
            #expect(result.dicePresentation.allSatisfy { $0.shouldPresent })
        }
    }
    @Test func minorAndInvalidReceiptsStaySilentStoryCriticalCanPresent() {
        let die = CombatDie(sides: 20, value: 12)
        #expect(!CombatDiceRoll(kind: .minor, dice: [die], caption: "Shove").shouldPresent)
        #expect(CombatDiceRoll(kind: .storyCritical, dice: [die], caption: "Keep the key").shouldPresent)
        #expect(!CombatDiceRoll(kind: .attack, dice: [CombatDie(sides: 20, value: 21)], caption: "").shouldPresent)
        #expect(!CombatDiceRoll(kind: .damage, dice: [], caption: "").shouldPresent)
    }
    @Test func physicsIsStableAcrossRefreshRatesAndDetectsCockedFaces() {
        let normals: [SIMD3<Float>] = [.init(1,0,0), .init(-1,0,0), .init(0,1,0), .init(0,-1,0), .init(0,0,1), .init(0,0,-1)]
        #expect(TabletopDiceMotion.upperFace(normals: normals, orientation: simd_quatf(angle: .pi / 4, axis: .init(0,0,1))) == nil)
        for fps in [30,60,120] {
            var motion = TabletopDiceMotion(faceNormal: normals[0], restingHeight: 0.7, index: 1, count: 2)
            for _ in 0..<(fps * 3) { motion.advance(delta: 1 / Double(fps)) }
            #expect(motion.finished && motion.contacts > 0)
            #expect(abs(motion.position.y - 0.7) < 0.0001)
            #expect(TabletopDiceMotion.upperFace(normals: normals, orientation: motion.orientation) == 0)
        }
    }
}

import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct TripAttackTests {
    private func fight(seed: UInt64 = 1, targetHP: Int = 80, ranged: Bool = false,
                       prone: Bool = false, slowed: Bool = false) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            .init(id: TacticalCombat.playerID, name: "Voss", player: true, position: .init(x: 100, y: 100),
                  hp: 80, maximumHP: 80, defence: 12, attackBonus: 30, damageMin: 8, damageMax: 8,
                  initiativeBonus: 100, rangedWeapon: .bow, sneakDice: 0),
            .init(id: "target", name: "Target", player: false, position: .init(x: ranged ? 300 : 180, y: 100),
                  hp: targetHP, maximumHP: 80, defence: 12, attackBonus: 4, damageMin: 4, damageMax: 4,
                  initiativeBonus: -100, conditions: .init(slowed: slowed, prone: prone ? true : nil)),
            .init(id: "witness", name: "Witness", player: false, position: .init(x: 500, y: 100),
                  hp: 80, maximumHP: 80, defence: 12, attackBonus: 4, damageMin: 4, damageMax: 4,
                  initiativeBonus: 0)
        ], seed: seed)
    }
    private func successfulTrip() throws -> TacticalCombat {
        for seed in 1...30 {
            var model = fight(seed: UInt64(seed))
            let result = model.attack(target: "target", clearLine: true, maneuver: .tripAttack, hasSword: true)
            if result?.damage == 4 { return model }
        }
        throw NSError(domain: "No successful fixture", code: 1)
    }
    @Test func hitKnocksDownUntilVictimsTurnAndStandingSpendsMovementOnce() throws {
        var model = try successfulTrip()
        #expect(model.actors.first { $0.id == "target" }!.isProne)
        #expect(!model.budget.canAttack)
        #expect(model.current.usedManeuvers == [.tripAttack])
        _ = model.endTurn()
        #expect(model.current.id == "witness")
        #expect(model.actors.first { $0.id == "target" }!.isProne)
        _ = model.endTurn()
        #expect(model.current.id == "target" && !model.current.isProne)
        #expect(model.budget.canAttack && model.budget.movementRemaining == 120)
        let loaded = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(loaded == model && loaded.isValid)
        _ = model.endTurn(); _ = model.endTurn(); _ = model.endTurn()
        #expect(model.current.id == "target" && model.budget == CombatBudget())
    }
    @Test func missSpendsUseButDoesNotKnockDownAndKnockoutNeverAppliesProne() throws {
        var sawMiss = false
        for seed in 1...100 {
            var model = fight(seed: UInt64(seed))
            let attempted = model.attack(target: "target", clearLine: true, maneuver: .tripAttack, hasSword: true)
            let result = try #require(attempted)
            if result.roll == 1 {
                sawMiss = true
                #expect(result.damage == 0 && !model.actors.first { $0.id == "target" }!.isProne)
                #expect(model.current.usedManeuvers == [.tripAttack] && !model.budget.canAttack)
            }
            var lethal = fight(seed: UInt64(seed), targetHP: 1)
            let hit = lethal.attack(target: "target", clearLine: true, maneuver: .tripAttack, hasSword: true)
            if hit?.damage ?? 0 > 0 {
                #expect(hit?.knockedOut == true && lethal.actors.first { $0.id == "target" }!.conditions?.prone != true)
            }
        }
        #expect(sawMiss)
    }
    @Test func invalidTargetsAndWrongEquipmentAreAtomic() {
        for (ranged, prone, sword, clear) in [(true,false,true,true), (false,true,true,true), (false,false,false,true), (false,false,true,false)] {
            var model = fight(ranged: ranged, prone: prone)
            let before = model
            let result = model.attack(target: "target", clearLine: clear, maneuver: .tripAttack, hasSword: sword)
            #expect(result == nil && model == before)
        }
    }
    @Test func proneGrantsNearbyAdvantageAndDistantDisadvantage() throws {
        for ranged in [false, true] {
            var model = fight(ranged: ranged, prone: true)
            let target = model.actors.first { $0.id == "target" }!
            #expect(model.attackEdge(ranged: ranged, target: target, allyLine: { _, _ in true }) == (ranged ? -1 : 1))
            let operation = model.attack(target: target.id, clearLine: true, ranged: ranged)
            let strike = try #require(operation)
            #expect(strike.attackRolls.count == 2)
            #expect(strike.roll == (ranged ? strike.attackRolls.min()! : strike.attackRolls.max()!))
            #expect(model.actors.first { $0.id == target.id }!.isProne)
        }
    }
    @Test func saveWhileGroundedPreservesProneAndLegacyConditionsStillLoad() throws {
        let model = try successfulTrip()
        let data = try JSONEncoder().encode(model)
        let loaded = try JSONDecoder().decode(TacticalCombat.self, from: data)
        #expect(loaded == model && loaded.isValid)
        let old = Data("{\"weakened\":true,\"slowed\":false}".utf8)
        let condition = try JSONDecoder().decode(CombatConditions.self, from: old)
        #expect(condition.prone == nil && condition.weakened)
    }
    @Test func slowedRecoveryUsesHalfTheReducedSpeed() throws {
        for seed in 1...30 {
            var model = fight(seed: UInt64(seed), slowed: true)
            let result = model.attack(target: "target", clearLine: true, maneuver: .tripAttack, hasSword: true)
            if result?.damage ?? 0 == 0 { continue }
            _ = model.endTurn(); _ = model.endTurn()
            #expect(model.current.conditions?.slowed == true)
            #expect(model.budget.movementRemaining == 60 && model.budget.canAttack)
            return
        }
        Issue.record("No hit fixture")
    }
    @Test func enemyTripsToSetUpAnAdjacentAllyAndAvoidsGroundedTargets() {
        let base = fight()
        var actors = base.actors
        for i in actors.indices {
            actors[i].position = .init(x: actors[i].player ? 100 : 180, y: actors[i].id == "witness" ? 140 : 100)
            actors[i].initiativeBonus = actors[i].id == "target" ? 100 : -100
            actors[i].usedManeuvers = [.powerStrike]
        }
        let model = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: actors, seed: 1)
        let target = model.actors.first { $0.player }!
        #expect(model.preferredManeuver(target: target, ranged: false, hasSword: true) == .tripAttack)
        var down = target; down.conditions = .init(prone: true)
        #expect(model.preferredManeuver(target: down, ranged: false, hasSword: true) != .tripAttack)
    }
    @Test func tripTimingHasContactBeforeRecoveryAndGroundHoldBeforeStanding() {
        #expect(WeaponTechniqueMotion.meleeFrames(.tripAttack) == 16)
        #expect(WeaponTechniqueMotion.meleeImpact(.tripAttack) == 8.0 / 18)
        #expect(WeaponTechniqueMotion.meleeDuration(.tripAttack) > WeaponTechniqueMotion.meleeImpact(.tripAttack))
        var fall = CombatRecoil(from: .zero, to: .init(x: 80, y: 0), heavy: false, kind: .tripFall)
        fall.elapsed = ProneMotion.holdTime
        #expect(fall.phase == ProneMotion.holdPhase && !fall.finished)
        fall.elapsed += 0.6
        #expect(fall.finished)
    }
    @Test func everyTripFacingHasCompleteRegisteredBodyAndGear() throws {
        #expect(TripAnimationSet.hashes.count == 4)
        for character in TripAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try TripAnimationSet.validate(sprite, character: character)
            for facing in ActorFacing.allCases {
                let frames = try (0..<16).map { phase in
                    let name = try TripAnimationSet.name(facing: facing, phase: phase)
                    return try #require(sprite.frame(atlas: character + ".atlas", name: name))
                }
                #expect(frames.first!.indices == frames.last!.indices)
                if character == TripAnimationSet.body { #expect(Set(frames.map { Data($0.indices) }).count >= 8) }
                let first = SwordSwingPath.blade(phase: 0, facing: facing, maneuver: .tripAttack)
                let last = SwordSwingPath.blade(phase: 15, facing: facing, maneuver: .tripAttack)
                #expect(hypot(first.tip.x-last.tip.x, first.tip.y-last.tip.y) < 0.01)
            }
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character))
    }

}

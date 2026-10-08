import Foundation
import CoreGraphics
import Testing
@testable import RainShadowCore

struct BearFormTests {
    private func fight(enemyDamage: Int = 1) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 160, y: 120),
                hp: 12, maximumHP: 12, defence: 40, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 50),
            Combatant(id: "crew", name: "Crew", player: false, position: CGPoint(x: 240, y: 120),
                hp: 100, maximumHP: 100, defence: 1, attackBonus: 100, damageMin: enemyDamage, damageMax: enemyDamage, initiativeBonus: 0)
        ], seed: 42)
    }
    @Test func formReadoutTracksEnduranceCombatModifiersAndRestoresHuman() throws {
        var combat = fight(enemyDamage: 3)
        #expect(BearFormReadout(combat) == nil)
        _ = combat.transformToBear(hasClearance: true)
        let form = try #require(BearFormReadout(combat))
        #expect(form.endurance == 8 && form.humanHealth == 12)
        #expect(form.defence == 14 && form.attackBonus == 6 && form.movementFeet == 30)
        _ = combat.endTurn()
        let strike = combat.attack(target: TacticalCombat.playerID, clearLine: true)
        #expect(strike?.damage == 3)
        let damaged = try #require(BearFormReadout(combat))
        #expect(damaged.endurance == 5 && damaged.humanHealth == 12)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(combat))
        #expect(BearFormReadout(restored) == damaged)
        _ = combat.endTurn()
        let reverted = combat.revertBear()
        #expect(reverted && BearFormReadout(combat) == nil)
        #expect(combat.current.hp == 12 && combat.current.defence == 40)
    }

    @Test func activationIsAtomicAndCostsAStandardAction() {
        var combat = fight(); let original = combat
        let blocked = combat.transformToBear(hasClearance: false)
        #expect(!blocked && combat == original)
        let accepted = combat.transformToBear(hasClearance: true)
        #expect(accepted && combat.isBear && !combat.budget.canAttack)
        #expect(combat.budget.availableMovement(speed: combat.movementSpeed(for: combat.current)) == 240)
        #expect(combat.bearForm?.temporaryHP == 8 && combat.isValid)
        let alreadyBear = combat
        let repeated = combat.transformToBear(hasClearance: true)
        #expect(!repeated && combat == alreadyBear)
    }
    @Test func lastsThreeFullTurnsAfterActivationAndCannotBeRecharged() {
        var combat = fight()
        _ = combat.transformToBear(hasClearance: true)
        _ = combat.endTurn(); _ = combat.endTurn()
        #expect(combat.bearForm?.turnsRemaining == 3)
        for remaining in [2, 1, 0] {
            _ = combat.endTurn(); _ = combat.endTurn()
            #expect(combat.bearForm?.turnsRemaining == remaining)
        }
        #expect(!combat.isBear && !combat.canTransform && combat.bearForm?.temporaryHP == 0)
        #expect(combat.current.defence == 40 && combat.current.hp == 12 && combat.isValid)
    }
    @Test func temporaryEnduranceAbsorbsDamageAndOverflowCarriesToHuman() {
        var combat = fight(enemyDamage: 10)
        _ = combat.transformToBear(hasClearance: true); _ = combat.endTurn()
        let strike = combat.attack(target: TacticalCombat.playerID, clearLine: true)
        #expect(strike?.damage == 10)
        #expect(!combat.isBear && combat.bearForm?.temporaryHP == 0)
        #expect(combat.actors.first(where: \.player)?.hp == 10)
        #expect(combat.isValid)
    }
    @Test func voluntaryReversionRestoresStatsAndStaysSpentAfterReload() throws {
        var combat = fight()
        let human = combat.current
        _ = combat.transformToBear(hasClearance: true); _ = combat.endTurn(); _ = combat.endTurn()
        var resumed = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(combat))
        #expect(resumed == combat && resumed.isBear)
        let reverted = resumed.revertBear()
        #expect(reverted && !resumed.isBear && !resumed.budget.canAttack)
        #expect(resumed.current == human)
        let after = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(resumed))
        #expect(after == resumed && !after.canTransform && after.isValid)
    }
    @Test func clawUsesBearDamageAndYieldEndsTheForm() {
        var combat = fight()
        _ = combat.transformToBear(hasClearance: true); _ = combat.endTurn(); _ = combat.endTurn()
        let strike = combat.attack(target: "crew", clearLine: true)
        #expect((5...8).contains(strike?.damage ?? 0))
        combat.yield()
        #expect(combat.outcome == .lost && !combat.isBear && combat.isValid)
    }
    @Test func legacyCheckpointsLoadWithoutAFormAndMalformedFormsAreRejected() throws {
        let data = try JSONEncoder().encode(fight())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "bearForm")
        let legacy = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.bearForm == nil && legacy.canTransform)
        object["bearForm"] = ["turnsRemaining": 3, "temporaryHP": -1, "activationTurn": true]
        let corrupt = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(!corrupt.isValid)
    }
    @Test func largerClearanceUsesTheRasterAndRestoresOccupancy() {
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 640, height: 480), obstacles: [
            CGRect(x: 0, y: 144, width: 320, height: 100)
        ], agentProfile: .detective)
        let actor = fight().current
        map.registerActor(id: actor.id, kind: .player, at: actor.position)
        let before = map.occupancy.actors
        #expect(!BearFormRules.canStand(in: map, actor: actor))
        var open = actor; open.position = CGPoint(x: 448, y: 120)
        #expect(BearFormRules.canStand(in: map, actor: open))
        #expect(map.occupancy.actors == before)
        let route = CombatNavigation.route(in: map, actor: open, to: actor.position, bear: true)
        #expect(route == nil)
    }
    @Test func completeBearBundleSupportsEveryDirectionAndRejectsHumanEquipment() throws {
        let sprite = try IEIndexedSprite.load(character: BearAnimationSet.character)
        try BearAnimationSet.validate(sprite)
        #expect(sprite.frames.count == 832)
        for action in [CharacterVisualAction.idle, .walk, .attack, .hit, .revert] {
            for facing in ActorFacing.allCases {
                let count = action == .attack ? 12 : try CharacterBodyCode.bearGuardian.frameCount(for: action, facing: facing)
                for phase in 0..<count {
                    let name = try CharacterBodyCode.bearGuardian.frameName(action: action, facing: facing, phase: phase)
                    #expect(sprite.frame(atlas: BearAnimationSet.atlas, name: name)?.isEmpty == false)
                }
            }
        }
        #expect(throws: (any Error).self) {
            try CharacterAppearance(body: .bearGuardian, equipment: [.init(item: .splintMail)]).validate()
        }
    }
    @Test func roarRejectsUnavailableAndBlockedTargetsWithoutSpendingAnything() {
        var combat = fight(); let human = combat
        let notBear = combat.goadingRoar(clearLine: { _, _ in true })
        #expect(notBear == nil && combat == human)
        _ = combat.transformToBear(hasClearance: true)
        let spent = combat
        let noAction = combat.goadingRoar(clearLine: { _, _ in true })
        #expect(noAction == nil && combat == spent)
        _ = combat.endTurn(); _ = combat.endTurn()
        let ready = combat
        let blocked = combat.goadingRoar(clearLine: { _, _ in false })
        #expect(blocked == nil && combat == ready)
        combat.reconcilePosition(id: "crew", point: CGPoint(x: 800, y: 120))
        let distant = combat
        let far = combat.goadingRoar(clearLine: { _, _ in true })
        #expect(far == nil && combat == distant)
    }
    @Test func roarPreservesHPExpiresAfterVictimTurnAndCannotBeReused() throws {
        var combat = fight()
        _ = combat.transformToBear(hasClearance: true); _ = combat.endTurn(); _ = combat.endTurn()
        let hp = combat.actors.map(\.hp)
        let targets = combat.goadingRoar(clearLine: { _, _ in true })
        #expect(targets == ["crew"] && combat.actors.map(\.hp) == hp)
        #expect(!combat.budget.canAttack && combat.bearForm?.roarSpent == true)
        #expect(combat.actors.first { $0.id == "crew" }?.conditions?.goadedBy == TacticalCombat.playerID)
        #expect(combat.isValid)
        var loaded = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(combat))
        #expect(loaded == combat)
        _ = loaded.endTurn()
        #expect(loaded.goadingTarget(for: loaded.current)?.id == TacticalCombat.playerID)
        _ = loaded.endTurn()
        #expect(loaded.actors.first { $0.id == "crew" }?.conditions?.goadedBy == nil)
        let before = loaded
        let repeated = loaded.goadingRoar(clearLine: { _, _ in true })
        #expect(repeated == nil && loaded == before)
    }
    @Test func losingBearFormImmediatelyReleasesGoadedEnemies() {
        var combat = fight(enemyDamage: 10)
        _ = combat.transformToBear(hasClearance: true); _ = combat.endTurn(); _ = combat.endTurn()
        _ = combat.goadingRoar(clearLine: { _, _ in true }); _ = combat.endTurn()
        let strike = combat.attack(target: TacticalCombat.playerID, clearLine: true)
        #expect(strike?.damage == 10 && !combat.isBear)
        #expect(combat.goadingTarget(for: combat.current) == nil && combat.current.conditions?.goadedBy == nil)
        #expect(combat.isValid)
    }
    @Test func oldActiveBearCheckpointsHaveAnUnusedRoar() throws {
        var combat = fight(); _ = combat.transformToBear(hasClearance: true)
        _ = combat.endTurn(); _ = combat.endTurn()
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(combat)) as? [String: Any])
        var form = try #require(object["bearForm"] as? [String: Any]); form.removeValue(forKey: "roarSpent"); object["bearForm"] = form
        let loaded = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(loaded.canGoadingRoar && loaded.isValid)
    }
    @Test func roarOnlyAffectsVisibleConsciousEnemiesInRange() {
        var actors = fight().actors
        for i in 1...4 {
            var enemy = actors.first { !$0.player }!; enemy.id = "extra.\(i)"
            enemy.position = CGPoint(x: i == 1 ? 399 : i == 2 ? 401 : 200, y: 120)
            if i == 3 { enemy.hidden = true; enemy.lastSeenPosition = enemy.position }
            if i == 4 { enemy.hp = 0 }
            actors.append(enemy)
        }
        var combat = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: actors, seed: 42)
        _ = combat.transformToBear(hasClearance: true)
        repeat { _ = combat.endTurn() } while !combat.isPlayerTurn
        let targets = combat.goadingRoar(clearLine: { _, _ in true })
        #expect(Set(targets ?? []) == ["crew", "extra.1"])
    }
    @Test func roarBundleHasRegisteredUniquePosesAndRestEndpoints() throws {
        let roar = try IEIndexedSprite.load(character: BearRoarAnimationSet.character)
        let base = try IEIndexedSprite.load(character: BearAnimationSet.character)
        try BearRoarAnimationSet.validate(roar); try BearAnimationSet.validate(base)
        #expect(roar.sourcePivotFromCanvasBottomLeft == base.sourcePivotFromCanvasBottomLeft)
        for facing in ActorFacing.allCases {
            let frames = try (0..<24).map { phase in
                try #require(roar.frame(atlas: BearRoarAnimationSet.character + ".atlas",
                    name: CharacterBodyCode.bearGuardian.frameName(action: .roar, facing: facing, phase: phase)))
            }
            #expect(frames.first!.indices == frames.last!.indices)
            #expect(Set(frames.map { Data($0.indices) }).count >= 10)
        }
        #expect(BearFormRules.clawImpactTime < BearFormRules.clawDuration)
        #expect(BearFormRules.roarImpactTime < BearFormRules.roarDuration)
    }
    @Test func clawBundleHasFullRearUpAndRegisteredRestEndpoints() throws {
        let claw = try IEIndexedSprite.load(character: BearClawAnimationSet.character)
        let base = try IEIndexedSprite.load(character: BearAnimationSet.character)
        try BearClawAnimationSet.validate(claw); try BearAnimationSet.validate(base)
        #expect(claw.sourcePivotFromCanvasBottomLeft == base.sourcePivotFromCanvasBottomLeft)
        #expect(claw.colors == base.colors)
        for facing in ActorFacing.allCases {
            #expect(try CharacterBodyCode.bearGuardian.frameCount(for: .attack, facing: facing) == 24)
            let frames = try (0..<24).map { phase in
                try #require(claw.frame(atlas: BearClawAnimationSet.character + ".atlas",
                    name: CharacterBodyCode.bearGuardian.frameName(action: .attack, facing: facing, phase: phase)))
            }
            #expect(frames.first!.indices == frames.last!.indices)
            #expect(Set(frames.map { Data($0.indices) }).count >= 20)
            #expect(frames[8].indices != frames[12].indices)
        }
        #expect(BearFormRules.clawImpactTime * BearFormRules.clawFPS == 12)
        #expect(BearFormRules.clawDuration * BearFormRules.clawFPS == 24)
    }
    @Test func goadedEnemyCannotSpendItsAttackOnABarrel() {
        var actors = fight().actors
        let i = actors.firstIndex { !$0.player }!
        actors[i].rangedWeapon = .bow
        actors[i].position = CGPoint(x: 380, y: 120)
        actors[i].conditions = CombatConditions(weakened: true, slowed: true)
        var combat = TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: actors, seed: 42,
            barrels: [.init(id: "oil", position: CGPoint(x: 160, y: 240))])
        _ = combat.transformToBear(hasClearance: true); _ = combat.endTurn(); _ = combat.endTurn()
        _ = combat.goadingRoar(clearLine: { _, _ in true }); _ = combat.endTurn()
        let before = combat
        let explosion = combat.igniteBarrel("oil", clearShot: true, visible: { _, _ in true })
        #expect(explosion == nil && combat == before)
        #expect(combat.goadingTarget(for: combat.current)?.id == TacticalCombat.playerID)
    }
}

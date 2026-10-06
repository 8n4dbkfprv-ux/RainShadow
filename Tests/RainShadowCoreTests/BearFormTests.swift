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
                let count = try CharacterBodyCode.bearGuardian.frameCount(for: action, facing: facing)
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
}

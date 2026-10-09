import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct BowAttackTests {
    private func fight(distance: Double = 300, bow: Bool = true) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 100, y: 100),
                hp: 12, maximumHP: 12, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 0),
            Combatant(id: "lookout", name: "Lookout", player: false, position: CGPoint(x: 100 + distance, y: 100),
                hp: 7, maximumHP: 7, defence: 11, attackBonus: 2, damageMin: 1, damageMax: 3, initiativeBonus: 50,
                rangedWeapon: bow ? .bow : nil)
        ], seed: 42)
    }
    @Test func rejectedShotsNeverSpendActionsOrRolls() {
        for (distance, bow, line) in [(300.0, true, false), (700, true, true), (80, true, true), (300, false, true)] {
            var model = fight(distance: distance, bow: bow)
            let before = model
            #expect(model.attack(target: TacticalCombat.playerID, clearLine: line, ranged: true) == nil)
            #expect(model == before)
        }
    }
    @Test func oneArrowCostsAStandardActionAndLeavesMovement() {
        var model = fight()
        #expect(model.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true) != nil)
        #expect(!model.budget.canAttack)
        #expect(model.budget.availableMovement(speed: model.current.speed) == 240)
        let after = model
        #expect(model.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true) == nil)
        #expect(model == after)
    }
    @Test func archerCanStillUseMeleeWhenEngaged() {
        var model = fight(distance: 80)
        #expect(model.attack(target: TacticalCombat.playerID, clearLine: true) != nil)
        var far = fight()
        #expect(far.attack(target: TacticalCombat.playerID, clearLine: true) == nil)
    }
    @Test func saveRetainsBowAndAcceptedOutcomeWithoutReplay() throws {
        var model = fight()
        _ = model.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true)
        let encoded = try JSONEncoder().encode(model)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: encoded)
        #expect(restored == model && restored.isValid && !restored.budget.canAttack)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var actors = try #require(object["actors"] as? [[String: Any]])
        for i in actors.indices { actors[i].removeValue(forKey: "rangedWeapon") }
        object["actors"] = actors
        let legacy = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.isValid && legacy.actors.allSatisfy { $0.rangedWeapon == nil })
    }
    @Test func projectileStartsAtReleaseAndEndsExactlyAtImpact() {
        #expect(BowAttackRules.releaseTime == 10.0 / 15)
        #expect(BowAttackRules.releaseTime < BowAttackRules.recoveryTime)
        let a = CGPoint(x: 20, y: 80), b = CGPoint(x: 320, y: 60)
        #expect(BowAttackRules.arrowPosition(from: a, to: b, progress: -1) == a)
        let end = BowAttackRules.arrowPosition(from: a, to: b, progress: 1)
        #expect(abs(end.x - b.x) < 0.00001 && abs(end.y - b.y) < 0.00001)
        #expect(BowAttackRules.flightDuration(from: a, to: b) >= 0.22)
        #expect(BowAttackRules.flightDuration(from: a, to: b) <= 0.65)
    }
    @Test func allFacingsHaveCompletePinnedFiringClips() throws {
        let sprite = try IEIndexedSprite.load(character: BowAttackAnimationSet.character)
        try BowAttackAnimationSet.validate(sprite)
        for facing in ActorFacing.allCases {
            #expect(try CharacterBodyCode.humanMale01.frameCount(for: .shoot, facing: facing) == 18)
            let muzzle = BowAttackAnimationSet.muzzleOffset(facing: facing)
            #expect(muzzle.x.isFinite && muzzle.y.isFinite)
        }
    }
    @Test func armorCoversEveryBowPoseWithoutReplacingApprovedBody() throws {
        for item in [CharacterEquipmentCode.splintMail, .ironHelmet] {
            let character = try #require(BowAttackAnimationSet.equipment(item))
            let sprite = try IEIndexedSprite.load(character: character)
            try BowAttackAnimationSet.validateEquipment(sprite, character: character)
            #expect(sprite.frames.count == 960)
        }
        #expect(BowAttackAnimationSet.equipment(.lanternShortsword) == nil)
        try BowAttackAnimationSet.validate(IEIndexedSprite.load(character: BowAttackAnimationSet.character))
        try StealthAnimationSet.validate(IEIndexedSprite.load(character: StealthAnimationSet.bow), character: StealthAnimationSet.bow)
        try WeaponTechniqueAnimationSet.validate(IEIndexedSprite.load(character: WeaponTechniqueAnimationSet.pinning), character: WeaponTechniqueAnimationSet.pinning)
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
    }

}

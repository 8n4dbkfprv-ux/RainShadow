import Foundation
import CoreGraphics
import Testing
@testable import RainShadowCore

struct BladeWardTests {
    private func fight(damage: Int = 7, ranged: Bool = false, burning: Bool = false, seed: UInt64 = 42) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 160, y: 120),
                hp: 100, maximumHP: 100, defence: 10, attackBonus: 5, damageMin: 3, damageMax: 5,
                initiativeBonus: 100, burningTurns: burning ? 2 : nil),
            Combatant(id: "crew", name: "Crew", player: false, position: CGPoint(x: ranged ? 460 : 240, y: 120),
                hp: 100, maximumHP: 100, defence: 10, attackBonus: 100, damageMin: damage, damageMax: damage,
                initiativeBonus: 0, rangedWeapon: ranged ? .bow : nil, fireArrows: 3)
        ], seed: seed)
    }
    @Test func wardSpendsAnActionAndExpiresOnTheSecondFollowingTurn() {
        var game = fight(); let defence = game.defence(for: game.current)
        #expect({ game.castBladeWard() }())
        #expect(!game.budget.canAttack && game.current.bladeWardTurns == 2)
        #expect(game.defence(for: game.current) == defence)
        let spent = game; #expect(!{ game.castBladeWard() }() && game == spent)
        _ = game.endTurn(); #expect(game.actors.first(where: \.player)!.bladeWardTurns == 2)
        _ = game.endTurn(); #expect(game.current.bladeWardTurns == 1)
        _ = game.endTurn(); _ = game.endTurn(); #expect(!game.current.hasBladeWard)
    }
    @Test func physicalHitsAreHalvedIncludingArrowsAndZeroDamageHits() throws {
        for ranged in [false, true] { for damage in [1, 7, 8] {
            var game = fight(damage: damage, ranged: ranged)
            #expect({ game.castBladeWard() }()); _ = game.endTurn()
            let attempt = game.attack(target: TacticalCombat.playerID, clearLine: true, ranged: ranged, ammunition: ranged ? .fire : .normal)
            let result = try #require(attempt)
            #expect(result.landed && result.damage == damage / 2 && result.wardAbsorbed == damage - damage / 2)
            let candidate = game.actors.first(where: \.player)
            let player = try #require(candidate)
            #expect(player.hp == 100 - damage / 2)
            #expect(player.isBurning == ranged)
        } }
    }
    @Test func burningDamageIsNotReduced() {
        var protected = fight(burning: true), plain = protected
        #expect({ protected.castBladeWard() }())
        _ = protected.endTurn(); _ = plain.endTurn()
        #expect(protected.actors.first(where: \.player)!.hp == plain.actors.first(where: \.player)!.hp)
        #expect(protected.actors.first(where: \.player)!.hp < 100)
    }
    @Test func canRefreshButCannotCastInBearForm() {
        var game = fight(); #expect({ game.castBladeWard() }())
        _ = game.endTurn(); _ = game.endTurn()
        #expect({ game.castBladeWard() }() && game.current.bladeWardTurns == 2)
        _ = game.endTurn(); _ = game.endTurn()
        #expect({ game.transformToBear(hasClearance: true) }())
        #expect(game.current.hasBladeWard && !game.canCastBladeWard)
        let before = game; #expect(!{ game.castBladeWard() }() && game == before)
    }
    @Test func savesPreserveDurationAndOlderActorsStillDecode() throws {
        var game = fight(); #expect({ game.castBladeWard() }())
        let data = try JSONEncoder().encode(game)
        #expect(try JSONDecoder().decode(TacticalCombat.self, from: data) == game)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var actors = try #require(json["actors"] as? [[String: Any]])
        for i in actors.indices { actors[i].removeValue(forKey: "bladeWardTurns"); actors[i]["defending"] = true }
        json["actors"] = actors
        let old = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.isValid && !old.current.hasBladeWard && old.defence(for: old.current) == old.current.defence)
        actors[0]["bladeWardTurns"] = 3; json["actors"] = actors
        let invalid = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!invalid.isValid)
    }
    @Test func castingBundleHasEveryFacingAndPreservesApprovedHuman() throws {
        let human = try IEIndexedSprite.load(character: VossAnimationSet.character)
        try VossAnimationSet.validate(human)
        for character in BladeWardAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try BladeWardAnimationSet.validate(sprite, character: character)
        }
        #expect(BladeWardAnimationSet.phase(elapsed: BladeWardAnimationSet.impactTime) == 8)
        #expect(BladeWardAnimationSet.phase(elapsed: 99) == 15)
    }
}

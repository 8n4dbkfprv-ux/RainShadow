import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct ShoveTests {
    private func fight(seed: UInt64 = 42, source: ShoveProfile = .voss, target: ShoveProfile = .crew) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 100, y: 150), hp: 100, maximumHP: 100,
                defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 100, shoveProfile: source),
            Combatant(id: "crew", name: "Crew", player: false, position: CGPoint(x: 180, y: 150), hp: 100, maximumHP: 100,
                defence: 12, attackBonus: 2, damageMin: 2, damageMax: 3, initiativeBonus: -100, shoveProfile: target)
        ], seed: seed)
    }
    let end = CGPoint(x: 260, y: 150)
    @Test func successMovesWithoutDamageOrSpendingTheNormalAttack() throws {
        var game = fight(source: .init(strength: 14, athletics: 30, acrobatics: 2, weight: 80))
        let before = game
        let attempt = game.shove(target: "crew", clearLine: true, destination: end)
        let result = try #require(attempt)
        #expect(result.succeeded && result.displacement?.to == end)
        #expect(game.actors.first { $0.id == "crew" }?.hp == 100)
        #expect(game.budget == before.budget && game.current.shoveSpent == true && !game.canShove)
        let after = game
        let repeatAttempt = game.shove(target: "crew", clearLine: true, destination: end)
        #expect(repeatAttempt == nil && game == after)
        _ = game.endTurn(); _ = game.endTurn()
        #expect(game.canShove && game.current.player)
    }
    @Test func resistanceSpendsBonusButDoesNotMoveOrDamage() throws {
        var game = fight(source: .init(strength: 14, athletics: -5, acrobatics: 0, weight: 80),
                         target: .init(strength: 12, athletics: 30, acrobatics: 0, weight: 80))
        let before = game
        let attempt = game.shove(target: "crew", clearLine: true, destination: end)
        let result = try #require(attempt)
        #expect(!result.succeeded && result.displacement == nil && game.current.shoveSpent == true)
        #expect(game.actors.first { $0.id == "crew" } == before.actors.first { $0.id == "crew" })
        #expect(game.budget == before.budget && game.randomState != before.randomState)
    }
    @Test func invalidTargetsLeaveTheEntireStateUntouched() {
        for (target, clear, point) in [("crew", false, end), ("missing", true, end), (TacticalCombat.playerID, true, end),
            ("crew", true, CGPoint(x: CGFloat.nan, y: 150)), ("crew", true, CGPoint(x: 180, y: 150)),
            ("crew", true, CGPoint(x: 100, y: 150)), ("crew", true, CGPoint(x: 180, y: 230)), ("crew", true, CGPoint(x: 500, y: 150))] {
            var game = fight(); let before = game
            let result = game.shove(target: target, clearLine: clear, destination: point)
            #expect(result == nil && game == before)
        }
        var heavy = fight(target: .bear); let before = heavy
        let result = heavy.shove(target: "crew", clearLine: true, destination: CGPoint(x: 204, y: 150))
        #expect(result == nil && heavy == before)
    }
    @Test func oddsUseTheBetterDefensiveSkillAndHiddenAdvantage() throws {
        var game = fight(target: .init(strength: 10, athletics: 0, acrobatics: 8, weight: 80))
        let base = try #require(game.shovePreview(target: "crew", clearLine: true, destination: end))
        #expect(base.dc == 18 && base.bonus == 4 && base.chance == 35)
        _ = game.hide(observed: false)
        let preview = try #require(game.shovePreview(target: "crew", clearLine: true, destination: end))
        #expect(preview.advantage && preview.chance == 58)
        let attempt = game.shove(target: "crew", clearLine: true, destination: end)
        let result = try #require(attempt)
        #expect(result.secondRoll != nil && game.current.hidden != true)
        #expect(ShoveRules.chance(bonus: 30, dc: 10, advantage: false) == 100)
        #expect(ShoveRules.chance(bonus: -5, dc: 40, advantage: true) == 0)
    }
    @Test func saveReloadPreservesOutcomeAndBonusAndReadsOlderActors() throws {
        var game = fight(); _ = game.shove(target: "crew", clearLine: true, destination: end)
        let copy = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(game))
        #expect(copy == game && copy.isValid && !copy.canShove)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fight())) as? [String: Any])
        var actors = try #require(json["actors"] as? [[String: Any]])
        for i in actors.indices { actors[i].removeValue(forKey: "shoveProfile"); actors[i].removeValue(forKey: "shoveSpent") }
        json["actors"] = actors
        let old = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.isValid && old.canShove && old.physique(of: old.current) == .voss)
    }
    @Test func shoveStillWorksAfterTheStandardActionWasSpent() throws {
        var game = fight(); _ = game.defend()
        #expect(!game.budget.canAttack && game.canShove)
        let result = game.shove(target: "crew", clearLine: true, destination: end)
        #expect(result != nil && !game.budget.canAttack)
        var bear = fight(); _ = bear.transformToBear(hasClearance: true)
        #expect(!bear.canShove)
    }
    @Test func searchRasterClipsLandingAndRestoresOccupancy() throws {
        let game = fight(), target = game.actors.first { !$0.player }!
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 600, height: 400),
            obstacles: [CGRect(x: 244, y: 0, width: 16, height: 400)])
        for actor in game.actors { map.registerActor(id: actor.id, kind: actor.player ? .player : .npc, at: actor.position) }
        let before = map.occupancy.actors
        let end = CombatNavigation.knockbackDestination(in: map, actor: target, awayFrom: game.current.position,
            actors: game.actors, destroyedBarrels: [], maximumDistance: 80)
        #expect(end.x >= target.position.x && end.x < 244)
        #expect(map.occupancy.actors == before)
        let open = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 600, height: 400), obstacles: [])
        let limited = CombatNavigation.knockbackDestination(in: open, actor: target, awayFrom: game.current.position,
            actors: game.actors, destroyedBarrels: [], maximumDistance: 30)
        #expect(limited == CGPoint(x: 210, y: 150))
        let block = Combatant(id: "blocker", name: "B", player: false, position: CGPoint(x: 244, y: 150), hp: 1, maximumHP: 1,
            defence: 10, attackBonus: 1, damageMin: 1, damageMax: 1, initiativeBonus: 0)
        open.registerActor(id: block.id, kind: .npc, at: block.position)
        let blocked = CombatNavigation.knockbackDestination(in: open, actor: target, awayFrom: game.current.position,
            actors: game.actors + [block], destroyedBarrels: [])
        #expect(blocked.x < block.position.x)
    }
    @Test func equipmentAndSixteenPushDirectionsAreComplete() throws {
        #expect(ShoveAnimationSet.hashes.count == 5)
        for name in ShoveAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: name)
            try ShoveAnimationSet.validate(sprite, character: name)
            for facing in ActorFacing.allCases {
                let frames = try (0..<12).map { try #require(sprite.frame(atlas: name + ".atlas", name: ShoveAnimationSet.name(facing: facing, phase: $0))) }
                if name == ShoveAnimationSet.body {
                    #expect(Set(frames.map { Data($0.indices) }).count >= 7)
                    #expect(frames.first!.indices == frames.last!.indices)
                }
            }
        }
    }
}

import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct CombatAttackPlanTests {
    private func fixture(distance: CGFloat = 260, obstacles: [CGRect] = [], advantage: Bool = false) -> (TacticalCombat, NavigationMap) {
        let actors = [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 160, y: 300),
                hp: 50, maximumHP: 50, defence: 12, attackBonus: 4, damageMin: 3, damageMax: 5,
                initiativeBonus: 100, rangedWeapon: .bow, conditions: CombatConditions(attackAdvantage: advantage)),
            Combatant(id: "enemy", name: "Enemy", player: false, position: CGPoint(x: 160 + distance, y: 300),
                hp: 50, maximumHP: 50, defence: 12, attackBonus: 4, damageMin: 3, damageMax: 5, initiativeBonus: -100)]
        let model = TacticalCombat(encounterID: "qa", areaID: "qa", actors: actors, seed: 42)
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 1400, height: 800), obstacles: obstacles)
        for actor in actors { map.registerActor(id: actor.id, kind: actor.player ? .player : .npc, at: actor.position) }
        return (model, map)
    }
    private func order(ranged: Bool = false, maneuver: CombatManeuver? = nil, sneak: Bool = false) -> CombatAttackOrder {
        CombatAttackOrder(targetID: "enemy", ranged: ranged, ammunition: .normal, maneuver: maneuver, hasSword: true, sneak: sneak)
    }
    @Test func approachIsReadOnlyAndItsForecastMatchesTheArrivalAttack() throws {
        for maneuver in [nil, .powerStrike, .feintingCut, .tripAttack] as [CombatManeuver?] {
            var (model, map) = fixture()
            let before = model
            let occupancy = map.occupancy.actors
            let plan = try #require(CombatAttackPlanner.plan(combat: model, order: order(maneuver: maneuver), map: map))
            #expect(model == before)
            #expect(map.occupancy.actors == occupancy)
            #expect(plan.reason == nil)
            let path = try #require(plan.path)
            #expect(plan.movement <= 240)
            let moved = model.move(along: path)
            #expect(moved && model.budget.canAttack)
            #expect(CombatNavigation.distance(model.current.position, model.actors.first { !$0.player }!.position) <= TacticalCombat.meleeReach)
            let result = model.attack(target: "enemy", clearLine: true, maneuver: maneuver, hasSword: true)
            let strike = try #require(result)
            #expect(!strike.landed || plan.preview.damage.contains(strike.damage))
            #expect(!model.budget.canAttack)
        }
    }
    @Test func inRangeAttacksNeverSpendMovementAndFullTurnShotsNeverApproach() throws {
        let (near, map) = fixture(distance: 80)
        let plan = try #require(CombatAttackPlanner.plan(combat: near, order: order(), map: map))
        #expect(plan.reason == nil && plan.path == nil && plan.movement == 0)
        let (far, farMap) = fixture(distance: 700)
        let aimed = try #require(CombatAttackPlanner.plan(combat: far, order: order(ranged: true, maneuver: .aimedShot), map: farMap))
        #expect(aimed.path == nil && aimed.reason != nil)
        let ordinary = try #require(CombatAttackPlanner.plan(combat: far, order: order(ranged: true), map: farMap))
        #expect(ordinary.path != nil && ordinary.reason == nil)
    }
    @Test func blockedOrUnaffordableOrdersNeverOfferPartialWalks() throws {
        for (distance, obstacles) in [(CGFloat(800), [CGRect]()), (260, [CGRect(x: 280, y: 0, width: 32, height: 800)])] {
            let (model, map) = fixture(distance: distance, obstacles: obstacles)
            let plan = try #require(CombatAttackPlanner.plan(combat: model, order: order(), map: map))
            #expect(plan.path == nil && plan.reason != nil)
        }
        var (spent, map) = fixture()
        _ = spent.dash()
        let plan = try #require(CombatAttackPlanner.plan(combat: spent, order: order(), map: map))
        #expect(plan.path == nil && plan.reason != nil)
    }
    @Test func rangedApproachCanBackOutOfMinimumRangeAndSneakRetainsEligibility() throws {
        let (near, map) = fixture(distance: 80)
        let shot = try #require(CombatAttackPlanner.plan(combat: near, order: order(ranged: true), map: map))
        #expect(shot.path != nil && shot.reason == nil)
        let (sneak, sneakMap) = fixture(advantage: true)
        let sneakPlan = try #require(CombatAttackPlanner.plan(combat: sneak, order: order(sneak: true), map: sneakMap))
        #expect(sneakPlan.path != nil && sneakPlan.preview.sneakDice == 1)
    }
    @Test func approachCanRouteAroundCoverWithoutCrossingIt() throws {
        let (model, map) = fixture(obstacles: [CGRect(x: 280, y: 264, width: 32, height: 72)])
        let target = model.actors.first { !$0.player }!
        #expect(!CombatNavigation.clearLine(in: map, from: model.current.position, to: target.position,
            excluding: [model.current.id, target.id]))
        let plan = try #require(CombatAttackPlanner.plan(combat: model, order: order(), map: map))
        let path = try #require(plan.path)
        #expect(plan.reason == nil)
        #expect(CombatNavigation.clearLine(in: map, from: path.destination!, to: target.position,
            excluding: [model.current.id, target.id]))
    }
    @Test func arrivalForecastDropsStealthWhenApproachEntersSight() throws {
        let (original, map) = fixture()
        var actors = original.actors
        actors[0].hidden = true
        actors[1].combatFacing = ActorFacing.west.rawValue
        let model = TacticalCombat(encounterID: "qa", areaID: "qa", actors: actors, seed: 42)
        let plan = try #require(CombatAttackPlanner.plan(combat: model, order: order(), map: map))
        #expect(plan.path != nil)
        #expect(plan.preview.sneakDice == 0 && plan.preview.edge == 0)
        let sneak = try #require(CombatAttackPlanner.plan(combat: model, order: order(sneak: true), map: map))
        #expect(sneak.path == nil && sneak.reason != nil)
    }

}

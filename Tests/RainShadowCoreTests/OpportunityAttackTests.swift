import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct OpportunityAttackTests {
    private func fight(enemies: Int = 1, ranged: Bool = false, prone: Bool = false,
                       spent: Bool = false, seed: UInt64 = 42) -> TacticalCombat {
        let player = Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: .zero,
            hp: 100, maximumHP: 100, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 100)
        let foes = (0..<enemies).map { i in
            Combatant(id: "foe.\(i)", name: "Foe \(i)", player: false, position: CGPoint(x: 60, y: i == 0 ? 0 : 15),
                hp: 100, maximumHP: 100, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: -100 - i,
                rangedWeapon: ranged ? .bow : nil, conditions: prone ? CombatConditions(prone: true) : nil,
                reactionSpent: spent ? true : nil)
        }
        return TacticalCombat(encounterID: "opportunity", areaID: "qa", actors: [player] + foes, seed: seed)
    }
    private func retreat(_ model: TacticalCombat, to point: CGPoint = CGPoint(x: -120, y: 0)) -> Path {
        Path(points: [point], from: model.current.position)
    }
    private let clear: (Combatant, Combatant) -> Bool = { _, _ in true }

    @Test func exitInterruptsInsideReachAndOnlySpendsTheReactorsReaction() throws {
        var model = fight()
        let original = model, route = retreat(model)
        let warning = try #require(model.opportunityExits(along: route, clearLine: clear).first)
        #expect(model == original)
        #expect(warning.point.x < 0 && CombatNavigation.distance(warning.point, original.actors[1].position) <= TacticalCombat.meleeReach)
        let stepResult = model.moveWithOpportunityAttacks(along: route, clearLine: clear)

        let step = try #require(stepResult)
        #expect(step.reaction?.opportunityAttack == true && step.reaction?.attacker == "foe.0")
        #expect(model.current.id == original.current.id && model.budget.canAttack && model.canUseBonusAction)
        #expect(model.actors[1].reactionSpent == true && model.current.hasReaction)
        #expect(model.current.position == warning.point)
        let remaining = try #require(step.remainder)
        let finishResult = model.moveWithOpportunityAttacks(along: remaining, clearLine: clear)

        let finish = try #require(finishResult)
        #expect(finish.reaction == nil && model.current.position == CGPoint(x: -120, y: 0))
        #expect(model.budget.availableMovement(speed: 240) == 120)
        #expect(model.displayedLog.contains { $0.contains("Opportunity Attack") })
        #expect(model.isValid)
    }

    @Test func eachEnemyReactsOnceAndItsOwnTurnRefreshesIt() throws {
        var model = fight(enemies: 2)
        var path = retreat(model), attackers: [String] = []
        for _ in 0..<4 {
            let stepResult = model.moveWithOpportunityAttacks(along: path, clearLine: clear)

            let step = try #require(stepResult)
            if let strike = step.reaction { attackers.append(strike.attacker) }
            guard let remainder = step.remainder else { break }
            path = remainder
        }
        #expect(Set(attackers) == ["foe.0", "foe.1"] && attackers.count == 2)
        #expect(model.actors.filter { !$0.player }.allSatisfy { !$0.hasReaction })
        let nextID = model.actors[1].id
        _ = model.endTurn()
        #expect(model.current.id == nextID && model.current.hasReaction)
        #expect(model.actors.filter { !$0.player && $0.id != nextID }.allSatisfy { $0.reactionSpent == true })
    }

    @Test func disengageCostsActionPreservesMovementAndBonusAndExpires() throws {
        var model = fight()
        #expect(model.canDisengage)
        let accepted = model.disengage()
        #expect(accepted && !model.budget.canAttack && model.canUseBonusAction && model.current.hasReaction)
        #expect(model.budget.availableMovement(speed: 240) == 240)
        let saved = model
        let repeated = model.disengage()
        #expect(!repeated && model == saved)
        #expect(model.opportunityExits(along: retreat(model), clearLine: clear).isEmpty)
        let stepResult = model.moveWithOpportunityAttacks(along: retreat(model), clearLine: clear)

        let step = try #require(stepResult)
        #expect(step.reaction == nil && model.current.hp == 100 && model.actors[1].hasReaction)
        _ = model.endTurn()
        #expect(model.actors.first(where: \.player)?.disengaged != true)
        _ = model.endTurn()
        #expect(model.canDisengage)
    }

    @Test func illegalMovementIsInertAndDisengageCannotSpendAnAbsentAction() {
        var model = fight()
        let saved = model
        let rejected = model.moveWithOpportunityAttacks(along: retreat(model, to: CGPoint(x: -241, y: 0)), clearLine: clear)
        #expect(rejected == nil && model == saved)
        _ = model.castBladeWard()
        let spent = model
        let rejectedDisengage = model.disengage()
        #expect(!rejectedDisengage && model == spent)
    }

    @Test func noAttackForApproachingBlockedSightProneRangedOrSpentReactors() {
        for model in [fight(ranged: true), fight(prone: true), fight(spent: true)] {
            #expect(model.opportunityExits(along: retreat(model), clearLine: clear).isEmpty)
        }
        let model = fight()
        #expect(model.opportunityExits(along: retreat(model, to: CGPoint(x: 20, y: 0)), clearLine: clear).isEmpty)
        #expect(model.opportunityExits(along: retreat(model), clearLine: { _, _ in false }).isEmpty)
        var archer = fight(ranged: true)
        _ = archer.endTurn()
        let switched = archer.readyWeapon(ranged: false)
        #expect(switched && archer.canMakeOpportunityAttack(archer.current))
        _ = archer.readyWeapon(ranged: true)
        #expect(!archer.canMakeOpportunityAttack(archer.current))
    }

    @Test func detectsPassingThroughReachOnOneLongSegmentAndIgnoresTangents() {
        var model = fight()
        model.reconcilePosition(id: TacticalCombat.playerID, point: CGPoint(x: -180, y: 0))
        let route = retreat(model, to: CGPoint(x: 240, y: 0))
        #expect(model.opportunityExits(along: route, clearLine: clear).count == 1)
        model.reconcilePosition(id: TacticalCombat.playerID, point: CGPoint(x: -180, y: 79))
        #expect(model.opportunityExits(along: retreat(model, to: CGPoint(x: 240, y: 79)), clearLine: clear).isEmpty)
    }

    @Test func savesRetainSpentReactionsAndDisengageAndOldSavesDecode() throws {
        var model = fight()
        _ = model.moveWithOpportunityAttacks(along: retreat(model), clearLine: clear)
        _ = model.disengage()
        let data = try JSONEncoder().encode(model)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: data)
        #expect(restored == model && restored.actors[1].reactionSpent == true && restored.current.disengaged == true)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var actors = try #require(json["actors"] as? [[String: Any]])
        for i in actors.indices { for key in ["reactionSpent", "disengaged", "rangedReadied"] { actors[i].removeValue(forKey: key) } }
        json["actors"] = actors
        let legacy = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.isValid && legacy.actors.allSatisfy(\.hasReaction) && legacy.current.disengaged == nil)
    }

    @Test func forcedDisplacementDoesNotProvoke() {
        var model = fight()
        let result = model.shove(target: "foe.0", clearLine: true, destination: CGPoint(x: 140, y: 0))
        #expect(result != nil && model.actors.allSatisfy(\.hasReaction))
        #expect(!model.log.contains { $0.contains("Opportunity Attack") })
    }

    @Test func reactionCanDefeatActiveEnemyWithoutLeavingInvalidTurnOrChargingAction() throws {
        var killed = false
        for seed in 1...20 {
            var model = fight(enemies: 2, seed: UInt64(seed))
            // Use a legal old-save-shaped payload to author low HP and a lethal Voss.
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any])
            var actors = try #require(json["actors"] as? [[String: Any]])
            actors[0]["damageMin"] = 100; actors[0]["damageMax"] = 100; actors[0]["attackBonus"] = 100
            actors[1]["hp"] = 1
            json["actors"] = actors
            model = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: json))
            _ = model.endTurn()
            let mover = model.current.id
            let stepResult = model.moveWithOpportunityAttacks(along: retreat(model, to: CGPoint(x: 240, y: 0)), clearLine: clear)

            let step = try #require(stepResult)
            if step.reaction?.knockedOut == true {
                killed = true
                #expect(step.remainder == nil && model.current.id != mover && model.outcome == nil && model.isValid)
                #expect(model.actors.first(where: \.player)?.reactionSpent == true)
                #expect(model.budget == CombatBudget())
                break
            }
        }
        #expect(killed)
    }
    @Test func bearCanDisengageAndUseClawsAsItsReaction() throws {
        var model = fight()
        _ = model.transformToBear(hasClearance: true)
        _ = model.disengage()
        #expect(model.current.disengaged == true && model.isBear && !model.budget.canAttack)
        _ = model.endTurn()
        let stepResult = model.moveWithOpportunityAttacks(along: retreat(model, to: CGPoint(x: 240, y: 0)), clearLine: clear)
        let step = try #require(stepResult)
        #expect(step.reaction?.attacker == TacticalCombat.playerID && step.reaction?.opportunityAttack == true)
        if let strike = step.reaction, strike.landed {
            #expect((BearFormRules.damageMin...BearFormRules.damageMax).contains(strike.damage))
        }
        #expect(model.isValid && !model.current.player && model.budget.canAttack)
    }

    @Test func threatenedArcherDisengagesWhenLeavingWouldBeLethalAndChoosesFreelyOnceSafe() throws {
        var player = fight().current
        player.position = CGPoint(x: 500, y: 400); player.initiativeBonus = -100
        player.attackBonus = 100; player.damageMin = 20; player.damageMax = 20
        let archer = Combatant(id: "archer", name: "Archer", player: false, position: CGPoint(x: 596, y: 400),
            hp: 3, maximumHP: 20, defence: 12, attackBonus: 3, damageMin: 1, damageMax: 2, initiativeBonus: 100,
            rangedWeapon: .bow, enemyRole: .archer, usedManeuvers: CombatManeuver.allCases, shoveSpent: true)
        var model = TacticalCombat(encounterID: "qa", areaID: "qa", actors: [player, archer], seed: 42)
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 1400, height: 900), obstacles: [])
        for actor in model.actors { map.registerActor(id: actor.id, kind: actor.player ? .player : .npc, at: actor.position) }
        let saved = model
        let decision = EnemyTactics.choose(combat: model, map: map)
        #expect(model == saved)
        guard case .disengage(let route) = decision.action else {
            Issue.record("Expected safe disengage, got \(decision.reason), score \(decision.score)"); return
        }
        #expect(model.opportunityRisk(along: route, clearLine: clear) > 0)
        _ = model.disengage()
        #expect(model.opportunityRisk(along: route, clearLine: clear) == 0)
        let moved = model.moveWithOpportunityAttacks(along: route, clearLine: clear)
        #expect(moved?.reaction == nil && model.current.hp == 3)
        #expect(CombatNavigation.distance(model.current.position, player.position) > TacticalCombat.meleeReach)
    }

    @Test func diagonalInterruptsDoNotInflateThePreviewedMovementCost() throws {
        for y in [13.0, 31, 53, 71, 99] {
            var model = fight()
            let endpoint = CGPoint(x: -150, y: y)
            let route = retreat(model, to: endpoint)
            let cost = CombatNavigation.length(route, from: model.current.position)
            var remaining: Path? = route
            for _ in 0..<4 {
                guard let route = remaining else { break }
                let stepResult = model.moveWithOpportunityAttacks(along: route, clearLine: clear)
                let step = try #require(stepResult)
                remaining = step.remainder
            }
            #expect(model.current.position == endpoint && remaining == nil)
            #expect(abs(model.budget.availableMovement(speed: 240) - (240 - cost)) < 0.0001)
        }
    }

    @Test func concealedRetreatOnlyProvokesIfAnObserverActuallySeesIt() throws {
        for facing in [ActorFacing.east, .west] {
            var model = fight()
            model.setInitialFacing("foe.0", facing: facing)
            _ = model.hide(observed: false)
            let route = retreat(model)
            let original = model
            let warnings = model.opportunityExits(along: route, clearLine: clear)
            #expect(model == original && warnings.isEmpty == (facing == .east))
            let step = model.moveWithOpportunityAttacks(along: route, clearLine: clear)
            #expect((step?.reaction != nil) == (facing == .west))
            #expect((model.current.hidden == true) == (facing == .east))
        }
    }

    @Test func concealmentDoesNotInspectAnUnwalkedReturnDiagonal() {
        var model = fight()
        model.setInitialFacing("foe.0", facing: .northEast)
        _ = model.hide(observed: false)
        _ = model.dash()
        let route = Path(points: [CGPoint(x: 0, y: 100), CGPoint(x: 200, y: 100)], from: .zero)
        let result = model.moveWithOpportunityAttacks(along: route, clearLine: { _, mover in
            (90...110).contains(mover.position.x) && (40...60).contains(mover.position.y)
        })
        #expect(result != nil && result?.reaction == nil && model.current.hidden == true)
        #expect(model.current.position == CGPoint(x: 200, y: 100))
    }

}

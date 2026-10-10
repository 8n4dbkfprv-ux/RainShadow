import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct EnemyTacticsTests {
    private func fixture(role: EnemyCombatRole = .bruiser, distance: CGFloat = 96, ally: Bool = false,
                         allyAfterTarget: Bool = false, targetHP: Int = 30, defence: Int = 12,
                         fire: Int = 0, burning: Bool = false, spent: [CombatManeuver] = [],
                         obstacles: [CGRect] = [], barrels: [CombatBarrel] = []) -> (TacticalCombat, NavigationMap) {
        var actors = [
            Combatant(id: "enemy.0", name: role.title, player: false, position: CGPoint(x: 600, y: 400),
                hp: burning ? 3 : 20, maximumHP: 20, defence: 11, attackBonus: 3, damageMin: 1, damageMax: 3,
                initiativeBonus: 100, rangedWeapon: role == .archer ? .bow : nil, fireArrows: fire,
                enemyRole: role, usedManeuvers: spent, burningTurns: burning ? 2 : nil),
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: CGPoint(x: 600 - distance, y: 400),
                hp: targetHP, maximumHP: 30, defence: defence, attackBonus: 5, damageMin: 3, damageMax: 5,
                initiativeBonus: -50)]
        if ally { actors.append(Combatant(id: "enemy.1", name: "Bruiser", player: false,
            position: CGPoint(x: 600 - distance, y: 460), hp: 20, maximumHP: 20,
            defence: 11, attackBonus: 3, damageMin: 2, damageMax: 4, initiativeBonus: allyAfterTarget ? -100 : 50, enemyRole: .bruiser)) }
        let model = TacticalCombat(encounterID: "qa", areaID: "qa", actors: actors, seed: 42, barrels: barrels)
        let map = NavigationMap(worldBounds: CGRect(x: -600, y: 0, width: 2400, height: 1000), obstacles: obstacles)
        for actor in actors { map.registerActor(id: actor.id, kind: actor.player ? .player : .npc, at: actor.position) }
        return (model, map)
    }
    private func attack(_ decision: EnemyDecision) throws -> CombatAttackOrder {
        guard case .attack(let order) = decision.action else {
            Issue.record("Expected attack, got \(decision.reason) (score \(decision.score))")
            throw Failure()
        }
        return order
    }
    struct Failure: Error {}

    @Test func rolesChooseDifferentMeleeTechniques() throws {
        let (bruiser, map) = fixture()
        #expect(try attack(EnemyTactics.choose(combat: bruiser, map: map)).maneuver == .powerStrike)
        let (opportunist, other) = fixture(role: .opportunist)
        #expect(try attack(EnemyTactics.choose(combat: opportunist, map: other)).maneuver == .feintingCut)
        #expect(!opportunist.canUse(.powerStrike, hasSword: true))
        var copy = opportunist
        let denied = copy.attack(target: TacticalCombat.playerID, clearLine: true, maneuver: .powerStrike, hasSword: true)
        #expect(denied == nil && copy == opportunist)
    }
    @Test func tripCoordinatesWithAnAllyBeforeTheVictimCanStand() throws {
        let (model, map) = fixture(role: .opportunist, ally: true)
        #expect(try attack(EnemyTactics.choose(combat: model, map: map)).maneuver == .tripAttack)
        let (late, lateMap) = fixture(role: .opportunist, ally: true, allyAfterTarget: true)
        #expect(try attack(EnemyTactics.choose(combat: late, map: lateMap)).maneuver == .feintingCut)
    }
    @Test func finishersAndPoorAccuracyDoNotWasteTechniques() throws {
        let (finish, map) = fixture(role: .opportunist, targetHP: 2)
        #expect(try attack(EnemyTactics.choose(combat: finish, map: map)).maneuver == nil)
        let (armoured, other) = fixture(defence: 23)
        #expect(try attack(EnemyTactics.choose(combat: armoured, map: other)).maneuver == nil)
        let (spent, spentMap) = fixture(spent: [.powerStrike])
        #expect(try attack(EnemyTactics.choose(combat: spent, map: spentMap)).maneuver == nil)
    }
    @Test func pinningShotPreventsAnApproachAndDoesNotReplaceAUsefulFinisher() throws {
        let (archer, map) = fixture(role: .archer, distance: 300)
        #expect(try attack(EnemyTactics.choose(combat: archer, map: map)).maneuver == .pinningShot)
        let (finish, other) = fixture(role: .archer, distance: 360, targetHP: 1, fire: 3)
        let choice = try attack(EnemyTactics.choose(combat: finish, map: other))
        #expect(choice.ammunition == .normal && choice.maneuver != .pinningShot)
    }
    @Test func fireArrowsAreChosenForBurningValueAndConservedOnBurningTargets() throws {
        let (model, map) = fixture(role: .archer, distance: 400, fire: 3)
        #expect(try attack(EnemyTactics.choose(combat: model, map: map)).ammunition == .fire)
        var actors = model.actors
        actors[1].burningTurns = 2
        let burning = TacticalCombat(encounterID: "qa", areaID: "qa", actors: actors, seed: 42)
        #expect(try attack(EnemyTactics.choose(combat: burning, map: map)).ammunition == .normal)
    }
    @Test func archerRetreatsWithLeftoverMovementThenStops() throws {
        var (model, map) = fixture(role: .archer, distance: 150, spent: [.aimedShot, .pinningShot])
        _ = model.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true)
        let origin = model.current.position
        var moves = 0
        for _ in 0..<12 {
            let choice = EnemyTactics.choose(combat: model, map: map)
            if case .move(let path) = choice.action {
                let moved = model.move(along: path)
                #expect(moved)
                map.updateActor(id: model.current.id, position: model.current.position, isMoving: false)
                moves += 1
            } else { break }
        }
        #expect(moves > 0 && moves < 12)
        #expect(CombatNavigation.distance(model.current.position, model.actors[1].position) > CombatNavigation.distance(origin, model.actors[1].position))
        #expect(!model.budget.canAttack)
        if case .endTurn = EnemyTactics.choose(combat: model, map: map).action {} else { Issue.record("Archer must stop repositioning") }
    }
    @Test func safeBarrelChainsCompeteWithAttacksButNeverHitAllies() throws {
        let barrels = [CombatBarrel(id: "oil.0", position: CGPoint(x: 220, y: 340)),
                       CombatBarrel(id: "oil.1", position: CGPoint(x: 140, y: 340)),
                       CombatBarrel(id: "oil.2", position: CGPoint(x: 220, y: 420))]
        let (model, map) = fixture(role: .archer, distance: 400, fire: 3, barrels: barrels)
        if case .barrel = EnemyTactics.choose(combat: model, map: map).action {} else { Issue.record("Safe chain should beat one arrow") }
        let (unsafe, other) = fixture(role: .archer, distance: 400, ally: true, fire: 3, barrels: barrels)
        if case .barrel(let id) = EnemyTactics.choose(combat: unsafe, map: other).action {
            let chain = unsafe.explosionChain(startingAt: id) { a, b in CombatNavigation.clearLine(in: other, from: a, to: b, excluding: Array(other.occupancy.actors.keys)) }
            Issue.record("An ally is inside the chain: \(id), chain \(chain.map(\.id)), actors \(unsafe.actors.map(\.position))")
        }
    }
    @Test func extinguishingLethalFireBeatsAnAttack() {
        let (model, map) = fixture(burning: true)
        if case .extinguish = EnemyTactics.choose(combat: model, map: map).action {} else { Issue.record("Burning enemy should save itself") }
    }
    @Test func planningIsReadOnlyDeterministicAndRoundTrips() throws {
        let (model, map) = fixture(role: .archer, distance: 250, fire: 3)
        let before = model, occupants = map.occupancy.actors
        let first = EnemyTactics.choose(combat: model, map: map)
        let second = EnemyTactics.choose(combat: model, map: map)
        #expect(first.reason == second.reason && first.score == second.score)
        #expect(model == before && map.occupancy.actors == occupants)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && restored.isValid)
    }
    @Test func existingSavesAcquireRolesWithoutResettingCombat() throws {
        var (model, _) = fixture(ally: true)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(model)) as? [String: Any])
        var actors = try #require(object["actors"] as? [[String: Any]])
        for index in actors.indices { actors[index].removeValue(forKey: "enemyRole") }
        object["actors"] = actors
        model = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        let before = model
        model.assignEnemyRoles()
        #expect(model.actors.filter { !$0.player }.map(\.enemyRole) == [.bruiser, .opportunist])
        #expect(model.randomState == before.randomState && model.budget == before.budget && model.turn == before.turn)
        #expect(model.actors.map(\.hp) == before.actors.map(\.hp) && model.actors.map(\.position) == before.actors.map(\.position))
        let assigned = model
        model.assignEnemyRoles()
        #expect(model == assigned)
    }
    @Test func wallsAndHiddenTargetsDoNotGrantAttacksOrKnowledge() {
        let (model, map) = fixture(distance: 300, obstacles: [CGRect(x: 430, y: 0, width: 40, height: 1000)])
        if case .endTurn = EnemyTactics.choose(combat: model, map: map).action {} else { Issue.record("Solid wall seals the route") }
        var actors = model.actors
        actors[1].hidden = true; actors[1].lastSeenPosition = CGPoint(x: 100, y: 100)
        let hidden = TacticalCombat(encounterID: "qa", areaID: "qa", actors: actors, seed: 42)
        if case .endTurn = EnemyTactics.choose(combat: hidden, map: map).action {} else { Issue.record("Hidden target must be handled by last-seen search") }
    }
    @Test func approachPreservesAttackAndOnlyDashesWhenItCannotAttack() throws {
        var (model, map) = fixture(distance: 250)
        guard case .move(let path) = EnemyTactics.choose(combat: model, map: map).action else { Issue.record("Expected approach"); return }
        let moved = model.move(along: path)
        #expect(moved && model.budget.canAttack)
        map.updateActor(id: model.current.id, position: model.current.position, isMoving: false)
        _ = try attack(EnemyTactics.choose(combat: model, map: map))
        var (far, farMap) = fixture(distance: 550)
        for _ in 0..<3 {
            let choice = EnemyTactics.choose(combat: far, map: farMap)
            switch choice.action {
            case .move(let path):
                _ = far.move(along: path); farMap.updateActor(id: far.current.id, position: far.current.position, isMoving: false)
            case .dash(let path):
                let dashed = far.dash(), moved = far.move(along: path)
                #expect(dashed && moved && !far.budget.canAttack); return
            default: Issue.record("Expected move then explicit Dash: \(choice.reason), position \(far.current.position), budget \(far.budget)"); return
            }
        }
        Issue.record("Never chose Dash")
    }
}

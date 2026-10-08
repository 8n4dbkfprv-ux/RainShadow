import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore
@testable import RainShadowPersistence

struct TacticalCombatTests {
    private func fight(seed: UInt64 = 42) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            Combatant(id: "detective.voss", name: "Voss", player: true, position: CGPoint(x: 100, y: 100),
                      hp: 12, maximumHP: 12, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 30),
            Combatant(id: "crew", name: "Crew", player: false, position: CGPoint(x: 180, y: 100),
                      hp: 7, maximumHP: 7, defence: 11, attackBonus: 2, damageMin: 1, damageMax: 3, initiativeBonus: 0)
        ], seed: seed)
    }
    @Test func pinnedTemplePlusTransitionOracle() {
        // Independently transcribed from upstream constructor at 03d7204510bc.
        let rows: [[Int?]] = [[0,nil,nil,nil,nil],[1,0,nil,nil,nil],[2,0,0,nil,nil],
                             [3,0,0,0,nil],[4,2,1,nil,0],[5,2,2,nil,0],[6,5,2,nil,3]]
        for state in 0..<7 { for cost in 0..<5 {
            #expect(CombatBudget.transition(state: state, cost: cost) == rows[state][cost])
        } }
        #expect(CombatBudget.transition(state: -1, cost: 1) == nil)
        #expect(CombatBudget.transition(state: 4, cost: 9) == nil)
    }
    @Test func movementAndStandardActionsAreNotInterchangeablePoints() {
        var budget = CombatBudget()
        let result27 = budget.move(distance: 60, speed: 240)
        #expect(result27)
        #expect(budget.state == 2 && budget.movementRemaining == 180)
        let result29 = budget.spend(2)
        #expect(result29)
        let result30 = budget.move(distance: 180, speed: 240)
        #expect(result30)
        let spent = budget
        let result32 = !budget.move(distance: 1, speed: 240)
        #expect(result32)
        let result33 = !budget.spend(2)
        #expect(result33)
        #expect(budget == spent)
        var doubleMove = CombatBudget()
        let result36 = doubleMove.move(distance: 400, speed: 240)
        #expect(result36)
        #expect(!doubleMove.canAttack)
        #expect(doubleMove.movementRemaining == 80)
        let previous = doubleMove
        let result40 = !doubleMove.move(distance: 81, speed: 240)
        #expect(result40)
        #expect(doubleMove == previous)
        let result42 = !doubleMove.move(distance: .nan, speed: 240)
        #expect(result42)
    }
    @Test func failedStrikeSpendsNeitherBudgetNorRandomness() {
        var combat = fight()
        let before = combat
        let result47 = combat.attack(target: "crew", clearLine: false) == nil
        #expect(result47)
        let result48 = combat.attack(target: "detective.voss", clearLine: true) == nil
        #expect(result48)
        let result49 = combat.attack(target: "missing", clearLine: true) == nil
        #expect(result49)
        #expect(combat == before)
        let result51 = combat.attack(target: "crew", clearLine: true) != nil
        #expect(result51)
        let after = combat
        let result53 = combat.attack(target: "crew", clearLine: true) == nil
        #expect(result53)
        #expect(combat == after)
    }
    @Test func bladeWardPersistsThroughTheNextTurnAndBudgetResets() {
        var combat = fight()
        let result58 = combat.castBladeWard()
        #expect(result58)
        #expect(combat.current.bladeWardTurns == 2)
        #expect(!combat.budget.canAttack)
        let result61 = combat.endTurn()
        #expect(result61)
        #expect(combat.actors.first(where: \.player)!.bladeWardTurns == 2)
        let result63 = combat.endTurn()
        #expect(result63)
        #expect(combat.round == 2)
        #expect(combat.current.bladeWardTurns == 1 && combat.budget.state == 4)
    }
    @Test func checkpointPreservesNextRollAndOlderSavesHaveNoCombat() throws {
        var combat = fight()
        let result69 = combat.castBladeWard()
        #expect(result69)
        _ = combat.endTurn()
        let snapshot = SaveSnapshot(tacticalCombat: try JSONEncoder().encode(combat))
        let envelope = try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(snapshot))
        var restored = try JSONDecoder().decode(TacticalCombat.self, from: #require(envelope.tacticalCombat))
        #expect(restored.isValid && restored == combat)
        let result75 = restored.attack(target: "detective.voss", clearLine: true) == combat.attack(target: "detective.voss", clearLine: true)
        #expect(result75)
        #expect(restored == combat)
        #expect(try JSONDecoder().decode(SaveSnapshot.self, from: Data("{}".utf8)).tacticalCombat == nil)
    }
    @Test func nonlethalVictoryStopsTurnsAndStoryGrantsOnce() {
        var combat = fight()
        for _ in 0..<100 where combat.outcome == nil {
            if combat.isPlayerTurn { _ = combat.attack(target: "crew", clearLine: true) }
            if combat.outcome == nil { _ = combat.endTurn() }
        }
        #expect(combat.outcome == .won)
        #expect(combat.actors.first(where: { !$0.player })!.hp == 0)
        let finished = combat
        let result88 = !combat.endTurn()
        #expect(result88)
        let result89 = combat.attack(target: "crew", clearLine: true) == nil
        #expect(result89)
        #expect(combat == finished)
        var story = CaseState(caseID: EmptyCoatJournalContent.caseID)
        WharfLadderStory.beginVisit(&story); story.setFlag("combat.e1.trigger.desk")
        let result93 = WharfLadderStory.resolve(.e1, outcome: .won, in: &story)
        #expect(result93)
        let result94 = !WharfLadderStory.resolve(.e1, outcome: .won, in: &story)
        #expect(result94)
        #expect(story.counter("watch.attention") == 1)
        #expect(!story.hasFlag("combat.e1.auto-resolved"))
    }
    @Test func yieldingIsANonlethalLoss() {
        var combat = fight()
        combat.yield()
        #expect(combat.outcome == .lost && combat.isValid)
        let result102 = !combat.castBladeWard()
        #expect(result102)
    }
    @Test func rasterWallBlocksMeleeAndMovementCostUsesGroundProjection() {
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 400, height: 300),
                                obstacles: [CGRect(x: 140, y: 0, width: 16, height: 300)])
        #expect(!CombatNavigation.clearLine(in: map, from: CGPoint(x: 120, y: 100), to: CGPoint(x: 180, y: 100)))
        #expect(CombatNavigation.distance(.zero, CGPoint(x: 0, y: 75)) == 100)
        let path = Path(points: [CGPoint(x: 0, y: 75), CGPoint(x: 100, y: 75)], from: .zero)
        #expect(CombatNavigation.length(path, from: .zero) == 200)
        #expect(CombatNavigation.prefix(path, from: .zero, within: 150).destination == CGPoint(x: 0, y: 75))
    }
    @Test func participantStampsDoNotBlockMeleeAndAreFullyRestored() {
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 500, height: 400), obstacles: [])
        let a = CGPoint(x: 180, y: 180), b = CGPoint(x: 260, y: 180)
        map.registerActor(id: TacticalCombat.playerID, kind: .player, at: a)
        map.registerActor(id: "crew", kind: .npc, at: b)
        let records = map.occupancy.actors
        let flags = [a, b].map { map.searchMap.blockedTile(at: map.searchMap.cell(for: $0)) }
        #expect(CombatNavigation.clearLine(in: map, from: a, to: b, excluding: [TacticalCombat.playerID, "crew"]))
        #expect(map.occupancy.actors == records)
        #expect([a, b].map { map.searchMap.blockedTile(at: map.searchMap.cell(for: $0)) } == flags)
        map.registerActor(id: "blocker", kind: .npc, at: CGPoint(x: 220, y: 180))
        #expect(!CombatNavigation.clearLine(in: map, from: a, to: b, excluding: [TacticalCombat.playerID, "crew"]))
    }
    @MainActor @Test func realWharfStagingAllowsAnExitRouteWithCombatIdentities() throws {
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior)
        let map = area.makeNavigationMap()
        let origin = try #require(area.regions.first?.approachPoint?.cgPoint)
        map.registerActor(id: TacticalCombat.playerID, kind: .player, at: origin)
        let points = WharfLadderStaging.positions(near: origin, count: 2, navigation: map, ignoringActorID: TacticalCombat.playerID)
        #expect(points.count == 2)
        for (i, point) in points.enumerated() { map.registerActor(id: "crew.\(i)", kind: .npc, at: point) }
        let actor = Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: origin,
            hp: 12, maximumHP: 12, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 3)
        let exits = (0..<16).compactMap { i -> Path? in
            let angle = CGFloat(i) * .pi / 8
            return CombatNavigation.route(in: map, actor: actor,
                to: CGPoint(x: origin.x + cos(angle) * 150, y: origin.y + sin(angle) * 150 * 0.75))
        }
        #expect(exits.contains { CombatNavigation.length($0, from: origin) <= 240 })
    }
    @Test func invalidCheckpointIsRejected() throws {
        let data = try JSONEncoder().encode(fight())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["turn"] = 999
        let invalid = try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(!invalid.isValid)
    }
}

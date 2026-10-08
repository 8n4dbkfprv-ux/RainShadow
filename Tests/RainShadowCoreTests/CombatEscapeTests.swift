import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore
@testable import RainShadowPersistence

struct CombatEscapeTests {
    private func fight(distance: Double = 480) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: .zero,
                hp: 5, maximumHP: 12, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 100),
            Combatant(id: "crew", name: "Crew", player: false, position: CGPoint(x: 0, y: distance * 0.75),
                hp: 7, maximumHP: 7, defence: 11, attackBonus: 2, damageMin: 1, damageMax: 3, initiativeBonus: 0)
        ], seed: 42)
    }
    @Test func escapeBoundaryUsesGroundDistanceAndPreservesHealthAndBudget() {
        var model = fight(distance: 479)
        let before = model
        #expect(!{ model.flee() }())
        #expect(model == before && model.fleeUnavailableReason?.contains("1 ft") == true)
        model = fight()
        _ = model.castBladeWard() // No standard action is needed to flee.
        let budget = model.budget, rng = model.randomState
        #expect({ model.flee() }())
        #expect(model.outcome == .fled && model.current.hp == 5 && model.isValid)
        #expect(model.budget == budget && model.randomState == rng)
        let escaped = model
        #expect(!{ model.flee() }() && !{ model.endTurn() }())
        #expect(model == escaped)
    }
    @Test func nearestConsciousEnemyControlsEscapeAndEnemyTurnCannotFlee() {
        var model = fight()
        var actors = model.actors
        var second = actors[1]; second.id = "near"; second.position = CGPoint(x: 80, y: 0)
        actors.append(second)
        model = TacticalCombat(encounterID: "gate", areaID: model.areaID, actors: actors, seed: 42)
        #expect(!{ model.flee() }())
        actors[2].hp = 0
        model = TacticalCombat(encounterID: "gate", areaID: model.areaID, actors: actors, seed: 42)
        #expect(model.fleeUnavailableReason == nil)
        _ = model.endTurn()
        let before = model
        #expect(!{ model.flee() }() && model == before)
    }
    @Test func proneCannotFleeAndBearEscapeRetainsHumanHealth() {
        var model = fight(), actors = fight().actors
        actors[0].conditions = .init(prone: true)
        model = TacticalCombat(encounterID: "gate", areaID: model.areaID, actors: actors, seed: 42)
        #expect(!{ model.flee() }() && model.fleeUnavailableReason?.contains("Stand up") == true)
        model = fight()
        #expect({ model.transformToBear(hasClearance: true) }())
        #expect({ model.flee() }())
        #expect(!model.isBear && model.current.hp == 5 && model.isValid)
    }
    @Test func escapeAndHealthSurviveSaveWithOlderSaveDefaults() throws {
        var model = fight(); _ = model.flee()
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && restored.outcome == .fled && restored.isValid)
        let snapshot = SaveSnapshot(currentHealth: 5)
        #expect(try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(snapshot)).currentHealth == 5)
        #expect(try JSONDecoder().decode(SaveSnapshot.self, from: Data("{}".utf8)).currentHealth == 12)
        var old = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(fight())) as? [String: Any])
        old.removeValue(forKey: "fled")
        #expect(try JSONDecoder().decode(TacticalCombat.self, from: JSONSerialization.data(withJSONObject: old)).outcome == nil)
    }
    @Test func escapeDoesNotResolveStoryOrGrantRewardsAndCanBeRetried() {
        for encounter in WharfLadderStory.Encounter.allCases {
            var state = CaseState(caseID: EmptyCoatJournalContent.caseID)
            WharfLadderStory.beginVisit(&state)
            let trigger = encounter == .e1 ? "combat.e1.trigger.desk" : encounter.prefix + ".trigger"
            state.setFlag(trigger)
            state.grantEvidence("evidence.sealMark.scrap")
            let evidence = state.evidenceIDs
            WharfLadderStory.flee(encounter, in: &state)
            #expect(!WharfLadderStory.requested(encounter, in: state))
            #expect(!WharfLadderStory.crossed(encounter, in: state))
            #expect(!state.hasFlag(encounter.prefix + ".done") && !state.hasFlag("injury.voss.bruised"))
            #expect(WharfLadderStory.pendingAftermath(in: state) == nil)
            #expect(state.evidenceIDs == evidence && state.counter("watch.attention") == 0)
            state.setFlag(trigger)
            #expect(WharfLadderStory.resolve(encounter, outcome: .won, in: &state))
            #expect(!state.hasFlag(encounter.prefix + ".outcome.fled"))
        }
    }
}

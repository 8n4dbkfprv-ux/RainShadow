import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct CombatDashTests {
    private func fight() -> TacticalCombat {
        TacticalCombat(encounterID: "dash", areaID: "city_wharf_ladder", actors: [
            Combatant(id: TacticalCombat.playerID, name: "Voss", player: true, position: .zero,
                hp: 12, maximumHP: 12, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: 100),
            Combatant(id: "enemy", name: "Enemy", player: false, position: CGPoint(x: 800, y: 0),
                hp: 12, maximumHP: 12, defence: 12, attackBonus: 5, damageMin: 3, damageMax: 5, initiativeBonus: -100)
        ], seed: 42)
    }
    @Test func movementNeverSilentlySpendsAnAttack() {
        var budget = CombatBudget()
        #expect(budget.availableMovement(speed: 240) == 240)
        do { let result = !budget.move(distance: 241, speed: 240); #expect(result) }
        #expect(budget == CombatBudget())
        do { let result = budget.move(distance: 240, speed: 240); #expect(result) }
        #expect(budget.canAttack && budget.availableMovement(speed: 240) == 0)
        do { let result = !budget.move(distance: 1, speed: 240); #expect(result) }
        do { let result = budget.dash(speed: 240); #expect(result) }
        #expect(!budget.canAttack && budget.availableMovement(speed: 240) == 240)
        do { let result = budget.move(distance: 240, speed: 240); #expect(result) }
        do { let result = budget.availableMovement(speed: 240) == 0 && !budget.dash(speed: 240); #expect(result) }
    }
    @Test func dashBeforeOrAfterPartialMovementAddsExactlyOneSpeed() {
        for first in [0.0, 60, 239, 240] {
            var budget = CombatBudget()
            if first > 0 { do { let result = budget.move(distance: first, speed: 240); #expect(result) } }
            do { let result = budget.dash(speed: 240); #expect(result) }
            #expect(budget.availableMovement(speed: 240) == 480 - first)
            let saved = budget
            do { let result = !budget.dash(speed: 240) && budget == saved; #expect(result) }
            do { let result = budget.move(distance: 480 - first, speed: 240); #expect(result) }
            do { let result = !budget.move(distance: 1, speed: 240); #expect(result) }
        }
    }
    @Test func spentActionCannotDashButRetainsNormalMovement() {
        var budget = CombatBudget()
        do { let result = budget.spend(2); #expect(result) }
        let saved = budget
        do { let result = !budget.dash(speed: 240) && budget == saved; #expect(result) }
        #expect(budget.availableMovement(speed: 240) == 240)
        do { let result = budget.move(distance: 240, speed: 240); #expect(result) }
        var invalid = CombatBudget()
        do { let result = !invalid.dash(speed: .nan) && !invalid.dash(speed: 0); #expect(result) }
        #expect(invalid == CombatBudget())
    }
    @Test func dashPersistsAndResetsForPlayerAndEnemy() throws {
        var model = fight()
        do { let result = model.dash(); #expect(result) }
        let speed = model.movementSpeed(for: model.current)
        #expect(model.budget.availableMovement(speed: speed) == speed * 2)
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        #expect(restored == model && !restored.canDash)
        do { let result = model.endTurn(); #expect(result) }
        do { let result = !model.current.player && model.canDash && model.dash(); #expect(result) }
        do { let result = model.endTurn(); #expect(result) }
        #expect(model.current.player && model.canDash)
        #expect(model.budget.availableMovement(speed: speed) == speed)
    }
    @Test func bearAndSlowedActorsDashAtTheirCurrentSpeed() {
        var model = fight()
        do { let result = model.transformToBear(hasClearance: true); #expect(result) }
        #expect(!model.canDash) // Transformation used this turn's action.
        do { let result = model.endTurn() && model.endTurn(); #expect(result) }
        #expect(model.isBear && model.canDash)
        let speed = model.movementSpeed(for: model.current)
        do { let result = model.dash(); #expect(result) }
        #expect(model.budget.availableMovement(speed: speed) == speed * 2)
        var slowed = CombatBudget()
        do { let result = slowed.dash(speed: 120); #expect(result) }
        #expect(slowed.availableMovement(speed: 120) == 240)
    }
    @Test func oldBudgetSnapshotsKeepPreviouslySpentActions() throws {
        let old = try JSONDecoder().decode(CombatBudget.self, from: Data(#"{"state":0,"movementRemaining":80}"#.utf8))
        #expect(!old.canAttack && old.availableMovement(speed: 240) == 80)
    }
}

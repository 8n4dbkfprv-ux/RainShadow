import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct RangedAmmunitionTests {
    private func fight(seed: UInt64 = 42, npcArrows: Int = 1) -> TacticalCombat {
        TacticalCombat(encounterID: "gate", areaID: "city_wharf_ladder", actors: [
            .init(id: TacticalCombat.playerID, name: "Voss", player: true, position: .zero,
                hp: 100, maximumHP: 100, defence: 12, attackBonus: 100, damageMin: 3, damageMax: 3,
                initiativeBonus: 100, rangedWeapon: .bow),
            .init(id: "enemy", name: "Lookout", player: false, position: .init(x: 250, y: 0),
                hp: 100, maximumHP: 100, defence: 12, attackBonus: 100, damageMin: 3, damageMax: 3,
                initiativeBonus: -100, rangedWeapon: .bow, fireArrows: npcArrows)
        ], seed: seed, barrels: [.init(id: "barrel", position: .init(x: 200, y: 0))])
    }
    @Test func ordinaryArrowsNeverBurnAndFireMustBeExplicit() throws {
        for seed in 1...50 {
            var normal = fight(seed: UInt64(seed)), fire = normal
            let plain = try #require({ normal.attack(target: "enemy", clearLine: true, ranged: true) }())
            let flaming = try #require({ fire.attack(target: "enemy", clearLine: true, ranged: true, ammunition: .fire) }())
            #expect(!plain.fireArrow && !normal.actors[1].isBurning)
            #expect(flaming.fireArrow && fire.actors[1].isBurning == flaming.landed)
            #expect(plain.damage == flaming.damage)
        }
    }
    @Test func npcCannotFireSpecialAmmoWithoutStockAndInvalidShotsAreInert() throws {
        var game = fight(); _ = game.endTurn()
        let before = game
        #expect({ game.attack(target: TacticalCombat.playerID, clearLine: false, ranged: true, ammunition: .fire) }() == nil)
        #expect(game == before)
        let shot = try #require({ game.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true, ammunition: .fire) }())
        #expect(shot.fireArrow && game.current.fireArrows == 0)
        _ = game.endTurn(); _ = game.endTurn()
        let empty = game
        #expect({ game.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true, ammunition: .fire) }() == nil)
        #expect(game == empty)
        #expect({ game.attack(target: TacticalCombat.playerID, clearLine: true, ranged: true) }() != nil)
        #expect(try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(game)) == game)
    }
    @Test func normalArrowsBreakBarrelsWithoutExplosion() {
        var game = fight()
        #expect({ game.breakBarrel("barrel", clearLine: true, ranged: true) }())
        #expect(game.barrels?.first?.isBroken == true && game.barrels?.first?.exploded == false)
        #expect(game.actors.allSatisfy { $0.hp == 100 && !$0.isBurning })
        _ = game.endTurn(); _ = game.endTurn()
        #expect({ game.igniteBarrel("barrel", clearShot: true, visible: { _, _ in true }) }() != nil)
    }
    @Test func specialAmmoCannotBeCombinedWithTechniquesOrSneakAttack() {
        var game = fight(); let before = game
        #expect({ game.attack(target: "enemy", clearLine: true, ranged: true, ammunition: .fire, maneuver: .aimedShot) }() == nil)
        #expect({ game.attack(target: "enemy", clearLine: true, ranged: true, ammunition: .fire, requireSneakAttack: true) }() == nil)
        #expect(game == before)
    }
    @Test func ammunitionConsumptionPrefersQuiverAndPreservesMetadata() {
        let fire = CombatAmmunition.fireItemID
        var inventory = CharacterInventory(equipped: [.quiver1: .init(id: fire, quantity: 2, isIdentified: false, charges: 7)],
            backpack: .init(stacks: [.init(id: fire, quantity: 1), .init(id: "elven-court-arrow", quantity: 8)]))
        #expect({ inventory.consumeFireArrow() }())
        #expect(inventory.item(in: .quiver1) == .init(id: fire, quantity: 1, isIdentified: false, charges: 7))
        #expect({ inventory.consumeFireArrow() }() && inventory.item(in: .quiver1) == nil)
        #expect({ inventory.consumeFireArrow() }() && inventory.quantity(of: fire) == 0)
        let empty = inventory
        #expect(!{ inventory.consumeFireArrow() }() && inventory == empty)
        #expect(inventory.quantity(of: "elven-court-arrow") == 8)
    }
    @Test func bowMustBeEquippedAndFireItemIsStackableAmmunition() throws {
        let bow = CarriedItemStack(id: HarborpointItems.elvenCourtBowID, quantity: 1)
        #expect(!CharacterInventory(backpack: .init(stacks: [bow])).hasEquippedBow)
        #expect(CharacterInventory(equipped: [.weapon2: bow]).hasEquippedBow)
        let definition = try #require(HarborpointItems.definition(for: CombatAmmunition.fireItemID))
        #expect(definition.category == .ammunition && definition.maxStack == 20)
        var model = fight(); model.setPlayerBowEquipped(false)
        let before = model
        #expect({ model.attack(target: "enemy", clearLine: true, ranged: true) }() == nil && model == before)
    }
}

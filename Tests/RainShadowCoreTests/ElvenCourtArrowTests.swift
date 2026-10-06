import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct ElvenCourtArrowTests {
    private let catalog = HarborpointItems.catalog
    private let bow = CarriedItemStack(id: "elven-court-bow", quantity: 1)
    private let arrow = CarriedItemStack(id: "elven-court-arrow", quantity: 1)

    @Test func ammunitionUsesQuiverSlotsWithoutWeakeningTwoHandedRules() throws {
        let definition = try catalog.require(arrow.id)
        #expect(definition.category == .ammunition)
        #expect(Set(definition.equippableSlots) == Set(EquipmentSlot.quiverSlots))
        var inventory = CharacterInventory(equipped: [.weapon1: bow])
        for slot in EquipmentSlot.quiverSlots {
            #expect(inventory.canEquip(arrow, in: slot, catalog: catalog))
        }
        #expect(!inventory.canEquip(arrow, in: .holster, catalog: catalog))
        #expect(!inventory.canEquip(arrow, in: .weapon1, catalog: catalog))
        try inventory.equip(arrow, in: .quiver2, catalog: catalog)
        #expect(VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog) == .elvenCourtArrow)
        let sword = CarriedItemStack(id: "lantern-shortsword", quantity: 1)
        #expect(inventory.refusal(equipping: sword, in: .holster, catalog: catalog)
            == .offHandBlockedByTwoHandedWeapon(blockedBy: .weapon1))
    }

    @Test func heldAppearanceRequiresBothEquippedArrowAndReadiedBow() throws {
        var inventory = CharacterInventory(backpack: .init(stacks: [arrow, bow]))
        let limits = ItemStackLimits(catalog: catalog)
        try inventory.equipFromBackpack(at: 0, to: .quiver1, catalog: catalog, limits: limits)
        #expect(VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog) == nil)
        try inventory.equipFromBackpack(at: 0, to: .weapon2, catalog: catalog, limits: limits)
        #expect(VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog) == .elvenCourtArrow)
        try inventory.equip(.init(id: "lantern-shortsword", quantity: 1), in: .weapon1, catalog: catalog)
        #expect(VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog) == nil)
        _ = try inventory.unequip(from: .weapon1, catalog: catalog)
        try inventory.moveEquipped(from: .quiver1, to: .quiver3, catalog: catalog)
        #expect(VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog) == .elvenCourtArrow)
        try inventory.unequipToBackpack(from: .quiver3, catalog: catalog, limits: limits)
        #expect(VossAmmunitionAppearance.equipped(in: inventory, catalog: catalog) == nil)
        #expect(inventory.quantity(of: arrow.id) == 1)
        #expect(inventory.quantity(of: bow.id) == 1)
        #expect(VossWeaponAppearance.equipped(in: inventory, catalog: catalog) == .elvenCourtBow)
    }

    @Test func grantDefersAndReceiptPersistsWithoutDuplicatingDroppedArrows() throws {
        #expect(HarborpointItems.elvenCourtArrowGrant(hasReceived: false, existingIDs: [], availableSlots: 0).isEmpty)
        #expect(HarborpointItems.elvenCourtArrowGrant(hasReceived: false, existingIDs: [], availableSlots: 1) == [arrow.id])
        #expect(HarborpointItems.elvenCourtArrowGrant(hasReceived: false, existingIDs: [arrow.id]).isEmpty)
        #expect(HarborpointItems.elvenCourtArrowGrant(hasReceived: true, existingIDs: []).isEmpty)
        var save = try JSONDecoder().decode(SaveSnapshot.self, from: Data(#"{"schemaVersion":1}"#.utf8))
        #expect(!save.hasReceivedElvenCourtArrow)
        save.hasReceivedElvenCourtArrow = true
        save.equippedItems = ["quiver2": .init(id: arrow.id, quantity: 3)]
        #expect(try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(save)) == save)
    }

    @Test func allArrowFramesShareTheBodyRegistrationAndIdleTiming() throws {
        let appearance = VossAmmunitionAppearance.elvenCourtArrow
        let sprite = try IEIndexedSprite.load(character: appearance.character)
        let body = try IEIndexedSprite.load(character: VossAnimationSet.character)
        try VossAnimationSet.validate(body)
        try appearance.validate(sprite)
        try CharacterEquipmentCode.elvenCourtArrow.validate(sprite)
        #expect(sprite.displayUnitsPerSourcePixel == body.displayUnitsPerSourcePixel)
        #expect(!sprite.hasEmbeddedShadow)
        var count = 0
        for frame in body.frames {
            guard let name = appearance.frameName(matching: frame.id) else { continue }
            let overlay = try #require(sprite.frame(atlas: appearance.atlas, name: name))
            if !overlay.isEmpty {
                #expect(Double(overlay.trimOriginTopLeft.width) + overlay.pivotFromCropBottomLeft.x == 64)
                #expect(Double(128-overlay.trimOriginTopLeft.height-overlay.size.height) + overlay.pivotFromCropBottomLeft.y == 46)
            }
            count += 1
        }
        #expect(count == 1200)
        #expect(appearance.frameName(matching: .init(atlas: VossAnimationSet.atlas, name: "seated_idle_sw_00.png")) == nil)
        #expect(!CharacterEquipmentCode.elvenCourtArrow.supports(body: .humanFemale01))
        for direction in VossAnimationSet.directions {
            let first = try #require(sprite.frame(atlas: appearance.atlas, name: "idle_\(direction)_00.png"))
            for phase in [1,26,27,28,29,30,31,32,33,58,59,60,61,62,63,64] {
                let held = try #require(sprite.frame(atlas: appearance.atlas, name: String(format: "idle_%@_%02d.png", direction, phase)))
                #expect(held.indices == first.indices)
                #expect(held.trimOriginTopLeft == first.trimOriginTopLeft)
            }
        }
    }
}

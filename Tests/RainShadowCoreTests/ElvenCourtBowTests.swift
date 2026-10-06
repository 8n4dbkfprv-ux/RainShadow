import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct ElvenCourtBowTests {
    @Test func swappingAndUnequippingPreserveBothWeaponsAndClearAppearance() throws {
        let catalog = HarborpointItems.catalog
        let limits = ItemStackLimits(catalog: catalog)
        let bow = CarriedItemStack(id: HarborpointItems.elvenCourtBowID, quantity: 1)
        let sword = CarriedItemStack(id: "lantern-shortsword", quantity: 1)
        var inventory = CharacterInventory(equipped: [.weapon1: sword], backpack: .init(stacks: [bow]))
        try inventory.equipFromBackpack(at: 0, to: .weapon1, catalog: catalog, limits: limits)
        #expect(VossWeaponAppearance.equipped(in: inventory, catalog: catalog) == .elvenCourtBow)
        #expect(inventory.backpack.stacks == [sword])
        #expect(inventory.quantity(of: bow.id) == 1)
        try inventory.unequipToBackpack(from: .weapon1, catalog: catalog, limits: limits)
        #expect(VossWeaponAppearance.equipped(in: inventory, catalog: catalog) == nil)
        #expect(inventory.quantity(of: bow.id) == 1)
        #expect(inventory.quantity(of: sword.id) == 1)
    }

    @Test func bowRequiresAWeaponSlotAndAnEmptyOffHand() throws {
        let catalog = HarborpointItems.catalog
        let definition = try catalog.require(HarborpointItems.elvenCourtBowID)
        #expect(definition.flags.contains(.twoHanded))
        #expect(Set(definition.equippableSlots) == Set(EquipmentSlot.weaponSlots))
        let bow = CarriedItemStack(id: definition.id, quantity: 1)
        let sword = CarriedItemStack(id: "lantern-shortsword", quantity: 1)
        var inventory = CharacterInventory()
        #expect(!inventory.canEquip(bow, in: .holster, catalog: catalog))
        try inventory.equip(sword, in: .holster, catalog: catalog)
        #expect(inventory.refusal(equipping: bow, in: .weapon1, catalog: catalog)
            == .twoHandedBlockedByOffHand(occupied: .holster))
        try inventory.unequip(from: .holster, catalog: catalog)
        try inventory.equip(bow, in: .weapon1, catalog: catalog)
        #expect(inventory.refusal(equipping: sword, in: .holster, catalog: catalog)
            == .offHandBlockedByTwoHandedWeapon(blockedBy: .weapon1))
    }

    @Test func grantDefersForFullBagsAndDoesNotReplaceExistingOrDroppedBows() throws {
        let bow = HarborpointItems.elvenCourtBowID
        #expect(HarborpointItems.elvenCourtBowGrant(hasReceived: false, existingIDs: [], availableSlots: 0).isEmpty)
        #expect(HarborpointItems.elvenCourtBowGrant(hasReceived: false, existingIDs: [], availableSlots: 1) == [bow])
        #expect(HarborpointItems.elvenCourtBowGrant(hasReceived: false, existingIDs: [bow]).isEmpty)
        #expect(HarborpointItems.elvenCourtBowGrant(hasReceived: true, existingIDs: []).isEmpty)
        var save = try JSONDecoder().decode(SaveSnapshot.self, from: Data(#"{"schemaVersion":1}"#.utf8))
        #expect(!save.hasReceivedElvenCourtBow)
        save.hasReceivedElvenCourtBow = true
        save.equippedItems = ["weapon1": .init(id: bow, quantity: 1)]
        #expect(try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(save)) == save)
    }

    @Test func everyStandingFrameMatchesTheApprovedBodyRegistration() throws {
        let appearance = VossWeaponAppearance.elvenCourtBow
        let bow = try IEIndexedSprite.load(character: appearance.character)
        let body = try IEIndexedSprite.load(character: VossAnimationSet.character)
        try VossAnimationSet.validate(body)
        try appearance.validate(bow)
        try CharacterEquipmentCode.elvenCourtBow.validate(bow)
        #expect(bow.displayUnitsPerSourcePixel == body.displayUnitsPerSourcePixel)
        #expect(!bow.hasEmbeddedShadow)
        var count = 0
        for frame in body.frames {
            guard let name = appearance.frameName(matching: frame.id) else { continue }
            let overlay = try #require(bow.frame(atlas: appearance.atlas, name: name))
            if !overlay.isEmpty {
                #expect(Double(overlay.trimOriginTopLeft.width) + overlay.pivotFromCropBottomLeft.x == 64)
                #expect(Double(128-overlay.trimOriginTopLeft.height-overlay.size.height) + overlay.pivotFromCropBottomLeft.y == 46)
            }
            count += 1
        }
        #expect(count == 1200)
        #expect(appearance.frameName(matching: .init(atlas: VossAnimationSet.atlas, name: "seated_idle_sw_00.png")) == nil)
        #expect(CharacterEquipmentCode.elvenCourtBow.supports(body: .humanMale01))
        #expect(!CharacterEquipmentCode.elvenCourtBow.supports(body: .humanFemale01))
        for direction in VossAnimationSet.directions {
            let first = try #require(bow.frame(atlas: appearance.atlas, name: "idle_\(direction)_00.png"))
            for phase in [1,26,27,28,29,30,31,32,33,58,59,60,61,62,63,64] {
                let held = try #require(bow.frame(atlas: appearance.atlas, name: String(format: "idle_%@_%02d.png", direction, phase)))
                #expect(held.indices == first.indices)
                #expect(held.trimOriginTopLeft == first.trimOriginTopLeft)
            }
        }
    }
}

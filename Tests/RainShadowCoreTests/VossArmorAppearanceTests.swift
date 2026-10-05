import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct VossArmorAppearanceTests {
    @Test func itemsEquipIndependentlyAndOnlyInTheirOwnSlots() throws {
        let catalog = HarborpointItems.catalog
        let helmet = CarriedItemStack(id: "iron-helmet", quantity: 1)
        let mail = CarriedItemStack(id: "splint-mail", quantity: 1)
        var inventory = CharacterInventory(backpack: .init(stacks: [helmet, mail]))
        #expect(VossArmorAppearance.allCases.allSatisfy { !$0.isEquipped(in: inventory) })
        #expect(!inventory.canEquip(helmet, in: .coat, catalog: catalog))
        #expect(!inventory.canEquip(mail, in: .fedora, catalog: catalog))
        try inventory.equip(helmet, in: .fedora, catalog: catalog)
        #expect(VossArmorAppearance.ironHelmet.isEquipped(in: inventory))
        #expect(!VossArmorAppearance.splintMail.isEquipped(in: inventory))
        try inventory.equip(mail, in: .coat, catalog: catalog)
        #expect(inventory.defenceBonus(catalog: catalog) == 7)
        try inventory.unequip(from: .fedora, catalog: catalog)
        #expect(!VossArmorAppearance.ironHelmet.isEquipped(in: inventory))
        #expect(VossArmorAppearance.splintMail.isEquipped(in: inventory))
        #expect(inventory.defenceBonus(catalog: catalog) == 6)
        try inventory.unequip(from: .coat, catalog: catalog)
        #expect(inventory.defenceBonus(catalog: catalog) == 0)
    }

    @Test func everyIdleAndWalkFrameHasBothRegisteredArmorLayers() throws {
        let body = try IEIndexedSprite.load(character: VossAnimationSet.character)
        for appearance in VossArmorAppearance.allCases {
            let sprite = try IEIndexedSprite.load(character: appearance.character)
            try appearance.validate(sprite)
            #expect(!sprite.hasEmbeddedShadow)
            var count = 0
            for frame in body.frames {
                guard let name = appearance.frameName(matching: frame.id) else { continue }
                let layer = try #require(sprite.frame(atlas: appearance.atlas, name: name))
                count += 1
                #expect(!layer.isEmpty)
                #expect(Double(layer.trimOriginTopLeft.width) + layer.pivotFromCropBottomLeft.x == 64)
                #expect(Double(128-layer.trimOriginTopLeft.height-layer.size.height) + layer.pivotFromCropBottomLeft.y == 46)
                #expect(layer.indices.allSatisfy { $0 == 0 || (4..<40).contains(Int($0)) })
            }
            #expect(count == 1200)
            #expect(appearance.frameName(matching: .init(atlas: VossAnimationSet.atlas, name: "seated_idle_sw_00.png")) == nil)
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

    @Test func helmetHasCompleteIndependentWearingVariants() throws {
        let body = try IEIndexedSprite.load(character: VossAnimationSet.character)
        let helmet = try IEIndexedSprite.load(character: VossArmorAppearance.ironHelmet.character)
        var checked = 0
        for frame in body.frames {
            guard let name = VossArmorAppearance.ironHelmet.frameName(matching: frame.id, wearingMail: false) else { continue }
            #expect(name == "unarmored_" + frame.id.name)
            let independent = try #require(helmet.frame(atlas: VossArmorAppearance.ironHelmet.atlas, name: name))
            #expect(!independent.isEmpty)
            #expect(Double(independent.trimOriginTopLeft.width) + independent.pivotFromCropBottomLeft.x == 64)
            #expect(Double(128-independent.trimOriginTopLeft.height-independent.size.height) + independent.pivotFromCropBottomLeft.y == 46)
            checked += 1
        }
        #expect(checked == 1200)
        #expect(VossArmorAppearance.ironHelmet.paperdollArt(wearingMail: false) == "voss_paperdoll_iron_helmet_unarmored")
        #expect(VossArmorAppearance.splintMail.paperdollArt(wearingMail: false) == "voss_paperdoll_splint_mail")
    }

    @Test func armorGrantIsAdditiveAndOneTime() throws {
        #expect(HarborpointItems.armorKitGrant(hasReceived: false, existingIDs: ["lantern-shortsword"]) == ["iron-helmet", "splint-mail"])
        #expect(HarborpointItems.armorKitGrant(hasReceived: false, existingIDs: ["iron-helmet"]) == ["splint-mail"])
        #expect(HarborpointItems.armorKitGrant(hasReceived: true, existingIDs: []) == [])
        #expect(HarborpointItems.armorKitGrant(hasReceived: false, existingIDs: [], availableSlots: 0) == [])
        #expect(HarborpointItems.armorKitGrant(hasReceived: false, existingIDs: [], availableSlots: 1) == ["iron-helmet"])
        let old = try JSONDecoder().decode(SaveSnapshot.self, from: Data(#"{"schemaVersion":1,"hasSeededStarterKit":true}"#.utf8))
        #expect(!old.hasReceivedArmorKit)
        var save = old
        save.hasReceivedArmorKit = true
        save.equippedItems = ["fedora": .init(id: "iron-helmet", quantity: 1), "coat": .init(id: "splint-mail", quantity: 1)]
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(save))
        #expect(restored == save)
    }
}

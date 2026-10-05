import Foundation
import Testing
@testable import RainShadowCore

struct VossWeaponAppearanceTests {
    @Test func carryingIsNotEquippingAndRemovingClearsTheAppearance() throws {
        let catalog = HarborpointItems.catalog
        let sword = CarriedItemStack(id: "lantern-shortsword", quantity: 1)
        let bag = CharacterInventory(backpack: CarriedInventoryState(stacks: [sword]))
        #expect(VossWeaponAppearance.equipped(in: bag, catalog: catalog) == nil)
        let equipped = CharacterInventory(equipped: [.weapon1: sword])
        #expect(VossWeaponAppearance.equipped(in: equipped, catalog: catalog) == .lanternShortsword)
        #expect(VossWeaponAppearance.equipped(in: CharacterInventory(), catalog: catalog) == nil)
        #expect(catalog.definition(for: sword.id)?.iconArtName == "inventory_item_lantern_shortsword_v01")
    }

    @Test func everyStandingFrameHasASynchronizedIndependentlyRegisteredWeapon() throws {
        let appearance = VossWeaponAppearance.lanternShortsword
        let weapon = try IEIndexedSprite.load(character: appearance.character)
        let body = try IEIndexedSprite.load(character: VossAnimationSet.character)
        try appearance.validate(weapon)
        #expect(weapon.displayUnitsPerSourcePixel == body.displayUnitsPerSourcePixel)
        #expect(!weapon.hasEmbeddedShadow)
        var count = 0
        for frame in body.frames {
            guard let name = appearance.frameName(matching: frame.id) else { continue }
            let overlay = try #require(weapon.frame(atlas: appearance.atlas, name: name))
            count += 1
            if !overlay.isEmpty {
                // Both crops resolve back to the same root: (64,46) y-up.
                #expect(Double(overlay.trimOriginTopLeft.width) + overlay.pivotFromCropBottomLeft.x == 64)
                #expect(Double(128-overlay.trimOriginTopLeft.height-overlay.size.height) + overlay.pivotFromCropBottomLeft.y == 46)
                #expect(overlay.indices.allSatisfy { $0 == 0 || (4..<40).contains(Int($0)) })
            }
        }
        #expect(count == 1200)
        #expect(appearance.frameName(matching: .init(atlas: VossAnimationSet.atlas, name: "seated_idle_sw_00.png")) == nil)
        #expect(appearance.frameName(matching: .init(atlas: "Voss.atlas", name: "idle_s_00.png")) == nil)
    }

    @Test func weaponUsesTheSameIdleHoldsAsItsBody() throws {
        let appearance = VossWeaponAppearance.lanternShortsword
        let sprite = try IEIndexedSprite.load(character: appearance.character)
        for direction in VossAnimationSet.directions {
            let first = try #require(sprite.frame(atlas: appearance.atlas, name: "idle_\(direction)_00.png"))
            for phase in [1,26,27,28,29,30,31,32,33,58,59,60,61,62,63,64] {
                let frame = try #require(sprite.frame(atlas: appearance.atlas, name: String(format: "idle_%@_%02d.png", direction, phase)))
                #expect(frame.indices == first.indices)
                #expect(frame.trimOriginTopLeft == first.trimOriginTopLeft)
            }
        }
    }
}

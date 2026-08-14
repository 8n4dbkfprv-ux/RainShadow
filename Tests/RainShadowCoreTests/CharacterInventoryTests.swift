import Foundation
import Testing
@testable import RainShadowCore

struct CharacterInventoryTests {

    // MARK: - Fixture

    /// A catalog with the wardrobe the shipped content does not have art for yet,
    /// so the rules can be tested ahead of the apparel art batch.
    private static let catalog: ItemCatalog = {
        let items: [ItemDefinition] = [
            ItemDefinition(
                id: "revolver", identifiedName: "Revolver", category: .weapon,
                weightOunces: 38, iconArtName: "x",
                identifiedDescription: "d", damageLow: 2, damageHigh: 7
            ),
            ItemDefinition(
                id: "shotgun", identifiedName: "Shotgun", category: .weapon,
                weightOunces: 112, iconArtName: "x",
                identifiedDescription: "d", flags: [.twoHanded]
            ),
            ItemDefinition(
                id: "trench-coat", identifiedName: "Trench Coat", category: .outerwear,
                weightOunces: 64, iconArtName: "x",
                identifiedDescription: "d", defenceBonus: 2
            ),
            ItemDefinition(
                id: "fedora", identifiedName: "Fedora", category: .headwear,
                weightOunces: 8, iconArtName: "x",
                identifiedDescription: "d", defenceBonus: 1
            ),
            ItemDefinition(
                id: "cursed-ring", identifiedName: "Cursed Ring", category: .ring,
                weightOunces: 1, iconArtName: "x",
                identifiedDescription: "d", flags: [.cursed], defenceBonus: 1
            ),
            ItemDefinition(
                id: "case-notes", identifiedName: "Case Notebook", category: .evidence,
                weightOunces: 8, iconArtName: "x",
                identifiedDescription: "d", flags: [.undroppable]
            ),
            ItemDefinition(
                id: "cartridges", identifiedName: "Cartridges", category: .ammunition,
                weightOunces: 1, maxStack: 40, iconArtName: "x",
                identifiedDescription: "d"
            ),
            ItemDefinition(
                id: "matchbook", identifiedName: "Matchbook",
                unidentifiedName: "Paper Matchbook", category: .evidence,
                weightOunces: 1, maxStack: 10, loreToIdentify: 4, iconArtName: "x",
                identifiedDescription: "known", unidentifiedDescription: "unknown"
            ),
            ItemDefinition(
                id: "lead-brick", identifiedName: "Lead Brick", category: .personal,
                weightOunces: 320, iconArtName: "x", identifiedDescription: "d"
            )
        ]
        return try! ItemCatalogLoader.validate(ItemCatalogDocument(id: "test", items: items))
    }()

    private static var limits: ItemStackLimits { ItemStackLimits(catalog: catalog) }

    private static func stack(_ id: String, _ quantity: Int = 1) -> CarriedItemStack {
        CarriedItemStack(id: id, quantity: quantity)
    }

    private static func inventory(bag: [CarriedItemStack] = []) -> CharacterInventory {
        CharacterInventory(backpack: CarriedInventoryState(stacks: bag))
    }

    // MARK: - Slot gating

    @Test func categoryDecidesTheSlot() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("trench-coat"), in: .coat, catalog: Self.catalog)
        #expect(inv.item(in: .coat)?.id == "trench-coat")

        #expect(throws: InventoryRefusal.wrongSlot(
            itemID: "trench-coat", category: .outerwear, slot: .fedora
        )) {
            var other = Self.inventory()
            try other.equip(Self.stack("trench-coat"), in: .fedora, catalog: Self.catalog)
        }
    }

    @Test func ammunitionGoesOnlyInTheQuivers() {
        var inv = Self.inventory()
        #expect(inv.canEquip(Self.stack("cartridges", 20), in: .quiver1, catalog: Self.catalog))
        #expect(!inv.canEquip(Self.stack("cartridges", 20), in: .quickItem1, catalog: Self.catalog))
        #expect(!inv.canEquip(Self.stack("cartridges", 20), in: .coat, catalog: Self.catalog))
    }

    @Test func evidenceIsCarriedNeverWorn() {
        let inv = Self.inventory()
        for slot in EquipmentSlot.allCases {
            #expect(
                !inv.canEquip(Self.stack("case-notes"), in: slot, catalog: Self.catalog),
                "evidence should not fit \(slot.rawValue)"
            )
        }
    }

    // MARK: - Two-handed exclusion

    @Test func twoHandedWeaponBlocksTheOffHand() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("shotgun"), in: .weapon1, catalog: Self.catalog)
        #expect(inv.twoHandedWeaponSlot(catalog: Self.catalog) == .weapon1)

        #expect(throws: InventoryRefusal.offHandBlockedByTwoHandedWeapon(blockedBy: .weapon1)) {
            var copy = inv
            try copy.equip(Self.stack("revolver"), in: .holster, catalog: Self.catalog)
        }
    }

    @Test func anOccupiedOffHandRefusesATwoHander() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("revolver"), in: .holster, catalog: Self.catalog)

        #expect(throws: InventoryRefusal.twoHandedBlockedByOffHand(occupied: .holster)) {
            var copy = inv
            try copy.equip(Self.stack("shotgun"), in: .weapon1, catalog: Self.catalog)
        }
        // A one-handed weapon in the same slot is fine.
        try inv.equip(Self.stack("revolver"), in: .weapon1, catalog: Self.catalog)
        #expect(inv.item(in: .weapon1)?.id == "revolver")
    }

    @Test func theBlockHoldsFromAnyReadySlotNotJustTheFirst() throws {
        // BG:EE blocks the off-hand for a two-hander anywhere in the quick-weapon
        // bar, readied or not.
        var inv = Self.inventory()
        try inv.equip(Self.stack("shotgun"), in: .weapon3, catalog: Self.catalog)
        #expect(!inv.canEquip(Self.stack("revolver"), in: .holster, catalog: Self.catalog))
    }

    // MARK: - Cursed

    @Test func cursedItemsWillNotComeOff() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("cursed-ring"), in: .ringLeft, catalog: Self.catalog)

        #expect(throws: InventoryRefusal.cursedInPlace(slot: .ringLeft)) {
            var copy = inv
            _ = try copy.unequip(from: .ringLeft, catalog: Self.catalog)
        }
        // Nor can they be displaced by equipping over them.
        #expect(throws: InventoryRefusal.cursedInPlace(slot: .ringLeft)) {
            var copy = inv
            try copy.equip(Self.stack("cursed-ring"), in: .ringLeft, catalog: Self.catalog)
        }
        // The other hand is unaffected.
        #expect(inv.canEquip(Self.stack("cursed-ring"), in: .ringRight, catalog: Self.catalog))
    }

    @Test func unequippingAnEmptySlotIsRefused() {
        var inv = Self.inventory()
        #expect(throws: InventoryRefusal.slotEmpty(slot: .belt)) {
            _ = try inv.unequip(from: .belt, catalog: Self.catalog)
        }
    }

    // MARK: - Equipping across the bag boundary

    @Test func equippingFromTheBagFreesItsSlot() throws {
        var inv = Self.inventory(bag: [Self.stack("trench-coat")])
        #expect(inv.backpack.stacks.count == 1)

        try inv.equipFromBackpack(
            at: 0, to: .coat, catalog: Self.catalog, limits: Self.limits
        )
        #expect(inv.backpack.stacks.isEmpty)
        #expect(inv.item(in: .coat)?.id == "trench-coat")
    }

    @Test func equippingOverAWornItemReturnsItToTheBag() throws {
        var inv = Self.inventory(bag: [Self.stack("fedora")])
        try inv.equip(Self.stack("fedora"), in: .fedora, catalog: Self.catalog)

        try inv.equipFromBackpack(
            at: 0, to: .fedora, catalog: Self.catalog, limits: Self.limits
        )
        #expect(inv.item(in: .fedora)?.id == "fedora")
        #expect(inv.backpack.stacks.count == 1, "the displaced hat should land in the bag")
    }

    @Test func aRefusedEquipLeavesBothSidesUntouched() throws {
        var inv = Self.inventory(bag: [Self.stack("trench-coat")])
        let before = inv

        #expect(throws: (any Error).self) {
            try inv.equipFromBackpack(
                at: 0, to: .fedora, catalog: Self.catalog, limits: Self.limits
            )
        }
        #expect(inv == before, "a refused equip must not move anything")
    }

    @Test func unequippingIntoAFullBagIsRefusedRatherThanDroppingTheItem() throws {
        let filler = (0..<16).map { CarriedItemStack(id: "lead-brick", quantity: 1, charges: $0) }
        var inv = CharacterInventory(backpack: CarriedInventoryState(stacks: filler))
        try inv.equip(Self.stack("trench-coat"), in: .coat, catalog: Self.catalog)
        let before = inv

        #expect(throws: InventoryRefusal.bagFull) {
            try inv.unequipToBackpack(from: .coat, catalog: Self.catalog, limits: Self.limits)
        }
        #expect(inv == before)
        #expect(inv.item(in: .coat) != nil, "the coat stays on rather than vanishing")
    }

    // MARK: - Moving between equipped slots

    @Test func aReadiedWeaponCanChangeSlots() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("revolver"), in: .weapon1, catalog: Self.catalog)
        try inv.moveEquipped(from: .weapon1, to: .weapon3, catalog: Self.catalog)
        #expect(inv.item(in: .weapon1) == nil)
        #expect(inv.item(in: .weapon3)?.id == "revolver")
    }

    @Test func movingOntoAnOccupiedSlotSwapsBothWays() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("revolver"), in: .weapon1, catalog: Self.catalog)
        try inv.equip(Self.stack("shotgun"), in: .weapon2, catalog: Self.catalog)

        try inv.moveEquipped(from: .weapon1, to: .weapon2, catalog: Self.catalog)
        #expect(inv.item(in: .weapon2)?.id == "revolver")
        #expect(inv.item(in: .weapon1)?.id == "shotgun")
    }

    @Test func aTwoHanderCanMoveWithinItsOwnBank() throws {
        // The destination must be tested against the inventory as it will be once
        // the source is empty, or a two-hander would refuse to move because of
        // itself.
        var inv = Self.inventory()
        try inv.equip(Self.stack("shotgun"), in: .weapon1, catalog: Self.catalog)
        try inv.moveEquipped(from: .weapon1, to: .weapon2, catalog: Self.catalog)
        #expect(inv.item(in: .weapon2)?.id == "shotgun")
    }

    @Test func aMoveToTheWrongKindOfSlotIsRefused() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("revolver"), in: .weapon1, catalog: Self.catalog)
        let before = inv
        #expect(throws: (any Error).self) {
            try inv.moveEquipped(from: .weapon1, to: .fedora, catalog: Self.catalog)
        }
        #expect(inv == before)
    }

    @Test func aCursedItemWillNotMoveEither() throws {
        var inv = Self.inventory()
        try inv.equip(Self.stack("cursed-ring"), in: .ringLeft, catalog: Self.catalog)
        #expect(throws: InventoryRefusal.cursedInPlace(slot: .ringLeft)) {
            try inv.moveEquipped(from: .ringLeft, to: .ringRight, catalog: Self.catalog)
        }
    }

    // MARK: - Reordering the bag

    @Test func reorderingTheBagMovesOneStack() {
        var bag = CarriedInventoryState(stacks: [
            Self.stack("revolver"), Self.stack("trench-coat"), Self.stack("fedora")
        ])
        let moved = bag.move(from: 0, to: 2)
        #expect(moved)
        #expect(bag.stacks.map(\.id) == ["trench-coat", "fedora", "revolver"])
    }

    @Test func reorderingRefusesTheNoOpAndTheMissingIndex() {
        var bag = CarriedInventoryState(stacks: [Self.stack("revolver")])
        let sameSlot = bag.move(from: 0, to: 0)
        let missing = bag.move(from: 4, to: 0)
        #expect(!sameSlot)
        #expect(!missing)
        #expect(bag.stacks.count == 1)
    }

    // MARK: - Dropping

    @Test func undroppableItemsRefuseToLeaveTheBag() {
        var inv = Self.inventory(bag: [Self.stack("case-notes")])
        #expect(throws: InventoryRefusal.undroppable(itemID: "case-notes")) {
            _ = try inv.removeFromBackpack(at: 0, catalog: Self.catalog)
        }
        #expect(inv.backpack.stacks.count == 1)
    }

    @Test func ordinaryItemsLeaveTheBagFreely() throws {
        var inv = Self.inventory(bag: [Self.stack("revolver")])
        let taken = try inv.removeFromBackpack(at: 0, catalog: Self.catalog)
        #expect(taken.id == "revolver")
        #expect(inv.backpack.stacks.isEmpty)
    }

    // MARK: - Stacking

    @Test func matchingStacksTopUpBeforeTakingAFreshSlot() {
        var bag = CarriedInventoryState(stacks: [Self.stack("cartridges", 30)])
        let merged = bag.append(Self.stack("cartridges", 5), limits: Self.limits)
        #expect(merged)
        #expect(bag.stacks.count == 1)
        #expect(bag.stacks[0].quantity == 35)
    }

    @Test func stacksSpillIntoANewSlotAtTheCeiling() {
        var bag = CarriedInventoryState(stacks: [Self.stack("cartridges", 30)])
        let spilled = bag.append(Self.stack("cartridges", 20), limits: Self.limits)
        #expect(spilled)
        #expect(bag.stacks.count == 2)
        #expect(bag.stacks[0].quantity == 40, "the first stack fills to its ceiling")
        #expect(bag.stacks[1].quantity == 10)
    }

    @Test func nonStackingIsTheDefaultSoOldCallersDoNotSilentlyMerge() {
        var bag = CarriedInventoryState(stacks: [Self.stack("cartridges", 30)])
        let appended = bag.append(Self.stack("cartridges", 5))
        #expect(appended)
        #expect(bag.stacks.count == 2, "without limits nothing merges")
    }

    @Test func identifiedAndUnidentifiedStacksDoNotMerge() {
        let known = CarriedItemStack(id: "matchbook", quantity: 2, isIdentified: true)
        let unknown = CarriedItemStack(id: "matchbook", quantity: 2, isIdentified: false)
        #expect(!known.canMerge(with: unknown))

        var bag = CarriedInventoryState(stacks: [known])
        let appended = bag.append(unknown, limits: Self.limits)
        #expect(appended)
        #expect(bag.stacks.count == 2, "they draw differently, so they stay apart")
    }

    @Test func chargedItemsNeverMerge() {
        let a = CarriedItemStack(id: "cartridges", quantity: 1, charges: 3)
        let b = CarriedItemStack(id: "cartridges", quantity: 1, charges: 5)
        #expect(!a.canMerge(with: b))
    }

    @Test func aBatchThatCannotFitLeavesTheBagExactlyAsItWas() {
        let filler = (0..<15).map { CarriedItemStack(id: "revolver", quantity: 1, charges: $0) }
        var bag = CarriedInventoryState(stacks: filler)
        let before = bag
        // Two unmergeable stacks into one free slot: all-or-nothing must refuse.
        let batch = [
            CarriedItemStack(id: "revolver", quantity: 1, charges: 90),
            CarriedItemStack(id: "revolver", quantity: 1, charges: 91)
        ]
        let accepted = bag.append(contentsOf: batch, limits: Self.limits)
        #expect(!accepted)
        #expect(bag == before)
    }

    // MARK: - Splitting

    @Test func splittingDividesOneStackIntoTwoAdjacentSlots() {
        var bag = CarriedInventoryState(stacks: [Self.stack("cartridges", 30)])
        let didSplit = bag.split(at: 0, count: 12)
        #expect(didSplit)
        #expect(bag.stacks.count == 2)
        #expect(bag.stacks[0].quantity == 18)
        #expect(bag.stacks[1].quantity == 12)
    }

    @Test func splittingRefusesTheDegenerateCases() {
        var bag = CarriedInventoryState(stacks: [Self.stack("cartridges", 30)])
        let zero = bag.split(at: 0, count: 0)
        let whole = bag.split(at: 0, count: 30)
        let overflow = bag.split(at: 0, count: 31)
        let missing = bag.split(at: 4, count: 1)
        #expect(!zero, "a zero split is a no-op, not a split")
        #expect(!whole, "splitting the whole stack moves nothing")
        #expect(!overflow)
        #expect(!missing)
        #expect(bag.stacks.count == 1)
    }

    @Test func splittingNeedsAFreeSlot() {
        var stacks = [Self.stack("cartridges", 30)]
        stacks += (0..<15).map { CarriedItemStack(id: "revolver", quantity: 1, charges: $0) }
        var bag = CarriedInventoryState(stacks: stacks)
        #expect(bag.availableSlotCount == 0)
        let didSplit = bag.split(at: 0, count: 10)
        #expect(!didSplit)
    }

    // MARK: - Identification

    @Test func loreIdentifiesWhatItCovers() throws {
        var inv = Self.inventory(bag: [
            CarriedItemStack(id: "matchbook", quantity: 1, isIdentified: false)
        ])
        // Below the threshold nothing happens.
        let tooLittleLore = try inv.identifyBackpackStack(at: 0, lore: 3, catalog: Self.catalog)
        #expect(!tooLittleLore)
        #expect(inv.backpack.stacks[0].isIdentified == false)

        let recognised = try inv.identifyBackpackStack(at: 0, lore: 4, catalog: Self.catalog)
        #expect(recognised)
        #expect(inv.backpack.stacks[0].isIdentified)

        // A second attempt reports no change rather than churning the save.
        let again = try inv.identifyBackpackStack(at: 0, lore: 9, catalog: Self.catalog)
        #expect(!again)
    }

    @Test func theSweepIdentifiesEveryStackLoreCovers() {
        var inv = Self.inventory(bag: [
            CarriedItemStack(id: "matchbook", quantity: 1, isIdentified: false),
            CarriedItemStack(id: "matchbook", quantity: 2, isIdentified: false),
            CarriedItemStack(id: "revolver", quantity: 1, isIdentified: true)
        ])
        let identified = inv.identifyEverythingKnown(lore: 4, catalog: Self.catalog)
        #expect(identified == 2)
        #expect(inv.backpack.stacks.allSatisfy { $0.isIdentified })
    }

    // MARK: - Weight and encumbrance

    @Test func weightCountsWhatIsWornAndWhatIsCarried() throws {
        var inv = Self.inventory(bag: [Self.stack("cartridges", 10)])
        try inv.equip(Self.stack("trench-coat"), in: .coat, catalog: Self.catalog)
        // 64 oz coat + 10 × 1 oz cartridges.
        #expect(inv.carriedWeightOunces(catalog: Self.catalog) == 74)
    }

    @Test func encumbranceBandsFollowTheAdventurersGuide() {
        let allowance = CarryAllowance(pounds: 55) // 880 oz
        // At the limit exactly: still free.
        #expect(EncumbranceRules.band(carriedOunces: 880, allowance: allowance) == .unencumbered)
        // Over the limit: halved.
        #expect(EncumbranceRules.band(carriedOunces: 881, allowance: allowance) == .overloaded)
        // At 110% exactly: still only halved.
        #expect(EncumbranceRules.band(carriedOunces: 968, allowance: allowance) == .overloaded)
        // Past 110%: stopped.
        #expect(EncumbranceRules.band(carriedOunces: 969, allowance: allowance) == .immobile)
    }

    @Test func encumbranceReachesTheMovementProfile() {
        let allowance = CarryAllowance(pounds: 55)
        let free = EncumbranceRules.profile(carriedOunces: 100, allowance: allowance)
        let heavy = EncumbranceRules.profile(carriedOunces: 900, allowance: allowance)
        let stuck = EncumbranceRules.profile(carriedOunces: 2_000, allowance: allowance)

        #expect(free.walkSpeed > 0)
        // BG divides the movement *rate* by the encumbrance factor, so overloaded
        // is exactly half speed.
        #expect(abs(heavy.walkSpeed - free.walkSpeed / 2) < 0.001)
        #expect(stuck.isImmobile)
        #expect(stuck.walkSpeed == 0)
    }

    @Test func theWarningBandCarriesNoPenalty() {
        let allowance = CarryAllowance(pounds: 55)
        // 90% of 880 = 792: amber, but the engine applies nothing.
        let readout = EncumbranceReadout(carriedOunces: 800, allowance: allowance)
        #expect(readout.isWarning)
        #expect(readout.band == .unencumbered)
    }

    @Test func aZeroAllowanceDoesNotFreezeAnEmptyBag() {
        let readout = EncumbranceReadout(carriedOunces: 0, allowance: CarryAllowance(ounces: 0))
        #expect(readout.band == .unencumbered)
        #expect(!readout.isWarning)
    }

    @Test func theReadoutSpellsWeightInPounds() {
        let readout = EncumbranceReadout(
            carriedOunces: 74, allowance: CarryAllowance(pounds: 55)
        )
        #expect(readout.formatted == "4.6 / 55 lb")
    }

    // MARK: - Derived statistics

    @Test func defenceCountsWornGearOnly() throws {
        var inv = Self.inventory(bag: [Self.stack("fedora")])
        #expect(inv.defenceBonus(catalog: Self.catalog) == 0, "a hat in the bag protects nobody")

        try inv.equip(Self.stack("trench-coat"), in: .coat, catalog: Self.catalog)
        try inv.equip(Self.stack("fedora"), in: .fedora, catalog: Self.catalog)
        #expect(inv.defenceBonus(catalog: Self.catalog) == 3)
    }

    @Test func theReadiedWeaponIsTheFirstOccupiedReadySlot() throws {
        var inv = Self.inventory()
        #expect(inv.readiedWeapon(catalog: Self.catalog) == nil)

        try inv.equip(Self.stack("revolver"), in: .weapon2, catalog: Self.catalog)
        #expect(inv.readiedWeapon(catalog: Self.catalog)?.id == "revolver")
        #expect(inv.readiedWeapon(catalog: Self.catalog)?.damageBand == "2–7")
    }
}

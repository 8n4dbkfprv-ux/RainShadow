import Foundation
import Testing
@testable import RainShadowCore

struct ItemCatalogTests {

    // MARK: - Shipped catalog

    @Test func shippedCatalogLoadsEveryAuthoredItem() throws {
        let catalog = try ItemCatalogLoader.load()
        #expect(!catalog.isEmpty)
        for id in HarborpointItems.starterItemIDs {
            #expect(catalog.definition(for: id) != nil, "starter item '\(id)' is not authored")
        }
        #expect(catalog.definition(for: "blue-room-token") != nil)
        // Renamed starter items: the old ids must not linger in the catalog.
        #expect(catalog.definition(for: "service-revolver") == nil)
        #expect(catalog.definition(for: "flashlight") == nil)
        #expect(catalog.definition(for: "wallet") == nil)
        #expect(catalog.definition(for: "cigarette-case") == nil)
        #expect(catalog.definition(for: "matchbook") == nil)
        let token = try catalog.require("blue-room-token")
        #expect(token.unidentifiedName == "Stamped Brass Token")
        #expect(token.iconArtName == "inventory_item_matchbook_v01")
        #expect(HarborpointItems.starterItemIDs == ["lantern-shortsword", "iron-helmet", "splint-mail"])
        for id in ["dark-lantern", "coin-purse", "tobacco-tin"] {
            #expect(catalog.definition(for: id) == nil)
        }
    }

    @Test func shippedCatalogPreservesAuthoredPresentation() throws {
        let sword = try ItemCatalogLoader.load().require("lantern-shortsword")
        #expect(sword.identifiedName == "Lantern Service Shortsword")
        #expect(sword.category == .weapon)
        #expect(sword.iconArtName == "inventory_item_lantern_shortsword_v01")
        #expect(sword.note == "Lantern Guard issue · never handed back")
        #expect(sword.identifiedDescription.hasPrefix("The blade Voss kept from his Lantern years."))
        #expect(!sword.flags.contains(.twoHanded))
        #expect(sword.damageLow == 2 && sword.damageHigh == 7)
    }

    @Test func caseCriticalItemsAreFlagged() throws {
        let catalog = try ItemCatalogLoader.load()
        let notes = try catalog.require("case-notes")
        #expect(notes.flags.contains(.questCritical))
        #expect(notes.flags.contains(.undroppable))
        // The brass key is the case's central physical object; it may move, but
        // it must never be destroyed or sold.
        let key = try catalog.require("brass-key")
        #expect(key.flags.contains(.questCritical))
        #expect(!key.flags.contains(.undroppable))
    }

    @Test func cachedLoadReturnsTheSameCatalog() throws {
        let first = try ItemCatalogLoader.loadCached()
        let second = try ItemCatalogLoader.loadCached()
        #expect(first == second)
    }

    // MARK: - Slot gating

    @Test func categoriesResolveToTheEnginesSlots() throws {
        let catalog = try ItemCatalogLoader.load()

        // A weapon reaches the four ready slots and the off-hand, as in BG.
        let sword = try catalog.require("lantern-shortsword")
        #expect(Set(sword.equippableSlots) == Set(EquipmentSlot.weaponSlots + [.holster]))

        // Field tools and personal effects are quick-slot items.
        let lantern = ItemDefinition(id: "test-lantern", identifiedName: "Lantern",
            category: .tool, weightOunces: 16, iconArtName: "test", identifiedDescription: "A field tool.")
        #expect(Set(lantern.equippableSlots) == Set(EquipmentSlot.quickItemSlots))

        // Evidence is carried, never worn or readied.
        let key = try catalog.require("brass-key")
        #expect(key.equippableSlots.isEmpty)
        #expect(!key.isEquippable)
    }

    @Test func slotIndicesMatchTheCreatureFormat() {
        // cre_v1.htm: 0 helmet, 1 armor, 2 shield, 3 gloves, 4/5 rings, 6 amulet,
        // 7 belt, 8 boots, 9–12 weapons, 13–16 quivers, 17 cloak, 18–20 quick items.
        #expect(EquipmentSlot.fedora.bgSlotIndex == 0)
        #expect(EquipmentSlot.coat.bgSlotIndex == 1)
        #expect(EquipmentSlot.holster.bgSlotIndex == 2)
        #expect(EquipmentSlot.gloves.bgSlotIndex == 3)
        #expect(EquipmentSlot.ringLeft.bgSlotIndex == 4)
        #expect(EquipmentSlot.ringRight.bgSlotIndex == 5)
        #expect(EquipmentSlot.charm.bgSlotIndex == 6)
        #expect(EquipmentSlot.belt.bgSlotIndex == 7)
        #expect(EquipmentSlot.shoes.bgSlotIndex == 8)
        #expect(EquipmentSlot.weapon1.bgSlotIndex == 9)
        #expect(EquipmentSlot.quiver1.bgSlotIndex == 13)
        #expect(EquipmentSlot.cloak.bgSlotIndex == 17)
        #expect(EquipmentSlot.quickItem1.bgSlotIndex == 18)

        // Every shipped slot index is distinct — a collision would silently
        // overwrite one slot with another on any index-keyed round trip.
        let indices = EquipmentSlot.allCases.map(\.bgSlotIndex)
        #expect(Set(indices).count == indices.count)
    }

    @Test func paperdollSlotsMatchThePaintedNodeNames() {
        // InventoryOverlay builds these node names; a rename here silently
        // detaches the model from the art.
        #expect(EquipmentSlot.coat.nodeName == "inventory.equip.coat")
        #expect(EquipmentSlot.ringLeft.nodeName == "inventory.equip.ringLeft")
        #expect(EquipmentSlot.paperdollSlots.count == 10)
        #expect(EquipmentSlot.paperdollSlots.allSatisfy { $0.isWorn })
        #expect(EquipmentSlot.weaponSlots.allSatisfy { !$0.isWorn })
    }

    // MARK: - Identification

    @Test func attackTypeDefaultsForLegacyCatalogsAndRoundTrips() throws {
        let legacy = Data(#"{"id":"sword","identifiedName":"Sword","category":"SERVICE WEAPON","iconArtName":"x","identifiedDescription":"d"}"#.utf8)
        let sword = try JSONDecoder().decode(ItemDefinition.self, from: legacy)
        #expect(sword.weaponAttackType == .melee)
        #expect(sword.equippableSlots.contains(.holster))

        let ranged = Data(#"{"id":"sling","identifiedName":"Sling","category":"SERVICE WEAPON","weaponAttackType":"ranged","iconArtName":"x","identifiedDescription":"d"}"#.utf8)
        let sling = try JSONDecoder().decode(ItemDefinition.self, from: ranged)
        #expect(sling.weaponAttackType == .ranged)
        #expect(sling.equippableSlots == EquipmentSlot.weaponSlots)
        let restored = try JSONDecoder().decode(ItemDefinition.self, from: JSONEncoder().encode(sling))
        #expect(restored == sling)
    }

    @Test func offHandEligibilityUsesHandednessAndAttackType() {
        let greatsword = ItemDefinition(id: "greatsword", identifiedName: "Greatsword",
            category: .weapon, weightOunces: 112, iconArtName: "x",
            identifiedDescription: "d", flags: [.twoHanded])
        #expect(greatsword.equippableSlots == EquipmentSlot.weaponSlots)
        let shield = ItemDefinition(id: "shield", identifiedName: "Shield",
            category: .shield, weightOunces: 64, iconArtName: "x", identifiedDescription: "d")
        #expect(shield.equippableSlots == [.holster])
    }

    @Test func unidentifiedItemsShowTheirUnknownFace() throws {
        let token = try ItemCatalogLoader.load().require("blue-room-token")
        #expect(token.loreToIdentify == 4)
        #expect(!token.isSelfEvident)
        #expect(token.displayName(identified: false) == "Stamped Brass Token")
        #expect(token.displayName(identified: true) == "Blue Room Token")
        #expect(
            token.displayDescription(identified: false)
                != token.displayDescription(identified: true)
        )
    }

    @Test func selfEvidentItemsReadTheSameEitherWay() throws {
        let lantern = try ItemCatalogLoader.load().require("brass-key")
        #expect(lantern.isSelfEvident)
        #expect(lantern.displayName(identified: false) == lantern.displayName(identified: true))
        #expect(
            lantern.displayDescription(identified: false)
                == lantern.displayDescription(identified: true)
        )
    }

    // MARK: - Loader errors

    @Test func unsupportedSchemaVersionIsRejected() throws {
        let data = Data(#"{"schemaVersion": 99, "id": "x", "items": []}"#.utf8)
        #expect(throws: ItemCatalogError.unsupportedSchemaVersion(found: 99, supported: 1)) {
            try ItemCatalogLoader.decode(data)
        }
    }

    @Test func emptyCatalogIsRejected() throws {
        let data = Data(#"{"schemaVersion": 1, "id": "empty", "items": []}"#.utf8)
        #expect(throws: ItemCatalogError.emptyCatalog(name: "empty")) {
            try ItemCatalogLoader.decode(data)
        }
    }

    @Test func duplicateItemIDIsRejected() throws {
        let document = ItemCatalogDocument(
            id: "dupes",
            items: [Self.sample(id: "twice"), Self.sample(id: "twice")]
        )
        #expect(throws: ItemCatalogError.duplicateItemID(catalog: "dupes", itemID: "twice")) {
            try ItemCatalogLoader.validate(document)
        }
    }

    @Test func unknownItemLookupThrowsRatherThanInventingAnItem() throws {
        // The catalog this replaced title-cased unknown ids into a plausible-looking
        // item, so a typo shipped as content. It must fail instead.
        let catalog = try ItemCatalogLoader.load()
        #expect(catalog.definition(for: "no-such-item") == nil)
        #expect(throws: ItemCatalogError.unknownItem(id: "no-such-item")) {
            try catalog.require("no-such-item")
        }
    }

    @Test func unknownFlagNameIsRejected() throws {
        let data = Data(#"["cursed", "sparkly"]"#.utf8)
        #expect(throws: ItemCatalogError.unknownItemFlag(name: "sparkly")) {
            try JSONDecoder().decode(ItemFlags.self, from: data)
        }
    }

    @Test func wornGearMayNotStack() throws {
        let document = ItemCatalogDocument(
            id: "bad",
            items: [
                ItemDefinition(
                    id: "spare-coats",
                    identifiedName: "Spare Coats",
                    category: .outerwear,
                    weightOunces: 40,
                    maxStack: 4,
                    iconArtName: "x",
                    identifiedDescription: "Four coats worn at once."
                )
            ]
        )
        #expect(throws: ItemCatalogError.stackableWornItem(itemID: "spare-coats")) {
            try ItemCatalogLoader.validate(document)
        }
    }

    @Test func ammunitionMayStack() throws {
        let document = ItemCatalogDocument(
            id: "ok",
            items: [
                ItemDefinition(
                    id: "bolts",
                    identifiedName: "Crossbow Bolts",
                    category: .ammunition,
                    weightOunces: 1,
                    maxStack: 40,
                    iconArtName: "x",
                    identifiedDescription: "Short iron-tipped quarrels."
                )
            ]
        )
        let catalog = try ItemCatalogLoader.validate(document)
        let bolts = try catalog.require("bolts")
        #expect(bolts.stacks)
        #expect(Set(bolts.equippableSlots) == Set(EquipmentSlot.quiverSlots))
    }

    // MARK: - Round trip

    @Test func flagsSurviveAJSONRoundTrip() throws {
        let flags: ItemFlags = [.cursed, .questCritical]
        let data = try JSONEncoder().encode(flags)
        #expect(try JSONDecoder().decode(ItemFlags.self, from: data) == flags)
        #expect(Set(flags.names) == ["cursed", "questCritical"])
    }

    @Test func definitionsSurviveAJSONRoundTrip() throws {
        let original = try ItemCatalogLoader.load().require("blue-room-token")
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(ItemDefinition.self, from: data) == original)
    }

    // MARK: - Helpers

    private static func sample(id: String) -> ItemDefinition {
        ItemDefinition(
            id: id,
            identifiedName: id,
            category: .evidence,
            weightOunces: 1,
            iconArtName: "x",
            identifiedDescription: "sample"
        )
    }
}

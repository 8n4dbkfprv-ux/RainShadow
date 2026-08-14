import Foundation
import Testing
@testable import RainShadowCore

/// Item identity in the inventory window.
///
/// These used to be source-text assertions against `InventoryOverlay.swift` —
/// `#expect(source.contains("let authoredID: String"))` and friends, pinned down
/// to a specific indentation — because the window lives outside the SwiftPM
/// target and could not be reached any other way. They failed on a reformat and
/// passed on a behavioural regression, which is the wrong way round.
///
/// The identity rules now live in `InventoryItemPresentation` in RainShadowCore,
/// so they are tested for what they do.
struct InventoryOverlayIdentityTests {

    private static let catalog = HarborpointItems.catalog

    // MARK: - Presentation identity

    @Test func repeatedItemsGetDistinctPresentationKeys() {
        // Persistence stores ordered stacks rather than per-stack identities, so
        // the slot index is the occurrence identity. Two matchbooks in two slots
        // must not collapse onto one selectable key.
        let stacks = [
            CarriedItemStack(id: "matchbook", quantity: 1),
            CarriedItemStack(id: "matchbook", quantity: 1),
            CarriedItemStack(id: "brass-key", quantity: 1)
        ]
        let items = InventoryItemPresentation.carriedItems(stacks, catalog: Self.catalog)

        #expect(items.count == 3)
        #expect(Set(items.map(\.id)).count == 3, "presentation keys must be unique")
        // The authored identity is preserved alongside the presentation key.
        #expect(items[0].authoredID == "matchbook")
        #expect(items[1].authoredID == "matchbook")
        #expect(items[0].id != items[1].id)
    }

    @Test func presentationKeysAreStableForAGivenSlot() {
        let first = InventoryItemPresentation.presentationID(authoredID: "matchbook", slotIndex: 2)
        let second = InventoryItemPresentation.presentationID(authoredID: "matchbook", slotIndex: 2)
        #expect(first == second)
        #expect(first != InventoryItemPresentation.presentationID(authoredID: "matchbook", slotIndex: 3))
    }

    @Test func equippedAndCarriedCopiesOfOneItemDoNotShareAKey() {
        // The same revolver worn and carried must be separately selectable, or
        // clicking one would highlight both.
        let carried = InventoryItemPresentation.presentationID(
            authoredID: "service-revolver", slotIndex: 0
        )
        let worn = InventoryItemPresentation.presentationID(
            authoredID: "service-revolver", slot: .weapon1
        )
        #expect(carried != worn)
    }

    @Test func everyEquipmentSlotProducesADistinctKey() {
        let keys = EquipmentSlot.allCases.map {
            InventoryItemPresentation.presentationID(authoredID: "service-revolver", slot: $0)
        }
        #expect(Set(keys).count == keys.count)
    }

    // MARK: - What the window draws

    @Test func theStarterKitResolvesAgainstTheAuthoredCatalog() throws {
        // The six painted starter items are real carried stacks now, not a
        // reserved slot count with nothing behind it.
        let stacks = HarborpointItems.starterItemIDs.map {
            CarriedItemStack(id: $0, quantity: 1)
        }
        let items = InventoryItemPresentation.carriedItems(stacks, catalog: Self.catalog)
        #expect(items.count == HarborpointItems.starterItemIDs.count)
        for item in items {
            #expect(!item.name.isEmpty)
            #expect(item.artName.hasPrefix("inventory_item_"))
            #expect(!item.description.isEmpty)
        }
    }

    @Test func aCarriedRevolverKeepsItsAuthoredPresentation() throws {
        let stack = CarriedItemStack(id: "service-revolver", quantity: 1)
        let item = try #require(
            InventoryItemPresentation.item(
                for: stack,
                catalog: Self.catalog,
                presentationID: "carried.0.service-revolver"
            )
        )
        #expect(item.name == "Service Revolver")
        #expect(item.category == .weapon)
        #expect(item.categoryDisplayName == "SERVICE WEAPON")
        #expect(item.artName == "inventory_item_service_revolver_v01")
        #expect(item.isIdentified)
    }

    @Test func anUnidentifiedStackShowsItsUnknownFaceAndSaysSo() throws {
        let stack = CarriedItemStack(id: "matchbook", quantity: 1, isIdentified: false)
        let item = try #require(
            InventoryItemPresentation.item(
                for: stack,
                catalog: Self.catalog,
                presentationID: "carried.0.matchbook"
            )
        )
        #expect(item.name == "Paper Matchbook")
        #expect(!item.isIdentified)
        #expect(item.note == "Unidentified", "the note carries the state the blue wash paints")

        let known = try #require(
            InventoryItemPresentation.item(
                for: stack.identified(),
                catalog: Self.catalog,
                presentationID: "carried.0.matchbook"
            )
        )
        #expect(known.name == "Matchbook")
        #expect(known.description != item.description)
    }

    @Test func quantityCarriesThroughToTheSlotBadge() throws {
        let item = try #require(
            InventoryItemPresentation.item(
                for: CarriedItemStack(id: "matchbook", quantity: 7),
                catalog: Self.catalog,
                presentationID: "carried.0.matchbook"
            )
        )
        #expect(item.quantity == 7)
    }

    @Test func displayNameFallsBackToTheIDRatherThanInventingCopy() {
        // The catalog this replaced title-cased unknown ids into plausible-looking
        // items. A receipt for an unauthored id should look wrong, not plausible.
        let name = InventoryItemPresentation.displayName(
            forItemID: "no-such-item",
            catalog: Self.catalog
        )
        #expect(name == "no-such-item")
    }

    // MARK: - The window's own contract

    @Test func theBagPaintsSixteenSlots() {
        // Previously asserted by searching InventoryOverlay.swift for the literal
        // "static let bagSlotCount = 16".
        #expect(InventoryScreenLayout.bagSlotCount == 16)
    }

    @Test func nothingRefersToTheRetiredNearbyPanel() throws {
        // inventory_section_nearby_v05 was the modal Nearby backing; deliberate
        // container access uses the non-modal strip now. This one stays a source
        // check because it is asserting an absence across a whole file.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("RainShadow Shared/UI/InventoryOverlay.swift"),
            encoding: .utf8
        )
        #expect(!source.lowercased().contains("nearby"))
        #expect(source.contains("inventory_section_bag_v06"))
    }
}

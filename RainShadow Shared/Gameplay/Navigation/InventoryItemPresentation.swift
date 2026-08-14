import Foundation

/// One item as the interface draws it: an authored `ItemDefinition` resolved
/// against a carried stack, so identification and quantity are already applied.
///
/// This replaced a hand-written `InventoryItemCatalog` whose `default:` branch
/// title-cased any unrecognised id into a plausible-looking item. That turned an
/// authoring typo into shipped content instead of an error, and it is why the
/// catalog now throws on an unknown id.
struct InventoryItem: Identifiable, Equatable {
    /// Presentation key. Persistence stores ordered stacks rather than per-stack
    /// identities, so the slot index is the occurrence identity.
    let id: String
    /// Catalog identity.
    let authoredID: String
    let name: String
    let category: ItemCategory
    let description: String
    let note: String
    let artName: String
    let quantity: Int
    let isIdentified: Bool

    var categoryDisplayName: String { category.displayName }
}

/// Builds `InventoryItem` view models from carried stacks.
enum InventoryItemPresentation {
    /// Presentation id for a stack at a known slot index.
    static func presentationID(authoredID: String, slotIndex: Int) -> String {
        "carried.\(slotIndex).\(authoredID)"
    }

    /// Presentation id for an equipped stack.
    static func presentationID(authoredID: String, slot: EquipmentSlot) -> String {
        "equipped.\(slot.rawValue).\(authoredID)"
    }

    static func item(
        for stack: CarriedItemStack,
        catalog: ItemCatalog,
        presentationID: String
    ) -> InventoryItem? {
        guard let definition = catalog.definition(for: stack.id) else {
            // Authoring error, not a runtime condition — same policy the window
            // already applies to missing art.
            assertionFailure("No item definition authored for '\(stack.id)'")
            return nil
        }
        return InventoryItem(
            id: presentationID,
            authoredID: stack.id,
            name: definition.displayName(identified: stack.isIdentified),
            category: definition.category,
            description: definition.displayDescription(identified: stack.isIdentified),
            note: stack.isIdentified ? definition.note : "Unidentified",
            artName: definition.iconArtName,
            quantity: stack.quantity,
            isIdentified: stack.isIdentified
        )
    }

    /// Every carried stack, in bag order.
    static func carriedItems(
        _ stacks: [CarriedItemStack],
        catalog: ItemCatalog
    ) -> [InventoryItem] {
        stacks.enumerated().compactMap { index, stack in
            item(
                for: stack,
                catalog: catalog,
                presentationID: presentationID(authoredID: stack.id, slotIndex: index)
            )
        }
    }

    /// Short display name for receipts and feedback lines.
    static func displayName(
        forItemID id: String,
        catalog: ItemCatalog,
        identified: Bool = true
    ) -> String {
        catalog.definition(for: id)?.displayName(identified: identified) ?? id
    }
}

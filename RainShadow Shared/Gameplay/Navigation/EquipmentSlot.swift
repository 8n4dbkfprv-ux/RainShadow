import Foundation

/// What an item *is*, which is what decides where it can go.
///
/// The Infinity Engine gates equipping on the `ITM` header's item category
/// (`itm_v1.htm` offset 0x001c): a helmet-category item enters the helmet slot and
/// nowhere else. RainShadow keeps that rule and renames the categories to the
/// wardrobe Harborpoint actually has — no bracers, no plate.
///
/// The first four raw values are the display strings the inventory description
/// strip already showed before items became data; they are load-bearing copy, not
/// identifiers, and the JSON catalog keys off the `CodingKey` names instead.
enum ItemCategory: String, Codable, Sendable, CaseIterable {
    case weapon = "SERVICE WEAPON"
    case evidence = "EVIDENCE"
    case tool = "FIELD TOOL"
    case personal = "PERSONAL EFFECT"
    case ammunition = "AMMUNITION"
    case headwear = "HEADWEAR"
    case outerwear = "OUTERWEAR"
    case handwear = "HANDWEAR"
    case footwear = "FOOTWEAR"
    case waistwear = "BELT"
    case overcoat = "OVERCOAT"
    case ring = "RING"
    case charm = "CHARM"
    case document = "DOCUMENT"

    /// Display copy for the inventory description strip.
    var displayName: String { rawValue }
}

/// The CRE v1.0 item-slot table (`cre_v1.htm`), mapped onto the ten paperdoll
/// slots the inventory window already paints plus the three loadout rows.
///
/// The engine stores 40 slots per creature; RainShadow ships the 23 that have a
/// painted home. `bgSlotIndex` records the engine's index for every case so the
/// parity claim stays checkable rather than asserted — the numbers are the
/// engine's, not ours.
///
/// Case names match the node-name suffixes `InventoryOverlay` already builds
/// (`inventory.equip.coat`, `.fedora`, `.holster`, …), so the painted art keeps
/// working without a rename pass.
enum EquipmentSlot: String, Codable, Sendable, CaseIterable, Hashable {
    // Paperdoll — the ten slots painted at InventoryOverlay's equipped-bar geometry.
    case fedora
    case coat
    case holster
    case gloves
    case ringLeft
    case ringRight
    case charm
    case belt
    case shoes
    case cloak

    // Loadout column — READY WEAPONS.
    case weapon1
    case weapon2
    case weapon3
    case weapon4

    // Loadout column — COAT POCKETS, which hold ammunition the way BG's quivers do.
    case quiver1
    case quiver2
    case quiver3

    // Loadout column — QUICK ITEMS.
    case quickItem1
    case quickItem2
    case quickItem3

    /// The engine's slot index for this slot (`cre_v1.htm`). Documentation of the
    /// parity claim; nothing serialises it.
    var bgSlotIndex: Int {
        switch self {
        case .fedora: 0        // Helmet
        case .coat: 1          // Armor
        case .holster: 2       // Shield / off-hand
        case .gloves: 3        // Gloves
        case .ringLeft: 4      // Left ring
        case .ringRight: 5     // Right ring
        case .charm: 6         // Amulet
        case .belt: 7          // Belt
        case .shoes: 8         // Boots
        case .weapon1: 9
        case .weapon2: 10
        case .weapon3: 11
        case .weapon4: 12
        case .quiver1: 13
        case .quiver2: 14
        case .quiver3: 15
        case .cloak: 17
        case .quickItem1: 18
        case .quickItem2: 19
        case .quickItem3: 20
        }
    }

    /// The categories this slot will take. One category, one home — except the
    /// weapon and quick-item banks, which are interchangeable in the engine too.
    var acceptedCategories: Set<ItemCategory> {
        switch self {
        case .fedora: [.headwear]
        case .coat: [.outerwear]
        case .gloves: [.handwear]
        case .shoes: [.footwear]
        case .belt: [.waistwear]
        case .cloak: [.overcoat]
        case .charm: [.charm]
        case .ringLeft, .ringRight: [.ring]
        case .holster, .weapon1, .weapon2, .weapon3, .weapon4: [.weapon]
        case .quiver1, .quiver2, .quiver3: [.ammunition]
        case .quickItem1, .quickItem2, .quickItem3: [.tool, .personal, .document]
        }
    }

    func accepts(_ category: ItemCategory) -> Bool {
        acceptedCategories.contains(category)
    }

    /// The four ready-weapon slots, in bar order.
    static let weaponSlots: [EquipmentSlot] = [.weapon1, .weapon2, .weapon3, .weapon4]

    /// The three ammunition slots, in bar order.
    static let quiverSlots: [EquipmentSlot] = [.quiver1, .quiver2, .quiver3]

    /// The three quick-item slots, in bar order.
    static let quickItemSlots: [EquipmentSlot] = [.quickItem1, .quickItem2, .quickItem3]

    /// The ten paperdoll slots, in the order the window paints them.
    static let paperdollSlots: [EquipmentSlot] = [
        .coat, .gloves, .fedora, .charm,
        .holster, .ringLeft, .ringRight,
        .cloak, .shoes, .belt
    ]

    /// Slots whose contents contribute a worn defence bonus rather than a carried one.
    var isWorn: Bool {
        Self.paperdollSlots.contains(self)
    }

    /// The node-name the inventory window uses for this slot's hit target.
    var nodeName: String { "inventory.equip.\(rawValue)" }
}

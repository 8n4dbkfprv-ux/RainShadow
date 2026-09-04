import Foundation

/// Per-item behaviour bits. The Infinity Engine packs these into the `ITM`
/// header's flags dword (`itm_v1.htm` offset 0x0018) and into the per-stack flags
/// on the creature's item entry (`cre_v1.htm` offset 0x0010); RainShadow splits
/// them the same way — these are the definition-level bits, while
/// `CarriedItemStack.isIdentified` is per-stack because two matchbooks can differ.
///
/// Authored in JSON as a string array (`"flags": ["cursed", "undroppable"]`)
/// rather than a bitmask, because a save file nobody can read by eye is how
/// authoring mistakes survive review.
struct ItemFlags: OptionSet, Codable, Sendable, Hashable {
    let rawValue: Int

    init(rawValue: Int) { self.rawValue = rawValue }

    /// Cannot be unequipped once worn (BG: cursed).
    static let cursed = ItemFlags(rawValue: 1 << 0)
    /// Cannot be dropped or returned to a container (BG: undroppable).
    static let undroppable = ItemFlags(rawValue: 1 << 1)
    /// Cannot be pickpocketed off the carrier (BG: unstealable).
    static let unstealable = ItemFlags(rawValue: 1 << 2)
    /// Occupies both hands; suppresses the off-hand slot (BG: two-handed).
    static let twoHanded = ItemFlags(rawValue: 1 << 3)
    /// Case-critical. Never destroyed, never sold (BG: critical / unsellable).
    static let questCritical = ItemFlags(rawValue: 1 << 4)

    private static let namedFlags: [(name: String, flag: ItemFlags)] = [
        ("cursed", .cursed),
        ("undroppable", .undroppable),
        ("unstealable", .unstealable),
        ("twoHanded", .twoHanded),
        ("questCritical", .questCritical)
    ]

    init(names: [String]) throws {
        var value: ItemFlags = []
        for name in names {
            guard let match = Self.namedFlags.first(where: { $0.name == name }) else {
                throw ItemCatalogError.unknownItemFlag(name: name)
            }
            value.insert(match.flag)
        }
        self = value
    }

    var names: [String] {
        Self.namedFlags.filter { contains($0.flag) }.map(\.name)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try ItemFlags(names: container.decode([String].self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(names)
    }
}

/// One authored item — the `ITM` v1 header analogue.
///
/// The engine's header carries paired unidentified/identified names and
/// descriptions, a category, weight, price, stack amount, lore-to-identify, and
/// an inventory + ground icon. Every one of those has a job in this UI, so they
/// are all here. What is deliberately absent: extended headers, feature blocks,
/// casting abilities, and the class/race/alignment usability masks — RainShadow
/// has one character and no spell system, so those would be empty fields
/// pretending to be a design.
struct ItemDefinition: Equatable, Codable, Sendable, Identifiable {
    /// Stable authored id, lowercase kebab-case (`service-revolver`).
    let id: String
    /// Shown once the item is identified.
    let identifiedName: String
    /// Shown before identification. Absent means the item is never mysterious.
    let unidentifiedName: String?
    let category: ItemCategory
    /// Ounces. Imperial to match the £/s/d wallet; `CurrencyAmount` sets the register.
    let weightOunces: Int
    /// Worth in pence, through `CurrencyAmount`.
    let valuePence: Int
    /// Maximum stack depth. 1 means the item never stacks.
    let maxStack: Int
    /// Lore needed to identify on pickup or by right-click. 0 means self-evident.
    let loreToIdentify: Int
    /// Inventory icon texture name (no extension), resolved through `GameArt`.
    let iconArtName: String
    /// Texture used when the item lies on the ground. Falls back to the icon.
    let groundArtName: String?
    let identifiedDescription: String
    let unidentifiedDescription: String?
    /// The quiet second line under the description strip.
    let note: String
    let flags: ItemFlags
    /// Defence this item contributes while worn. BG counts armour down from 10;
    /// RainShadow counts protection up, so a coat that turns a glancing blow adds.
    let defenceBonus: Int
    /// Damage band for a weapon, inclusive. `nil` for everything that is not one.
    let damageLow: Int?
    let damageHigh: Int?

    init(
        id: String,
        identifiedName: String,
        unidentifiedName: String? = nil,
        category: ItemCategory,
        weightOunces: Int,
        valuePence: Int = 0,
        maxStack: Int = 1,
        loreToIdentify: Int = 0,
        iconArtName: String,
        groundArtName: String? = nil,
        identifiedDescription: String,
        unidentifiedDescription: String? = nil,
        note: String = "",
        flags: ItemFlags = [],
        defenceBonus: Int = 0,
        damageLow: Int? = nil,
        damageHigh: Int? = nil
    ) {
        self.id = id
        self.identifiedName = identifiedName
        self.unidentifiedName = unidentifiedName
        self.category = category
        self.weightOunces = max(0, weightOunces)
        self.valuePence = max(0, valuePence)
        self.maxStack = max(1, maxStack)
        self.loreToIdentify = max(0, loreToIdentify)
        self.iconArtName = iconArtName
        self.groundArtName = groundArtName
        self.identifiedDescription = identifiedDescription
        self.unidentifiedDescription = unidentifiedDescription
        self.note = note
        self.flags = flags
        self.defenceBonus = defenceBonus
        self.damageLow = damageLow
        self.damageHigh = damageHigh
    }

    // Authored JSON omits everything that has a sensible default.
    private enum CodingKeys: String, CodingKey {
        case id, identifiedName, unidentifiedName, category
        case weightOunces, valuePence, maxStack, loreToIdentify
        case iconArtName, groundArtName
        case identifiedDescription, unidentifiedDescription, note, flags
        case defenceBonus, damageLow, damageHigh
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            identifiedName: try c.decode(String.self, forKey: .identifiedName),
            unidentifiedName: try c.decodeIfPresent(String.self, forKey: .unidentifiedName),
            category: try c.decode(ItemCategory.self, forKey: .category),
            weightOunces: try c.decodeIfPresent(Int.self, forKey: .weightOunces) ?? 0,
            valuePence: try c.decodeIfPresent(Int.self, forKey: .valuePence) ?? 0,
            maxStack: try c.decodeIfPresent(Int.self, forKey: .maxStack) ?? 1,
            loreToIdentify: try c.decodeIfPresent(Int.self, forKey: .loreToIdentify) ?? 0,
            iconArtName: try c.decode(String.self, forKey: .iconArtName),
            groundArtName: try c.decodeIfPresent(String.self, forKey: .groundArtName),
            identifiedDescription: try c.decode(String.self, forKey: .identifiedDescription),
            unidentifiedDescription: try c.decodeIfPresent(
                String.self, forKey: .unidentifiedDescription
            ),
            note: try c.decodeIfPresent(String.self, forKey: .note) ?? "",
            flags: try c.decodeIfPresent(ItemFlags.self, forKey: .flags) ?? [],
            defenceBonus: try c.decodeIfPresent(Int.self, forKey: .defenceBonus) ?? 0,
            damageLow: try c.decodeIfPresent(Int.self, forKey: .damageLow),
            damageHigh: try c.decodeIfPresent(Int.self, forKey: .damageHigh)
        )
    }

    // MARK: - Derived

    /// Slots this item can be equipped into, from its category. The engine derives
    /// the same way; authoring a per-item slot list would only create a second
    /// source of truth to disagree with the first.
    var equippableSlots: [EquipmentSlot] {
        EquipmentSlot.allCases.filter { $0.accepts(category) }
    }

    var isEquippable: Bool { !equippableSlots.isEmpty }

    var stacks: Bool { maxStack > 1 }

    /// BG shows the unidentified name until the item is known.
    func displayName(identified: Bool) -> String {
        identified ? identifiedName : (unidentifiedName ?? identifiedName)
    }

    func displayDescription(identified: Bool) -> String {
        identified
            ? identifiedDescription
            : (unidentifiedDescription ?? identifiedDescription)
    }

    /// An item with no lore requirement is known the moment it is picked up.
    var isSelfEvident: Bool { loreToIdentify == 0 }

    var groundTextureName: String { groundArtName ?? iconArtName }

    /// Formatted damage band for the inventory stat row (e.g. `2–7`), en dash as
    /// the shipped panel already spells it.
    var damageBand: String? {
        guard let damageLow, let damageHigh else { return nil }
        return damageLow == damageHigh ? "\(damageLow)" : "\(damageLow)–\(damageHigh)"
    }
}

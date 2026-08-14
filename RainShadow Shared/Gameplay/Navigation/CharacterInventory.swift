import Foundation

/// Why an equip, unequip, or drop was refused.
///
/// The engine simply declines and says so; nothing here silently relocates an
/// item to somewhere it *would* fit. A refused order is refused — the same rule
/// the navigation layer already holds itself to for unreachable ground.
enum InventoryRefusal: Error, Equatable, Sendable, CustomStringConvertible {
    case unknownItem(id: String)
    case wrongSlot(itemID: String, category: ItemCategory, slot: EquipmentSlot)
    case offHandBlockedByTwoHandedWeapon(blockedBy: EquipmentSlot)
    case twoHandedBlockedByOffHand(occupied: EquipmentSlot)
    case cursedInPlace(slot: EquipmentSlot)
    case slotEmpty(slot: EquipmentSlot)
    case undroppable(itemID: String)
    case bagFull
    case noSuchStack(index: Int)

    var description: String {
        switch self {
        case .unknownItem(let id):
            "No item definition is authored for '\(id)'"
        case .wrongSlot(let itemID, let category, let slot):
            "'\(itemID)' is \(category.displayName.lowercased()) and does not belong in \(slot.rawValue)"
        case .offHandBlockedByTwoHandedWeapon(let blockedBy):
            "The off-hand is blocked while a two-handed weapon is readied in \(blockedBy.rawValue)"
        case .twoHandedBlockedByOffHand(let occupied):
            "A two-handed weapon needs both hands; \(occupied.rawValue) is occupied"
        case .cursedInPlace(let slot):
            "The item in \(slot.rawValue) will not come off"
        case .slotEmpty(let slot):
            "\(slot.rawValue) is empty"
        case .undroppable(let itemID):
            "'\(itemID)' cannot be put down"
        case .bagFull:
            "The case bag is full"
        case .noSuchStack(let index):
            "No carried stack at index \(index)"
        }
    }
}

/// What one character carries and wears — the CRE inventory analogue.
///
/// Equipped slots and the case bag are one value because almost every real
/// operation crosses between them: equipping empties a bag slot, unequipping
/// fills one, and the weight that decides encumbrance is the sum of both. Two
/// separate values would need a coordinator to keep them honest, which is the
/// coordinator this type already is.
///
/// Pure and `Sendable`. Content rules arrive as an `ItemCatalog` parameter rather
/// than being stored, so this value stays safe to persist and cheap to compare.
struct CharacterInventory: Equatable, Sendable {
    private(set) var equipped: [EquipmentSlot: CarriedItemStack]
    private(set) var backpack: CarriedInventoryState

    init(
        equipped: [EquipmentSlot: CarriedItemStack] = [:],
        backpack: CarriedInventoryState = CarriedInventoryState()
    ) {
        self.equipped = equipped.filter { $0.value.quantity > 0 }
        self.backpack = backpack
    }

    // MARK: - Reading

    func item(in slot: EquipmentSlot) -> CarriedItemStack? {
        equipped[slot]
    }

    var equippedSlots: [EquipmentSlot] {
        EquipmentSlot.allCases.filter { equipped[$0] != nil }
    }

    var isEmpty: Bool { equipped.isEmpty && backpack.stacks.isEmpty }

    /// The ready-weapon slot holding a two-handed weapon, if any. BG blocks the
    /// off-hand whenever one is in the quick-weapon bar, readied or not.
    func twoHandedWeaponSlot(catalog: ItemCatalog) -> EquipmentSlot? {
        EquipmentSlot.weaponSlots.first { slot in
            guard let stack = equipped[slot],
                  let definition = catalog.definition(for: stack.id) else { return false }
            return definition.flags.contains(.twoHanded)
        }
    }

    // MARK: - Equip rules

    /// `nil` means the move is legal. Pure — safe to call from hover and hit-test
    /// paths to decide whether a slot should read as a valid drop target.
    func refusal(
        equipping stack: CarriedItemStack,
        in slot: EquipmentSlot,
        catalog: ItemCatalog
    ) -> InventoryRefusal? {
        guard let definition = catalog.definition(for: stack.id) else {
            return .unknownItem(id: stack.id)
        }
        guard slot.accepts(definition.category) else {
            return .wrongSlot(itemID: stack.id, category: definition.category, slot: slot)
        }
        // Whatever is already there has to be willing to leave.
        if let occupant = equipped[slot],
           let occupantDefinition = catalog.definition(for: occupant.id),
           occupantDefinition.flags.contains(.cursed) {
            return .cursedInPlace(slot: slot)
        }
        if slot == .holster, let blocking = twoHandedWeaponSlot(catalog: catalog) {
            return .offHandBlockedByTwoHandedWeapon(blockedBy: blocking)
        }
        if definition.flags.contains(.twoHanded),
           EquipmentSlot.weaponSlots.contains(slot),
           equipped[.holster] != nil {
            return .twoHandedBlockedByOffHand(occupied: .holster)
        }
        return nil
    }

    func canEquip(
        _ stack: CarriedItemStack,
        in slot: EquipmentSlot,
        catalog: ItemCatalog
    ) -> Bool {
        refusal(equipping: stack, in: slot, catalog: catalog) == nil
    }

    // MARK: - Equipping

    /// Place a stack into a slot, returning whatever it displaced. BG hands the
    /// displaced item back to the cursor, which is exactly what this return value
    /// is for — the caller decides where it lands.
    @discardableResult
    mutating func equip(
        _ stack: CarriedItemStack,
        in slot: EquipmentSlot,
        catalog: ItemCatalog
    ) throws -> CarriedItemStack? {
        if let refusal = refusal(equipping: stack, in: slot, catalog: catalog) {
            throw refusal
        }
        let displaced = equipped[slot]
        equipped[slot] = stack
        return displaced
    }

    /// Take a slot's contents off. Cursed items refuse.
    @discardableResult
    mutating func unequip(
        from slot: EquipmentSlot,
        catalog: ItemCatalog
    ) throws -> CarriedItemStack {
        guard let stack = equipped[slot] else {
            throw InventoryRefusal.slotEmpty(slot: slot)
        }
        if let definition = catalog.definition(for: stack.id),
           definition.flags.contains(.cursed) {
            throw InventoryRefusal.cursedInPlace(slot: slot)
        }
        equipped[slot] = nil
        return stack
    }

    /// Move a worn or readied item straight to another slot, swapping with
    /// whatever is there. Both ends have to agree: the destination must accept the
    /// item, and neither occupant may be cursed.
    mutating func moveEquipped(
        from source: EquipmentSlot,
        to destination: EquipmentSlot,
        catalog: ItemCatalog
    ) throws {
        guard source != destination else { return }
        guard let moving = equipped[source] else {
            throw InventoryRefusal.slotEmpty(slot: source)
        }
        if let definition = catalog.definition(for: moving.id),
           definition.flags.contains(.cursed) {
            throw InventoryRefusal.cursedInPlace(slot: source)
        }

        // Test the destination against the inventory as it will be once the source
        // slot is empty, or a two-hander would refuse to move to its own bank.
        var candidate = self
        candidate.equipped[source] = nil
        if let refusal = candidate.refusal(equipping: moving, in: destination, catalog: catalog) {
            throw refusal
        }
        let displaced = candidate.equipped[destination]
        candidate.equipped[destination] = moving
        if let displaced {
            if let refusal = candidate.refusal(equipping: displaced, in: source, catalog: catalog) {
                throw refusal
            }
            candidate.equipped[source] = displaced
        }
        self = candidate
    }

    // MARK: - Moving between the bag and the body

    /// Equip the bag stack at `index`, sending anything it displaces back to the
    /// bag. Copy-then-commit: a refusal at any step leaves both sides untouched.
    mutating func equipFromBackpack(
        at index: Int,
        to slot: EquipmentSlot,
        catalog: ItemCatalog,
        limits: ItemStackLimits
    ) throws {
        guard let stack = backpack.stack(at: index) else {
            throw InventoryRefusal.noSuchStack(index: index)
        }
        if let refusal = refusal(equipping: stack, in: slot, catalog: catalog) {
            throw refusal
        }

        var nextBackpack = backpack
        var nextEquipped = equipped
        guard nextBackpack.takeStack(at: index) != nil else {
            throw InventoryRefusal.noSuchStack(index: index)
        }
        let displaced = nextEquipped[slot]
        nextEquipped[slot] = stack
        if let displaced, !nextBackpack.append(displaced, limits: limits) {
            throw InventoryRefusal.bagFull
        }
        backpack = nextBackpack
        equipped = nextEquipped
    }

    /// Take a slot off into the bag. Refuses rather than dropping the item on the
    /// floor when the bag has no room.
    mutating func unequipToBackpack(
        from slot: EquipmentSlot,
        catalog: ItemCatalog,
        limits: ItemStackLimits
    ) throws {
        guard let stack = equipped[slot] else {
            throw InventoryRefusal.slotEmpty(slot: slot)
        }
        if let definition = catalog.definition(for: stack.id),
           definition.flags.contains(.cursed) {
            throw InventoryRefusal.cursedInPlace(slot: slot)
        }

        var nextBackpack = backpack
        guard nextBackpack.append(stack, limits: limits) else {
            throw InventoryRefusal.bagFull
        }
        backpack = nextBackpack
        equipped[slot] = nil
    }

    // MARK: - Bag operations

    mutating func addToBackpack(
        _ stack: CarriedItemStack,
        limits: ItemStackLimits
    ) throws {
        var next = backpack
        guard next.append(stack, limits: limits) else {
            throw InventoryRefusal.bagFull
        }
        backpack = next
    }

    /// Remove a bag stack for a drop or a transfer. Undroppable items refuse.
    @discardableResult
    mutating func removeFromBackpack(
        at index: Int,
        catalog: ItemCatalog
    ) throws -> CarriedItemStack {
        guard let stack = backpack.stack(at: index) else {
            throw InventoryRefusal.noSuchStack(index: index)
        }
        if let definition = catalog.definition(for: stack.id),
           definition.flags.contains(.undroppable) {
            throw InventoryRefusal.undroppable(itemID: stack.id)
        }
        guard let taken = backpack.takeStack(at: index) else {
            throw InventoryRefusal.noSuchStack(index: index)
        }
        return taken
    }

    mutating func splitBackpackStack(at index: Int, count: Int) throws {
        var next = backpack
        guard next.split(at: index, count: count) else {
            throw InventoryRefusal.noSuchStack(index: index)
        }
        backpack = next
    }

    // MARK: - Identification

    /// BG checks an unidentified item against the carrier's Lore, both on pickup
    /// and on demand. Returns whether this attempt changed anything.
    @discardableResult
    mutating func identifyBackpackStack(
        at index: Int,
        lore: Int,
        catalog: ItemCatalog
    ) throws -> Bool {
        guard let stack = backpack.stack(at: index) else {
            throw InventoryRefusal.noSuchStack(index: index)
        }
        guard let definition = catalog.definition(for: stack.id) else {
            throw InventoryRefusal.unknownItem(id: stack.id)
        }
        guard !stack.isIdentified, lore >= definition.loreToIdentify else { return false }
        var next = backpack
        guard next.replace(at: index, with: stack.identified()) else { return false }
        backpack = next
        return true
    }

    /// Sweep the bag the way BG does when an item enters it: anything the
    /// carrier's Lore already covers is known immediately.
    @discardableResult
    mutating func identifyEverythingKnown(lore: Int, catalog: ItemCatalog) -> Int {
        var identified = 0
        for index in backpack.stacks.indices {
            if (try? identifyBackpackStack(at: index, lore: lore, catalog: catalog)) == true {
                identified += 1
            }
        }
        return identified
    }

    // MARK: - Derived statistics

    /// Everything worn plus everything carried, in ounces.
    func carriedWeightOunces(catalog: ItemCatalog) -> Int {
        var total = 0
        for stack in equipped.values {
            guard let definition = catalog.definition(for: stack.id) else { continue }
            total += definition.weightOunces * stack.quantity
        }
        for stack in backpack.stacks {
            guard let definition = catalog.definition(for: stack.id) else { continue }
            total += definition.weightOunces * stack.quantity
        }
        return total
    }

    /// Defence from worn gear only. A revolver in the bag protects nobody.
    func defenceBonus(catalog: ItemCatalog) -> Int {
        equipped.reduce(into: 0) { total, entry in
            guard entry.key.isWorn,
                  let definition = catalog.definition(for: entry.value.id) else { return }
            total += definition.defenceBonus
        }
    }

    /// The readied weapon: BG's first quick-weapon slot.
    func readiedWeapon(catalog: ItemCatalog) -> ItemDefinition? {
        for slot in EquipmentSlot.weaponSlots {
            guard let stack = equipped[slot],
                  let definition = catalog.definition(for: stack.id) else { continue }
            return definition
        }
        return nil
    }
}

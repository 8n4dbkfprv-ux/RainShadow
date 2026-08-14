import Foundation

/// Pre-decimal British currency stored as a single pence integer.
/// 1 pound = 20 shillings = 240 pence; 1 shilling = 12 pence.
struct CurrencyAmount: Hashable, Codable, Sendable {
    var pence: Int

    /// Matches the cosmetic starter balance previously shown in the inventory UI (£7 4s).
    static let startingWalletPence = 7 * 240 + 4 * 12 // 1_728

    init(pence: Int) {
        self.pence = max(0, pence)
    }

    init(pounds: Int = 0, shillings: Int = 0, pence: Int = 0) {
        self.pence = max(0, pounds * 240 + shillings * 12 + pence)
    }

    var pounds: Int { pence / 240 }
    var shillings: Int { (pence % 240) / 12 }
    var remainingPence: Int { pence % 12 }

    /// Period-flavored display, omitting zero components (e.g. `£7 4s`, `3s`, `5d`).
    var formatted: String {
        var parts: [String] = []
        if pounds > 0 { parts.append("£\(pounds)") }
        if shillings > 0 { parts.append("\(shillings)s") }
        if remainingPence > 0 || parts.isEmpty { parts.append("\(remainingPence)d") }
        return parts.joined(separator: " ")
    }

    static func += (lhs: inout CurrencyAmount, rhs: CurrencyAmount) {
        lhs.pence += rhs.pence
    }

    static func + (lhs: CurrencyAmount, rhs: CurrencyAmount) -> CurrencyAmount {
        CurrencyAmount(pence: lhs.pence + rhs.pence)
    }
}

/// Authored container entry — mirrors BG literal items, literal gold, and random-treasure tokens.
enum LootEntry: Hashable, Codable, Sendable {
    case coins(pence: Int)
    case randomCoins(table: RandomCoinTable)
    /// BG-style item stack; each resolved stack consumes one carried-inventory slot.
    case item(id: String, quantity: Int)
}

/// BG `RNDTREAS.2DA`-style table: d20 roll of 1 yields nothing; rolls 2…20 pick a pence amount.
struct RandomCoinTable: Hashable, Codable, Sendable {
    /// Exactly 19 pence values for rolls 2 through 20.
    let penceForRolls2to20: [Int]

    init(penceForRolls2to20: [Int]) {
        precondition(
            penceForRolls2to20.count == 19,
            "RandomCoinTable requires 19 entries for d20 rolls 2…20"
        )
        self.penceForRolls2to20 = penceForRolls2to20
    }

    /// Resolve one roll. Returns `nil` on a natural 1 (BG empty column).
    func roll(using rng: inout some RandomNumberGenerator) -> Int? {
        result(forDieRoll: Int.random(in: 1...20, using: &rng))
    }

    /// BG column pick for a known d20 face (1 → empty).
    func result(forDieRoll roll: Int) -> Int? {
        guard (1...20).contains(roll), roll > 1 else { return nil }
        return penceForRolls2to20[roll - 2]
    }
}

struct LootContainerDefinition: Hashable, Codable, Sendable {
    let id: String
    let entries: [LootEntry]
}

/// What actually sits in a container after BG resolve-once evaluation.
enum ResolvedLootStack: Hashable, Codable, Sendable {
    case coins(pence: Int)
    case item(id: String, quantity: Int)

    var isCoins: Bool {
        if case .coins = self { return true }
        return false
    }

    var coinPence: Int? {
        if case .coins(let pence) = self { return pence }
        return nil
    }
}

/// One acquired item stack carried in the case bag. Currency is deliberately
/// absent: BG-style coin pickups credit the shared wallet instead of consuming
/// an inventory slot.
struct CarriedItemStack: Hashable, Codable, Sendable {
    let id: String
    let quantity: Int
    /// Per-stack, not per-definition. Two matchbooks lifted off two different
    /// tables can differ in what Voss has worked out about them, which is why
    /// the engine stores this bit on the creature's item entry
    /// (`cre_v1.htm` offset 0x0010) and not in the shared `ITM` header.
    let isIdentified: Bool
    /// Remaining uses for a charged item; `nil` when the item has no charges.
    let charges: Int?

    init(id: String, quantity: Int, isIdentified: Bool = true, charges: Int? = nil) {
        self.id = id
        self.quantity = quantity
        self.isIdentified = isIdentified
        self.charges = charges
    }

    // Additive decoding: stacks written before identification existed load as
    // identified, which is what they were.
    private enum CodingKeys: String, CodingKey {
        case id, quantity, isIdentified, charges
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            quantity: try c.decode(Int.self, forKey: .quantity),
            isIdentified: try c.decodeIfPresent(Bool.self, forKey: .isIdentified) ?? true,
            charges: try c.decodeIfPresent(Int.self, forKey: .charges)
        )
    }

    func withQuantity(_ quantity: Int) -> CarriedItemStack {
        CarriedItemStack(
            id: id,
            quantity: quantity,
            isIdentified: isIdentified,
            charges: charges
        )
    }

    func identified() -> CarriedItemStack {
        isIdentified ? self : withIdentified(true)
    }

    func withIdentified(_ identified: Bool) -> CarriedItemStack {
        CarriedItemStack(
            id: id,
            quantity: quantity,
            isIdentified: identified,
            charges: charges
        )
    }

    /// Two stacks combine only when they read identically. BG will not merge an
    /// identified stack into an unidentified one — they draw differently and the
    /// player would lose the distinction — and a charged item has a per-item
    /// remainder that a merged quantity cannot express.
    func canMerge(with other: CarriedItemStack) -> Bool {
        id == other.id
            && isIdentified == other.isIdentified
            && charges == nil
            && other.charges == nil
    }
}

/// Per-item stack ceilings, read off the catalog. Passed into the bag rather than
/// stored on it: the bag is a persisted value and must not carry content rules
/// into the save file.
struct ItemStackLimits: Sendable {
    private let limitForID: @Sendable (String) -> Int

    init(limitForID: @escaping @Sendable (String) -> Int) {
        self.limitForID = limitForID
    }

    init(catalog: ItemCatalog) {
        let limits = Dictionary(
            uniqueKeysWithValues: catalog.allDefinitions.map { ($0.id, $0.maxStack) }
        )
        self.init { limits[$0] ?? 1 }
    }

    /// Nothing stacks. The behaviour the bag shipped with, kept as the default so
    /// a caller that has no catalog cannot silently start merging.
    static let nonStacking = ItemStackLimits { _ in 1 }

    func maxStack(for id: String) -> Int {
        max(1, limitForID(id))
    }
}

/// Ordered, slot-limited acquired inventory. The UI also paints a fixed starter
/// kit; `reservedSlotCount` lets that kit consume real slots without persisting
/// duplicate copies of those static presentation entries into every save.
struct CarriedInventoryState: Hashable, Sendable {
    static let defaultTotalSlotCapacity = 16

    let totalSlotCapacity: Int
    let reservedSlotCount: Int
    private(set) var stacks: [CarriedItemStack]

    init(
        stacks: [CarriedItemStack] = [],
        reservedSlotCount: Int = 0,
        totalSlotCapacity: Int = Self.defaultTotalSlotCapacity
    ) {
        let normalizedTotal = max(0, totalSlotCapacity)
        self.totalSlotCapacity = normalizedTotal
        self.reservedSlotCount = min(max(0, reservedSlotCount), normalizedTotal)
        let acquiredCapacity = normalizedTotal - self.reservedSlotCount
        self.stacks = Array(
            stacks.lazy
                .filter { $0.quantity > 0 }
                .prefix(acquiredCapacity)
        )
    }

    /// Slots available to acquired stacks after the static starter kit.
    var itemSlotCapacity: Int { totalSlotCapacity - reservedSlotCount }
    var occupiedSlotCount: Int { reservedSlotCount + stacks.count }
    var availableSlotCount: Int { max(0, itemSlotCapacity - stacks.count) }
    var isFull: Bool { availableSlotCount == 0 }

    func stack(at index: Int) -> CarriedItemStack? {
        guard stacks.indices.contains(index) else { return nil }
        return stacks[index]
    }

    @discardableResult
    mutating func append(
        _ stack: CarriedItemStack,
        limits: ItemStackLimits = .nonStacking
    ) -> Bool {
        append(contentsOf: [stack], limits: limits)
    }

    /// All-or-nothing append used by a take-all transaction.
    ///
    /// An incoming stack tops up a matching partial stack before it consumes a
    /// fresh slot, the way BG fills a half-empty quiver rather than opening a
    /// second one. The whole batch is solved against a copy first, so a batch
    /// that cannot fit leaves the bag exactly as it was — the same
    /// copy-then-commit discipline the transfer paths already use.
    @discardableResult
    mutating func append(
        contentsOf newStacks: [CarriedItemStack],
        limits: ItemStackLimits = .nonStacking
    ) -> Bool {
        guard newStacks.allSatisfy({ $0.quantity > 0 }) else { return false }
        var candidate = stacks
        for incoming in newStacks {
            guard Self.absorb(
                incoming,
                into: &candidate,
                limits: limits,
                capacity: itemSlotCapacity
            ) else { return false }
        }
        stacks = candidate
        return true
    }

    /// Fills matching partial stacks in slot order, then spills the remainder
    /// into new slots. `false` means the remainder ran out of room; the caller
    /// discards `candidate` rather than committing a partial transfer.
    private static func absorb(
        _ incoming: CarriedItemStack,
        into candidate: inout [CarriedItemStack],
        limits: ItemStackLimits,
        capacity: Int
    ) -> Bool {
        let ceiling = limits.maxStack(for: incoming.id)
        var remaining = incoming.quantity

        if ceiling > 1 {
            for index in candidate.indices where remaining > 0 {
                let existing = candidate[index]
                guard existing.canMerge(with: incoming),
                      existing.quantity < ceiling else { continue }
                let moved = min(ceiling - existing.quantity, remaining)
                candidate[index] = existing.withQuantity(existing.quantity + moved)
                remaining -= moved
            }
        }

        while remaining > 0 {
            guard candidate.count < capacity else { return false }
            // A non-stacking ceiling means "do not merge", not "break this stack
            // into singles" — a loot entry authored as four of something has
            // always occupied one slot, and must keep doing so.
            let taken = ceiling > 1 ? min(ceiling, remaining) : remaining
            candidate.append(incoming.withQuantity(taken))
            remaining -= taken
        }
        return true
    }

    /// BG stack splitting: pull `count` off the stack at `index` into a new slot.
    /// Refuses when the split would empty the source, when there is no free slot,
    /// or when the stack is one the engine would not have let you split.
    @discardableResult
    mutating func split(at index: Int, count: Int) -> Bool {
        guard let source = stack(at: index),
              count > 0,
              count < source.quantity,
              source.charges == nil,
              availableSlotCount > 0 else { return false }
        stacks[index] = source.withQuantity(source.quantity - count)
        stacks.insert(source.withQuantity(count), at: index + 1)
        return true
    }

    /// Reorder the bag. The stacks array is dense — empty slots are always at the
    /// end — so a move is a removal and a reinsertion rather than a swap.
    @discardableResult
    mutating func move(from source: Int, to destination: Int) -> Bool {
        guard stacks.indices.contains(source), source != destination else { return false }
        let stack = stacks.remove(at: source)
        stacks.insert(stack, at: min(max(0, destination), stacks.count))
        return true
    }

    /// Replace one stack in place — used by identification, which changes how a
    /// stack reads without moving it.
    @discardableResult
    mutating func replace(at index: Int, with stack: CarriedItemStack) -> Bool {
        guard stacks.indices.contains(index), stack.quantity > 0 else { return false }
        stacks[index] = stack
        return true
    }

    @discardableResult
    mutating func takeStack(at index: Int) -> CarriedItemStack? {
        guard stacks.indices.contains(index) else { return nil }
        return stacks.remove(at: index)
    }
}

/// Result of clicking one source stack in the compact loot panel.
enum LootStackTransferResult: Hashable, Sendable {
    case coins(pence: Int)
    case item(CarriedItemStack)
    /// The selected source item remains untouched.
    case inventoryFull
}

/// One atomic take-all transaction. `itemStacks` retains source order.
struct LootTakeAllResult: Hashable, Sendable {
    let creditedPence: Int
    let itemStacks: [CarriedItemStack]

    var didTransferAnything: Bool {
        creditedPence > 0 || !itemStacks.isEmpty
    }
}

enum LootResolver {
    /// Resolve authored entries into concrete stacks (BG: tokens roll once, then lock).
    static func resolve(
        _ definition: LootContainerDefinition,
        using rng: inout some RandomNumberGenerator
    ) -> [ResolvedLootStack] {
        var stacks: [ResolvedLootStack] = []
        for entry in definition.entries {
            switch entry {
            case .coins(let pence):
                if pence > 0 {
                    stacks.append(.coins(pence: pence))
                }
            case .randomCoins(let table):
                if let pence = table.roll(using: &rng), pence > 0 {
                    stacks.append(.coins(pence: pence))
                }
            case .item(let id, let quantity):
                if quantity > 0 {
                    stacks.append(.item(id: id, quantity: quantity))
                }
            }
        }
        return stacks
    }
}

/// Persisted map of container ID → resolved stacks. Resolve-once: never re-rolls.
struct LootContainerState: Hashable, Codable, Sendable {
    private(set) var resolved: [String: [ResolvedLootStack]]

    init(resolved: [String: [ResolvedLootStack]] = [:]) {
        self.resolved = resolved
    }

    func contents(of containerID: String) -> [ResolvedLootStack]? {
        resolved[containerID]
    }

    var hasResolved: Bool { !resolved.isEmpty }

    mutating func resolveIfNeeded(
        definition: LootContainerDefinition,
        using rng: inout some RandomNumberGenerator
    ) {
        guard resolved[definition.id] == nil else { return }
        resolved[definition.id] = LootResolver.resolve(definition, using: &rng)
    }

    mutating func resolveIfNeeded(
        definitions: [LootContainerDefinition],
        using rng: inout some RandomNumberGenerator
    ) {
        for definition in definitions {
            resolveIfNeeded(definition: definition, using: &rng)
        }
    }

    @discardableResult
    mutating func takeStack(at index: Int, from containerID: String) -> ResolvedLootStack? {
        guard var stacks = resolved[containerID],
              stacks.indices.contains(index) else { return nil }
        let taken = stacks.remove(at: index)
        resolved[containerID] = stacks
        return taken
    }

    /// BG-style bulk currency pickup retained for coin-only callers. Items remain
    /// in their original relative order and a repeated call cannot pay twice.
    @discardableResult
    mutating func takeAllCoins(from containerID: String) -> Int {
        takeAll(from: containerID, itemSlotCapacity: 0)?.creditedPence ?? 0
    }

    /// Removes every positive coin stack and the first item stacks that fit,
    /// committing the rewritten container only after the complete result has
    /// been derived. Overflow items retain their original relative order.
    @discardableResult
    mutating func takeAll(
        from containerID: String,
        itemSlotCapacity: Int
    ) -> LootTakeAllResult? {
        guard let stacks = resolved[containerID] else { return nil }

        let capacity = max(0, itemSlotCapacity)
        var creditedPence = 0
        var takenItems: [CarriedItemStack] = []
        var remaining: [ResolvedLootStack] = []
        remaining.reserveCapacity(stacks.count)

        for stack in stacks {
            switch stack {
            case .coins(let pence) where pence > 0:
                creditedPence += pence
            case .item(let id, let quantity)
                where quantity > 0 && takenItems.count < capacity:
                takenItems.append(CarriedItemStack(id: id, quantity: quantity))
            default:
                remaining.append(stack)
            }
        }

        resolved[containerID] = remaining
        return LootTakeAllResult(
            creditedPence: creditedPence,
            itemStacks: takenItems
        )
    }

    /// Appends a returned carried stack to an already resolved/active source.
    /// A missing container is never created implicitly.
    @discardableResult
    mutating func appendItem(_ item: CarriedItemStack, to containerID: String) -> Bool {
        guard item.quantity > 0, var stacks = resolved[containerID] else { return false }
        stacks.append(.item(id: item.id, quantity: item.quantity))
        resolved[containerID] = stacks
        return true
    }
}

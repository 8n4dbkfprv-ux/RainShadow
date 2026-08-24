import SpriteKit

@MainActor
final class GameSession {
    /// The painted 16-slot case bag already contains these fixed starter items:
    /// revolver, notebook, brass key, torch, wallet, and cigarette case.
    static let starterInventorySlotCount = 6

    private let saveStore: SaveStore
    private(set) var hasSeenOpening: Bool
    private(set) var hasSeenOfficeHint: Bool
    /// One-shot Empty Coat office intro (monologue + Lila visit). BG:EE-style: does not replay.
    private(set) var hasCompletedOfficeCaseIntro: Bool
    private(set) var inspectedHotspotIDs: Set<String>
    /// Dialogue/case flags and queued journal fragments (flags persist in save).
    private(set) var caseState: CaseState
    private(set) var isCityTravelOpen = false
    private(set) var currentCityDistrict: CityDistrictID = .sableRow
    /// Area-scoped variables, the way Baldur's Gate keeps them in the `.ARE`.
    ///
    /// A place for an area to remember something about itself that survives
    /// leaving it. Fog stays out — that is the explored bitmask, its own `.ARE`
    /// section — and so do ground piles, which are the item and container
    /// sections. Both are already keyed by area; folding them in here would tidy
    /// the namespace and coarsen the model.
    private(set) var areaVariables: AreaVariables

    /// Variable name for a district the player has physically entered.
    /// The BG world map keeps the same fact as an area-entry flag.
    static let visitedVariable = "VISITED"

    /// Districts Voss has physically entered (BG Classic world-map reveal seed).
    var visitedCityDistricts: Set<CityDistrictID> {
        Set(CityDistrictID.allCases.filter {
            areaVariables.isSet(
                Self.visitedVariable,
                in: CityDistrictAreaAdapter.areaID(for: $0)
            )
        })
    }
    /// Every area's explored bitmask, keyed the way the engine keys it: by area.
    ///
    /// The Infinity Engine stores this in the `.ARE` and restores it when the
    /// player returns, which is why a room you have walked is still drawn on your
    /// way back in and only the people standing in it are hidden again. It used
    /// to be a list of points Voss had stood in, keyed by *district* — so the
    /// office, which is not a district, had nowhere to put anything and started
    /// black on every single entry however many times he had crossed his own
    /// floor. An interior is not a special case; it is an area.
    private var fogByArea: [AreaID: FogBitmask] = [:]
    /// Walked fog unions immediately; the save file is written after a short
    /// pause so crossing cells does not rewrite the snapshot ten times a second.
    private var fogPersistTask: Task<Void, Never>?
    private(set) var currentHealth = 12
    let maximumHealth = 12
    /// Wallet balance in pence (£/s/d via `CurrencyAmount`).
    private(set) var walletPence: Int
    /// BG resolve-once loot state for searchable containers.
    private(set) var lootContainers: LootContainerState
    /// Items lying on the floor, keyed by area id.
    private(set) var groundPiles: GroundPileState
    /// What Voss wears and carries. The starter kit lives here as real stacks —
    /// it used to be a reserved slot count with nothing behind it, which meant
    /// the six painted items could not be equipped, dropped, or moved.
    private(set) var characterInventory: CharacterInventory
    /// Whether the painted starter kit has been promoted into real stacks.
    private(set) var hasSeededStarterKit: Bool

    /// The case bag. Kept as a passthrough so every existing reader — the loot
    /// panel, both scenes, the inventory window — keeps working unchanged.
    var carriedInventory: CarriedInventoryState { characterInventory.backpack }

    /// Authored item definitions. Loaded once; content, not state.
    let itemCatalog: ItemCatalog = HarborpointItems.catalog

    private var stackLimits: ItemStackLimits { ItemStackLimits(catalog: itemCatalog) }

    /// Voss's Lore, in the AD&D sense: what he recognises on sight. A constant
    /// until `PlayerTraits` ships, matching the Resolve the character sheet shows.
    static let detectiveLore = 6

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        let snapshot = saveStore.load()
        hasSeenOpening = snapshot.hasSeenOpening
        hasSeenOfficeHint = snapshot.hasSeenOfficeHint
        hasCompletedOfficeCaseIntro = snapshot.hasCompletedOfficeCaseIntro
        inspectedHotspotIDs = snapshot.inspectedHotspotIDs
        areaVariables = AreaVariables(
            flattened: snapshot.areaVariables.reduce(into: [:]) { out, entry in
                out[entry.key] = Self.toAreaVariable(entry.value)
            }
        )
        fogByArea = snapshot.exploredFog.reduce(into: [AreaID: FogBitmask]()) { out, entry in
            out[AreaID(rawValue: entry.key)] = FogBitmask(
                columns: entry.value.columns,
                rows: entry.value.rows,
                bytes: [UInt8](entry.value.bytes)
            )
        }
        caseState = CaseState(caseID: EmptyCoatJournalContent.caseID)
        caseState.flags.formUnion(snapshot.caseFlags)
        caseState.knowledgeIDs.formUnion(snapshot.caseKnowledgeIDs)
        caseState.evidenceIDs.formUnion(snapshot.caseEvidenceIDs)
        caseState.counters = snapshot.caseCounters
        for fragment in snapshot.caseJournalFragments {
            caseState.queueJournal(Self.toQueued(fragment))
        }
        walletPence = snapshot.walletPence
        lootContainers = LootContainerState(
            resolved: snapshot.lootContainers.mapValues { $0.map(Self.toResolved) }
        )
        groundPiles = GroundPileState(
            pilesByArea: snapshot.groundPiles.mapValues { $0.map(Self.toGroundStack) }
        )
        let catalog = HarborpointItems.catalog
        var stacks = snapshot.carriedItems.map(Self.toCarried)
        hasSeededStarterKit = snapshot.hasSeededStarterKit
        if !hasSeededStarterKit {
            // One-time promotion. Older saves recorded acquired stacks only and
            // represented the starter kit as reserved capacity, so the six painted
            // items go in front of whatever was already carried.
            stacks = Self.starterStacks(catalog: catalog) + stacks
            hasSeededStarterKit = true
        }
        var inventory = CharacterInventory(
            backpack: CarriedInventoryState(stacks: stacks)
        )
        for (rawSlot, persisted) in snapshot.equippedItems {
            // An unknown slot is dropped rather than failing the load; a renamed
            // slot must not cost the player their save.
            guard let slot = EquipmentSlot(rawValue: rawSlot) else { continue }
            try? inventory.equip(Self.toCarried(persisted), in: slot, catalog: catalog)
        }
        _ = inventory.identifyEverythingKnown(lore: Self.detectiveLore, catalog: catalog)
        characterInventory = inventory
        // After intro, city travel is available whenever free-play is restored.
        if hasCompletedOfficeCaseIntro {
            isCityTravelOpen = true
        }
    }

    /// Merge dialogue outcomes into the live case (flags, knowledge, evidence, counters,
    /// journal queue). See `CaseState.applying(_:wasSeeded:)` for why a seeded result
    /// replaces rather than unions — unioning silently discarded every `clearCaseFlag`.
    func mergeCaseStateFromDialogue(_ state: CaseState, wasSeeded: Bool = true) {
        caseState = caseState.applying(state, wasSeeded: wasSeeded)
        persist()
    }

    /// Mark the Empty Coat office intro + client visit finished (no cinematic replay).
    func markOfficeCaseIntroCompleted() {
        guard !hasCompletedOfficeCaseIntro else { return }
        hasCompletedOfficeCaseIntro = true
        isCityTravelOpen = true
        persist()
    }

    /// Snapshot for journal projection (hotspots + dialogue-earned state).
    var journalProjectionInput: JournalProjectionInput {
        JournalProjectionInput(
            inspectedHotspotIDs: inspectedHotspotIDs,
            caseState: caseState
        )
    }

    func markInspected(_ id: String) {
        guard inspectedHotspotIDs.insert(id).inserted else { return }
        persist()
    }

    func markOpeningSeen() {
        guard !hasSeenOpening else { return }
        hasSeenOpening = true
        persist()
    }

    func markOfficeHintSeen() {
        guard !hasSeenOfficeHint else { return }
        hasSeenOfficeHint = true
        persist()
    }

    func markCityTravelOpen() {
        isCityTravelOpen = true
    }

    func setCurrentCityDistrict(_ id: CityDistrictID) {
        currentCityDistrict = id
        markCityDistrictVisited(id)
    }

    func markCityDistrictVisited(_ id: CityDistrictID) {
        // Persisted now, where it previously lived only for the run. BG keeps
        // "already visited" in the world-map entry and writes it to the save, so
        // a district you walked stays revealed across a relaunch.
        guard !areaVariables.isSet(
            Self.visitedVariable,
            in: CityDistrictAreaAdapter.areaID(for: id)
        ) else { return }
        areaVariables.setFlag(true, Self.visitedVariable, in: CityDistrictAreaAdapter.areaID(for: id))
        persist()
    }

    // MARK: - Area variables

    func areaVariable(_ name: String, in area: AreaID) -> AreaVariableValue? {
        areaVariables.value(name, in: area)
    }

    func setAreaVariable(_ value: AreaVariableValue?, _ name: String, in area: AreaID) {
        areaVariables.set(value, name, in: area)
        persist()
    }

    /// Adopt the variables an area script wrote.
    ///
    /// Whole-store replacement rather than a diff: the runner already applied
    /// the script's writes to a copy, and reconciling two stores field by field
    /// would be a second implementation of the same rules.
    func applyAreaScriptVariables(_ updated: AreaVariables) {
        guard updated != areaVariables else { return }
        areaVariables = updated
        persist()
    }

    @discardableResult
    func incrementAreaVariable(_ name: String, in area: AreaID, by delta: Int = 1) -> Int {
        let next = areaVariables.increment(name, in: area, by: delta)
        persist()
        return next
    }

    func setCurrentHealth(_ health: Int) {
        currentHealth = min(max(0, health), maximumHealth)
    }

    /// What an area has ever shown the player, read back onto its current grid.
    func exploredFogCells(for areaID: AreaID, on grid: FogGrid) -> Set<FogCell> {
        fogByArea[areaID].map(grid.cells(from:)) ?? []
    }

    /// Fold what an area's fog now knows into what the game remembers.
    /// Union only — an area never un-explores.
    func recordExploredFog(_ areaID: AreaID, cells: Set<FogCell>, on grid: FogGrid) {
        guard !cells.isEmpty else { return }
        let known = fogByArea[areaID].map(grid.cells(from:)) ?? []
        let grown = known.union(cells)
        guard grown != known else { return }
        fogByArea[areaID] = grid.bitmask(of: grown)
        scheduleFogPersist()
    }

    /// Flush a pending fog save (area exit, process teardown).
    func flushPendingFogPersist() {
        guard fogPersistTask != nil else { return }
        persist()
    }

    private func scheduleFogPersist() {
        fogPersistTask?.cancel()
        fogPersistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    /// BG: resolve random treasure when the area is first entered, then lock.
    func resolveOfficeLootIfNeeded() {
        var state = lootContainers
        var rng = SystemRandomNumberGenerator()
        state.resolveIfNeeded(definitions: OfficeNavigationLayout.lootContainers, using: &rng)
        guard state != lootContainers else { return }
        lootContainers = state
        persist()
    }

    func lootContents(for hotspotID: String) -> [ResolvedLootStack] {
        lootContainers.contents(of: hotspotID) ?? []
    }

    func hasLootContainer(for hotspotID: String) -> Bool {
        OfficeNavigationLayout.lootContainer(for: hotspotID) != nil
    }

    /// Take a coin stack from a container into the wallet (BG: gold never occupies a bag slot).
    @discardableResult
    func takeCoins(at index: Int, from containerID: String) -> Int? {
        var state = lootContainers
        guard let stack = state.takeStack(at: index, from: containerID),
              case .coins(let pence) = stack,
              pence > 0 else { return nil }
        lootContainers = state
        walletPence += pence
        persist()
        return pence
    }

    /// Transfers one source stack. Coins bypass the case bag; an item consumes
    /// one acquired slot. Full/invalid attempts leave both source and inventory
    /// untouched and do not write a save.
    @discardableResult
    func takeLootStack(at index: Int, from containerID: String) -> LootStackTransferResult? {
        guard let stacks = lootContainers.contents(of: containerID),
              stacks.indices.contains(index) else { return nil }

        switch stacks[index] {
        case .coins(let pence):
            guard pence > 0 else { return nil }
            var nextContainers = lootContainers
            guard nextContainers.takeStack(at: index, from: containerID) != nil else { return nil }
            lootContainers = nextContainers
            walletPence += pence
            persist()
            return .coins(pence: pence)

        case .item(let id, let quantity):
            guard quantity > 0 else { return nil }

            let item = CarriedItemStack(
                id: id,
                quantity: quantity,
                isIdentified: Self.isSelfEvident(id, catalog: itemCatalog)
            )
            var nextContainers = lootContainers
            var nextInventory = characterInventory
            do {
                try nextInventory.addToBackpack(item, limits: stackLimits)
            } catch {
                return .inventoryFull
            }
            guard nextContainers.takeStack(at: index, from: containerID) != nil else { return nil }
            // BG checks Lore the moment an item enters the pack.
            _ = nextInventory.identifyEverythingKnown(
                lore: Self.detectiveLore,
                catalog: itemCatalog
            )
            lootContainers = nextContainers
            characterInventory = nextInventory
            persist()
            return .item(item)
        }
    }

    /// Returns one acquired stack to the end of an already active/resolved
    /// container. The copy-then-commit sequence prevents either side changing
    /// when an index or destination is invalid.
    @discardableResult
    func returnCarriedItem(at index: Int, to containerID: String) -> CarriedItemStack? {
        guard let item = carriedInventory.stack(at: index) else { return nil }

        var nextContainers = lootContainers
        var nextInventory = characterInventory
        guard let taken = try? nextInventory.removeFromBackpack(at: index, catalog: itemCatalog),
              taken == item,
              nextContainers.appendItem(item, to: containerID) else { return nil }
        lootContainers = nextContainers
        characterInventory = nextInventory
        persist()
        return item
    }

    /// Takes all currency plus the first item stacks that fit, in source order.
    /// Overflow item stacks stay in the source in order. The complete transaction
    /// is persisted once, so repeat activation cannot double-credit its coins.
    @discardableResult
    func takeAllLoot(from containerID: String) -> LootTakeAllResult? {
        var nextContainers = lootContainers
        var nextInventory = characterInventory
        var nextBackpack = nextInventory.backpack
        guard let result = nextContainers.takeAll(
            from: containerID,
            itemSlotCapacity: nextBackpack.availableSlotCount
        ) else { return nil }

        let incoming = result.itemStacks.map {
            CarriedItemStack(
                id: $0.id,
                quantity: $0.quantity,
                isIdentified: Self.isSelfEvident($0.id, catalog: itemCatalog)
            )
        }
        guard nextBackpack.append(contentsOf: incoming, limits: stackLimits) else { return nil }
        nextInventory = CharacterInventory(
            equipped: nextInventory.equipped,
            backpack: nextBackpack
        )
        _ = nextInventory.identifyEverythingKnown(
            lore: Self.detectiveLore,
            catalog: itemCatalog
        )

        guard result.didTransferAnything else { return result }
        lootContainers = nextContainers
        characterInventory = nextInventory
        walletPence += result.creditedPence
        persist()
        return result
    }

    // MARK: - Equipment

    /// Equip the bag stack at `index` into `slot`. Returns the refusal when the
    /// engine's rules say no, `nil` on success. Nothing is written on a refusal.
    @discardableResult
    func equipCarriedItem(at index: Int, to slot: EquipmentSlot) -> InventoryRefusal? {
        var next = characterInventory
        do {
            try next.equipFromBackpack(
                at: index,
                to: slot,
                catalog: itemCatalog,
                limits: stackLimits
            )
        } catch let refusal as InventoryRefusal {
            return refusal
        } catch {
            return .noSuchStack(index: index)
        }
        characterInventory = next
        persist()
        return nil
    }

    /// Take a slot off into the case bag. Cursed items and a full bag both refuse.
    @discardableResult
    func unequipItem(from slot: EquipmentSlot) -> InventoryRefusal? {
        var next = characterInventory
        do {
            try next.unequipToBackpack(
                from: slot,
                catalog: itemCatalog,
                limits: stackLimits
            )
        } catch let refusal as InventoryRefusal {
            return refusal
        } catch {
            return .slotEmpty(slot: slot)
        }
        characterInventory = next
        persist()
        return nil
    }

    /// Move a stack straight from a slot into a container (BG lets you place from
    /// the paperdoll without a stop in the bag).
    @discardableResult
    func unequipItem(from slot: EquipmentSlot, into containerID: String) -> InventoryRefusal? {
        guard lootContainers.contents(of: containerID) != nil else {
            return .slotEmpty(slot: slot)
        }
        var nextInventory = characterInventory
        var nextContainers = lootContainers
        let stack: CarriedItemStack
        do {
            stack = try nextInventory.unequip(from: slot, catalog: itemCatalog)
        } catch let refusal as InventoryRefusal {
            return refusal
        } catch {
            return .slotEmpty(slot: slot)
        }
        guard nextContainers.appendItem(stack, to: containerID) else {
            return .slotEmpty(slot: slot)
        }
        characterInventory = nextInventory
        lootContainers = nextContainers
        persist()
        return nil
    }

    /// Move a worn or readied item to another slot, swapping with its occupant.
    @discardableResult
    func moveEquippedItem(from source: EquipmentSlot, to destination: EquipmentSlot) -> InventoryRefusal? {
        var next = characterInventory
        do {
            try next.moveEquipped(from: source, to: destination, catalog: itemCatalog)
        } catch let refusal as InventoryRefusal {
            return refusal
        } catch {
            return .slotEmpty(slot: source)
        }
        characterInventory = next
        persist()
        return nil
    }

    // MARK: - Bag operations

    /// Reorder the case bag.
    @discardableResult
    func moveCarriedStack(from source: Int, to destination: Int) -> Bool {
        var backpack = characterInventory.backpack
        guard backpack.move(from: source, to: destination) else { return false }
        characterInventory = CharacterInventory(
            equipped: characterInventory.equipped,
            backpack: backpack
        )
        persist()
        return true
    }


    /// Remove a carried stack entirely — the caller owns where it lands. Returns
    /// `nil` when the item refuses to be put down.
    @discardableResult
    func removeCarriedItem(at index: Int) -> CarriedItemStack? {
        var next = characterInventory
        guard let taken = try? next.removeFromBackpack(at: index, catalog: itemCatalog) else {
            return nil
        }
        characterInventory = next
        persist()
        return taken
    }

    /// BG stack splitting.
    @discardableResult
    func splitCarriedStack(at index: Int, count: Int) -> Bool {
        var next = characterInventory
        guard (try? next.splitBackpackStack(at: index, count: count)) != nil else { return false }
        characterInventory = next
        persist()
        return true
    }

    /// Right-click identification against Voss's Lore. `true` when this attempt
    /// changed something — a repeat attempt reports `false` and writes nothing.
    @discardableResult
    func identifyCarriedItem(at index: Int) -> Bool {
        var next = characterInventory
        guard (try? next.identifyBackpackStack(
            at: index,
            lore: Self.detectiveLore,
            catalog: itemCatalog
        )) == true else { return false }
        characterInventory = next
        persist()
        return true
    }

    // MARK: - Ground piles

    /// How far the quick-loot bar reaches. BG:EE gathers ground items "in a fairly
    /// large radius" around the selected character rather than only underfoot.
    static let quickLootRadius: CGFloat = 420

    func groundStacks(in areaID: String) -> [GroundItemStack] {
        groundPiles.stacks(in: areaID)
    }

    func groundStacks(in areaID: String, near point: CGPoint) -> [GroundItemStack] {
        groundPiles.stacks(in: areaID, near: point, radius: Self.quickLootRadius)
    }

    /// Put a carried stack on the floor at `position`. Undroppable items refuse
    /// and nothing is written.
    @discardableResult
    func dropCarriedItem(at index: Int, in areaID: String, at position: CGPoint) -> CarriedItemStack? {
        var nextInventory = characterInventory
        guard let stack = try? nextInventory.removeFromBackpack(at: index, catalog: itemCatalog) else {
            return nil
        }
        var nextPiles = groundPiles
        nextPiles.drop(stack, in: areaID, at: position)
        characterInventory = nextInventory
        groundPiles = nextPiles
        persist()
        return stack
    }

    /// Lift one ground stack into the case bag. Returns `nil` when the bag is full,
    /// leaving the pile untouched — BG never destroys what will not fit.
    @discardableResult
    func takeGroundStack(_ entry: GroundItemStack, in areaID: String) -> CarriedItemStack? {
        var nextInventory = characterInventory
        do {
            try nextInventory.addToBackpack(entry.stack, limits: stackLimits)
        } catch {
            return nil
        }
        var nextPiles = groundPiles
        guard nextPiles.take(entry, from: areaID) != nil else { return nil }
        _ = nextInventory.identifyEverythingKnown(lore: Self.detectiveLore, catalog: itemCatalog)
        characterInventory = nextInventory
        groundPiles = nextPiles
        persist()
        return entry.stack
    }

    // MARK: - Derived

    var carriedWeightOunces: Int {
        characterInventory.carriedWeightOunces(catalog: itemCatalog)
    }

    var encumbrance: EncumbranceReadout {
        characterInventory.encumbrance(catalog: itemCatalog)
    }

    /// The profile Voss should walk with right now. `DetectiveActorNode` reads
    /// this whenever the bag changes; until inventory weight existed, nothing
    /// ever constructed anything but `.unencumbered`.
    var detectiveMovementProfile: MovementProfile {
        MovementProfile.humanoid.encumbered(encumbrance.band)
    }

    var defenceBonus: Int {
        characterInventory.defenceBonus(catalog: itemCatalog)
    }

    var readiedWeapon: ItemDefinition? {
        characterInventory.readiedWeapon(catalog: itemCatalog)
    }

    private func persist() {
        fogPersistTask?.cancel()
        fogPersistTask = nil
        saveStore.save(SaveSnapshot(
            hasSeenOpening: hasSeenOpening,
            hasSeenOfficeHint: hasSeenOfficeHint,
            hasCompletedOfficeCaseIntro: hasCompletedOfficeCaseIntro,
            inspectedHotspotIDs: inspectedHotspotIDs,
            walletPence: walletPence,
            lootContainers: lootContainers.resolved.mapValues { $0.map(Self.toPersisted) },
            carriedItems: carriedInventory.stacks.map(Self.toPersisted),
            equippedItems: characterInventory.equipped.reduce(
                into: [String: PersistedCarriedItemStack]()
            ) { result, entry in
                result[entry.key.rawValue] = Self.toPersisted(entry.value)
            },
            groundPiles: groundPiles.pilesByArea.mapValues { $0.map(Self.toPersisted) },
            hasSeededStarterKit: hasSeededStarterKit,
            caseFlags: caseState.flags,
            caseKnowledgeIDs: caseState.knowledgeIDs,
            caseEvidenceIDs: caseState.evidenceIDs,
            caseJournalFragments: caseState.queuedJournalFragments.map(Self.toPersisted),
            caseCounters: caseState.counters,
            areaVariables: areaVariables.flattened.reduce(into: [:]) { out, entry in
                out[entry.key] = Self.toPersisted(entry.value)
            },
            exploredFog: fogByArea.reduce(into: [String: PersistedExploredFog]()) { out, entry in
                out[entry.key.rawValue] = PersistedExploredFog(
                    columns: entry.value.columns,
                    rows: entry.value.rows,
                    bytes: Data(entry.value.bytes)
                )
            }
        ))
    }

    private static func toResolved(_ stack: PersistedLootStack) -> ResolvedLootStack {
        switch stack {
        case .coins(let pence): return .coins(pence: pence)
        case .item(let id, let quantity): return .item(id: id, quantity: quantity)
        }
    }

    private static func toPersisted(_ stack: ResolvedLootStack) -> PersistedLootStack {
        switch stack {
        case .coins(let pence): return .coins(pence: pence)
        case .item(let id, let quantity): return .item(id: id, quantity: quantity)
        }
    }

    private static func toCarried(_ stack: PersistedCarriedItemStack) -> CarriedItemStack {
        CarriedItemStack(
            id: stack.id,
            quantity: stack.quantity,
            isIdentified: stack.isIdentified,
            charges: stack.charges
        )
    }

    private static func toPersisted(_ stack: CarriedItemStack) -> PersistedCarriedItemStack {
        PersistedCarriedItemStack(
            id: stack.id,
            quantity: stack.quantity,
            isIdentified: stack.isIdentified,
            charges: stack.charges
        )
    }

    private static func toGroundStack(_ stack: PersistedGroundItemStack) -> GroundItemStack {
        GroundItemStack(
            stack: CarriedItemStack(
                id: stack.id,
                quantity: stack.quantity,
                isIdentified: stack.isIdentified,
                charges: stack.charges
            ),
            position: CGPoint(x: stack.x, y: stack.y)
        )
    }

    private static func toPersisted(_ entry: GroundItemStack) -> PersistedGroundItemStack {
        PersistedGroundItemStack(
            id: entry.stack.id,
            quantity: entry.stack.quantity,
            isIdentified: entry.stack.isIdentified,
            charges: entry.stack.charges,
            x: Double(entry.x),
            y: Double(entry.y)
        )
    }

    /// The painted starter kit as real stacks, in the order the window draws them.
    private static func starterStacks(catalog: ItemCatalog) -> [CarriedItemStack] {
        HarborpointItems.starterItemIDs.compactMap { id in
            guard let definition = catalog.definition(for: id) else { return nil }
            return CarriedItemStack(
                id: id,
                quantity: 1,
                isIdentified: definition.isSelfEvident
            )
        }
    }

    private static func isSelfEvident(_ id: String, catalog: ItemCatalog) -> Bool {
        catalog.definition(for: id)?.isSelfEvident ?? true
    }

    private static func toQueued(_ fragment: PersistedJournalFragment) -> QueuedJournalFragment {
        QueuedJournalFragment(
            id: fragment.id,
            // Persistence has no Core dependency, so the mirror stores a raw string.
            // Unknown values degrade to `.note` rather than failing the load.
            kind: JournalEntryKind(rawValue: fragment.kind) ?? .note,
            text: fragment.text
        )
    }

    private static func toPersisted(_ fragment: QueuedJournalFragment) -> PersistedJournalFragment {
        PersistedJournalFragment(id: fragment.id, kind: fragment.kind.rawValue, text: fragment.text)
    }

    /// `RainShadowPersistence` is Foundation-only and knows nothing of the core
    /// module, so the save's variable type is mirrored rather than shared —
    /// the same arrangement as every other persisted value here.
    private static func toPersisted(_ value: AreaVariableValue) -> PersistedAreaVariable {
        switch value {
        case .integer(let number): PersistedAreaVariable(kind: "integer", integer: number)
        case .number(let number): PersistedAreaVariable(kind: "number", number: number)
        case .text(let text): PersistedAreaVariable(kind: "text", text: text)
        }
    }

    /// An unrecognised tag decodes as zero rather than failing the load: one
    /// unknown variable must not cost the player their save.
    private static func toAreaVariable(_ stored: PersistedAreaVariable) -> AreaVariableValue {
        switch stored.kind {
        case "number": .number(stored.number ?? 0)
        case "text": .text(stored.text ?? "")
        default: .integer(stored.integer ?? 0)
        }
    }
}

@MainActor
final class GameContext {
    let saveStore: SaveStore
    let session: GameSession
    /// Display options. Separate from `saveStore` on purpose — see `GamePreferences`.
    let preferences: GamePreferences
    lazy var router = SceneRouter(context: self)

    /// Live BG:EE zoom step, shared by every scene the router builds.
    ///
    /// GemRB keeps `zoomLevel` on `GameControl`, which outlives an area change,
    /// so walking from the office to Sable Row keeps the framing the player
    /// chose. It is not written to the save, and a new game starts at 100%.
    var cameraZoomStep = CameraZoom.defaultStep

    init() {
        let saveStore = SaveStore()
        self.saveStore = saveStore
        session = GameSession(saveStore: saveStore)
        preferences = GamePreferences()
    }

    /// `preferences` defaults to `nil` rather than to `GamePreferences()`: a
    /// default argument is evaluated in a nonisolated context, and the store is
    /// `@MainActor` like `SaveStore`.
    init(saveStore: SaveStore, preferences: GamePreferences? = nil) {
        self.saveStore = saveStore
        session = GameSession(saveStore: saveStore)
        self.preferences = preferences ?? GamePreferences()
    }
}

@MainActor
enum GameBootstrap {
    private static var retainedContext: GameContext?
    private static weak var retainedView: SKView?

    static func start(in view: SKView) {
        let context = GameContext()
        retainedContext = context
        retainedView = view

        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        view.showsDrawCount = true
        #endif

        context.router.start(in: view)
    }

    /// Discards persisted progress and starts over from the opening.
    ///
    /// The whole `GameContext` is rebuilt rather than mutated: `GameSession`
    /// reads its snapshot once at construction, and scenes capture the context
    /// they were built with, so resetting in place would leave live scenes and
    /// the router holding the old session. This is the Infinity Engine's model
    /// too — a new game is a fresh set of GLOBAL variables, not an edit to the
    /// running one.
    ///
    /// Returns `false` when there is no view to restart into (nothing has
    /// bootstrapped yet).
    @discardableResult
    static func startNewGame() -> Bool {
        guard let view = retainedView else { return false }
        // Clear through the live store so the wipe hits the same defaults suite
        // and key the running session was loaded from.
        retainedContext?.saveStore.reset()
        start(in: view)
        return true
    }
}

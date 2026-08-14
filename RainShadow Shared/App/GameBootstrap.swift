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
    /// Districts Voss has physically entered (BG Classic world-map reveal seed).
    private(set) var visitedCityDistricts: Set<CityDistrictID> = []
    private var cityFogByDistrict: [CityDistrictID: [CGPoint]] = [:]
    private(set) var currentHealth = 12
    let maximumHealth = 12
    /// Wallet balance in pence (£/s/d via `CurrencyAmount`).
    private(set) var walletPence: Int
    /// BG resolve-once loot state for searchable containers.
    private(set) var lootContainers: LootContainerState
    /// Ordered acquired stacks. Static starter items are represented by reserved
    /// capacity rather than duplicated into persistence.
    private(set) var carriedInventory: CarriedInventoryState

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        let snapshot = saveStore.load()
        hasSeenOpening = snapshot.hasSeenOpening
        hasSeenOfficeHint = snapshot.hasSeenOfficeHint
        hasCompletedOfficeCaseIntro = snapshot.hasCompletedOfficeCaseIntro
        inspectedHotspotIDs = snapshot.inspectedHotspotIDs
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
        carriedInventory = CarriedInventoryState(
            stacks: snapshot.carriedItems.map(Self.toCarried),
            reservedSlotCount: Self.starterInventorySlotCount
        )
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
        visitedCityDistricts.insert(id)
    }

    func markCityDistrictVisited(_ id: CityDistrictID) {
        visitedCityDistricts.insert(id)
    }

    func setCurrentHealth(_ health: Int) {
        currentHealth = min(max(0, health), maximumHealth)
    }

    func cityFogRevealPoints(for district: CityDistrictID) -> [CGPoint] {
        cityFogByDistrict[district] ?? []
    }

    /// Legacy accessor used by older call sites; maps to current district fog.
    var cityFogRevealPoints: [CGPoint] {
        cityFogRevealPoints(for: currentCityDistrict)
    }

    func recordCityFogReveal(_ district: CityDistrictID, point: CGPoint) {
        var points = cityFogByDistrict[district] ?? []
        guard points.last != point else { return }
        points.append(point)
        cityFogByDistrict[district] = points
    }

    func recordCityFogReveal(_ point: CGPoint) {
        recordCityFogReveal(currentCityDistrict, point: point)
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
            guard !carriedInventory.isFull else { return .inventoryFull }

            let item = CarriedItemStack(id: id, quantity: quantity)
            var nextContainers = lootContainers
            var nextInventory = carriedInventory
            guard nextInventory.append(item),
                  nextContainers.takeStack(at: index, from: containerID) != nil else { return nil }
            lootContainers = nextContainers
            carriedInventory = nextInventory
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
        var nextInventory = carriedInventory
        guard nextContainers.appendItem(item, to: containerID),
              nextInventory.takeStack(at: index) == item else { return nil }
        lootContainers = nextContainers
        carriedInventory = nextInventory
        persist()
        return item
    }

    /// Takes all currency plus the first item stacks that fit, in source order.
    /// Overflow item stacks stay in the source in order. The complete transaction
    /// is persisted once, so repeat activation cannot double-credit its coins.
    @discardableResult
    func takeAllLoot(from containerID: String) -> LootTakeAllResult? {
        var nextContainers = lootContainers
        var nextInventory = carriedInventory
        guard let result = nextContainers.takeAll(
            from: containerID,
            itemSlotCapacity: nextInventory.availableSlotCount
        ), nextInventory.append(contentsOf: result.itemStacks) else { return nil }

        guard result.didTransferAnything else { return result }
        lootContainers = nextContainers
        carriedInventory = nextInventory
        walletPence += result.creditedPence
        persist()
        return result
    }

    private func persist() {
        saveStore.save(SaveSnapshot(
            hasSeenOpening: hasSeenOpening,
            hasSeenOfficeHint: hasSeenOfficeHint,
            hasCompletedOfficeCaseIntro: hasCompletedOfficeCaseIntro,
            inspectedHotspotIDs: inspectedHotspotIDs,
            walletPence: walletPence,
            lootContainers: lootContainers.resolved.mapValues { $0.map(Self.toPersisted) },
            carriedItems: carriedInventory.stacks.map(Self.toPersisted),
            caseFlags: caseState.flags,
            caseKnowledgeIDs: caseState.knowledgeIDs,
            caseEvidenceIDs: caseState.evidenceIDs,
            caseJournalFragments: caseState.queuedJournalFragments.map(Self.toPersisted),
            caseCounters: caseState.counters
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
        CarriedItemStack(id: stack.id, quantity: stack.quantity)
    }

    private static func toPersisted(_ stack: CarriedItemStack) -> PersistedCarriedItemStack {
        PersistedCarriedItemStack(id: stack.id, quantity: stack.quantity)
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
}

@MainActor
final class GameContext {
    let saveStore: SaveStore
    let session: GameSession
    lazy var router = SceneRouter(context: self)

    init() {
        let saveStore = SaveStore()
        self.saveStore = saveStore
        session = GameSession(saveStore: saveStore)
    }

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        session = GameSession(saveStore: saveStore)
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

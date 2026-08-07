import SpriteKit

@MainActor
final class GameSession {
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

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        let snapshot = saveStore.load()
        hasSeenOpening = snapshot.hasSeenOpening
        hasSeenOfficeHint = snapshot.hasSeenOfficeHint
        hasCompletedOfficeCaseIntro = snapshot.hasCompletedOfficeCaseIntro
        inspectedHotspotIDs = snapshot.inspectedHotspotIDs
        caseState = CaseState(caseID: EmptyCoatJournalContent.caseID)
        caseState.flags.formUnion(snapshot.caseFlags)
        walletPence = snapshot.walletPence
        lootContainers = LootContainerState(
            resolved: snapshot.lootContainers.mapValues { $0.map(Self.toResolved) }
        )
        // After intro, city travel is available whenever free-play is restored.
        if hasCompletedOfficeCaseIntro {
            isCityTravelOpen = true
        }
    }

    /// Merge dialogue outcomes into the live case (flags, knowledge, evidence, journal queue).
    func mergeCaseStateFromDialogue(_ state: CaseState) {
        caseState.flags.formUnion(state.flags)
        caseState.knowledgeIDs.formUnion(state.knowledgeIDs)
        caseState.evidenceIDs.formUnion(state.evidenceIDs)
        for fragment in state.queuedJournalFragments {
            caseState.queueJournal(fragment)
        }
        if caseState.caseID.isEmpty {
            caseState.caseID = state.caseID
        }
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
              case .coins(let pence) = stack else { return nil }
        lootContainers = state
        walletPence += pence
        persist()
        return pence
    }

    private func persist() {
        saveStore.save(SaveSnapshot(
            hasSeenOpening: hasSeenOpening,
            hasSeenOfficeHint: hasSeenOfficeHint,
            hasCompletedOfficeCaseIntro: hasCompletedOfficeCaseIntro,
            inspectedHotspotIDs: inspectedHotspotIDs,
            walletPence: walletPence,
            lootContainers: lootContainers.resolved.mapValues { $0.map(Self.toPersisted) },
            caseFlags: caseState.flags
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

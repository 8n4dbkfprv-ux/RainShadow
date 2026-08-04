import SpriteKit

@MainActor
final class GameSession {
    private let saveStore: SaveStore
    private(set) var hasSeenOpening: Bool
    private(set) var hasSeenOfficeHint: Bool
    private(set) var inspectedHotspotIDs: Set<String>
    /// Dialogue/case flags and queued journal fragments (session memory; not yet saved).
    private(set) var caseState: CaseState
    private(set) var isCityTravelOpen = false
    private(set) var currentCityDistrict: CityDistrictID = .sableRow
    private var cityFogByDistrict: [CityDistrictID: [CGPoint]] = [:]
    private(set) var currentHealth = 12
    let maximumHealth = 12

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        let snapshot = saveStore.load()
        hasSeenOpening = snapshot.hasSeenOpening
        hasSeenOfficeHint = snapshot.hasSeenOfficeHint
        inspectedHotspotIDs = snapshot.inspectedHotspotIDs
        caseState = CaseState(caseID: EmptyCoatJournalContent.caseID)
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

    private func persist() {
        saveStore.save(SaveSnapshot(
            hasSeenOpening: hasSeenOpening,
            hasSeenOfficeHint: hasSeenOfficeHint,
            inspectedHotspotIDs: inspectedHotspotIDs
        ))
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

    static func start(in view: SKView) {
        let context = GameContext()
        retainedContext = context

        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        #if DEBUG
        view.showsFPS = true
        view.showsNodeCount = true
        view.showsDrawCount = true
        #endif

        context.router.start(in: view)
    }
}

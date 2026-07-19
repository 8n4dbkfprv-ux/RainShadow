import SpriteKit

@MainActor
final class GameSession {
    private let saveStore: SaveStore
    private(set) var hasSeenOpening: Bool
    private(set) var hasSeenOfficeHint: Bool
    private(set) var inspectedHotspotIDs: Set<String>
    private(set) var cityFogRevealPoints: [CGPoint] = []
    private(set) var currentHealth = 12
    let maximumHealth = 12

    init(saveStore: SaveStore) {
        self.saveStore = saveStore
        let snapshot = saveStore.load()
        hasSeenOpening = snapshot.hasSeenOpening
        hasSeenOfficeHint = snapshot.hasSeenOfficeHint
        inspectedHotspotIDs = snapshot.inspectedHotspotIDs
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

    func setCurrentHealth(_ health: Int) {
        currentHealth = min(max(0, health), maximumHealth)
    }

    func recordCityFogReveal(_ point: CGPoint) {
        guard cityFogRevealPoints.last != point else { return }
        cityFogRevealPoints.append(point)
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

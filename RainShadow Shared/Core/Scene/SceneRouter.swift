import SpriteKit

enum GameRoute {
    case openingExterior
    case detectiveOffice
    case cityDistrict(CityDistrictID)
}

@MainActor
final class SceneRouter {
    unowned let context: GameContext
    private weak var view: SKView?
    private(set) var isTransitioning = false
    private var pendingCityArrivalKey: String?

    init(context: GameContext) {
        self.context = context
    }

    func start(in view: SKView) {
        self.view = view
        // QA hook: jump straight to a scene, e.g. RAINSHADOW_START_SCENE=office.
        if ProcessInfo.processInfo.environment["RAINSHADOW_START_SCENE"] == "office" {
            context.session.markOpeningSeen()
            present(.detectiveOffice, transition: nil)
            return
        }
        if ProcessInfo.processInfo.environment["RAINSHADOW_START_SCENE"] == "city" {
            context.session.markOpeningSeen()
            context.session.markCityTravelOpen()
            context.session.markCityDistrictVisited(.sableRow)
            present(.cityDistrict(.sableRow), transition: nil)
            return
        }
        present(.openingExterior, transition: nil)
    }

    func showOffice(arrivalKey: String? = nil) {
        guard !isTransitioning else { return }
        isTransitioning = true
        context.session.markOpeningSeen()
        _ = arrivalKey

        let transition = SKTransition.crossFade(withDuration: 1.15)
        transition.pausesOutgoingScene = false
        transition.pausesIncomingScene = false
        present(.detectiveOffice, transition: transition)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isTransitioning = false
        }
    }

    func showCityDistrict(
        _ districtID: CityDistrictID = .sableRow,
        arrivalKey: String? = nil
    ) {
        guard !isTransitioning else { return }
        isTransitioning = true
        context.session.markCityTravelOpen()
        context.session.setCurrentCityDistrict(districtID)
        pendingCityArrivalKey = arrivalKey

        let transition = SKTransition.crossFade(withDuration: 0.75)
        transition.pausesOutgoingScene = false
        transition.pausesIncomingScene = false
        present(.cityDistrict(districtID), transition: transition)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.isTransitioning = false
        }
    }

    private func present(_ route: GameRoute, transition: SKTransition?) {
        guard let view else { return }
        let scene: BaseGameScene
        switch route {
        case .openingExterior:
            scene = OpeningExteriorScene(context: context)
        case .detectiveOffice:
            scene = DetectiveOfficeScene(context: context)
        case .cityDistrict(let districtID):
            let arrival = pendingCityArrivalKey
            pendingCityArrivalKey = nil
            scene = CityDistrictScene(
                context: context,
                districtID: districtID,
                arrivalKey: arrival
            )
        }

        scene.scaleMode = .resizeFill
        if let transition, view.scene != nil {
            view.presentScene(scene, transition: transition)
        } else {
            view.presentScene(scene)
        }
    }
}

import SpriteKit

enum GameRoute {
    case openingExterior
    case detectiveOffice
}

@MainActor
final class SceneRouter {
    unowned let context: GameContext
    private weak var view: SKView?
    private(set) var isTransitioning = false

    init(context: GameContext) {
        self.context = context
    }

    func start(in view: SKView) {
        self.view = view
        present(.openingExterior, transition: nil)
    }

    func showOffice() {
        guard !isTransitioning else { return }
        isTransitioning = true
        context.session.markOpeningSeen()

        let transition = SKTransition.crossFade(withDuration: 1.15)
        transition.pausesOutgoingScene = false
        transition.pausesIncomingScene = false
        present(.detectiveOffice, transition: transition)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
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
        }

        scene.scaleMode = .resizeFill
        if let transition, view.scene != nil {
            view.presentScene(scene, transition: transition)
        } else {
            view.presentScene(scene)
        }
    }
}

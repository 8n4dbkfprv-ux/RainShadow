import SpriteKit

@MainActor
class BaseGameScene: SKScene {
    let context: GameContext
    let artSize: CGSize

    let backgroundRoot = SKNode()
    let floorEffectRoot = SKNode()
    let rearFixtureRoot = SKNode()
    let depthWorldRoot = SKNode()
    let occlusionRoot = SKNode()
    let weatherRoot = SKNode()
    let cinematicRoot = SKNode()
    let debugRoot = SKNode()
    let gameCamera = SKCameraNode()
    let hudRoot = SKNode()

    private var hasBuiltScene = false
    private(set) var baseCameraScale: CGFloat = 1

    var referenceVisibleHeight: CGFloat { 1_152 }

    init(context: GameContext, artSize: CGSize) {
        self.context = context
        self.artSize = artSize
        super.init(size: CGSize(width: 2_048, height: 1_152))
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.018, green: 0.022, blue: 0.03, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("RainShadow scenes are created programmatically")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        if !hasBuiltScene {
            installLayerTree()
            buildScene()
            hasBuiltScene = true
        }
        layoutViewport()
        sceneDidBecomeReady()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutViewport()
    }

    func buildScene() {}
    func sceneDidBecomeReady() {}
    func handlePointerUp(_ event: GamePointerEvent) {}
    func handlePointerMoved(_ event: GamePointerEvent) {}
    func handleDirectionalInput(_ direction: CGVector) {}
    func handleConfirmInput() {}
    func handleInventoryInput() {}

    func layoutViewport() {
        guard size.height > 0 else { return }
        baseCameraScale = referenceVisibleHeight / size.height
        gameCamera.setScale(baseCameraScale)
    }

    func updateDepth(of node: SKNode, bias: CGFloat = 0) {
        node.zPosition = SceneLayer.depthWorld.rawValue
            + (artSize.height - node.position.y) * 0.5
            + bias
    }

    private func installLayerTree() {
        let layers: [(SKNode, SceneLayer)] = [
            (backgroundRoot, .background),
            (floorEffectRoot, .floorEffects),
            (rearFixtureRoot, .rearFixtures),
            (depthWorldRoot, .depthWorld),
            (occlusionRoot, .occlusion),
            (weatherRoot, .weather),
            (cinematicRoot, .cinematic),
            (debugRoot, .hud)
        ]
        for (root, layer) in layers {
            root.zPosition = layer.rawValue
            addChild(root)
        }

        camera = gameCamera
        addChild(gameCamera)
        hudRoot.zPosition = SceneLayer.hud.rawValue
        gameCamera.addChild(hudRoot)
    }
}

#if os(iOS)
import UIKit

extension BaseGameScene {
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handlePointerUp(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }
}
#elseif os(macOS)
import AppKit

extension BaseGameScene {
    override func mouseUp(with event: NSEvent) {
        handlePointerUp(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func mouseMoved(with event: NSEvent) {
        handlePointerMoved(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        switch event.keyCode {
        case 0, 123: handleDirectionalInput(CGVector(dx: -1, dy: 0)) // A / left
        case 2, 124: handleDirectionalInput(CGVector(dx: 1, dy: 0)) // D / right
        case 1, 125: handleDirectionalInput(CGVector(dx: 0, dy: -1)) // S / down
        case 13, 126: handleDirectionalInput(CGVector(dx: 0, dy: 1)) // W / up
        case 34: handleInventoryInput() // I
        case 36, 49, 53: handleConfirmInput() // return / space / escape
        default: super.keyDown(with: event)
        }
    }
}
#endif

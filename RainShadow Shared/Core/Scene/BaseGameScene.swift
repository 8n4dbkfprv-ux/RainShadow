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
    /// Screen-locked chrome parented to the camera (identity scale). Child positions
    /// use viewport-centered points where `±size/2` are the view edges.
    let hudRoot = SKNode()

    private var hasBuiltScene = false
    private var isPerformingLayout = false
    private(set) var baseCameraScale: CGFloat = 1
    #if os(iOS)
    private var twoFingerCancelIsActive = false
    #endif

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
        // First present can still carry the init size (2048×1152). Match the live
        // SKView *before* any HUD layout so the left rail is not framed off-screen.
        syncSizeFromViewIfNeeded()
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
    func handlePointerDown(_ event: GamePointerEvent) {}
    func handlePointerDragged(_ event: GamePointerEvent) {}
    func handlePointerUp(_ event: GamePointerEvent) {}
    func handlePointerCancelled(_ event: GamePointerEvent) {}
    func handlePointerMoved(_ event: GamePointerEvent) {}
    func handleScrollInput(_ deltaY: CGFloat) {}
    func handleDirectionalInput(_ direction: CGVector) {}
    func handleConfirmInput() {}
    func handleInventoryInput() {}
    func handleMapInput() {}
    func handleJournalInput() {}
    func handleCancelInput() {}

    /// Viewport used for all HUD chrome. After `syncSizeFromViewIfNeeded()`, this is
    /// the live SKView point size (and equals `scene.size`).
    var hudViewportSize: CGSize { size }

    /// Keep `scene.size` equal to the SKView's point bounds under `.resizeFill`.
    @discardableResult
    func syncSizeFromViewIfNeeded() -> Bool {
        guard let view, view.bounds.width > 1, view.bounds.height > 1 else { return false }
        let viewSize = view.bounds.size
        guard abs(size.width - viewSize.width) > 0.5
            || abs(size.height - viewSize.height) > 0.5 else { return false }
        size = viewSize
        return true
    }

    func layoutViewport() {
        // Re-entrancy: assigning `size` triggers `didChangeSize` → `layoutViewport`.
        // The nested call is ignored; this outer call continues with the new size.
        if isPerformingLayout { return }
        isPerformingLayout = true
        defer { isPerformingLayout = false }

        _ = syncSizeFromViewIfNeeded()
        guard size.height > 0, size.width > 0 else { return }

        // Uniform orthographic play zoom only — fixed dimetric projection.
        baseCameraScale = DefaultPlayZoom.cameraScale(
            visibleWorldHeight: referenceVisibleHeight,
            sceneHeight: size.height
        )
        gameCamera.setScale(baseCameraScale)

        // Camera-child HUD: identity transform relative to the camera. Apple's
        // camera counter-transform keeps ±size/2 on the view edges at any zoom.
        hudRoot.position = .zero
        hudRoot.setScale(1)
    }

    /// No-op kept for call sites that previously re-anchored a world-space HUD.
    /// Camera-child chrome tracks the camera automatically.
    func syncHudToCamera() {
        hudRoot.position = .zero
        hudRoot.setScale(1)
    }

    func updateDepth(of node: SKNode, bias: CGFloat = 0) {
        node.zPosition = SceneLayer.depthWorld.rawValue
            + (artSize.height - node.position.y) * 0.5
            + bias
    }

    private static let movementFeedbackNodeName = "movement.command.feedback"

    /// Compact Infinity-Engine-style order feedback. Valid orders land on the
    /// resolved ground point; invalid ones briefly mark the rejected click.
    func showMovementFeedback(at point: CGPoint, isValid: Bool) {
        clearMovementFeedback()

        let marker = SKShapeNode(ellipseOf: CGSize(width: 38, height: 19))
        marker.name = Self.movementFeedbackNodeName
        marker.position = point
        marker.fillColor = .clear
        marker.strokeColor = isValid
            ? SKColor(red: 0.28, green: 0.86, blue: 0.78, alpha: 0.95)
            : SKColor(red: 0.9, green: 0.25, blue: 0.22, alpha: 0.95)
        marker.lineWidth = 3
        marker.alpha = 0
        marker.zPosition = 20
        floorEffectRoot.addChild(marker)

        marker.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.05),
                .scale(to: 0.82, duration: 0.12)
            ]),
            .wait(forDuration: 0.28),
            .fadeOut(withDuration: 0.25),
            .removeFromParent()
        ]))
    }

    /// Removes any live move-order ring (e.g. when Escape / right-click cancels a walk).
    func clearMovementFeedback() {
        floorEffectRoot.childNode(withName: Self.movementFeedbackNodeName)?.removeFromParent()
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
        // Screen-locked HUD as camera child (identity scale). This is the SpriteKit
        // contract for fixed chrome; world-space scaling previously allowed a stale
        // init size to map the left rail past the visible left edge.
        hudRoot.zPosition = SceneLayer.hud.rawValue
        hudRoot.position = .zero
        hudRoot.setScale(1)
        gameCamera.addChild(hudRoot)
    }
}

#if os(iOS)
import UIKit

extension BaseGameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let activeTouchCount = event?.allTouches?.filter {
            $0.phase != .ended && $0.phase != .cancelled
        }.count ?? touches.count
        if activeTouchCount >= 2 {
            if !twoFingerCancelIsActive {
                twoFingerCancelIsActive = true
                if let touch = touches.first {
                    handlePointerCancelled(
                        GamePointerEvent(location: touch.location(in: self), kind: .touch)
                    )
                }
                handleCancelInput()
            }
            return
        }
        guard !twoFingerCancelIsActive else { return }
        guard let touch = touches.first else { return }
        handlePointerDown(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !twoFingerCancelIsActive else { return }
        guard let touch = touches.first else { return }
        handlePointerDragged(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if twoFingerCancelIsActive {
            let hasActiveTouches = event?.allTouches?.contains {
                $0.phase != .ended && $0.phase != .cancelled
            } ?? false
            if !hasActiveTouches { twoFingerCancelIsActive = false }
            return
        }
        guard let touch = touches.first else { return }
        handlePointerUp(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if twoFingerCancelIsActive {
            let hasActiveTouches = event?.allTouches?.contains {
                $0.phase != .ended && $0.phase != .cancelled
            } ?? false
            if !hasActiveTouches { twoFingerCancelIsActive = false }
            return
        }
        guard let touch = touches.first else { return }
        handlePointerCancelled(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }
}
#elseif os(macOS)
import AppKit

extension BaseGameScene {
    override func mouseDown(with event: NSEvent) {
        handlePointerDown(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func mouseDragged(with event: NSEvent) {
        handlePointerDragged(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func mouseUp(with event: NSEvent) {
        handlePointerUp(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func mouseMoved(with event: NSEvent) {
        handlePointerMoved(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func scrollWheel(with event: NSEvent) {
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        handleScrollInput(event.scrollingDeltaY * multiplier)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0, 123: handleDirectionalInput(CGVector(dx: -1, dy: 0)) // A / left
        case 2, 124: handleDirectionalInput(CGVector(dx: 1, dy: 0)) // D / right
        case 1, 125: handleDirectionalInput(CGVector(dx: 0, dy: -1)) // S / down
        case 13, 126: handleDirectionalInput(CGVector(dx: 0, dy: 1)) // W / up
        case 34 where !event.isARepeat: handleInventoryInput() // I
        case 46 where !event.isARepeat: handleMapInput() // M
        case 38 where !event.isARepeat: handleJournalInput() // J
        case 36, 49: // return / space
            if !event.isARepeat { handleConfirmInput() }
        case 53 where !event.isARepeat: handleCancelInput() // escape
        default: super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        handleCancelInput()
    }
}
#endif

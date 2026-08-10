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
    private var twoFingerGestureIsActive = false
    /// Wall-clock start of the active single-finger press (long-press → waypoint queue).
    private var touchDownTime: TimeInterval?
    private var touchDownLocation: CGPoint?
    private static let longPressQueueDuration: TimeInterval = 0.45
    private static let longPressMoveSlop: CGFloat = 12
    /// Two-finger centroid in view points, tracked so the gesture can pan the
    /// viewport — the touch stand-in for BG's middle-drag.
    private var twoFingerAnchor: CGPoint?
    private var twoFingerPanDistance: CGFloat = 0
    /// Below this much travel the gesture is a two-finger *tap* (clear targeting)
    /// rather than a pan.
    private static let twoFingerTapSlop: CGFloat = 12
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
    /// Arrow / WASD press. Return `true` when an open overlay consumed it;
    /// otherwise the key falls through to viewport scrolling. These keys never
    /// move the actor (GDD §8.3, movement roadmap frozen rule 1).
    func handleDirectionalInput(_ direction: CGVector) -> Bool { false }
    func handleConfirmInput() {}
    /// Digit 1…9 for dialogue reply selection (BG:EE number-key choices). No-op by default.
    func handleDialogueChoiceDigit(_ digit: Int) {}

    // MARK: - Dialogue

    /// Shared BG-style conversation panel.
    ///
    /// This used to be a `private let` on `DetectiveOfficeScene`, which meant the office
    /// was the only place in the game where anyone could talk. Every scene now has the
    /// panel and the one presentation door below; a scene opts in by forwarding input to
    /// it, exactly as the office does.
    let dialoguePresenter = DialoguePresenter()
    /// True while the panel owns input and the world is paused.
    var dialogueIsActive = false

    /// Fired as each node appears — voice-over and presentation cues. Scenes override.
    func dialogueNodeDidShow(_ node: CaseDialogueNode) {}

    /// The one door for presenting authored dialogue.
    ///
    /// Seeding and merging are a pair. A conversation that is not seeded from the live
    /// case cannot evaluate `hasFlag` / `hasEvidence` / `hasKnowledge` gates at all, and
    /// one that is not merged back discards everything it granted.
    ///
    /// - Parameter ownerID: The conversation's owner, if any. Its talk count (IE
    ///   `NumTimesTalkedTo`) is bumped when the conversation **ends**, so a graph can gate
    ///   an alternate opening on `timesTalkedTo(ownerID:atLeast:)`.
    func presentDialogue(
        _ graph: DialogueGraph,
        ownerID: String? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        dialoguePresenter.onNodeShown = { [weak self] node in
            self?.dialogueNodeDidShow(node)
        }
        dialoguePresenter.present(
            graph: graph,
            context: DialogueRuntimeContext(
                caseState: context.session.caseState,
                dialogueState: DialogueState(graphID: graph.id)
            )
        ) { [weak self] in
            guard let self else { return }
            var finished = self.dialoguePresenter.runtimeContext.caseState
            if let ownerID {
                finished.noteTalk(with: ownerID)
            }
            self.context.session.mergeCaseStateFromDialogue(finished)
            onComplete?()
        }
    }

    /// Scene point → dialogue-panel point. Scenes decide *when* to forward input; this
    /// only removes the two-hop conversion from every call site.
    func dialoguePanelPoint(for sceneLocation: CGPoint) -> CGPoint {
        let hudPoint = hudRoot.convert(sceneLocation, from: self)
        return dialoguePresenter.convert(hudPoint, from: hudRoot)
    }
    func handleInventoryInput() {}
    func handleMapInput() {}
    func handleJournalInput() {}
    /// BG:EE Stop. Escape only — right-click no longer cancels movement.
    func handleCancelInput() {}
    /// BG:EE right-click / two-finger tap: drop any targeting mode and reset the
    /// action bar, leaving an in-progress path alone.
    func handleClearTargetingInput() {}

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

    // MARK: - Viewport

    /// Infinity Engine viewport model.
    ///
    /// BG:EE does not tether the camera to the party. The player scrolls the
    /// viewport freely — screen edge, middle-drag, arrow keys — and re-centres
    /// deliberately, by double-clicking the ground (`MoveViewportTo(p, true)`)
    /// or double-clicking a portrait.
    ///
    /// RainShadow keeps `following` as the *default* because a lone detective is
    /// easier to lose than a six-portrait party, but any manual scroll detaches
    /// to `free`, which is how the engine behaves the moment you touch the view.
    enum CameraMode: Equatable {
        case following
        case free
    }

    private(set) var cameraMode: CameraMode = .following
    /// Authoritative camera target while `free`; unused while `following`.
    private var freeCameraTarget: CGPoint = .zero
    /// Live scroll direction in scene axes (+y up) from edge or keyboard input.
    private var cameraScrollVector: CGVector = .zero
    private var lastCameraUpdateTime: TimeInterval?
    #if os(macOS)
    private var heldScrollKeys: Set<UInt16> = []
    #endif

    /// Viewport scroll rate: one visible screen height per second.
    ///
    /// BG stores `Keyboard Scroll Speed` (64) and `Mouse Scroll Speed` in engine
    /// pixels per frame, which are bound to its fixed resolution and tick rate.
    /// A screen-relative rate covers the same proportion of the view per second
    /// on any window, which is the property those constants were really encoding.
    var cameraScrollSpeed: CGFloat { referenceVisibleHeight }

    /// Distance from the view edge that starts an edge scroll (BG `EdgeScrollOffset`).
    static let edgeScrollInset: CGFloat = 16

    /// Hands the viewport to the player at its current position. Called by every
    /// manual scroll so the camera stops chasing the actor mid-gesture.
    func detachCamera() {
        guard cameraMode != .free else { return }
        cameraMode = .free
        freeCameraTarget = gameCamera.position
    }

    /// BG:EE `MoveViewportTo(p, center: true)` — the double-click recentre. Leaves
    /// the viewport free so it holds the point instead of snapping back next frame.
    func recenterCamera(on point: CGPoint) {
        cameraMode = .free
        freeCameraTarget = point
    }

    /// Re-attaches the viewport to the actor (BG:EE portrait double-click).
    func followCamera() {
        cameraMode = .following
        cameraScrollVector = .zero
    }

    /// Scroll direction from edge hover or held keys; `.zero` stops the scroll.
    func setCameraScroll(_ vector: CGVector) {
        guard vector != cameraScrollVector else { return }
        if vector != .zero { detachCamera() }
        cameraScrollVector = vector
    }

    /// Middle-drag pan. `viewDelta` is in view points; BG scrolls the viewport
    /// *with* the mouse (`Scroll(me.Delta())`) rather than dragging the world
    /// under it, so the sign is not inverted here.
    func panCamera(byViewDelta viewDelta: CGVector) {
        guard viewDelta != .zero else { return }
        detachCamera()
        freeCameraTarget.x += viewDelta.dx * baseCameraScale
        freeCameraTarget.y += viewDelta.dy * baseCameraScale
    }

    /// Per-frame viewport update. Scenes call this instead of assigning
    /// `gameCamera.position` directly so follow, free scroll, and the world-edge
    /// clamp all stay in one place.
    func updateCamera(following target: CGPoint, in bounds: CGRect, at currentTime: TimeInterval) {
        defer { lastCameraUpdateTime = currentTime }
        guard size.width > 0, size.height > 0 else { return }

        switch cameraMode {
        case .following:
            gameCamera.position = clampedCameraPosition(following: target, in: bounds)
        case .free:
            if cameraScrollVector != .zero, let previous = lastCameraUpdateTime {
                let delta = min(
                    max(0, currentTime - previous),
                    ActorLocomotionPacing.maximumFrameDelta
                )
                let step = cameraScrollSpeed * CGFloat(delta)
                freeCameraTarget.x += cameraScrollVector.dx * step
                freeCameraTarget.y += cameraScrollVector.dy * step
            }
            gameCamera.position = clampedCameraPosition(following: freeCameraTarget, in: bounds)
        }
    }

    /// Scroll vector implied by a pointer sitting near the view edge. `hudPoint`
    /// is viewport-centred (`hudRoot` space), where `±size/2` are the edges.
    func edgeScrollVector(forHudPoint hudPoint: CGPoint) -> CGVector {
        let limitX = size.width / 2 - Self.edgeScrollInset
        let limitY = size.height / 2 - Self.edgeScrollInset
        var vector = CGVector.zero
        if hudPoint.x < -limitX {
            vector.dx = -1
        } else if hudPoint.x > limitX {
            vector.dx = 1
        }
        if hudPoint.y < -limitY {
            vector.dy = -1
        } else if hudPoint.y > limitY {
            vector.dy = 1
        }
        return vector
    }

    /// Camera position that follows `target` without ever showing past the world
    /// edges — Infinity Engine framing, where the viewport pans inside the plate
    /// rather than the plate floating inside a larger viewport.
    ///
    /// At the BG1 play density the visible height is well under any area plate,
    /// so both the office and the city districts pan rather than sit fixed.
    /// `bounds` is a rect, not a size: the office plate is centred on its layout
    /// focus rather than anchored at the origin.
    func clampedCameraPosition(following target: CGPoint, in bounds: CGRect) -> CGPoint {
        let halfWidth = size.width * baseCameraScale / 2
        let halfHeight = referenceVisibleHeight / 2
        return CGPoint(
            x: Self.clampAxis(target.x, half: halfWidth, min: bounds.minX, max: bounds.maxX),
            y: Self.clampAxis(target.y, half: halfHeight, min: bounds.minY, max: bounds.maxY)
        )
    }

    /// Centres the axis outright when the plate is narrower than the viewport,
    /// instead of pinning it to the far edge.
    private static func clampAxis(
        _ value: CGFloat,
        half: CGFloat,
        min lowerEdge: CGFloat,
        max upperEdge: CGFloat
    ) -> CGFloat {
        let lower = lowerEdge + half
        let upper = upperEdge - half
        guard upper > lower else { return (lowerEdge + upperEdge) / 2 }
        return Swift.min(Swift.max(value, lower), upper)
    }

    func updateDepth(of node: SKNode, bias: CGFloat = 0) {
        node.zPosition = SceneLayer.depthWorld.rawValue
            + (artSize.height - node.position.y) * 0.5
            + bias
    }

    private static let movementFeedbackNodeName = "movement.command.feedback"
    private static let waypointPipNodeName = "movement.waypoint.pip"
    private static let moveMarkerFrameCount = 8
    private static let moveMarkerDisplaySize = CGSize(width: 48, height: 24)
    private static let waypointPipDisplaySize = CGSize(width: 28, height: 14)

    /// Local z that clears `SceneLayer.occlusion` while still parented under
    /// `floorEffectRoot` (whose layer z is `SceneLayer.floorEffects`). Tall door /
    /// cutaway art otherwise swallows blocked markers near exit approaches.
    private static var movementFeedbackLocalZ: CGFloat {
        SceneLayer.occlusion.rawValue - SceneLayer.floorEffects.rawValue + 20
    }

    /// Compact Infinity-Engine-style order feedback. Valid orders land on the
    /// resolved ground point; invalid ones briefly mark the rejected click.
    /// Prefer painted `ui_move_marker_*` / blocked frames; fall back to a coded ellipse.
    func showMovementFeedback(at point: CGPoint, isValid: Bool) {
        clearMovementFeedback()

        if let textures = moveMarkerTextures(isValid: isValid), !textures.isEmpty {
            let marker = SKSpriteNode(texture: textures[0], size: Self.moveMarkerDisplaySize)
            marker.name = Self.movementFeedbackNodeName
            marker.position = point
            marker.zPosition = Self.movementFeedbackLocalZ
            marker.alpha = 0
            floorEffectRoot.addChild(marker)

            // Match IE destination feedback pacing: readable snap-in, then settle/fade.
            let frameTime = 0.065
            let animate = SKAction.animate(with: textures, timePerFrame: frameTime)
            marker.run(.sequence([
                .group([
                    .fadeIn(withDuration: 0.03),
                    animate
                ]),
                .fadeOut(withDuration: 0.14),
                .removeFromParent()
            ]))
            return
        }

        let marker = SKShapeNode(ellipseOf: CGSize(width: 38, height: 19))
        marker.name = Self.movementFeedbackNodeName
        marker.position = point
        marker.fillColor = .clear
        marker.strokeColor = isValid
            ? SKColor(red: 0.28, green: 0.86, blue: 0.78, alpha: 0.95)
            : SKColor(red: 0.9, green: 0.25, blue: 0.22, alpha: 0.95)
        marker.lineWidth = 3
        marker.alpha = 0
        marker.zPosition = Self.movementFeedbackLocalZ
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

    /// Removes any live move-order marker (e.g. when Escape / right-click cancels a walk).
    func clearMovementFeedback() {
        floorEffectRoot.childNode(withName: Self.movementFeedbackNodeName)?.removeFromParent()
    }

    /// Persistent pip at a queued BG:EE-style waypoint until that leg is reached.
    func showWaypointPip(at point: CGPoint) {
        let pip: SKNode
        if let texture = GameArt.texture(named: "ui_waypoint_pip") {
            let sprite = SKSpriteNode(texture: texture, size: Self.waypointPipDisplaySize)
            sprite.alpha = 0.92
            pip = sprite
        } else {
            let shape = SKShapeNode(ellipseOf: CGSize(width: 22, height: 11))
            shape.fillColor = .clear
            shape.strokeColor = SKColor(red: 0.28, green: 0.86, blue: 0.78, alpha: 0.85)
            shape.lineWidth = 2
            pip = shape
        }
        pip.name = Self.waypointPipNodeName
        pip.position = point
        pip.zPosition = 18
        floorEffectRoot.addChild(pip)
    }

    /// Removes every queued-waypoint pip (cancel / replace-on-click).
    func clearWaypointPips() {
        while let pip = floorEffectRoot.childNode(withName: Self.waypointPipNodeName) {
            pip.removeFromParent()
        }
    }

    /// Removes the pip nearest `point` (leg completed).
    func removeWaypointPip(nearest point: CGPoint, within tolerance: CGFloat = 24) {
        var best: SKNode?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for child in floorEffectRoot.children where child.name == Self.waypointPipNodeName {
            let distance = hypot(child.position.x - point.x, child.position.y - point.y)
            if distance < bestDistance {
                bestDistance = distance
                best = child
            }
        }
        if bestDistance <= tolerance {
            best?.removeFromParent()
        }
    }

    private func moveMarkerTextures(isValid: Bool) -> [SKTexture]? {
        if isValid {
            let frames = (0..<Self.moveMarkerFrameCount).compactMap { index in
                GameArt.texture(named: String(format: "ui_move_marker_%02d", index))
            }
            return frames.count == Self.moveMarkerFrameCount ? frames : nil
        }
        let frames = (0..<Self.moveMarkerFrameCount).compactMap { index in
            GameArt.texture(named: String(format: "ui_move_marker_blocked_%02d", index))
        }
        if frames.count == Self.moveMarkerFrameCount { return frames }
        if let single = GameArt.texture(named: "ui_move_marker_blocked") {
            return [single]
        }
        return nil
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
        dialoguePresenter.zPosition = 60
        hudRoot.addChild(dialoguePresenter)
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
            if !twoFingerGestureIsActive {
                twoFingerGestureIsActive = true
                touchDownTime = nil
                touchDownLocation = nil
                twoFingerAnchor = Self.touchCentroid(in: event, view: view)
                twoFingerPanDistance = 0
                if let touch = touches.first {
                    handlePointerCancelled(
                        GamePointerEvent(location: touch.location(in: self), kind: .touch)
                    )
                }
                // Whether this is a pan or the touch right-click is decided on
                // release, by how far the centroid travelled.
            }
            return
        }
        guard !twoFingerGestureIsActive else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchDownTime = ProcessInfo.processInfo.systemUptime
        touchDownLocation = location
        handlePointerDown(GamePointerEvent(location: location, kind: .touch))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if twoFingerGestureIsActive {
            // Two-finger drag pans the viewport (touch equivalent of BG's
            // middle-drag). View points, not scene points: scene space moves with
            // the camera, so reading it mid-pan would feed back into itself.
            guard let anchor = twoFingerAnchor,
                  let centroid = Self.touchCentroid(in: event, view: view) else { return }
            let delta = CGVector(dx: centroid.x - anchor.x, dy: -(centroid.y - anchor.y))
            twoFingerAnchor = centroid
            twoFingerPanDistance += hypot(delta.dx, delta.dy)
            panCamera(byViewDelta: delta)
            return
        }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if let origin = touchDownLocation {
            let moved = hypot(location.x - origin.x, location.y - origin.y)
            if moved > Self.longPressMoveSlop {
                // Dragged far enough that this is no longer a stationary long-press queue.
                touchDownTime = nil
            }
        }
        handlePointerDragged(GamePointerEvent(location: location, kind: .touch))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if twoFingerGestureIsActive {
            let hasActiveTouches = event?.allTouches?.contains {
                $0.phase != .ended && $0.phase != .cancelled
            } ?? false
            if !hasActiveTouches {
                twoFingerGestureIsActive = false
                // A two-finger tap that never became a pan is the touch
                // equivalent of BG:EE right-click: clear targeting, keep walking.
                if twoFingerPanDistance <= Self.twoFingerTapSlop {
                    handleClearTargetingInput()
                }
                twoFingerAnchor = nil
                twoFingerPanDistance = 0
            }
            return
        }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let isQueue: Bool
        if let start = touchDownTime {
            isQueue = ProcessInfo.processInfo.systemUptime - start >= Self.longPressQueueDuration
        } else {
            isQueue = false
        }
        touchDownTime = nil
        touchDownLocation = nil
        handlePointerUp(
            GamePointerEvent(location: location, kind: .touch, isWaypointQueue: isQueue)
        )
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDownTime = nil
        touchDownLocation = nil
        if twoFingerGestureIsActive {
            let hasActiveTouches = event?.allTouches?.contains {
                $0.phase != .ended && $0.phase != .cancelled
            } ?? false
            if !hasActiveTouches {
                twoFingerGestureIsActive = false
                twoFingerAnchor = nil
                twoFingerPanDistance = 0
            }
            return
        }
        guard let touch = touches.first else { return }
        handlePointerCancelled(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }

    /// Mean position of the live touches in view points, which unlike scene
    /// points does not move when the camera does.
    private static func touchCentroid(in event: UIEvent?, view: SKView?) -> CGPoint? {
        let live = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? []
        guard !live.isEmpty else { return nil }
        var sum = CGPoint.zero
        for touch in live {
            let point = touch.location(in: view)
            sum.x += point.x
            sum.y += point.y
        }
        return CGPoint(x: sum.x / CGFloat(live.count), y: sum.y / CGFloat(live.count))
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
        let queue = event.modifierFlags.contains(.shift)
        handlePointerUp(
            GamePointerEvent(
                location: event.location(in: self),
                kind: .mouse,
                isWaypointQueue: queue,
                isDoubleClick: event.clickCount == 2
            )
        )
    }

    override func mouseMoved(with event: NSEvent) {
        handlePointerMoved(GamePointerEvent(location: event.location(in: self), kind: .mouse))
    }

    override func scrollWheel(with event: NSEvent) {
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        handleScrollInput(event.scrollingDeltaY * multiplier)
    }

    /// Middle-button drag pans the viewport, as GemRB's `OnMouseDrag` does for
    /// `GEM_MB_MIDDLE`. Device deltas are used rather than scene coordinates:
    /// scene space moves with the camera, so reading it mid-pan feeds back.
    override func otherMouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return }
        panCamera(byViewDelta: CGVector(dx: event.deltaX, dy: -event.deltaY))
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        // Arrows / WASD scroll the viewport, never the actor. GDD §8.3 and frozen
        // rule 1 both say point-and-click owns movement and these keys are camera
        // pan only; BG does the same in `ApplyKeyScrolling`. Open overlays get
        // first refusal so the journal and reply list still take arrow keys.
        case 0, 123, 2, 124, 1, 125, 13, 126:
            if handleDirectionalInput(Self.scrollDirection(forKeyCode: event.keyCode)) {
                heldScrollKeys.removeAll()
                applyKeyScrolling()
                return
            }
            if !event.isARepeat { heldScrollKeys.insert(event.keyCode) }
            applyKeyScrolling()
        case 34 where !event.isARepeat: handleInventoryInput() // I
        case 46 where !event.isARepeat: handleMapInput() // M
        case 38 where !event.isARepeat: handleJournalInput() // J
        case 36, 49: // return / space
            if !event.isARepeat { handleConfirmInput() }
        case 53 where !event.isARepeat: handleCancelInput() // escape
        default:
            // BG:EE: 1–9 select dialogue reply options (not Space/Return).
            if !event.isARepeat,
               let chars = event.charactersIgnoringModifiers,
               let ch = chars.first,
               ch >= "1", ch <= "9",
               let digit = Int(String(ch))
            {
                handleDialogueChoiceDigit(digit)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 0, 123, 2, 124, 1, 125, 13, 126:
            heldScrollKeys.remove(event.keyCode)
            applyKeyScrolling()
        default:
            super.keyUp(with: event)
        }
    }

    private static func scrollDirection(forKeyCode keyCode: UInt16) -> CGVector {
        switch keyCode {
        case 0, 123: CGVector(dx: -1, dy: 0) // A / left
        case 2, 124: CGVector(dx: 1, dy: 0) // D / right
        case 1, 125: CGVector(dx: 0, dy: -1) // S / down
        default: CGVector(dx: 0, dy: 1) // W / up
        }
    }

    /// GemRB `ApplyKeyScrolling`: held direction keys become a scroll vector that
    /// the viewport spends per frame, rather than a one-shot jump per press.
    private func applyKeyScrolling() {
        var vector = CGVector.zero
        if heldScrollKeys.contains(0) || heldScrollKeys.contains(123) { vector.dx -= 1 }
        if heldScrollKeys.contains(2) || heldScrollKeys.contains(124) { vector.dx += 1 }
        if heldScrollKeys.contains(1) || heldScrollKeys.contains(125) { vector.dy -= 1 }
        if heldScrollKeys.contains(13) || heldScrollKeys.contains(126) { vector.dy += 1 }
        setCameraScroll(vector)
    }

    /// BG:EE right-click clears the targeting mode and resets the action bar —
    /// it does **not** stop movement (`GameControl::OnMouseUp`, `GEM_MB_MENU`).
    /// Escape remains the only Stop.
    override func rightMouseDown(with event: NSEvent) {
        handleClearTargetingInput()
    }
}
#endif

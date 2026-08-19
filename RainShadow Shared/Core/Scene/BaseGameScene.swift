import SpriteKit

@MainActor
class BaseGameScene: SKScene {
    let context: GameContext
    let artSize: CGSize

    /// The area this scene is currently running, once it has loaded one.
    ///
    /// Optional because the opening exterior is a cinematic backdrop with no
    /// navigable floor — it authors an entrance so arrivals have somewhere to
    /// land, but nothing walks there, so it never loads a runtime.
    private(set) var areaRuntime: AreaRuntime?

    /// Adopt an area. Called once from `buildScene`.
    func loadArea(_ runtime: AreaRuntime) {
        areaRuntime = runtime
    }

    private var propTextureCache: [String: SKTexture] = [:]
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
    /// Reusable, non-modal container strip. Scenes supply container contents and
    /// forward input only while it is visible.
    let lootContainerPanel = LootContainerPanelNode()
    /// BG:EE quick-loot strip over the area's ground pile. Non-modal like the
    /// container strip; scenes supply nearby stacks and forward input.
    let quickLootBar = QuickLootBarNode()

    private var hasBuiltScene = false
    private var isPerformingLayout = false
    /// Camera scale at 100% zoom. Kept as the *base* rather than the live scale
    /// because `CutsceneDirector` multiplies authored framing against it, and an
    /// authored push must not shift because the player happened to be zoomed in.
    private(set) var baseCameraScale: CGFloat = 1
    #if os(macOS)
    /// Trackpad pinch is a stream of fractions; the engine zoom is an integer
    /// step. Accumulate until a notch is crossed rather than mapping continuously.
    private var pendingMagnification: CGFloat = 0
    private static let magnificationPerStep: CGFloat = 0.08
    #endif
    #if os(iOS)
    /// Distance between the two live touches, for pinch. Tracked beside the
    /// centroid so one gesture can pan and zoom the way BG:EE's iPad build does.
    private var twoFingerSpread: CGFloat?
    private var pendingPinchTravel: CGFloat = 0
    /// View points of spread per BG:EE zoom notch.
    private static let pinchPointsPerStep: CGFloat = 26
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
        // GemRB keeps `zoomLevel` on `GameControl`, which outlives an area
        // change, so the framing the player chose survives walking outside.
        zoomStep = context.cameraZoomStep
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
            dumpPlacedSpritesIfRequested()
        }
        layoutViewport()
        sceneDidBecomeReady()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutViewport()
    }

    /// `SceneRouter` builds a fresh scene per route and never told the old one it
    /// was leaving, so a transition during a cutscene left an armed gate, hidden
    /// rails, and a camera with no owner. Nothing survives the scene now.
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        cutsceneDirector.tearDown()
        sceneWillExit()
    }

    /// Last chance to unwind scene-owned state. Subclasses override.
    /// Start the area's ambient beds.
    ///
    /// Baldur's Gate keeps ambients in the `.ARE` — a resref, a volume, a
    /// position and radius for local ones, a schedule for the ones that only run
    /// at night. Each RainShadow scene instead opened with one hardcoded
    /// `RainAudio.loopingAmbience` call, which is why the office's rain lived in
    /// `DetectiveOfficeScene` as a filename and a magic 0.27.
    ///
    /// Positional ambients are not honoured yet: nothing shipped authors a point
    /// or radius, and `RainAudio.loopingAmbience` deliberately sets
    /// `isPositional = false` because these are beds rather than sources. When an
    /// area authors a located sound, that is the change to make.
    func buildAmbients(from area: AreaDefinition) {
        for ambient in area.ambients where ambient.isLooping {
            // Records name the asset; the audio layer wants a filename.
            let fileName = ambient.assetName.hasSuffix(".m4a")
                ? ambient.assetName
                : "\(ambient.assetName).m4a"
            let node = RainAudio.loopingAmbience(
                fileNamed: fileName,
                volume: Float(ambient.volume)
            )
            node.name = ambient.id
            addChild(node)
        }
    }

    /// Run one tick of the loaded area's script.
    ///
    /// Polled, because that is what a Baldur's Gate area script is: it asks
    /// questions about world state every tick rather than being handed events.
    /// The runner is pure and returns what should happen; applying it is here,
    /// because the save and the case state live outside the package.
    ///
    /// Variables are written back through `GameSession`, which persists them, so
    /// a one-shot block guarded on its own variable stays fired across a
    /// relaunch — the idiom every larger script is built from.
    func tickAreaScript() {
        guard let runtime = areaRuntime, let script = runtime.script else { return }
        let scriptContext = AreaScriptContext(
            area: runtime.id,
            variables: context.session.areaVariables,
            dialogue: DialogueRuntimeContext(
                caseState: context.session.caseState,
                dialogueState: DialogueState(graphID: script.id)
            )
        )
        let outcome = AreaScriptRunner.tick(script, in: scriptContext)
        guard outcome.didFire else { return }
        context.session.applyAreaScriptVariables(outcome.variables)
        for action in outcome.actions {
            switch action {
            case .caseAction, .startCutscene:
                // Nothing shipped authors these yet. Left unhandled rather than
                // half-wired: a case action needs the dialogue runtime's own
                // application path, and a cutscene needs a `CutsceneStage`.
                break
            case .setVariable, .incrementVariable, .setGlobal:
                break  // already applied by the runner
            }
        }
    }

    /// Build an area's scenery from its record.
    ///
    /// The counterpart to `RAINSHADOW_DUMP_PROPS`: the dump reads the scene
    /// graph out, this puts it back. Every field it consumes is one the dump
    /// proved is load-bearing — layer decides whether a prop sorts against
    /// actors at all, blend and alpha carry the additive light casts, and a
    /// prop's id is separate from its texture because a node's name is not its
    /// art.
    ///
    /// Returns the sprites by id so a scene can keep references to the few it
    /// still has to drive — a door that re-warps when it falls, an apron that
    /// sorts against a seated actor every frame.
    @discardableResult
    func buildProps(from area: AreaDefinition) -> [String: SKSpriteNode] {
        var placed: [String: SKSpriteNode] = [:]
        for (order, prop) in area.props.enumerated() {
            guard let sprite = makeProp(prop, order: order) else { continue }
            placed[prop.id] = sprite
        }
        return placed
    }

    /// How far apart consecutive props in a layer sit in depth.
    ///
    /// Small enough that a whole area's props cannot climb out of their layer —
    /// the layers are thousands apart and no area has thousands of props — and
    /// large enough to survive `Float` rounding at those magnitudes.
    static let propOrderStep: CGFloat = 0.001

    /// One prop. `nil` when its texture is missing, which is an asset error
    /// rather than a runtime condition — the scene simply draws without it,
    /// exactly as the imperative placement did.
    func makeProp(_ prop: AreaProp, order: Int = 0) -> SKSpriteNode? {
        guard let texture = propTexture(named: prop.textureName) else { return nil }

        let sprite: SKSpriteNode
        if let worldSize = prop.worldSize {
            sprite = SKSpriteNode(texture: texture, size: worldSize.cgSize)
        } else {
            // Scale, not size, so anything that later animates the prop's scale
            // composes with what it was built at instead of multiplying by it.
            sprite = SKSpriteNode(texture: texture)
            sprite.xScale = prop.scaleX
            sprite.yScale = prop.scaleY
        }
        // The node keeps its *id*, not its texture name: hover registration and
        // hotspot lookups key on identity, and two of the office's props draw
        // art with a different name.
        sprite.name = prop.id
        sprite.anchorPoint = CGPoint(x: prop.anchorX, y: prop.anchorY)
        sprite.position = prop.groundPoint.cgPoint
        sprite.alpha = prop.alpha
        sprite.zRotation = prop.rotation
        sprite.blendMode = blendMode(for: prop.blend)
        if let warp = prop.warp {
            sprite.warpGeometry = warpGrid(warp)
            // One subdivision, matching the placement this replaced: the corner
            // displacement is linear across the quad, so denser tessellation
            // costs vertices and changes nothing.
            sprite.subdivisionLevels = 1
        }

        // Separating props by their position in the record is what makes that
        // order the *drawn* order.
        //
        // Without it a flat layer is ten sprites all at one zPosition, and the
        // view runs with `ignoresSiblingOrder = true` — under which SpriteKit
        // draws equal-z siblings in whatever order batches best, not in child
        // order. That is invisible for opaque scenery and not invisible for the
        // office's five additive light casts: two builds whose scene graphs were
        // provably identical rendered them a step or two apart per channel, and
        // an order nobody states is an order that can change under you.
        let ordering = CGFloat(order) * Self.propOrderStep
        switch prop.layer {
        case .floorEffects:
            sprite.zPosition = SceneLayer.floorEffects.rawValue + prop.depthBias + ordering
            floorEffectRoot.addChild(sprite)
        case .rearFixtures:
            sprite.zPosition = SceneLayer.rearFixtures.rawValue + prop.depthBias + ordering
            rearFixtureRoot.addChild(sprite)
        case .occlusion:
            sprite.zPosition = SceneLayer.occlusion.rawValue + prop.depthBias + ordering
            occlusionRoot.addChild(sprite)
        case .depthWorld:
            // Sorted by ground point, so the bias is what remains after the
            // part that follows from position — which is how it was recovered.
            // The ordering step only ever breaks a tie between two props whose
            // ground points agree exactly.
            updateDepth(of: sprite, bias: prop.depthBias + ordering)
            depthWorldRoot.addChild(sprite)
        }
        return sprite
    }

    /// One texture per distinct piece of art, for the life of the scene.
    ///
    /// Two of the office's props draw the same file — the blind-stripe cast
    /// appears once raking across the floor and again, dimmer and rotated, on
    /// the wall — and the imperative placement they replaced loaded it once and
    /// built both sprites from it.
    private func propTexture(named name: String) -> SKTexture? {
        if let cached = propTextureCache[name] { return cached }
        guard let texture = GameArt.texture(named: name) else { return nil }
        // Not cosmetic at this magnification. `GameArt` hands back `.nearest`
        // and every one of the office's 55 placements overrode it to `.linear`;
        // the dump confirmed all 55, so this is the measured default rather than
        // a guess. A prop that wants crisp pixels needs a field of its own, not
        // a silent exception here.
        texture.filteringMode = .linear
        propTextureCache[name] = texture
        return texture
    }

    private func warpGrid(_ warp: AreaPropWarp) -> SKWarpGeometryGrid {
        let source: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(1, 0),
            SIMD2(0, 1), SIMD2(1, 1)
        ]
        let destination = warp.destinationCorners.map {
            SIMD2(Float($0.x), Float($0.y))
        }
        return SKWarpGeometryGrid(
            columns: 1,
            rows: 1,
            sourcePositions: source,
            destinationPositions: destination
        )
    }

    private func blendMode(for blend: AreaPropBlend) -> SKBlendMode {
        switch blend {
        case .alpha: .alpha
        case .add: .add
        case .multiply: .multiply
        case .screen: .screen
        case .replace: .replace
        }
    }

    /// `RAINSHADOW_DUMP_PROPS=1` prints every sprite the scene placed, with the
    /// numbers the renderer actually used.
    ///
    /// Ground truth for the Infinity Engine WED split. Deciding which scenery
    /// can be baked into the plate needs each object's real position, scale,
    /// anchor and layer, and reading those out of `buildScene` means
    /// re-implementing `OfficeInteriorScale` in a parser and hoping it agrees.
    /// The scene graph already knows.
    ///
    /// Prints to stderr between markers so a capture script can lift it out
    /// without the frame's base64 getting in the way.
    func dumpPlacedSpritesIfRequested() {
        guard ProcessInfo.processInfo.environment["RAINSHADOW_DUMP_PROPS"] == "1" else { return }
        let layers: [(String, SKNode)] = [
            ("floorEffects", floorEffectRoot),
            ("rearFixtures", rearFixtureRoot),
            ("depthWorld", depthWorldRoot),
            ("occlusion", occlusionRoot)
        ]
        FileHandle.standardError.write(Data("RAINSHADOW_PROPS_BEGIN\n".utf8))
        for (layerName, root) in layers {
            for node in root.children {
                guard let sprite = node as? SKSpriteNode else { continue }
                dumpSprite(sprite, layer: layerName, parent: nil)
            }
        }
        FileHandle.standardError.write(Data("RAINSHADOW_PROPS_END\n".utf8))
        dumpWorldTree()
    }

    /// Every node under the scene, not just the placed sprites.
    ///
    /// The sprite dump answers "did the props change"; this answers "did
    /// anything else". Both were needed to land the office's props as data: the
    /// two scene graphs agreed sprite for sprite while the rendered frame still
    /// differed, and nothing else could say where.
    private func dumpWorldTree() {
        FileHandle.standardError.write(Data("RAINSHADOW_TREE_BEGIN\n".utf8))
        func walk(_ node: SKNode, path: String) {
            let name = node.name ?? "<unnamed>"
            let here = "\(path)/\(type(of: node))[\(name)]"
            let size = (node as? SKSpriteNode).map { "\($0.size)" } ?? "-"
            let line = [
                here,
                "pos=\(node.position)",
                "z=\(node.zPosition)",
                "alpha=\(node.alpha)",
                "scale=\(node.xScale),\(node.yScale)",
                "size=\(size)",
                "hidden=\(node.isHidden)",
                "children=\(node.children.count)"
            ].joined(separator: "\t")
            FileHandle.standardError.write(Data((line + "\n").utf8))
            for child in node.children { walk(child, path: here) }
        }
        for child in children { walk(child, path: "") }
        FileHandle.standardError.write(Data("RAINSHADOW_TREE_END\n".utf8))
    }

    /// One sprite, plus any children, in world space.
    ///
    /// Children matter: desk items are positioned in the desk's own canvas, so
    /// their `position` is meaningless without the parent's transform. Resolving
    /// to scene coordinates here means the bake never has to know that.
    ///
    /// Blend mode and alpha matter more. The office's light spills and the
    /// ceiling-fan shadow are not plain alpha composites, and baking them as if
    /// they were would wash the room out — the kind of error that looks like a
    /// lighting change rather than a bug.
    private func dumpSprite(_ sprite: SKSpriteNode, layer: String, parent: String?) {
        let worldPosition = sprite.parent.map { $0.convert(sprite.position, to: self) }
            ?? sprite.position
        let blend: String
        switch sprite.blendMode {
        case .alpha: blend = "alpha"
        case .add: blend = "add"
        case .subtract: blend = "subtract"
        case .multiply: blend = "multiply"
        case .multiplyX2: blend = "multiplyX2"
        case .screen: blend = "screen"
        case .replace: blend = "replace"
        @unknown default: blend = "alpha"
        }
        let textureRect = sprite.texture.map { $0.textureRect() }
            ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        // The texture's own identity, not the node's name. They differ: the rug
        // node is `office_worn_rug` but draws `office_worn_rug_burgundy`, and a
        // bake that resolves art by node name silently composites the wrong
        // picture. `SKTexture.description` carries the filename.
        // Filtering is not cosmetic at this magnification: `GameArt` hands back
        // `.nearest` and most placement overrides it to `.linear`, so a
        // data-driven rebuild that guessed would resharpen half the room.
        let filtering: String
        switch sprite.texture?.filteringMode {
        case .some(.nearest): filtering = "nearest"
        case .some(.linear): filtering = "linear"
        default: filtering = "linear"
        }
        let textureName = sprite.texture.flatMap { GameArt.sourceName(of: $0) }
            ?? sprite.name
            ?? "<none>"
        let line = [
            layer,
            sprite.name ?? "<unnamed>",
            "\(worldPosition.x)", "\(worldPosition.y)",
            "\(sprite.xScale)", "\(sprite.yScale)",
            "\(sprite.anchorPoint.x)", "\(sprite.anchorPoint.y)",
            "\(sprite.size.width)", "\(sprite.size.height)",
            "\(sprite.zPosition)",
            "\(sprite.alpha)",
            blend,
            "\(sprite.zRotation)",
            "\(textureRect.origin.x)", "\(textureRect.origin.y)",
            "\(textureRect.width)", "\(textureRect.height)",
            "\(sprite.isHidden)",
            parent ?? "-",
            textureName,
            filtering,
            warpDescription(of: sprite),
            "color=\(sprite.color)",
            "cbf=\(sprite.colorBlendFactor)",
            "centerRect=\(sprite.centerRect)",
            "mipmaps=\(sprite.texture?.usesMipmaps ?? false)",
            "shader=\(sprite.shader == nil ? "-" : "yes")",
            "subdiv=\(sprite.subdivisionLevels)",
            "texSize=\(sprite.texture?.size() ?? .zero)"
        ].joined(separator: "\t")
        FileHandle.standardError.write(Data((line + "\n").utf8))
        for child in sprite.children {
            guard let childSprite = child as? SKSpriteNode else { continue }
            dumpSprite(childSprite, layer: layer, parent: sprite.name ?? "<unnamed>")
        }
    }

    /// A sprite's build-time warp, as the destination grid in unit space.
    ///
    /// The one property of a placed sprite the dump could not see. It is not
    /// cosmetic: the office window is warped so its rails rise with the painted
    /// wall trim while both jambs stay vertical, and rebuilding it flat leaves
    /// the window sitting square on a wall that leans — which reads as the art
    /// being wrong rather than the placement.
    private func warpDescription(of sprite: SKSpriteNode) -> String {
        guard let grid = sprite.warpGeometry as? SKWarpGeometryGrid else { return "-" }
        let corners = (0..<grid.vertexCount).map { index -> String in
            let point = grid.destPosition(at: index)
            return "\(point.x),\(point.y)"
        }
        return "\(grid.numberOfColumns)x\(grid.numberOfRows):" + corners.joined(separator: ";")
    }

    func sceneWillExit() {}

    /// QA only. The review capture launch drives the update loop far slower than
    /// wall-clock, so a cutscene is only a few ticks in when the capture fires and
    /// every timed cinematic reviews as its opening beat. This seeks the timeline
    /// to where it should be. Scenes with their own time-seeded state override.
    func seekForCapture(elapsed: TimeInterval) {
        cutsceneDirector.seekForCapture(elapsed: elapsed)
    }

    func buildScene() {}
    func sceneDidBecomeReady() {}
    func handlePointerDown(_ event: GamePointerEvent) {}
    func handlePointerDragged(_ event: GamePointerEvent) {}
    func handlePointerUp(_ event: GamePointerEvent) {}
    func handlePointerCancelled(_ event: GamePointerEvent) {}
    func handlePointerMoved(_ event: GamePointerEvent) {}
    /// Wheel / trackpad scroll. Return `true` when an open overlay consumed it;
    /// otherwise it falls through to zoom, exactly as `handleDirectionalInput`
    /// falls through to viewport scrolling.
    func handleScrollInput(_ deltaY: CGFloat) -> Bool { false }
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

    /// Plays authored cutscenes. Every scene has one for the same reason every
    /// scene has the dialogue panel: the office used to be the only place in the
    /// game that could run a cutscene, so the opening exterior grew its own
    /// one-off timeline and the city districts simply could not have one.
    private(set) lazy var cutsceneDirector = CutsceneDirector(scene: self)

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

    #if os(macOS)
    /// Applies a resolved world cursor.
    ///
    /// The system cursor set has no travel arrow, so `dragLink` stands in — it at
    /// least reads as "leaves here", which is the distinction BG draws and that
    /// both scenes previously lost by drawing a district portal with the same
    /// cursor as a lamp post. A painted cursor would be better and is art, not
    /// code.
    func applyWorldCursor(_ state: WorldCursorState) {
        let cursor: NSCursor
        switch state.cursor {
        case .normal: cursor = .arrow
        case .walk: cursor = .arrow
        case .blocked: cursor = .operationNotAllowed
        case .travel: cursor = .dragLink
        case .interact, .talk: cursor = .pointingHand
        }
        // BG greys the cursor rather than swapping it; `operationNotAllowed` is the
        // nearest system equivalent that keeps the refusal legible.
        (state.isDisabled ? NSCursor.operationNotAllowed : cursor).set()
    }
    #endif

    /// Why the world is frozen. Replaces the per-scene boolean expressions that
    /// had nowhere to put a pause the player asked for.
    var pause = WorldPauseController()

    /// True while dialogue or an overlay wants Return/Space for its own confirm.
    ///
    /// BG:EE binds Space to pause, but this game's dialogue contract (README,
    /// GDD §8.3) also uses Space for Continue / End Dialogue. Scenes report here
    /// so Space can mean pause in the world and confirm in a modal, without
    /// either meaning leaking into the other.
    var isModalInputActive: Bool { false }

    /// Space, or the clock in the corner. BG:EE's clock *is* the pause button.
    func handleTacticalPauseInput() {}
    /// BG:EE right-click / two-finger tap: drop any targeting mode and reset the
    /// action bar, leaving an in-progress path alone.
    func handleClearTargetingInput() {}

    /// Right-click with a location. BG uses the right button both to clear
    /// targeting and, over the inventory, to attempt identification — so a scene
    /// gets first refusal on the located event before the global clear runs.
    /// Returning `true` means the scene consumed it.
    @discardableResult
    func handleSecondaryPointer(at point: CGPoint) -> Bool { false }

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

        // Uniform orthographic play zoom only — the ground projection is baked
        // into the area plates, never re-projected here. See
        // Documentation/InfinityEngineGroundProjection.md.
        baseCameraScale = DefaultPlayZoom.cameraScale(
            visibleWorldHeight: referenceVisibleHeight,
            sceneHeight: size.height
        )
        // The zoom-out ceiling is aspect-dependent, so it is resolved against the
        // live view rather than baked into a constant: the office is bound
        // vertically at 16:9 and horizontally at 21:9.
        zoomBounds = resolvedZoomBounds()
        zoomStep = CameraZoom.clamped(step: zoomStep, to: zoomBounds)
        context.cameraZoomStep = zoomStep
        gameCamera.setScale(playCameraScale)
        // A resize can widen the viewport under a camera that was legal at the
        // old size, and can tighten the ceiling out from under the current step.
        // Settle here rather than leaving it to whichever scene happens to
        // re-clamp in its own layout override — only the city did.
        settleCameraAfterZoom()

        // Camera-child HUD: identity transform relative to the camera. Apple's
        // camera counter-transform keeps ±size/2 on the view edges at any zoom.
        hudRoot.position = .zero
        hudRoot.setScale(1)
        lootContainerPanel.layout(for: hudViewportSize)
        quickLootBar.layout(for: hudViewportSize)
        cinematicRoot.position = .zero
        cinematicRoot.setScale(1)

        // `baseCameraScale` was just re-applied above, which used to silently
        // undo a cutscene push the moment the window was resized. Re-assert it.
        cutsceneDirector.layoutChrome()
        cutsceneDirector.applyCameraScale()
    }

    /// No-op kept for call sites that previously re-anchored a world-space HUD.
    /// Camera-child chrome tracks the camera automatically.
    func syncHudToCamera() {
        hudRoot.position = .zero
        hudRoot.setScale(1)
    }

    // MARK: - Zoom

    /// BG:EE zoom step (`GameControl::zoomLevel`). 16 is 100%, the BG1 density
    /// every art scale contract is measured against.
    private(set) var zoomStep: Int = CameraZoom.defaultStep
    /// Steps the player may reach here — BG:EE's 1…27 narrowed by what the
    /// painted plate can still cover. Recomputed on every layout pass.
    private(set) var zoomBounds: ClosedRange<Int> = CameraZoom.engineStepRange

    /// A cinematic scene drives the camera itself and takes no player zoom.
    var allowsPlayerZoom: Bool { true }

    /// Rect the scene clamps the camera inside — the same one it hands
    /// `updateCamera`. Overridden per scene so the fit limit and the position
    /// clamp cannot drift apart.
    var cameraClampBounds: CGRect { .zero }
    /// Painted extent the viewport must never zoom out past. For the office this
    /// is the plate, not the room: `cameraClampBounds` is *smaller* than the
    /// viewport there and says where the camera may go, not what the art covers.
    var cameraPlateBounds: CGRect { .zero }

    /// Camera-visible world height at the current step.
    var playVisibleHeight: CGFloat {
        CameraZoom.visibleHeight(base: referenceVisibleHeight, step: zoomStep)
    }

    /// Live uniform camera scale. Everything that used to read `baseCameraScale`
    /// as "the current scale" reads this instead.
    var playCameraScale: CGFloat {
        guard size.height > 0 else { return baseCameraScale }
        return playVisibleHeight / size.height
    }

    /// GemRB `Zoom Lock`: the wheel and pinch pan instead of zooming.
    var zoomLockEnabled: Bool { context.preferences.zoomLockEnabled }

    /// Lower step = less world shown = zoomed in, as in `GetScalePercent`.
    func setZoomStep(_ step: Int) {
        guard allowsPlayerZoom, !cutsceneDirector.ownsCamera else { return }
        let clamped = CameraZoom.clamped(step: step, to: zoomBounds)
        guard clamped != zoomStep else { return }
        zoomStep = clamped
        context.cameraZoomStep = zoomStep
        gameCamera.setScale(playCameraScale)
        settleCameraAfterZoom()
    }

    /// Re-clamp now rather than waiting for the next `updateCamera`.
    ///
    /// A zoom-out widens the viewport under a camera position that was legal at
    /// the old scale, so the frame drawn between the zoom and the next update
    /// can show past the plate edge — which is the one thing the fit ceiling
    /// exists to prevent. Caught by a QA capture, where the update loop never
    /// runs at all and the city sat 148 world units below its own plate.
    private func settleCameraAfterZoom() {
        let bounds = cameraClampBounds
        guard !bounds.isEmpty else { return }
        let settled = clampedCameraPosition(following: gameCamera.position, in: bounds)
        gameCamera.position = settled
        if cameraMode == .free { freeCameraTarget = settled }
    }

    func zoomIn() { setZoomStep(zoomStep - 1) }
    func zoomOut() { setZoomStep(zoomStep + 1) }

    /// Wheel or trackpad scroll no overlay claimed. BG:EE zooms here; under
    /// `Zoom Lock` GemRB redirects the same event to `Scroll(...)` instead,
    /// which is what a trackpad's two-finger scroll wants.
    func applyViewportScrollGesture(dx: CGFloat, dy: CGFloat) {
        guard allowsPlayerZoom, !cutsceneDirector.ownsCamera else { return }
        if zoomLockEnabled {
            panCamera(byViewDelta: CGVector(dx: dx, dy: dy))
            return
        }
        guard dy != 0 else { return }
        dy > 0 ? zoomIn() : zoomOut()
    }

    /// BG:EE's band, narrowed to what this scene's plate can cover. A scene with
    /// no painted extent (the cinematic exterior) keeps the engine band.
    private func resolvedZoomBounds() -> ClosedRange<Int> {
        let plate = cameraPlateBounds
        guard size.height > 0, !plate.isEmpty else { return CameraZoom.engineStepRange }
        let ceiling = CameraZoom.fitStep(
            base: referenceVisibleHeight,
            viewportAspect: size.width / size.height,
            anchor: CGPoint(x: cameraClampBounds.midX, y: cameraClampBounds.midY),
            plate: plate
        )
        return CameraZoom.engineStepRange.lowerBound...max(CameraZoom.engineStepRange.lowerBound, ceiling)
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
    var cameraScrollSpeed: CGFloat { playVisibleHeight }

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
        freeCameraTarget.x += viewDelta.dx * playCameraScale
        freeCameraTarget.y += viewDelta.dy * playCameraScale
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
            // Settle the target on the clamped result rather than letting it run
            // on unbounded. A target parked far outside the plate while zoomed in
            // would otherwise be stale the moment the player zoomed out.
            freeCameraTarget = clampedCameraPosition(following: freeCameraTarget, in: bounds)
            gameCamera.position = freeCameraTarget
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
        let halfWidth = size.width * playCameraScale / 2
        let halfHeight = playVisibleHeight / 2
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
        // Cutscene chrome is screen-space — letterbox bars and a fade overlay
        // must not drift when the camera pans — so `cinematicRoot` hangs off the
        // camera exactly as the HUD does, one layer beneath it. It was installed
        // in world space and used by nothing, which is why the office letterbox
        // had to be parented to `hudRoot` instead.
        cinematicRoot.zPosition = SceneLayer.cinematic.rawValue
        cinematicRoot.position = .zero
        cinematicRoot.setScale(1)
        gameCamera.addChild(cinematicRoot)

        hudRoot.zPosition = SceneLayer.hud.rawValue
        hudRoot.position = .zero
        hudRoot.setScale(1)
        gameCamera.addChild(hudRoot)
        lootContainerPanel.zPosition = 50
        lootContainerPanel.isHidden = true
        hudRoot.addChild(lootContainerPanel)
        quickLootBar.zPosition = 49
        quickLootBar.isHidden = true
        hudRoot.addChild(quickLootBar)
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
                twoFingerSpread = Self.touchSpread(in: event, view: view)
                twoFingerPanDistance = 0
                pendingPinchTravel = 0
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
            applyPinch(in: event)
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
                twoFingerSpread = nil
                twoFingerPanDistance = 0
                pendingPinchTravel = 0
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
                twoFingerSpread = nil
                twoFingerPanDistance = 0
                pendingPinchTravel = 0
            }
            return
        }
        guard let touch = touches.first else { return }
        handlePointerCancelled(GamePointerEvent(location: touch.location(in: self), kind: .touch))
    }

    /// Two-finger pinch — the touch equivalent of BG:EE's wheel zoom, riding the
    /// same gesture that pans. Spread travel is folded into `twoFingerPanDistance`
    /// so a pinch can never be mistaken for the two-finger *tap* that clears
    /// targeting.
    private func applyPinch(in event: UIEvent?) {
        guard let spread = Self.touchSpread(in: event, view: view) else { return }
        defer { twoFingerSpread = spread }
        guard let previous = twoFingerSpread else { return }
        let change = spread - previous
        guard change != 0 else { return }
        twoFingerPanDistance += abs(change)
        guard allowsPlayerZoom, !zoomLockEnabled, !cutsceneDirector.ownsCamera else { return }
        pendingPinchTravel += change
        while pendingPinchTravel >= Self.pinchPointsPerStep {
            pendingPinchTravel -= Self.pinchPointsPerStep
            zoomIn()
        }
        while pendingPinchTravel <= -Self.pinchPointsPerStep {
            pendingPinchTravel += Self.pinchPointsPerStep
            zoomOut()
        }
    }

    /// Distance between the two live touches in view points. Nil unless exactly
    /// the pinch pair is down, so a third finger cannot jitter the zoom.
    private static func touchSpread(in event: UIEvent?, view: SKView?) -> CGFloat? {
        let live = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled } ?? []
        guard live.count == 2 else { return nil }
        let points = live.map { $0.location(in: view) }
        return hypot(points[0].x - points[1].x, points[0].y - points[1].y)
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
        let deltaY = event.scrollingDeltaY * multiplier
        // GemRB `OnMouseWheelScroll`: an open overlay owns the wheel; anything
        // left over is zoom (or pan, under Zoom Lock).
        if handleScrollInput(deltaY) { return }
        applyViewportScrollGesture(dx: event.scrollingDeltaX * multiplier, dy: deltaY)
    }

    /// Trackpad pinch. Same destination as the wheel, different device.
    override func magnify(with event: NSEvent) {
        guard allowsPlayerZoom, !zoomLockEnabled, !cutsceneDirector.ownsCamera else { return }
        pendingMagnification += event.magnification
        while pendingMagnification >= Self.magnificationPerStep {
            pendingMagnification -= Self.magnificationPerStep
            zoomIn()
        }
        while pendingMagnification <= -Self.magnificationPerStep {
            pendingMagnification += Self.magnificationPerStep
            zoomOut()
        }
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
        // BG:EE binds minus / equals to zoom out / in.
        case 27: zoomOut()
        case 24: zoomIn()
        case 34 where !event.isARepeat: handleInventoryInput() // I
        case 46 where !event.isARepeat: handleMapInput() // M
        case 38 where !event.isARepeat: handleJournalInput() // J
        case 36: // return
            if !event.isARepeat { handleConfirmInput() }
        case 49: // space
            // Modal first, so the dialogue contract is untouched; otherwise this
            // is BG:EE's pause key.
            if !event.isARepeat {
                if isModalInputActive {
                    handleConfirmInput()
                } else {
                    handleTacticalPauseInput()
                }
            }
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
        if handleSecondaryPointer(at: event.location(in: self)) { return }
        handleClearTargetingInput()
    }
}
#endif

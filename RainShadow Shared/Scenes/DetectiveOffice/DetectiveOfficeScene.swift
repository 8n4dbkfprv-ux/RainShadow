import SpriteKit
import ImageIO
#if os(macOS)
import AppKit
#endif

@MainActor
final class DetectiveOfficeScene: BaseGameScene {
    private let detective = DetectiveActorNode()
    private let client = ClientActorNode()
    private var officeDoor: SKSpriteNode?
    private let caseIntroductionPresenter = CaseIntroductionPresenter()
    private let inventoryOverlay = InventoryOverlay()
    private let portraitBar = PortraitBarNode()
    private let actionBar = ActionBarNode()
    private let areaMapOverlay = AreaMapOverlay()
    private let journalOverlay = JournalOverlay()
    private var fogOfWar: OfficeFogOfWarNode?
    private var navigation: NavigationGrid!
    private var hotspots: [OfficeHotspot] = []
    /// Prop sprites that receive Image #1 cyan edge + teal wash on hover, keyed by hotspot id.
    private var hotspotHoverSprites: [String: [SKSpriteNode]] = [:]
    private var hoveredHotspotID: String?
    private var inventoryIsPresented = false
    private var mapIsPresented = false
    private var journalIsPresented = false
    private var caseIntroductionStarted = false
    private var dialogueIsActive = true

    override var referenceVisibleHeight: CGFloat { OfficeInteriorScale.cameraVisibleHeight }

    init(context: GameContext) {
        super.init(context: context, artSize: OfficeInteriorScale.sourceArtSize)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DetectiveOfficeScene is created programmatically")
    }

    override func buildScene() {
        addChild(RainAudio.loopingAmbience(fileNamed: "amb_rain_window.m4a", volume: 0.27))

        let env = OfficeInteriorScale.environment

        if let texture = GameArt.texture(named: "office_shell_base") {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
            background.anchorPoint = .zero
            background.position = OfficeInteriorScale.shellOrigin
            backgroundRoot.addChild(background)
        } else {
            buildFallbackOffice()
        }

        addWindowHighlightProp()
        addWindowRain()
        addLampAtmosphere()

        // Radiator is its own prop — never bind it to office.window (wrong sprite tint).
        addRearFixture(
            named: "office_radiator",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.radiator),
            scale: env
        )
        officeDoor = addRearFixture(
            named: "office_door_leaf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf),
            scale: env
        )
        if let officeDoor {
            registerHoverSprite(officeDoor, for: "office.door")
        }

        // Chair is separate furniture behind the desk — do not register for office.desk
        // (it invented false under/behind-desk highlight geometry; see Image #2).
        addDepthProp(
            named: "office_desk_chair",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair),
            scale: env * OfficeInteriorScale.PropRelativeScale.deskChair,
            bias: -70
        )
        addDepthProp(
            named: "office_filing_cabinet",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.filingCabinet),
            scale: env
        )
        addDepthProp(
            named: "office_coat_rack",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.coatRack),
            scale: env
        )
        addDepthProp(
            named: "office_visitor_armchair",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.visitorArmchair),
            scale: env
        )
        let deskPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskEnsemble)
        let deskScale = OfficeInteriorScale.deskDisplayScale
        if let deskBare = addDepthProp(
            named: "office_desk_bare",
            at: deskPosition,
            scale: deskScale,
            bias: -500
        ) {
            registerHoverSprite(deskBare, for: "office.desk")
        }
        addDeskItems(at: deskPosition, scale: deskScale)

        detective.position = OfficeNavigationLayout.actorStart
        updateDepth(of: detective)
        depthWorldRoot.addChild(detective)

        if let clientStart = OfficeNavigationLayout.clientArrivalPath.first {
            client.position = clientStart
        }
        updateDepth(of: client)
        depthWorldRoot.addChild(client)

        // Covers only the seated lap/legs with registered desk pixels. Its depth sits
        // above the actor but below every independent desktop item, so papers, mug,
        // phone, and lamp remain visible while the lower body stays behind the desk.
        if let deskActorOccluder = addDepthProp(
            named: "office_desk_actor_occluder",
            at: deskPosition,
            scale: deskScale,
            bias: -70
        ) {
            // This is desk artwork used to conceal the seated actor, not a desk-top prop.
            registerHoverSprite(deskActorOccluder, for: "office.desk")
        }

        if let deskFrontOccluder = addDepthProp(
            named: "office_desk_front_occluder_v03",
            at: deskPosition,
            scale: deskScale,
            bias: 10
        ) {
            // The visible front layer must wash with the desk or it masks most of the selection.
            registerHoverSprite(deskFrontOccluder, for: "office.desk")
        }

        addFogOfWar()

        configureNavigation()
        configureHotspots()

        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth,
            animated: false
        )
        hudRoot.addChild(portraitBar)
        hudRoot.addChild(actionBar)
        caseIntroductionPresenter.zPosition = 60
        hudRoot.addChild(caseIntroductionPresenter)
        inventoryOverlay.zPosition = 100
        inventoryOverlay.onDismiss = { [weak self] in
            self?.setInventoryPresented(false)
        }
        hudRoot.addChild(inventoryOverlay)
        areaMapOverlay.zPosition = 110
        areaMapOverlay.onDismiss = { [weak self] in
            self?.setMapPresented(false)
        }
        hudRoot.addChild(areaMapOverlay)
        journalOverlay.zPosition = 120
        journalOverlay.onDismiss = { [weak self] in
            self?.setJournalPresented(false)
        }
        hudRoot.addChild(journalOverlay)
        gameCamera.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.camera)
    }

    override func sceneDidBecomeReady() {
        guard !caseIntroductionStarted else { return }
        caseIntroductionStarted = true
        run(.sequence([
            .wait(forDuration: 0.8),
            .run { [weak self] in self?.startCaseIntroduction() }
        ]), withKey: "caseIntroductionDelay")
    }

    override func handlePointerDown(_ event: GamePointerEvent) {
        guard dialogueIsActive else {
            guard !mapIsPresented, !journalIsPresented, !inventoryIsPresented else { return }
            let hudPoint = hudRoot.convert(event.location, from: self)
            actionBar.beginPress(at: actionBar.convert(hudPoint, from: hudRoot))
            return
        }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerDown(at: dialoguePoint)
    }

    override func handlePointerDragged(_ event: GamePointerEvent) {
        guard dialogueIsActive else {
            let hudPoint = hudRoot.convert(event.location, from: self)
            actionBar.updatePress(at: actionBar.convert(hudPoint, from: hudRoot))
            return
        }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerDragged(at: dialoguePoint)
    }

    override func handlePointerCancelled(_ event: GamePointerEvent) {
        guard dialogueIsActive else {
            actionBar.cancelPress()
            return
        }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerUp(at: dialoguePoint)
    }

    override func handlePointerUp(_ event: GamePointerEvent) {
        if dialogueIsActive {
            let hudPoint = hudRoot.convert(event.location, from: self)
            let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
            if !caseIntroductionPresenter.handlePointerUp(at: dialoguePoint) {
                caseIntroductionPresenter.handlePointer(at: dialoguePoint)
            }
            return
        }

        let hudPoint = hudRoot.convert(event.location, from: self)
        if journalIsPresented {
            let journalPoint = journalOverlay.convert(hudPoint, from: hudRoot)
            journalOverlay.handlePointer(at: journalPoint)
            return
        }
        if mapIsPresented {
            let mapPoint = areaMapOverlay.convert(hudPoint, from: hudRoot)
            areaMapOverlay.handlePointer(at: mapPoint)
            return
        }
        if inventoryIsPresented {
            let overlayPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            inventoryOverlay.handlePointer(at: overlayPoint)
            return
        }

        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint) {
            setInventoryPresented(true)
            return
        }

        let actionPoint = actionBar.convert(hudPoint, from: hudRoot)
        let activatedButton = actionBar.endPress(at: actionPoint)
        if activatedButton == .map {
            setMapPresented(true)
            return
        }
        if activatedButton == .journal {
            setJournalPresented(true)
            return
        }

        if let hotspot = hotspots.first(where: { $0.hitArea.contains(event.location) }) {
            if hotspot.id == "office.door" {
                moveDetective(to: hotspot.approachPoint) { [weak self] in
                    self?.context.router.showCityDistrict()
                }
                return
            }
            moveDetective(to: hotspot.approachPoint) { [weak self] in
                guard let self else { return }
                self.context.session.markInspected(hotspot.id)
                self.presentInspection(hotspot)
            }
            return
        }

        guard let target = navigation.nearestWalkablePoint(to: event.location) else { return }
        moveDetective(to: target)
    }

    override func handleDirectionalInput(_ direction: CGVector) {
        if dialogueIsActive {
            let selectionDirection = direction.dx < 0 || direction.dy > 0 ? -1 : 1
            if !caseIntroductionPresenter.moveSelection(selectionDirection) {
                let scrollStep: CGFloat = direction.dx < 0 || direction.dy > 0 ? -44 : 44
                _ = caseIntroductionPresenter.scrollContent(by: scrollStep)
            }
            return
        }
        if mapIsPresented { return }
        if journalIsPresented {
            journalOverlay.handleDirectionalInput(direction)
            return
        }
        if inventoryIsPresented {
            let previous = direction.dx < 0 || direction.dy > 0
            inventoryOverlay.moveSelection(previous ? -1 : 1)
            return
        }

        let step = 128 * OfficeInteriorScale.environment
        let candidate = CGPoint(
            x: detective.position.x + direction.dx * step,
            y: detective.position.y + direction.dy * (step * 0.5)
        )
        guard let target = navigation.nearestWalkablePoint(to: candidate) else { return }
        moveDetective(to: target)
    }

    override func handlePointerMoved(_ event: GamePointerEvent) {
        #if os(macOS)
        let hudPoint = hudRoot.convert(event.location, from: self)
        if dialogueIsActive {
            clearHotspotHoverHighlight()
            let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
            let isInteractive = caseIntroductionPresenter.updatePointer(at: dialoguePoint)
            (isInteractive ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if mapIsPresented {
            clearHotspotHoverHighlight()
            let mapPoint = areaMapOverlay.convert(hudPoint, from: hudRoot)
            (areaMapOverlay.isInteractive(at: mapPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if journalIsPresented {
            clearHotspotHoverHighlight()
            let journalPoint = journalOverlay.convert(hudPoint, from: hudRoot)
            (journalOverlay.isInteractive(at: journalPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if inventoryIsPresented {
            clearHotspotHoverHighlight()
            let overlayPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            (inventoryOverlay.isInteractive(at: overlayPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }

        let actionPoint = actionBar.convert(hudPoint, from: hudRoot)
        let mapIsHighlighted = actionBar.hitTestMap(actionPoint)
        actionBar.setMapButtonHighlighted(mapIsHighlighted)
        actionBar.setJournalButtonHighlighted(false)
        if mapIsHighlighted {
            clearHotspotHoverHighlight()
            NSCursor.pointingHand.set()
            return
        }

        let journalIsHighlighted = actionBar.hitTestJournal(actionPoint)
        actionBar.setJournalButtonHighlighted(journalIsHighlighted)
        if journalIsHighlighted {
            clearHotspotHoverHighlight()
            NSCursor.pointingHand.set()
            return
        }

        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint) {
            clearHotspotHoverHighlight()
            NSCursor.pointingHand.set()
            return
        }

        // Image #1 cyan silhouette + teal wash before click; same hit list as inspect/door.
        updateHotspotHoverHighlight(at: event.location)
        let isInteractive = hoveredHotspotID != nil
        (isInteractive ? NSCursor.pointingHand : NSCursor.arrow).set()
        #endif
    }

    override func handleInventoryInput() {
        guard !dialogueIsActive, !mapIsPresented, !journalIsPresented else { return }
        setInventoryPresented(!inventoryIsPresented)
    }

    override func handleMapInput() {
        guard !dialogueIsActive, !inventoryIsPresented, !journalIsPresented else { return }
        setMapPresented(!mapIsPresented)
    }

    override func handleJournalInput() {
        guard !dialogueIsActive, !inventoryIsPresented, !mapIsPresented else { return }
        setJournalPresented(!journalIsPresented)
    }

    override func handleScrollInput(_ deltaY: CGFloat) {
        if journalIsPresented {
            journalOverlay.moveSelection(deltaY > 0 ? -1 : 1)
        } else if dialogueIsActive {
            _ = caseIntroductionPresenter.scrollContent(by: -deltaY)
        }
    }

    override func handleConfirmInput() {
        if journalIsPresented {
            setJournalPresented(false)
            return
        }
        if mapIsPresented {
            setMapPresented(false)
            return
        }
        if dialogueIsActive {
            caseIntroductionPresenter.activateFocusedControl()
            return
        }
        guard inventoryIsPresented else { return }
        setInventoryPresented(false)
    }

    override func layoutViewport() {
        super.layoutViewport()
        let visibleSize = CGSize(width: size.width * baseCameraScale, height: referenceVisibleHeight)
        inventoryOverlay.layout(for: visibleSize)
        areaMapOverlay.layout(for: visibleSize)
        journalOverlay.layout(for: size)
        caseIntroductionPresenter.layout(for: visibleSize)
        // Camera children use screen-space points. The other overlays intentionally
        // follow the authored visible-world canvas, while the edge rail must span
        // the physical viewport from top to bottom.
        portraitBar.layout(for: size)
        actionBar.layout(for: size)
    }

    override func update(_ currentTime: TimeInterval) {
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth
        )
        areaMapOverlay.updateCurrentPosition(detective.position)
        updateDepth(of: detective)
        updateDepth(of: client)
        fogOfWar?.reveal(at: detective.position)
    }

    private func startCaseIntroduction() {
        animateDoorFalling()
        client.performEntrance(along: OfficeNavigationLayout.clientArrivalPath) { [weak self] in
            guard let self else { return }
            let dialogueCameraPosition = OfficeNavigationLayout.DialogueCameraFraming.dialogueCameraWorldPosition
            let cameraLift = SKAction.move(to: dialogueCameraPosition, duration: 0.3)
            cameraLift.timingMode = .easeOut
            self.gameCamera.run(cameraLift, withKey: "dialogueCameraLift")
            // Shipped Empty Coat intro: noir monologue + Lila March triad dialogue.
            self.caseIntroductionPresenter.present(
                EmptyCoatCaseIntroduction.nodes,
                startingAt: EmptyCoatCaseIntroduction.startNodeID
            ) { [weak self] in
                self?.finishCaseIntroduction()
            }
        }
    }

    private func finishCaseIntroduction() {
        for action in OfficeClientVisitSequencer.actions(for: .finishCaseIntroductionStarted) {
            applyClientVisitAction(action)
        }
    }

    private func applyClientVisitAction(_ action: OfficeClientVisitSequencer.Action) {
        switch action {
        case .restoreCamera:
            let normalCameraPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.camera)
            let cameraRestore = SKAction.move(to: normalCameraPosition, duration: 0.3)
            cameraRestore.timingMode = .easeInEaseOut
            gameCamera.run(cameraRestore, withKey: "dialogueCameraLift")
        case .beginClientExit:
            client.performExit(along: OfficeNavigationLayout.clientDeparturePath) { [weak self] in
                guard let self else { return }
                for next in OfficeClientVisitSequencer.actions(for: .clientExitCompleted) {
                    self.applyClientVisitAction(next)
                }
            }
        case .returnDoor:
            // After Lila has finished the departure path and faded out.
            animateDoorReturning()
        case .unlockPlayerControl:
            dialogueIsActive = false
            showOfficeHintIfNeeded()
        }
    }

    private func presentInspection(_ hotspot: OfficeHotspot) {
        let nodeID = "inspection.\(hotspot.id)"
        clearHotspotHoverHighlight()
        dialogueIsActive = true
        caseIntroductionPresenter.present([
            CaseDialogueNode(
                id: nodeID,
                speaker: hotspot.name,
                text: hotspot.observation,
                portraitName: "dialogue_portrait_elias_vale_v01",
                endsDialogue: true
            )
        ], startingAt: nodeID) { [weak self] in
            self?.dialogueIsActive = false
        }
    }

    private func showOfficeHintIfNeeded() {
        guard !context.session.hasSeenOfficeHint else { return }
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = "Tap or click the floor to stand and move. Select an object to inspect it."
        hint.fontSize = 18
        hint.fontColor = SKColor(white: 0.82, alpha: 0.85)
        hint.position = CGPoint(x: 0, y: 280)
        hint.alpha = 0
        hudRoot.addChild(hint)
        hint.run(.sequence([
            .wait(forDuration: 0.6),
            .fadeIn(withDuration: 0.4),
            .wait(forDuration: 5.5),
            .fadeOut(withDuration: 0.8),
            .removeFromParent()
        ]))
        context.session.markOfficeHintSeen()
    }

    private func moveDetective(to target: CGPoint, completion: (() -> Void)? = nil) {
        guard let path = navigation.path(from: detective.position, to: target) else { return }
        detective.walk(path: path, completion: completion)
    }

    private func setInventoryPresented(_ presented: Bool) {
        guard inventoryIsPresented != presented else { return }
        inventoryIsPresented = presented
        if presented {
            clearHotspotHoverHighlight()
        }

        let pausedWorldRoots = [
            backgroundRoot,
            floorEffectRoot,
            rearFixtureRoot,
            depthWorldRoot,
            occlusionRoot,
            weatherRoot,
            cinematicRoot
        ]
        pausedWorldRoots.forEach { $0.isPaused = presented }
        portraitBar.isHidden = presented
        actionBar.isHidden = presented

        if presented {
            inventoryOverlay.present()
        } else {
            inventoryOverlay.hideAnimated()
        }
    }

    private func setMapPresented(_ presented: Bool) {
        guard mapIsPresented != presented else { return }
        mapIsPresented = presented
        if presented {
            clearHotspotHoverHighlight()
        }

        let pausedWorldRoots = [
            backgroundRoot,
            floorEffectRoot,
            rearFixtureRoot,
            depthWorldRoot,
            occlusionRoot,
            weatherRoot,
            cinematicRoot
        ]
        pausedWorldRoots.forEach { $0.isPaused = presented }
        portraitBar.isHidden = presented
        actionBar.isHidden = presented

        if presented {
            areaMapOverlay.present(currentPosition: detective.position)
        } else {
            areaMapOverlay.hideAnimated()
        }
    }

    private func setJournalPresented(_ presented: Bool) {
        guard journalIsPresented != presented else { return }
        journalIsPresented = presented
        if presented { clearHotspotHoverHighlight() }

        let pausedWorldRoots = [
            backgroundRoot,
            floorEffectRoot,
            rearFixtureRoot,
            depthWorldRoot,
            occlusionRoot,
            weatherRoot,
            cinematicRoot
        ]
        pausedWorldRoots.forEach { $0.isPaused = presented }
        portraitBar.isHidden = presented
        actionBar.isHidden = presented

        if presented {
            journalOverlay.present(inspectedHotspotIDs: context.session.inspectedHotspotIDs)
        } else {
            journalOverlay.hideAnimated()
        }
    }

    private func configureNavigation() {
        navigation = OfficeNavigationLayout.makeGrid()
    }

    private func configureHotspots() {
        hotspots = OfficeNavigationLayout.authoredHotspots.map { item in
            OfficeHotspot(
                id: item.id,
                name: item.name,
                hitArea: OfficeInteriorScale.mapRect(item.hitArea),
                approachPoint: OfficeNavigationLayout.approachPoints[item.id]!,
                observation: item.observation
            )
        }
    }

    private func registerHoverSprite(_ sprite: SKSpriteNode, for hotspotID: String) {
        hotspotHoverSprites[hotspotID, default: []].append(sprite)
    }

    /// Applies the shipped hover presentation contract for free exploration.
    private func updateHotspotHoverHighlight(at worldPoint: CGPoint) {
        let blocked = dialogueIsActive || mapIsPresented || inventoryIsPresented || journalIsPresented
        let targets = hotspots.map {
            HotspotHoverHighlight.Target(id: $0.id, hitArea: $0.hitArea)
        }
        let presentation = HotspotHoverHighlight.presentation(
            at: worldPoint,
            among: targets,
            worldInteractionBlocked: blocked
        )
        applyHotspotHoverPresentation(presentation)
    }

    private func clearHotspotHoverHighlight() {
        applyHotspotHoverPresentation(.hidden)
    }

    /// Cached cyan rim textures keyed by prop asset name (CPU-built, rim pixels only).
    private var hoverEdgeTextureCache: [String: SKTexture] = [:]

    /// Drives Image #1 cyan silhouette **edge** + teal body wash on registered props.
    /// Wash = colorBlendFactor; edge = CPU overlay texture (no SKShader solid-fill).
    private func applyHotspotHoverPresentation(_ presentation: HotspotHoverHighlight.Presentation) {
        hoveredHotspotID = presentation.hotspotID
        // Reset every hover-capable prop to neutral art (wash + outline off).
        for sprites in hotspotHoverSprites.values {
            for sprite in sprites {
                clearHoverVisual(on: sprite)
            }
        }
        guard presentation.isVisible,
              presentation.usesSpriteTint,
              let id = presentation.hotspotID else {
            return
        }
        for sprite in hotspotHoverSprites[id] ?? [] {
            applyHoverWashAndEdgeOverlay(to: sprite, presentation: presentation)
        }
    }

    private func clearHoverVisual(on sprite: SKSpriteNode) {
        sprite.color = .white
        sprite.colorBlendFactor = HotspotHoverHighlight.clearedColorBlendFactor
        sprite.children
            .filter {
                $0.name == HotspotHoverHighlight.edgeOverlayNodeName
                    || $0.name == "hoverSilhouetteOutline"
            }
            .forEach { $0.removeFromParent() }
    }

    /// Teal body wash + thin pure-cyan rim overlay (Image #1). Overlay never fills the body.
    private func applyHoverWashAndEdgeOverlay(
        to sprite: SKSpriteNode,
        presentation: HotspotHoverHighlight.Presentation
    ) {
        // 1) Body wash — original art still reads under teal tint.
        sprite.color = SKColor(
            red: presentation.washRed,
            green: presentation.washGreen,
            blue: presentation.washBlue,
            alpha: 1
        )
        sprite.colorBlendFactor = presentation.outlineEnabled
            ? presentation.colorBlendFactor
            : HotspotHoverHighlight.clearedColorBlendFactor

        guard presentation.outlineEnabled else { return }

        // 2) Cyan rim overlay (rim texels only; body stays clear in the overlay).
        guard let edgeTexture = cyanEdgeTexture(for: sprite, presentation: presentation) else {
            return
        }
        let overlay = SKSpriteNode(texture: edgeTexture, size: sprite.size)
        overlay.name = HotspotHoverHighlight.edgeOverlayNodeName
        overlay.anchorPoint = sprite.anchorPoint
        overlay.position = .zero
        overlay.zPosition = 1
        overlay.color = .white
        overlay.colorBlendFactor = 0
        overlay.blendMode = .alpha
        overlay.isUserInteractionEnabled = false
        sprite.addChild(overlay)
    }

    /// Builds or returns a cached rim-only texture for this prop asset.
    private func cyanEdgeTexture(
        for sprite: SKSpriteNode,
        presentation: HotspotHoverHighlight.Presentation
    ) -> SKTexture? {
        let key = sprite.name ?? "anonymous"
        if let cached = hoverEdgeTextureCache[key] {
            return cached
        }
        guard let source = loadStraightRGBA(named: key) else { return nil }
        let steps = HotspotHoverHighlight.outlineTexelSteps(
            worldWidth: presentation.outlineWidth,
            pixelWidth: source.width,
            pixelHeight: source.height,
            scaleX: sprite.xScale,
            scaleY: sprite.yScale
        )
        let overlayRGBA = HotspotHoverHighlight.makeCyanEdgeOverlayPremultipliedRGBA(
            sourceRGBA: source.rgba,
            width: source.width,
            height: source.height,
            stepX: steps.x,
            stepY: steps.y,
            presentation: presentation
        )
        guard let cgImage = makePremultipliedCGImage(
            rgba: overlayRGBA,
            width: source.width,
            height: source.height
        ) else {
            return nil
        }
        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .linear
        hoverEdgeTextureCache[key] = texture
        return texture
    }

    private func loadStraightRGBA(named name: String) -> (rgba: [UInt8], width: Int, height: Int)? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            return nil
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let width = image.width
        let height = image.height
        var premul = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &premul,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var straight = [UInt8](repeating: 0, count: premul.count)
        for i in Swift.stride(from: 0, to: premul.count, by: 4) {
            let a = premul[i + 3]
            straight[i + 3] = a
            if a == 0 {
                continue
            }
            if a == 255 {
                straight[i] = premul[i]
                straight[i + 1] = premul[i + 1]
                straight[i + 2] = premul[i + 2]
            } else {
                let fa = CGFloat(a)
                straight[i] = UInt8(min(255, (CGFloat(premul[i]) * 255.0 / fa).rounded()))
                straight[i + 1] = UInt8(min(255, (CGFloat(premul[i + 1]) * 255.0 / fa).rounded()))
                straight[i + 2] = UInt8(min(255, (CGFloat(premul[i + 2]) * 255.0 / fa).rounded()))
            }
        }
        return (straight, width, height)
    }

    private func makePremultipliedCGImage(
        rgba: [UInt8],
        width: Int,
        height: Int
    ) -> CGImage? {
        var bytes = rgba
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        return ctx.makeImage()
    }

    private func addWindowRain() {
        let crop = SKCropNode()
        let maskRect = OfficeInteriorScale.mapRect(OfficeNavigationLayout.AuthoredPlacement.windowRainMask)
        let mask = SKShapeNode(rect: maskRect)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask

        let rain = RainSystem.makeEmitter(
            width: 850 * OfficeInteriorScale.environment,
            height: 760 * OfficeInteriorScale.environment,
            birthRate: 150,
            speed: 520 * OfficeInteriorScale.environment,
            scale: 0.38 * OfficeInteriorScale.environment,
            alpha: 0.42
        )
        rain.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.windowRainEmitter)
        crop.addChild(rain)
        rearFixtureRoot.addChild(crop)
    }

    /// Mirrors the window pixels baked into the shell as an independent sprite so the
    /// same shader-free wash + edge overlay used by every other hotspot can target it.
    private func addWindowHighlightProp() {
        guard let texture = GameArt.texture(named: "office_window") else { return }
        let window = SKSpriteNode(texture: texture)
        window.name = "office_window"
        window.position = OfficeInteriorScale.mapPoint(CGPoint(x: 768, y: 1_507))
        window.setScale(OfficeInteriorScale.environment)
        window.texture?.filteringMode = .linear
        rearFixtureRoot.addChild(window)
        registerHoverSprite(window, for: "office.window")
    }

    private func addLampAtmosphere() {
        let pool = SKShapeNode(ellipseOf: CGSize(
            width: 1_050 * OfficeInteriorScale.environment,
            height: 570 * OfficeInteriorScale.environment
        ))
        pool.fillColor = SKColor(red: 0.72, green: 0.38, blue: 0.12, alpha: 0.08)
        pool.strokeColor = .clear
        pool.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.lampPool)
        pool.blendMode = .add
        floorEffectRoot.addChild(pool)
    }

    private func addFogOfWar() {
        let fog = OfficeFogOfWarNode(
            size: OfficeInteriorScale.scaledArtSize,
            origin: OfficeInteriorScale.shellOrigin,
            initialReveal: OfficeNavigationLayout.actorStart
        )
        // The opening conversation starts with Vivian crossing from the door,
        // so her authored entrance is part of the initially explored office.
        for point in OfficeNavigationLayout.clientArrivalPath {
            fog.reveal(at: point, forceTrailPoint: true)
        }
        weatherRoot.addChild(fog)
        fogOfWar = fog
    }

    @discardableResult
    private func addRearFixture(named textureName: String, at position: CGPoint, scale: CGFloat) -> SKSpriteNode? {
        guard let texture = GameArt.texture(named: textureName) else { return nil }
        let fixture = SKSpriteNode(texture: texture)
        fixture.name = textureName
        fixture.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        fixture.position = position
        fixture.setScale(scale)
        fixture.texture?.filteringMode = .linear
        rearFixtureRoot.addChild(fixture)
        return fixture
    }

    /// Vivian's entrance knocks the already damaged leaf off its hinges. Keeping
    /// the low anchor makes the swing read as a door tipping from its threshold.
    private func animateDoorFalling() {
        guard let officeDoor else { return }

        officeDoor.removeAction(forKey: "officeDoorMotion")
        let environment = OfficeInteriorScale.environment
        let fall = SKAction.group([
            .rotate(toAngle: -.pi / 2, duration: 0.32, shortestUnitArc: false),
            .moveBy(x: 18 * environment, y: -30 * environment, duration: 0.32)
        ])
        fall.timingMode = .easeIn
        let settle = SKAction.group([
            .moveBy(x: -4 * environment, y: 3 * environment, duration: 0.11),
            .rotate(byAngle: 0.035, duration: 0.11)
        ])
        settle.timingMode = .easeOut
        let rest = SKAction.group([
            .moveBy(x: 4 * environment, y: -3 * environment, duration: 0.09),
            .rotate(toAngle: -.pi / 2, duration: 0.09, shortestUnitArc: false)
        ])
        rest.timingMode = .easeIn
        officeDoor.run(.sequence([.wait(forDuration: 0.16), fall, settle, rest]), withKey: "officeDoorMotion")
    }

    /// The door is restored only after Vivian has finished her exit path and
    /// cleared the room, ready for the next visitor.
    private func animateDoorReturning() {
        guard let officeDoor else { return }

        officeDoor.removeAction(forKey: "officeDoorMotion")
        let uprightPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf)
        let returnToFrame = SKAction.group([
            .rotate(toAngle: 0, duration: 0.34, shortestUnitArc: false),
            .move(to: uprightPosition, duration: 0.34)
        ])
        returnToFrame.timingMode = .easeOut
        officeDoor.run(returnToFrame, withKey: "officeDoorMotion")
    }

    @discardableResult
    private func addDepthProp(
        named textureName: String,
        at position: CGPoint,
        scale: CGFloat = 1,
        bias: CGFloat = 0
    ) -> SKSpriteNode? {
        guard let texture = GameArt.texture(named: textureName) else { return nil }
        let prop = SKSpriteNode(texture: texture)
        prop.name = textureName
        prop.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        prop.position = position
        prop.setScale(scale)
        prop.texture?.filteringMode = .linear
        updateDepth(of: prop, bias: bias)
        depthWorldRoot.addChild(prop)
        return prop
    }

    /// Desk items are independent sprites aligned to the 932x780 bare-desk canvas.
    /// Only items with their own hotspot are highlight-registered; desk selection never
    /// leaks into loose props. Native content sizes reproduce the tiny BG-era room scale.
    private func addDeskItems(at deskPosition: CGPoint, scale: CGFloat) {
        let itemCenters: [(name: String, center: CGPoint, hotspotID: String?)] = [
            ("office_desk_papers", CGPoint(x: 423, y: 224), nil),
            ("office_desk_files", CGPoint(x: 186, y: 301), "office.files"),
            ("office_desk_lamp", CGPoint(x: 716, y: 120), nil),
            ("office_desk_phone", CGPoint(x: 648, y: 213), "office.phone"),
            ("office_desk_mug", CGPoint(x: 391, y: 298), nil),
            ("office_desk_ashtray", CGPoint(x: 502, y: 313), nil)
        ]
        let deskCanvas = CGSize(width: 932, height: 780)
        let deskAnchor = CGPoint(x: 0.5, y: 0.04)

        for item in itemCenters {
            guard let texture = GameArt.texture(named: item.name) else { continue }
            let node = SKSpriteNode(texture: texture)
            node.name = item.name
            node.position = CGPoint(
                x: deskPosition.x + (item.center.x - deskCanvas.width * deskAnchor.x) * scale,
                y: deskPosition.y + (deskCanvas.height * (1 - deskAnchor.y) - item.center.y) * scale
            )
            node.setScale(scale)
            node.texture?.filteringMode = .linear
            updateDepth(of: node)
            depthWorldRoot.addChild(node)
            if let hotspotID = item.hotspotID {
                registerHoverSprite(node, for: hotspotID)
            }
        }
    }

    private func buildFallbackOffice() {
        let floor = SKShapeNode(rect: CGRect(origin: OfficeInteriorScale.shellOrigin, size: OfficeInteriorScale.scaledArtSize))
        floor.fillColor = SKColor(red: 0.09, green: 0.075, blue: 0.065, alpha: 1)
        floor.strokeColor = .clear
        backgroundRoot.addChild(floor)

        let desk = SKShapeNode(rectOf: CGSize(width: 1_000 * OfficeInteriorScale.environment, height: 540 * OfficeInteriorScale.environment), cornerRadius: 16)
        desk.fillColor = SKColor(red: 0.2, green: 0.12, blue: 0.075, alpha: 1)
        desk.strokeColor = SKColor(red: 0.34, green: 0.2, blue: 0.1, alpha: 1)
        desk.position = OfficeInteriorScale.mapPoint(CGPoint(x: 1_440, y: 730))
        updateDepth(of: desk, bias: 4)
        depthWorldRoot.addChild(desk)

        let window = SKShapeNode(rect: OfficeInteriorScale.mapRect(CGRect(x: 180, y: 1_020, width: 820, height: 760)))
        window.fillColor = SKColor(red: 0.035, green: 0.09, blue: 0.15, alpha: 1)
        window.strokeColor = SKColor(white: 0.16, alpha: 1)
        window.lineWidth = 20 * OfficeInteriorScale.environment
        backgroundRoot.addChild(window)

        let door = SKShapeNode(rect: OfficeInteriorScale.mapRect(CGRect(x: 2_340, y: 870, width: 480, height: 940)))
        door.fillColor = SKColor(red: 0.12, green: 0.075, blue: 0.05, alpha: 1)
        door.strokeColor = SKColor(white: 0.13, alpha: 1)
        door.lineWidth = 18 * OfficeInteriorScale.environment
        backgroundRoot.addChild(door)
    }
}

/// Classic isometric fog-of-war: fully black unexplored space with a slightly
/// irregular painted edge. Reveal samples persist as the detective moves, while
/// the environment, props, actors, and HUD remain independent layers.
@MainActor
private final class OfficeFogOfWarNode: SKSpriteNode {
    private static let pointCapacity = 8
    private static let revealRadius: CGFloat = 390
    private static let maskPixelSize = CGSize(width: 512, height: 256)

    private var trail: [CGPoint] = []
    private var currentReveal: CGPoint

    init(size: CGSize, origin: CGPoint, initialReveal: CGPoint) {
        currentReveal = CGPoint(
            x: initialReveal.x - origin.x,
            y: initialReveal.y - origin.y
        )
        super.init(texture: nil, color: .black, size: size)
        anchorPoint = .zero
        position = origin
        updateFogTexture()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("OfficeFogOfWarNode is created programmatically")
    }

    func reveal(at worldPoint: CGPoint, forceTrailPoint: Bool = false) {
        let localPoint = CGPoint(x: worldPoint.x - position.x, y: worldPoint.y - position.y)
        let movement = hypot(localPoint.x - currentReveal.x, localPoint.y - currentReveal.y)
        let shouldCommit = forceTrailPoint || movement >= Self.revealRadius * 0.42
        guard forceTrailPoint || movement >= 12 else { return }

        if trail.isEmpty || shouldCommit {
            trail.append(localPoint)
            if trail.count > Self.pointCapacity - 1 {
                trail.removeFirst(trail.count - (Self.pointCapacity - 1))
            }
        }
        currentReveal = localPoint
        updateFogTexture()
    }

    private func updateFogTexture() {
        let points = Array(trail.suffix(Self.pointCapacity - 1)) + [currentReveal]
        let pixelWidth = Int(Self.maskPixelSize.width)
        let pixelHeight = Int(Self.maskPixelSize.height)
        let bytesPerRow = pixelWidth * 4
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        context.setBlendMode(.copy)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: Self.maskPixelSize))
        context.setBlendMode(.destinationOut)

        let pixelScale = Self.maskPixelSize.width / size.width
        for (index, point) in points.enumerated() {
            let center = CGPoint(
                x: point.x / size.width * Self.maskPixelSize.width,
                y: point.y / size.height * Self.maskPixelSize.height
            )
            let phase = CGFloat(index) * 0.83
            let featherLayers: [(scale: CGFloat, alpha: CGFloat)] = [
                (1.045, 0.16),
                (1.020, 0.24),
                (0.995, 0.36),
                (0.965, 1.00)
            ]
            for layer in featherLayers {
                let path = Self.irregularRevealPath(
                    center: center,
                    radius: Self.revealRadius * pixelScale * layer.scale,
                    phase: phase
                )
                context.addPath(path)
                context.setFillColor(CGColor(gray: 1, alpha: layer.alpha))
                context.fillPath()
            }
        }

        guard let image = context.makeImage() else { return }
        let fogTexture = SKTexture(cgImage: image)
        fogTexture.filteringMode = .linear
        texture = fogTexture
    }

    private static func irregularRevealPath(center: CGPoint, radius: CGFloat, phase: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let segmentCount = 96
        for segment in 0..<segmentCount {
            let angle = CGFloat(segment) / CGFloat(segmentCount) * .pi * 2
            let paintedEdge = sin(angle * 9 + phase) * 7.5
                + sin(angle * 21 - phase * 0.7) * 3.5
                + sin(angle * 37 + phase * 1.3) * 1.8
            let point = CGPoint(
                x: center.x + cos(angle) * (radius + paintedEdge),
                y: center.y + sin(angle) * (radius + paintedEdge)
            )
            if segment == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

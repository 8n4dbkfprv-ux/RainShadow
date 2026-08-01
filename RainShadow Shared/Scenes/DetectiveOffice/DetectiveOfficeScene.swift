import SpriteKit
import simd
#if os(macOS)
import AppKit
#endif

@MainActor
final class DetectiveOfficeScene: BaseGameScene {
    private let detective = DetectiveActorNode()
    private let client = ClientActorNode()
    private var officeDoor: SKSpriteNode?
    private var officeDoorThickness: SKSpriteNode?
    private var officeDoorFallShadow: SKShapeNode?
    private var officeDoorUsesFallenArtwork = false
    /// Separate chair prop; hidden while seated because the NE rear-view atlas
    /// already bakes the chair into the body sprite.
    private var deskChairProp: SKSpriteNode?
    private var deskActorOccluder: SKSpriteNode?
    private var deskFrontOccluder: SKSpriteNode?
    /// Writing-surface mask above seated torso (coat under wood).
    private var deskTopOccluder: SKSpriteNode?
    /// Loose desk props — lifted above the top occluder while seated.
    private var deskItemNodes: [SKSpriteNode] = []
    private let caseIntroductionPresenter = CaseIntroductionPresenter()
    private let inventoryOverlay = InventoryOverlay()
    private let portraitBar = PortraitBarNode()
    private let actionBar = ActionBarNode()
    private let areaMapOverlay = AreaMapOverlay()
    private let journalOverlay = JournalOverlay()
    private var fogOfWar: OfficeFogOfWarNode?
    private var navigation: NavigationGrid!
    private var hotspots: [OfficeHotspot] = []
    private struct HotspotHoverSprite {
        let sprite: SKSpriteNode
        let normalTexture: SKTexture
        let hoverTexture: SKTexture
    }

    /// Office hover art is pre-baked; hovering only swaps complete PNG textures.
    private var hotspotHoverSprites: [String: [HotspotHoverSprite]] = [:]
    private var hoveredHotspotID: String?
    private var inventoryIsPresented = false
    private var mapIsPresented = false
    private var journalIsPresented = false
    private var caseIntroductionStarted = false
    private var clientEntranceStarted = false
    /// Wall-clock origin of the forced/authored entrance (QA seek + pacing).
    private var clientEntranceStartedAt: TimeInterval?
    private var clientEntrancePath: [CGPoint] = []
    /// Dialogue node to show after the BG-style entrance cinematic (deferred Continue).
    private var pendingPostEntranceNodeID: String?
    private var dialogueIsActive = true
    /// Infinity Engine–style cutscene chrome: hide party/action rails while an
    /// authored NPC enter/exit sequence runs (dialogue panel is suppressed separately).
    private var cutsceneChromeSuppressed = false

    override var referenceVisibleHeight: CGFloat { OfficeInteriorScale.cameraVisibleHeight }

    init(context: GameContext) {
        super.init(context: context, artSize: OfficeInteriorScale.sourceArtSize)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DetectiveOfficeScene is created programmatically")
    }

    override func buildScene() {
        addChild(RainAudio.loopingAmbience(fileNamed: "amb_rain_window.m4a", volume: 0.27))

        let standardPropScale = OfficeInteriorScale.standardPropDisplayScale
        let smallPropScale = OfficeInteriorScale.smallPropDisplayScale

        // Stage 1+: one pre-rendered suite plate replaces shell + partition overlays.
        // Keep the plate intact — do not punch door columns or strip baked artwork.
        let usingSuitePlate: Bool
        if let texture = GameArt.texture(named: "office_suite_plate") {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
            background.name = "office_suite_plate"
            background.anchorPoint = .zero
            background.position = OfficeInteriorScale.shellOrigin
            backgroundRoot.addChild(background)
            usingSuitePlate = true
        } else if let texture = GameArt.texture(named: "office_shell_base") {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
            background.name = "office_shell_base"
            background.anchorPoint = .zero
            background.position = OfficeInteriorScale.shellOrigin
            backgroundRoot.addChild(background)
            usingSuitePlate = false
        } else {
            buildFallbackOffice()
            usingSuitePlate = false
        }

        addOfficeAtmosphere()
        addNoirStoryClutter()
        addWindowHighlightProp()
        addWindowRain()
        addRecordsWallArt()
        // Partition strips / cutaway mask / foreground void are obsolete in
        // production when the suite plate is present. Opt back in only for
        // legacy A/B: RAINSHADOW_LEGACY_PARTITION=1
        let legacyPartition = ProcessInfo.processInfo.environment["RAINSHADOW_LEGACY_PARTITION"] == "1"
        if !usingSuitePlate || legacyPartition {
            addPartitionWall()
            addForegroundCutaway()
        }
        addInternalOfficeDoor()
        addScaleReferenceStandsIfRequested()
        addArchitectureDebugOverlayIfRequested()

        // Radiator is its own prop — never bind it to the office.window hover texture.
        addRearFixture(
            named: "office_radiator",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.radiator),
            scale: standardPropScale
        )

        // MARK: Records wall
        addDepthProp(
            named: "office_bookshelf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.bookshelf),
            scale: OfficeInteriorScale.bookshelfDisplayScale
        )
        addFloorContactShadow(
            named: "office_cabinet_floor_shadow",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.filingCabinet),
            scale: standardPropScale
        )
        // Open-drawer cabinet is the interactive files hotspot; closed twin beside it.
        addDepthProp(
            named: "office_filing_cabinet_open",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.filingCabinet),
            scale: standardPropScale
        )
        // Closed twin beside the open-drawer cabinet (distinct art, same scale).
        addDepthProp(
            named: "office_filing_cabinet",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.filingCabinetB),
            scale: standardPropScale
        )
        addDepthProp(
            named: "office_safe",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.safe),
            scale: smallPropScale
        )
        addDepthProp(
            named: "office_archive_box_b",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.archiveBoxOnCabinet),
            scale: smallPropScale * 0.9,
            bias: 40
        )
        addDepthProp(
            named: "office_archive_stack",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.archiveStackOnCabinet),
            scale: OfficeInteriorScale.archiveStackDisplayScale,
            bias: 45
        )
        addDepthProp(
            named: "office_archive_box_a",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.archiveBoxA),
            scale: smallPropScale
        )

        // The suite plate owns the integrated jamb/reveal/threshold. The leaf
        // and its dark edge remain independent so the fall can carry real depth.
        officeDoorThickness = addRearFixture(
            named: "office_door_leaf_thickness",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf),
            scaleX: OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleX,
            scaleY: OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleY,
            anchorY: OfficeNavigationLayout.Architecture.entranceLeafAnchorY
        )
        officeDoorThickness?.alpha = 0
        officeDoor = addRearFixture(
            named: "office_door_leaf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf),
            scaleX: OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleX,
            scaleY: OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleY,
            anchorY: OfficeNavigationLayout.Architecture.entranceLeafAnchorY
        )
        if let officeDoor {
            registerHoverSprite(officeDoor, for: "office.door")
        }

        // MARK: Entrance / waiting nook (rack + two chairs + table)
        let coatRack = addDepthProp(
            named: "office_coat_rack",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.coatRack),
            scale: OfficeInteriorScale.coatRackDisplayScale
        )
        coatRack?.alpha = 0.78
        addDepthProp(
            named: "office_umbrella_stand",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.umbrellaStand),
            scale: smallPropScale
        )
        addDepthProp(
            named: "office_waiting_chair_a",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.waitingChairA),
            scale: OfficeInteriorScale.waitingChairDisplayScale
        )
        addDepthProp(
            named: "office_waiting_table",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.waitingTable),
            scale: OfficeInteriorScale.waitingTableDisplayScale
        )
        addDepthProp(
            named: "office_waiting_chair_b",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.waitingChairB),
            scale: OfficeInteriorScale.waitingChairBDisplayScale
        )
        addDepthProp(
            named: "office_newspaper",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.newspaper),
            scale: OfficeInteriorScale.pocketPropDisplayScale,
            bias: -20
        )
        addDepthProp(
            named: "office_waiting_ashtray",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.waitingAshtray),
            scale: OfficeInteriorScale.pocketPropDisplayScale,
            bias: -15
        )

        // MARK: Personal corner (west wall, own group near desk)
        addDepthProp(
            named: "office_personal_sideboard",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.personalSideboard),
            scale: OfficeInteriorScale.standardPropDisplayScale * 0.92,
            bias: -10
        )
        addDepthProp(
            named: "office_hidden_bottle",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.personalBottle),
            scale: OfficeInteriorScale.hiddenBottleDisplayScale,
            bias: -20
        )
        addDepthProp(
            named: "office_personal_glass",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.personalGlass),
            scale: OfficeInteriorScale.pocketPropDisplayScale,
            bias: -25
        )
        addDepthProp(
            named: "office_personal_fan",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.personalFan),
            scale: OfficeInteriorScale.standingFanDisplayScale,
            bias: -5
        )
        // MARK: Desk cluster
        deskChairProp = addDepthProp(
            named: "office_desk_chair",
            at: OfficeNavigationLayout.emptyDeskChairWorldPosition,
            scale: OfficeInteriorScale.seatingPropDisplayScale,
            bias: -40
        )
        deskChairProp?.isHidden = true
        addWornRug()
        addDepthProp(
            named: "office_visitor_armchair",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.visitorArmchair),
            scale: OfficeInteriorScale.visitorArmchairDisplayScale,
            bias: OfficeNavigationLayout.DeskDepth.visitorChairBias
        )
        addDepthProp(
            named: "office_visitor_armchair",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.visitorArmchairB),
            scale: OfficeInteriorScale.visitorArmchairDisplayScale * 0.96,
            bias: OfficeNavigationLayout.DeskDepth.visitorChairBias
        )
        addDepthProp(
            named: "office_wastebasket",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.wastebasket),
            scale: smallPropScale
        )
        let deskPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskEnsemble)
        let deskScale = OfficeInteriorScale.deskDisplayScale
        addFloorContactShadow(
            named: "office_desk_floor_shadow",
            at: deskPosition,
            scale: deskScale * 1.15
        )
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
        updateDetectiveDepth()
        depthWorldRoot.addChild(detective)

        if let clientStart = OfficeNavigationLayout.clientDoorwayPath.first {
            client.position = clientStart
        }
        updateDepth(of: client)
        depthWorldRoot.addChild(client)

        // Occluder biases are refreshed each frame in `updateDetectiveDepth`
        // (behind the rear-view seated body; above desk for standing walk-past).
        deskActorOccluder = addDepthProp(
            named: "office_desk_actor_occluder",
            at: deskPosition,
            scale: deskScale,
            bias: -60
        )
        if let deskActorOccluder {
            registerHoverSprite(deskActorOccluder, for: "office.desk")
        }

        deskFrontOccluder = addDepthProp(
            named: "office_desk_front_occluder_v04",
            at: deskPosition,
            scale: deskScale,
            bias: -20
        )
        if let deskFrontOccluder {
            registerHoverSprite(deskFrontOccluder, for: "office.desk")
        }

        deskTopOccluder = addDepthProp(
            named: "office_desk_top_occluder",
            at: deskPosition,
            scale: deskScale,
            bias: OfficeNavigationLayout.DeskDepth.topOccluderBias
        )
        if let deskTopOccluder {
            registerHoverSprite(deskTopOccluder, for: "office.desk")
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
        syncHudToCamera()
        addNodePositionMarkersIfRequested()
    }

    override func sceneDidBecomeReady() {
        guard !caseIntroductionStarted else { return }
        // QA hook: leave the office idle so art/layout can be inspected.
        if ProcessInfo.processInfo.environment["RAINSHADOW_SKIP_INTRO"] == "1" {
            caseIntroductionStarted = true
            if ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_FALLEN_DOOR"] == "1" {
                setDoorFallenForReview()
            } else if ProcessInfo.processInfo.environment["RAINSHADOW_ANIMATE_DOOR_FALL"] == "1" {
                // Let the review window finish appearing before the QA-only
                // motion starts, so timed captures can sample the actual fall.
                run(.sequence([
                    .wait(forDuration: 0.75),
                    .run { [weak self] in self?.animateDoorFalling() }
                ]))
            }
            // QA: run Lila's entrance without the monologue cue (mid-door captures).
            // Use GCD — SKAction waits do not fire when the capture launch has
            // no drawable / does not tick the scene.
            if ProcessInfo.processInfo.environment["RAINSHADOW_FORCE_CLIENT_ENTRANCE"] == "1" {
                navigation = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.beginClientEntranceIfNeeded()
                }
            }
            return
        }
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
            portraitBar.beginUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
            // Touch has no pointer-move phase, and synthetic/rapid clicks may not deliver
            // one on macOS. Apply the same selection feedback immediately on press.
            updateHotspotHoverHighlight(at: event.location)
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
            portraitBar.updateUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
            return
        }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerDragged(at: dialoguePoint)
    }

    override func handlePointerCancelled(_ event: GamePointerEvent) {
        guard dialogueIsActive else {
            actionBar.cancelPress()
            portraitBar.cancelUtilityPress()
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
        _ = portraitBar.endUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
        let activatedButton = actionBar.endPress(at: actionPoint)
        if activatedButton == .map {
            setMapPresented(true)
            return
        }
        if activatedButton == .journal {
            setJournalPresented(true)
            return
        }
        if activatedButton == .inventory || activatedButton == .character {
            setInventoryPresented(true)
            return
        }

        if let hotspot = hotspots.first(where: { $0.hitArea.contains(event.location) }) {
            if hotspot.id == "office.door" {
                moveDetective(
                    to: hotspot.approachPoint,
                    requiresExactDestination: true
                ) { [weak self] in
                    self?.context.router.showCityDistrict(.sableRow, arrivalKey: "from.office")
                }
                return
            }
            moveDetective(
                to: hotspot.approachPoint,
                requiresExactDestination: true
            ) { [weak self] in
                guard let self else { return }
                self.context.session.markInspected(hotspot.id)
                self.presentInspection(hotspot)
            }
            return
        }

        moveDetective(to: event.location)
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
        moveDetective(to: candidate)
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
        let hoveredAction = actionBar.hitTest(actionPoint)
        actionBar.setHighlightedButton(hoveredAction)
        if let hoveredAction, hoveredAction.isInteractive {
            clearHotspotHoverHighlight()
            NSCursor.pointingHand.set()
            return
        }

        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint)
            || portraitBar.hitTestUtility(portraitPoint) != nil {
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

    override func handleCancelInput() {
        if journalIsPresented {
            setJournalPresented(false)
        } else if mapIsPresented {
            setMapPresented(false)
        } else if inventoryIsPresented {
            setInventoryPresented(false)
        } else if !dialogueIsActive {
            detective.cancelMovement()
        }
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
        // After `super`, `size` matches the live SKView. Frame all chrome in those
        // points (not world-visible size, which inflated HUD when the camera zoomed).
        let hudViewportSize = size
        inventoryOverlay.layout(for: hudViewportSize)
        areaMapOverlay.layout(for: hudViewportSize)
        journalOverlay.layout(for: hudViewportSize)
        caseIntroductionPresenter.layout(for: hudViewportSize)
        portraitBar.layout(for: hudViewportSize)
        actionBar.layout(for: hudViewportSize)
    }

    override func update(_ currentTime: TimeInterval) {
        detective.updateLocomotion(
            at: currentTime,
            worldIsPaused: dialogueIsActive
                || mapIsPresented
                || journalIsPresented
                || inventoryIsPresented
        )
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth
        )
        areaMapOverlay.updateCurrentPosition(detective.position)
        updateDetectiveDepth()
        updateDepth(of: client)
        fogOfWar?.reveal(at: detective.position)
        // Follow dialogue camera lifts / restores every frame.
        syncHudToCamera()
    }

    /// Seated NE rear-view: torso/head above the front apron.
    /// Actor occluder stays desk-native — elevating it stamped a wood rectangle
    /// over the chair feet (the floor-band clipping under the seat).
    /// Desk-top stays desk-native. Bare desk stays at -500.
    /// Standing: front apron rises for walk-past.
    private func updateDetectiveDepth() {
        if detective.isDeskRegistered {
            // Pin the sort key to the desk ground anchor so local upper z and
            // apron bias form a stable order. The nav root sits ~80px north of
            // the desk; a plain y-sort would put the whole actor behind the wood.
            let deskY = OfficeInteriorScale.mapPoint(
                OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
            ).y
            let deskSortBias = (detective.position.y - deskY) * 0.5
            updateDepth(of: detective, bias: deskSortBias)
            // Only the camera-facing apron rises between the desk and the torso.
            if let deskActorOccluder {
                updateDepth(of: deskActorOccluder, bias: -60)
            }
            if let deskFrontOccluder {
                deskFrontOccluder.zPosition = detective.zPosition
                    + OfficeNavigationLayout.DeskDepth.seatedFrontApronBias
            }
            if let deskTopOccluder {
                updateDepth(
                    of: deskTopOccluder,
                    bias: OfficeNavigationLayout.DeskDepth.topOccluderBias
                )
            }
            for item in deskItemNodes {
                updateDepth(of: item)
            }
        } else {
            updateDepth(of: detective)
            if let deskActorOccluder {
                updateDepth(of: deskActorOccluder, bias: -60)
            }
            if let deskFrontOccluder {
                updateDepth(
                    of: deskFrontOccluder,
                    bias: OfficeNavigationLayout.DeskDepth.standingFrontApronBias
                )
            }
            if let deskTopOccluder {
                updateDepth(
                    of: deskTopOccluder,
                    bias: OfficeNavigationLayout.DeskDepth.topOccluderBias
                )
            }
            for item in deskItemNodes {
                updateDepth(of: item)
            }
        }
        // Hide only while the NE atlas still bakes a chair; late stand-up / egress
        // reveal the matching empty prop so the kneehole never goes empty.
        deskChairProp?.isHidden = detective.shouldHideEmptyDeskChair
    }

    private func startCaseIntroduction() {
        // Monologue first. Entrance is BG-style: Continue *from* the heels cue starts
        // a no-dialogue cinematic, then dialogue resumes on the next monologue page.
        // Grok Voice: play each monologue / Lila node clip on show (stops prior VO).
        clientEntranceStarted = false
        pendingPostEntranceNodeID = nil
        caseIntroductionPresenter.onNodeShown = { [weak self] node in
            self?.handleCaseIntroductionNodeShown(node)
        }
        caseIntroductionPresenter.shouldDeferAdvance = { [weak self] from, toDestinationID in
            guard let self else { return false }
            guard EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenLeaving: from.id) else {
                return false
            }
            // Baldur’s Gate: dismiss dialogue, play walk cinematic, then continue.
            self.pendingPostEntranceNodeID = toDestinationID
            RainAudio.stopVoiceOver(on: self)
            self.beginClientEntranceIfNeeded()
            return true
        }
        // Shipped Empty Coat intro: noir monologue (with late entrance cue) + Lila March triad dialogue.
        caseIntroductionPresenter.present(
            EmptyCoatCaseIntroduction.nodes,
            startingAt: EmptyCoatCaseIntroduction.startNodeID
        ) { [weak self] in
            self?.finishCaseIntroduction()
        }
    }

    private func handleCaseIntroductionNodeShown(_ node: CaseDialogueNode) {
        if let voice = node.voiceAssetName {
            RainAudio.playVoiceOver(fileNamed: voice, on: self)
        } else {
            RainAudio.stopVoiceOver(on: self)
        }
        // Entrance is leave-gated (Continue from cue), not show-gated.
    }

    private func beginClientEntranceIfNeeded() {
        guard !clientEntranceStarted else { return }
        clientEntranceStarted = true
        // BG CutSceneMode: strip free-play rails AND dialogue panel for the walk-in.
        // Rails stay suppressed for the whole visit; dialogue returns after staging.
        setCutsceneChromeSuppressed(true)
        caseIntroductionPresenter.setCutsceneSuppressed(true)
        // QA fallen-door captures already rest the leaf; replaying the fall
        // would reset it upright under the walk and stall SpriteKit timing.
        if ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_FALLEN_DOOR"] != "1" {
            animateDoorFalling()
        } else {
            navigation = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        }
        // The first leg is authored across the actual exterior threshold (its
        // start is outside the nav floor). Exact interior anchors then clear the
        // waiting furniture and cross the shipping painted partition door.
        let path = OfficeNavigationLayout.clientArrivalRoute(in: navigation)
        clientEntrancePath = path
        clientEntranceStartedAt = ProcessInfo.processInfo.systemUptime
        client.performEntrance(along: path) { [weak self] in
            guard let self else { return }
            // End entrance cutscene: open the deferred monologue page (post-cue).
            let nextID = self.pendingPostEntranceNodeID
                ?? EmptyCoatCaseIntroduction.nodes
                    .first(where: { $0.id == EmptyCoatCaseIntroduction.clientEntranceCueNodeID })?
                    .nextNodeID
            self.pendingPostEntranceNodeID = nil
            self.caseIntroductionPresenter.resumeAfterCutscene(advancingTo: nextID)
            let dialogueCameraPosition = OfficeNavigationLayout.DialogueCameraFraming.dialogueCameraWorldPosition
            let cameraLift = SKAction.move(to: dialogueCameraPosition, duration: 0.3)
            cameraLift.timingMode = .easeOut
            self.gameCamera.run(cameraLift, withKey: "dialogueCameraLift")
        }
    }

    /// QA: place Lila on the authored entrance polyline using wall-clock elapsed
    /// time so mid-door captures work even when SpriteKit actions are frozen.
    func seekForcedClientEntranceForCapture() {
        guard ProcessInfo.processInfo.environment["RAINSHADOW_FORCE_CLIENT_ENTRANCE"] == "1" else {
            return
        }
        if !clientEntranceStarted {
            beginClientEntranceIfNeeded()
        }
        let path = clientEntrancePath.isEmpty
            ? OfficeNavigationLayout.clientArrivalRoute(in: navigation)
            : clientEntrancePath
        // Prefer CAPTURE_DELAY as the seek clock: headless launches often fire
        // capture before the GCD entrance start, which zeroed wall-clock elapsed
        // and left Lila frozen at the exterior threshold.
        let elapsed: TimeInterval
        if let delay = Double(ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_DELAY"] ?? "") {
            elapsed = max(0, delay)
        } else {
            let started = clientEntranceStartedAt ?? ProcessInfo.processInfo.systemUptime
            elapsed = max(0, ProcessInfo.processInfo.systemUptime - started)
        }
        client.seekEntrance(along: path, elapsed: elapsed)
        updateDepth(of: client)
    }

    private func finishCaseIntroduction() {
        RainAudio.stopVoiceOver(on: self)
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
            // Visit is still cutscene-locked; keep rails suppressed if not already.
            setCutsceneChromeSuppressed(true)
            let path = OfficeNavigationLayout.clientDepartureRoute(in: navigation)
            client.performExit(along: path) { [weak self] in
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
            // EndCutSceneMode equivalent — free-play chrome returns.
            setCutsceneChromeSuppressed(false)
            showOfficeHintIfNeeded()
        }
    }

    /// Baldur's Gate–style free-play chrome hide for the authored client visit.
    /// Dialogue panel visibility is owned by `CaseIntroductionPresenter.setCutsceneSuppressed`.
    private func setCutsceneChromeSuppressed(_ suppressed: Bool, animated: Bool = true) {
        guard cutsceneChromeSuppressed != suppressed else {
            updateGameplayChromeVisibility(animated: animated)
            return
        }
        cutsceneChromeSuppressed = suppressed
        updateGameplayChromeVisibility(animated: animated)
    }

    /// Single source of truth for rail visibility (cutscene + full-screen overlays).
    private func updateGameplayChromeVisibility(animated: Bool) {
        let hiddenByOverlay = inventoryIsPresented || mapIsPresented || journalIsPresented
        let shouldHide = cutsceneChromeSuppressed || hiddenByOverlay
        let duration: TimeInterval = 0.2
        for node in [portraitBar as SKNode, actionBar as SKNode] {
            node.removeAction(forKey: "chromeVisibility")
            if shouldHide {
                // Hide immediately so cutscene mode is obvious even if a fade is mid-frame.
                if !animated {
                    node.alpha = 0
                    node.isHidden = true
                    continue
                }
                if node.isHidden, node.alpha <= 0.01 { continue }
                node.isHidden = false
                node.run(
                    .sequence([
                        .fadeOut(withDuration: duration),
                        .run { node.alpha = 0; node.isHidden = true }
                    ]),
                    withKey: "chromeVisibility"
                )
            } else {
                node.isHidden = false
                if !animated {
                    node.alpha = 1
                    continue
                }
                if node.alpha >= 0.99 { continue }
                node.run(.fadeIn(withDuration: duration), withKey: "chromeVisibility")
            }
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
                portraitName: "dialogue_portrait_harlan_voss_v01",
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

    private func moveDetective(
        to target: CGPoint,
        requiresExactDestination: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        guard let route = navigation.route(from: detective.position, to: target) else {
            showMovementFeedback(at: target, isValid: false)
            return
        }
        guard !requiresExactDestination || !route.destinationWasAdjusted else {
            showMovementFeedback(at: target, isValid: false)
            return
        }
        showMovementFeedback(at: route.resolvedDestination, isValid: true)
        detective.walk(path: route.waypoints, completion: completion)
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
        updateGameplayChromeVisibility(animated: true)

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
        updateGameplayChromeVisibility(animated: true)

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
        updateGameplayChromeVisibility(animated: true)

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
        guard let normalTexture = sprite.texture,
              let assetName = sprite.name,
              let hoverTexture = GameArt.standaloneTexture(named: "\(assetName)_hover") else {
            return
        }
        normalTexture.filteringMode = .linear
        hoverTexture.filteringMode = .linear
        hotspotHoverSprites[hotspotID, default: []].append(
            HotspotHoverSprite(
                sprite: sprite,
                normalTexture: normalTexture,
                hoverTexture: hoverTexture
            )
        )
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

    private func applyHotspotHoverPresentation(_ presentation: HotspotHoverHighlight.Presentation) {
        hoveredHotspotID = presentation.hotspotID
        for entries in hotspotHoverSprites.values {
            for entry in entries {
                if officeDoorUsesFallenArtwork,
                   let officeDoor,
                   entry.sprite === officeDoor {
                    continue
                }
                entry.sprite.texture = entry.normalTexture
            }
        }
        guard presentation.isVisible,
              let id = presentation.hotspotID else {
            return
        }
        for entry in hotspotHoverSprites[id] ?? [] {
            if officeDoorUsesFallenArtwork,
               let officeDoor,
               entry.sprite === officeDoor {
                continue
            }
            entry.sprite.texture = entry.hoverTexture
        }
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

    /// Window insert only — recess architecture is baked into the shell plate.
    private func addWindowHighlightProp() {
        guard let texture = GameArt.standaloneTexture(named: "office_window") else { return }
        let window = SKSpriteNode(texture: texture)
        window.name = "office_window"
        window.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.window)
        window.zRotation = OfficeNavigationLayout.AuthoredPlacement.windowRotation
        window.xScale = OfficeInteriorScale.windowDisplayScale
        window.yScale = OfficeInteriorScale.windowVerticalDisplayScale
        window.warpGeometry = uprightWindowWarp
        window.subdivisionLevels = 1
        window.texture?.filteringMode = .linear
        rearFixtureRoot.addChild(window)
        registerHoverSprite(window, for: "office.window")
    }

    /// A compact investigative wall: case board is the hero, with supporting
    /// map, surveillance photographs, and Voss's framed licence. The authored
    /// anchors keep the complete group above the records furniture.
    private func addRecordsWallArt() {
        let wallScale = OfficeInteriorScale.standardPropDisplayScale * 0.9
        let wallProps: [(name: String, position: CGPoint, scale: CGFloat)] = [
            (
                "office_wall_photos",
                OfficeNavigationLayout.AuthoredPlacement.wallPhotos,
                wallScale * 0.8
            ),
            (
                "office_case_board",
                OfficeNavigationLayout.AuthoredPlacement.caseBoard,
                wallScale * 1.14
            ),
            (
                "office_wall_city_map",
                OfficeNavigationLayout.AuthoredPlacement.wallCityMap,
                wallScale * 0.88
            ),
            (
                "office_framed_licence",
                OfficeNavigationLayout.AuthoredPlacement.framedLicence,
                wallScale * 0.78
            )
        ]
        for prop in wallProps {
            let name = prop.name
            guard let texture = GameArt.texture(named: name) else { continue }
            let node = SKSpriteNode(texture: texture)
            node.name = name
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = OfficeInteriorScale.mapPoint(prop.position)
            node.setScale(prop.scale)
            node.texture?.filteringMode = .linear
            rearFixtureRoot.addChild(node)
        }
    }

    /// Full-height authored partition plate, sliced for depth sort.
    ///
    /// Cutaway is a separate visibility mask applied offline into
    /// `office_partition_wall_cutaway` (default). Set `RAINSHADOW_PARTITION_MASK=0`
    /// to load the unmasked full-height plate for review.
    private func addPartitionWall() {
        let maskOff = ProcessInfo.processInfo.environment["RAINSHADOW_PARTITION_MASK"] == "0"
        let textureName = maskOff ? "office_partition_wall" : "office_partition_wall_cutaway"
        guard let texture = GameArt.texture(named: textureName)
            ?? GameArt.texture(named: "office_partition_wall") else { return }
        texture.filteringMode = .linear

        let plate = OfficeInteriorScale.sourceArtSize
        let geometry = OfficeNavigationLayout.Architecture.self
        let sliceWidth: CGFloat = 64
        var left = geometry.partitionPlateX0

        while left < geometry.partitionPlateX1 {
            let width = min(sliceWidth, geometry.partitionPlateX1 - left)
            let base = geometry.partitionPlateBaseY(atPlateX: left + width / 2)
            // The painted run climbs across each slice, so the window has to carry
            // half that climb at both ends or the cap comes out stair-stepped.
            let climb = geometry.partitionPlateBaseY(atPlateX: left + width)
                - geometry.partitionPlateBaseY(atPlateX: left)
            let headroom = climb / 2 + 6
            let bottom = base + 24 + headroom
            let top = base - geometry.partitionPlateFaceHeight
                - geometry.partitionPlateCapHeight - headroom
            let size = CGSize(width: width, height: bottom - top)
            let crop = CGRect(
                x: left / plate.width,
                y: 1 - bottom / plate.height,
                width: width / plate.width,
                height: size.height / plate.height
            )
            let slice = SKSpriteNode(
                texture: SKTexture(rect: crop, in: texture),
                size: OfficeInteriorScale.mapSize(size)
            )
            slice.name = "office_partition_wall"
            slice.anchorPoint = CGPoint(x: 0.5, y: 0)
            slice.position = OfficeInteriorScale.mapPoint(
                CGPoint(x: left + width / 2, y: plate.height - bottom)
            )
            updateDepth(of: slice)
            depthWorldRoot.addChild(slice)
            left += sliceWidth
        }
    }

    /// QA hook: mark every placed node's own position, so a capture shows whether
    /// the art sits on the point the layout authored for it.
    private func addNodePositionMarkersIfRequested() {
        guard ProcessInfo.processInfo.environment["RAINSHADOW_QA_MARKERS"] == "1" else { return }
        for root in [rearFixtureRoot, depthWorldRoot] {
            for node in root.children {
                let cross = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -9, y: 0))
                path.addLine(to: CGPoint(x: 9, y: 0))
                path.move(to: CGPoint(x: 0, y: -9))
                path.addLine(to: CGPoint(x: 0, y: 9))
                cross.path = path
                cross.strokeColor = SKColor(red: 1, green: 0.2, blue: 0.85, alpha: 1)
                cross.lineWidth = 2
                cross.position = node.position
                debugRoot.addChild(cross)
            }
        }
    }

    /// QA hook: park idle stand-ins behind the desk, in the internal doorway,
    /// and beside the waiting chair for architecture visibility review.
    private func addScaleReferenceStandsIfRequested() {
        guard ProcessInfo.processInfo.environment["RAINSHADOW_SCALE_RIG"] == "1",
              let texture = GameArt.texture(named: "voss_standing_idle_s_00") else { return }
        for position in OfficeNavigationLayout.scaleReferenceStands {
            let stand = SKSpriteNode(texture: texture, size: OfficeInteriorScale.ActorDisplay.spriteDisplaySize)
            stand.name = "qa_scale_reference_stand"
            stand.anchorPoint = CGPoint(x: 0.5, y: 40 / 256)
            stand.position = position
            stand.texture?.filteringMode = .nearest
            updateDepth(of: stand)
            depthWorldRoot.addChild(stand)
        }
    }

    /// QA overlay: shell axes, wall thickness and doorway footprint for architecture review.
    private func addArchitectureDebugOverlayIfRequested() {
        guard ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_MODE"] == "architecture_debug"
        else { return }

        let arch = OfficeNavigationLayout.Architecture.self
        let root = SKNode()
        root.name = "qa_architecture_debug"
        root.zPosition = 9_000
        debugRoot.addChild(root)

        func mapAuthored(_ point: CGPoint) -> CGPoint {
            OfficeInteriorScale.mapPoint(point)
        }

        func line(from a: CGPoint, to b: CGPoint, color: SKColor, width: CGFloat = 2) {
            let path = CGMutablePath()
            path.move(to: a)
            path.addLine(to: b)
            let node = SKShapeNode(path: path)
            node.strokeColor = color
            node.lineWidth = width
            node.glowWidth = 0
            root.addChild(node)
        }

        // Shell axes from the measured rear corner (authored y-up).
        let rear = arch.rearCorner
        let nwEnd = CGPoint(x: rear.x + arch.axisNW.dx * 0.55, y: rear.y - arch.axisNW.dy * 0.55)
        let neEnd = CGPoint(x: rear.x + arch.axisNE.dx * 0.55, y: rear.y - arch.axisNE.dy * 0.55)
        line(from: mapAuthored(rear), to: mapAuthored(nwEnd), color: SKColor(red: 0.2, green: 0.85, blue: 1, alpha: 0.95), width: 3)
        line(from: mapAuthored(rear), to: mapAuthored(neEnd), color: SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 0.95), width: 3)

        // Partition face + back edges (thickness), both parallel to AXIS_NE.
        let aFace = arch.partitionLineA + arch.partitionThicknessA
        let aBack = arch.partitionLineA
        func planAuthored(a: CGFloat, b: CGFloat) -> CGPoint {
            // Match office_room_plan.authored: rearCorner is y-up; axis dy is plate y-down.
            let x = rear.x + a * arch.axisNW.dx + b * arch.axisNE.dx
            let y = rear.y - a * arch.axisNW.dy - b * arch.axisNE.dy
            return CGPoint(x: x, y: y)
        }
        // Partition face/back edges — gapped at the door so yellow/pink debug
        // strokes do not cut through the green aperture (those were easy to
        // mistake for magenta no-go solids in the frame).
        let faceLo0 = mapAuthored(planAuthored(a: aFace, b: -0.01))
        let faceLo1 = mapAuthored(planAuthored(a: aFace, b: arch.partitionDoorB0))
        let faceHi0 = mapAuthored(planAuthored(a: aFace, b: arch.partitionDoorB1))
        let faceHi1 = mapAuthored(planAuthored(a: aFace, b: max(arch.partitionReturnB1 + 0.08, 1.05)))
        let backLo0 = mapAuthored(planAuthored(a: aBack, b: -0.01))
        let backLo1 = mapAuthored(planAuthored(a: aBack, b: arch.partitionDoorB0))
        let backHi0 = mapAuthored(planAuthored(a: aBack, b: arch.partitionDoorB1))
        let backHi1 = mapAuthored(planAuthored(a: aBack, b: max(arch.partitionReturnB1 + 0.08, 1.05)))
        let wallYellow = SKColor(red: 0.95, green: 0.9, blue: 0.2, alpha: 0.9)
        let wallYellowDim = SKColor(red: 0.95, green: 0.9, blue: 0.2, alpha: 0.55)
        let wallPink = SKColor(red: 1, green: 0.3, blue: 0.7, alpha: 0.9)
        line(from: faceLo0, to: faceLo1, color: wallYellow, width: 2)
        line(from: faceHi0, to: faceHi1, color: wallYellow, width: 2)
        line(from: backLo0, to: backLo1, color: wallYellowDim, width: 1.5)
        line(from: backHi0, to: backHi1, color: wallYellowDim, width: 1.5)
        line(from: faceLo0, to: backLo0, color: wallPink, width: 2)
        line(from: faceHi0, to: backHi0, color: wallPink, width: 2)

        // Doorway footprint (threshold rectangle in plan).
        let d0f = mapAuthored(planAuthored(a: aFace, b: arch.partitionDoorB0))
        let d1f = mapAuthored(planAuthored(a: aFace, b: arch.partitionDoorB1))
        let d0b = mapAuthored(planAuthored(a: aBack, b: arch.partitionDoorB0))
        let d1b = mapAuthored(planAuthored(a: aBack, b: arch.partitionDoorB1))
        let doorPath = CGMutablePath()
        doorPath.move(to: d0f)
        doorPath.addLine(to: d1f)
        doorPath.addLine(to: d1b)
        doorPath.addLine(to: d0b)
        doorPath.closeSubpath()
        let door = SKShapeNode(path: doorPath)
        door.strokeColor = SKColor(red: 0.3, green: 1, blue: 0.45, alpha: 0.95)
        door.fillColor = SKColor(red: 0.3, green: 1, blue: 0.45, alpha: 0.18)
        door.lineWidth = 2.5
        root.addChild(door)

        // Full-height → cutaway mask transition mark.
        let cut = mapAuthored(planAuthored(a: aFace, b: arch.partitionReturnB1))
        let cutMark = SKShapeNode(circleOfRadius: 6)
        cutMark.position = cut
        cutMark.strokeColor = .white
        cutMark.fillColor = SKColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.85)
        cutMark.lineWidth = 1.5
        root.addChild(cutMark)

        // Collision footprint (nav solids) — magenta outlines, separate from visuals.
        for rect in OfficeNavigationLayout.authoredPartitionSegments {
            let mapped = OfficeInteriorScale.mapRect(rect)
            let box = SKShapeNode(rect: CGRect(origin: .zero, size: mapped.size))
            box.position = mapped.origin
            box.strokeColor = SKColor(red: 1, green: 0.2, blue: 0.85, alpha: 0.9)
            box.fillColor = SKColor(red: 1, green: 0.2, blue: 0.85, alpha: 0.12)
            box.lineWidth = 1.5
            root.addChild(box)
        }

        // Exterior upright-leaf obstacle (orange). Present while the door is
        // closed; cleared from the live grid once the leaf has fallen.
        let exteriorDoor = SKShapeNode(rect: OfficeNavigationLayout.doorObstacle)
        exteriorDoor.strokeColor = SKColor(red: 1, green: 0.55, blue: 0.1, alpha: 0.95)
        exteriorDoor.fillColor = SKColor(red: 1, green: 0.55, blue: 0.1, alpha: 0.18)
        exteriorDoor.lineWidth = 2
        root.addChild(exteriorDoor)

        let maskState = ProcessInfo.processInfo.environment["RAINSHADOW_PARTITION_MASK"] == "0" ? "OFF" : "ON"
        let label = SKLabelNode(text: String(
            format: "mask=%@  thickness=%.0fpx  door b=[%.3f,%.3f]  cut@%.3f  collision cells=%d",
            maskState,
            arch.wallThicknessPx,
            arch.partitionDoorB0,
            arch.partitionDoorB1,
            arch.partitionReturnB1,
            OfficeNavigationLayout.authoredPartitionSegments.count
        ))
        label.fontName = "Menlo-Bold"
        label.fontSize = 13
        label.fontColor = SKColor(white: 0.95, alpha: 0.95)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.zPosition = 1
        if let camera = camera {
            label.position = CGPoint(x: camera.position.x - size.width * camera.xScale * 0.48,
                                     y: camera.position.y + size.height * camera.yScale * 0.46)
        } else {
            label.position = CGPoint(x: 24, y: -24)
        }
        root.addChild(label)
    }

    /// Soft void past the design boundary only — no kerb rails or end strips.
    private func addForegroundCutaway() {
        guard let texture = GameArt.texture(named: "office_foreground_cutaway") else { return }
        let void = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
        void.name = "office_foreground_cutaway"
        void.anchorPoint = .zero
        void.position = OfficeInteriorScale.shellOrigin
        void.texture?.filteringMode = .linear
        void.zPosition = 2
        occlusionRoot.addChild(void)
    }

    /// Plain frosted internal door, swung open into the private office. The
    /// sprite carries its own hinge barrels and shaded return face; its sheared
    /// texture remains at plate scale so the hinge jamb stays flush with the shell.
    private var internalOfficeDoorLeaf: SKSpriteNode?

    private func addInternalOfficeDoor() {
        guard let door = addDepthProp(
            named: "office_internal_door_leaf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.internalDoorLeaf),
            scale: OfficeNavigationLayout.Architecture.internalLeafDisplayScale
        ) else { return }
        door.name = "office_internal_door_leaf"
        internalOfficeDoorLeaf = door
    }

    /// Floor wear, warm lamp key, cool blind-striped window fill, hallway slit, vignette.
    private func addOfficeAtmosphere() {
        if let wear = GameArt.texture(named: "office_floor_wear_decal") {
            let node = SKSpriteNode(texture: wear)
            node.name = "office_floor_wear_decal"
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.floorWear)
            node.setScale(OfficeInteriorScale.floorDecalDisplayScale * 1.35)
            node.alpha = 0.55
            node.texture?.filteringMode = .linear
            floorEffectRoot.addChild(node)
        }

        if let spillTex = GameArt.texture(named: "office_light_window_spill") {
            let spill = SKSpriteNode(texture: spillTex)
            spill.name = "office_light_window_spill"
            spill.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            spill.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.windowSpill)
            spill.setScale(OfficeInteriorScale.floorDecalDisplayScale * 1.1)
            spill.alpha = 0.32
            spill.blendMode = .add
            spill.texture?.filteringMode = .linear
            floorEffectRoot.addChild(spill)
        }

        if let stripesTex = GameArt.texture(named: "office_light_blind_stripes") {
            let stripes = SKSpriteNode(texture: stripesTex)
            stripes.name = "office_light_blind_stripes"
            stripes.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            stripes.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.blindStripes)
            // Rake cool bands from the window across the rug and desk cluster.
            stripes.setScale(OfficeInteriorScale.floorDecalDisplayScale * 1.28)
            stripes.alpha = 0.68
            stripes.blendMode = .add
            stripes.texture?.filteringMode = .linear
            floorEffectRoot.addChild(stripes)

            // Soft wall-face stripes, dimmer than the floor cast.
            let wallStripes = SKSpriteNode(texture: stripesTex)
            wallStripes.name = "office_light_blind_stripes_wall"
            wallStripes.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            wallStripes.position = OfficeInteriorScale.mapPoint(
                CGPoint(x: OfficeNavigationLayout.AuthoredPlacement.window.x + 40,
                        y: OfficeNavigationLayout.AuthoredPlacement.window.y - 180)
            )
            wallStripes.setScale(OfficeInteriorScale.floorDecalDisplayScale * 0.72)
            wallStripes.alpha = 0.36
            wallStripes.blendMode = .add
            wallStripes.zRotation = -0.18
            wallStripes.texture?.filteringMode = .linear
            rearFixtureRoot.addChild(wallStripes)
        }

        if let fanTex = GameArt.texture(named: "office_shadow_ceiling_fan") {
            let fan = SKSpriteNode(texture: fanTex)
            fan.name = "office_shadow_ceiling_fan"
            fan.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            fan.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskEnsemble)
            fan.setScale(OfficeInteriorScale.floorDecalDisplayScale * 1.4)
            fan.alpha = 0.28
            fan.texture?.filteringMode = .linear
            floorEffectRoot.addChild(fan)
            fan.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 12.0)))
        }

        if let hallwayTex = GameArt.texture(named: "office_light_hallway") {
            let hallway = SKSpriteNode(texture: hallwayTex)
            hallway.name = "office_light_hallway"
            hallway.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            hallway.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.hallwayLight)
            hallway.setScale(OfficeInteriorScale.floorDecalDisplayScale * 0.85)
            hallway.alpha = 0.42
            hallway.blendMode = .add
            hallway.texture?.filteringMode = .linear
            floorEffectRoot.addChild(hallway)
        }

        if let poolTex = GameArt.texture(named: "office_light_lamp_pool") {
            let pool = SKSpriteNode(texture: poolTex)
            pool.name = "office_light_lamp_pool"
            pool.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            pool.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.lampPool)
            pool.setScale(OfficeInteriorScale.floorDecalDisplayScale * 0.95)
            pool.alpha = 0.66
            pool.blendMode = .add
            pool.texture?.filteringMode = .linear
            floorEffectRoot.addChild(pool)
        } else {
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

        if let vignetteTex = GameArt.texture(named: "office_shadow_vignette") {
            let vignette = SKSpriteNode(texture: vignetteTex, size: OfficeInteriorScale.scaledArtSize)
            vignette.name = "office_shadow_vignette"
            vignette.anchorPoint = .zero
            vignette.position = OfficeInteriorScale.shellOrigin
            vignette.alpha = 0.9
            vignette.blendMode = .alpha
            vignette.zPosition = 1
            vignette.texture?.filteringMode = .linear
            // Sit above the shell plate but under floor props / actors.
            backgroundRoot.addChild(vignette)
        }
    }

    /// Small, readable clues of a working detective's office: a damp runner at
    /// the public entrance, discarded notes by the wastebasket, and a tied case
    /// packet beside the records run. These stay non-blocking floor dressing.
    private func addNoirStoryClutter() {
        if let texture = GameArt.texture(named: "office_entrance_runner") {
            let runner = SKSpriteNode(texture: texture)
            runner.name = "office_entrance_runner"
            runner.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            runner.position = OfficeInteriorScale.mapPoint(
                OfficeNavigationLayout.AuthoredPlacement.entranceRunner
            )
            runner.setScale(OfficeInteriorScale.floorDecalDisplayScale * 0.46)
            runner.alpha = 0.72
            runner.texture?.filteringMode = .linear
            floorEffectRoot.addChild(runner)
        }

        addDepthProp(
            named: "office_floor_trash_a",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.floorTrashA),
            scale: OfficeInteriorScale.clutterDisplayScale * 0.72,
            bias: -80
        )
        addDepthProp(
            named: "office_floor_trash_b",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.floorTrashB),
            scale: OfficeInteriorScale.clutterDisplayScale * 0.82,
            bias: -55
        )
    }

    private func addFloorContactShadow(named textureName: String, at position: CGPoint, scale: CGFloat) {
        guard let texture = GameArt.texture(named: textureName) else { return }
        let shadow = SKSpriteNode(texture: texture)
        shadow.name = textureName
        shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        shadow.position = position
        shadow.setScale(scale)
        shadow.alpha = 0.55
        shadow.texture?.filteringMode = .linear
        floorEffectRoot.addChild(shadow)
    }

    /// One large burgundy rug anchoring the full desk + chair island.
    private func addWornRug() {
        guard let texture = GameArt.texture(named: "office_worn_rug_burgundy")
            ?? GameArt.texture(named: "office_worn_rug") else { return }
        let rug = SKSpriteNode(texture: texture)
        rug.name = "office_worn_rug"
        rug.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        rug.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.wornRug)
        // Keep in step with office_layout_plan.RUG_FACTOR / redesign preview.
        // 0.62 keeps the burgundy island west of the partition doorway.
        rug.setScale(OfficeInteriorScale.floorDecalDisplayScale * 0.62)
        rug.texture?.filteringMode = .linear
        floorEffectRoot.addChild(rug)
    }

    private func addFogOfWar() {
        let fog = OfficeFogOfWarNode(
            size: OfficeInteriorScale.scaledArtSize,
            origin: OfficeInteriorScale.shellOrigin,
            initialReveal: OfficeNavigationLayout.actorStart
        )
        // The opening conversation starts with Lila crossing from the door,
        // so her authored entrance is part of the initially explored office.
        for point in OfficeNavigationLayout.clientArrivalPath {
            fog.reveal(at: point, forceTrailPoint: true)
        }
        weatherRoot.addChild(fog)
        fogOfWar = fog
    }

    @discardableResult
    private func addRearFixture(
        named textureName: String,
        at position: CGPoint,
        scale: CGFloat,
        anchorX: CGFloat = 0.5,
        anchorY: CGFloat = 0.04
    ) -> SKSpriteNode? {
        addRearFixture(
            named: textureName,
            at: position,
            scaleX: scale,
            scaleY: scale,
            anchorX: anchorX,
            anchorY: anchorY
        )
    }

    private func addRearFixture(
        named textureName: String,
        at position: CGPoint,
        scaleX: CGFloat,
        scaleY: CGFloat,
        anchorX: CGFloat = 0.5,
        anchorY: CGFloat = 0.04
    ) -> SKSpriteNode? {
        guard let texture = GameArt.texture(named: textureName) else { return nil }
        let fixture = SKSpriteNode(texture: texture)
        fixture.name = textureName
        fixture.anchorPoint = CGPoint(x: anchorX, y: anchorY)
        fixture.position = position
        fixture.xScale = scaleX
        fixture.yScale = scaleY
        fixture.texture?.filteringMode = .linear
        rearFixtureRoot.addChild(fixture)
        return fixture
    }

    private func doorWarp(_ destination: [SIMD2<Float>]) -> SKWarpGeometryGrid {
        let source: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(1, 0),
            SIMD2(0, 1), SIMD2(1, 1)
        ]
        return SKWarpGeometryGrid(
            columns: 1,
            rows: 1,
            sourcePositions: source,
            destinationPositions: destination
        )
    }

    /// Project the window onto the NW wall plane: rails rise with the painted
    /// wall trim while both side jambs remain vertical. Rotating the whole node
    /// would lean the jambs and make the window look pasted onto the wall.
    private var uprightWindowWarp: SKWarpGeometryGrid {
        doorWarp([
            SIMD2(0.000, 0.000), SIMD2(1.000, 0.150),
            SIMD2(0.000, 0.774), SIMD2(1.000, 1.000)
        ])
    }

    private var uprightDoorWarp: SKWarpGeometryGrid {
        doorWarp([
            SIMD2(0, 0), SIMD2(1, 0),
            SIMD2(0, 1), SIMD2(1, 1)
        ])
    }

    private var fallenDoorRestPosition: CGPoint {
        let environment = OfficeInteriorScale.environment
        let upright = OfficeInteriorScale.mapPoint(
            OfficeNavigationLayout.AuthoredPlacement.doorLeaf
        )
        return CGPoint(
            // Land just inside the waiting-room threshold: hinge end remains
            // nearest the exterior opening while the near edge clears the
            // partition wall instead of appearing to rest across its cap.
            x: upright.x - 60 * environment,
            y: upright.y - 185 * environment
        )
    }

    private var tippingDoorWarp: SKWarpGeometryGrid {
        doorWarp([
            SIMD2(0.00, 0.00), SIMD2(1.00, 0.04),
            SIMD2(0.10, 0.78), SIMD2(0.90, 0.72)
        ])
    }

    private var floorDoorWarp: SKWarpGeometryGrid {
        doorWarp([
            SIMD2(0.00, 0.02), SIMD2(1.00, 0.10),
            SIMD2(0.25, 0.45), SIMD2(0.75, 0.53)
        ])
    }

    private func makeDoorFallShadow(at position: CGPoint) -> SKShapeNode {
        let environment = OfficeInteriorScale.environment
        let shadow = SKShapeNode(ellipseOf: CGSize(
            width: 175 * environment,
            height: 38 * environment
        ))
        shadow.name = "office_door_fall_contact_shadow"
        shadow.fillColor = SKColor(white: 0, alpha: 0.32)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(
            x: position.x + 4 * environment,
            y: position.y - 24 * environment
        )
        shadow.zRotation = -0.10
        shadow.alpha = 0
        updateDepth(of: shadow, bias: -70)
        depthWorldRoot.addChild(shadow)
        return shadow
    }

    /// The generated landed state carries its own floor projection, edge
    /// thickness, recessed panels and damaged hinge hardware. Swapping only at
    /// impact preserves the registered upright leaf while avoiding the flat
    /// billboard read of a front elevation compressed onto the floor.
    @discardableResult
    private func presentGeneratedFallenDoor(
        _ officeDoor: SKSpriteNode,
        thickness officeDoorThickness: SKSpriteNode
    ) -> Bool {
        guard let texture = GameArt.texture(named: "office_door_leaf_fallen") else {
            return false
        }

        texture.filteringMode = .linear
        officeDoor.texture = texture
        // SpriteKit's `size` setter preserves the current rendered footprint
        // through x/y scale. Normalize first or the old 0.117 fall scale is
        // inverted into an 8.5× landed sprite.
        officeDoor.setScale(1)
        officeDoor.size =
            OfficeNavigationLayout.Architecture.entranceFallenArtworkDisplaySize
        officeDoor.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        officeDoor.warpGeometry = nil
        officeDoor.position = fallenDoorRestPosition
        officeDoor.zRotation = 0
        officeDoor.alpha = 1
        officeDoorThickness.alpha = 0
        officeDoorUsesFallenArtwork = true
        updateDepth(of: officeDoor, bias: 24)
        return true
    }

    /// A separate landed-state sprite lets the final two fall frames overlap
    /// instead of changing one node's silhouette instantaneously at impact.
    private func makeGeneratedFallenDoorTransition() -> SKSpriteNode? {
        guard let texture = GameArt.texture(named: "office_door_leaf_fallen") else {
            return nil
        }

        texture.filteringMode = .linear
        let transition = SKSpriteNode(
            texture: texture,
            size: OfficeNavigationLayout.Architecture.entranceFallenArtworkDisplaySize
        )
        let environment = OfficeInteriorScale.environment
        transition.name = "office_door_leaf_fallen_transition"
        transition.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        transition.position = CGPoint(
            x: fallenDoorRestPosition.x + 8 * environment,
            y: fallenDoorRestPosition.y + 15 * environment
        )
        transition.setScale(0.88)
        transition.alpha = 0
        depthWorldRoot.addChild(transition)
        updateDepth(of: transition, bias: 25)
        return transition
    }

    /// Reconstruct the old warped front elevation just before the reverse
    /// animation. The generated landed art is presentation-only and must never
    /// be stretched upright into the baked doorway.
    private func prepareWarpedDoorForReturn(
        _ officeDoor: SKSpriteNode,
        thickness officeDoorThickness: SKSpriteNode
    ) {
        guard let uprightTexture = GameArt.texture(named: "office_door_leaf") else {
            return
        }

        let fallenScale =
            OfficeNavigationLayout.Architecture.entranceFallingTransitionScale
        officeDoor.texture = uprightTexture
        officeDoor.size = uprightTexture.size()
        officeDoorUsesFallenArtwork = false
        officeDoor.anchorPoint = CGPoint(
            x: 0.5,
            y: OfficeNavigationLayout.Architecture.entranceLeafAnchorY
        )
        officeDoor.warpGeometry = floorDoorWarp
        officeDoor.position = fallenDoorRestPosition
        officeDoor.zRotation = -0.10
        officeDoor.setScale(fallenScale)

        officeDoorThickness.warpGeometry = floorDoorWarp
        officeDoorThickness.position = fallenDoorRestPosition
        officeDoorThickness.zRotation = -0.10
        officeDoorThickness.setScale(fallenScale)
        officeDoorThickness.alpha = 0.95
        officeDoorThickness.zPosition = officeDoor.zPosition - 2
    }

    /// Deterministic QA endpoint for renderer captures. Review frames should
    /// inspect the same resting geometry as the animation without depending on
    /// window-focus timing or SpriteKit action advancement.
    private func setDoorFallenForReview() {
        guard let officeDoor, let officeDoorThickness else { return }

        let fallenScale =
            OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
            * OfficeNavigationLayout.Architecture.entranceFallenLeafScaleRatio
        let fallenPosition = fallenDoorRestPosition

        officeDoor.warpGeometry = floorDoorWarp
        officeDoorThickness.warpGeometry = floorDoorWarp
        officeDoor.subdivisionLevels = 1
        officeDoorThickness.subdivisionLevels = 1
        officeDoor.move(toParent: depthWorldRoot)
        officeDoorThickness.move(toParent: depthWorldRoot)
        officeDoor.position = fallenPosition
        officeDoorThickness.position = fallenPosition
        officeDoor.zRotation = -0.10
        officeDoorThickness.zRotation = -0.10
        officeDoor.setScale(fallenScale)
        officeDoorThickness.setScale(fallenScale)
        officeDoorThickness.alpha = 0.95
        updateDepth(of: officeDoor, bias: 24)
        officeDoorThickness.zPosition = officeDoor.zPosition - 2
        _ = presentGeneratedFallenDoor(
            officeDoor,
            thickness: officeDoorThickness
        )

        officeDoorFallShadow?.removeFromParent()
        let shadow = makeDoorFallShadow(at: fallenPosition)
        shadow.alpha = 0.42
        shadow.xScale = 1.08
        officeDoorFallShadow = shadow

        // Upright leaf is gone — open the exterior threshold for pathfinding.
        navigation = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
    }

    /// Lila's entrance knocks the already damaged leaf free. A projective warp
    /// tips the leaf into the floor plane; the dark extrusion and contact shadow
    /// keep it from reading as a flat card rotating in screen space.
    private func animateDoorFalling() {
        guard let officeDoor, let officeDoorThickness else { return }

        officeDoor.removeAction(forKey: "officeDoorMotion")
        officeDoorThickness.removeAction(forKey: "officeDoorThicknessMotion")
        officeDoor.alpha = 1
        officeDoorUsesFallenArtwork = false
        let environment = OfficeInteriorScale.environment
        let fallenScale =
            OfficeNavigationLayout.Architecture.entranceFallingTransitionScale
        let fallDuration: TimeInterval = 0.68
        let preImpactDuration: TimeInterval = 0.50
        let crossfadeDuration: TimeInterval = 0.16
        let wait = SKAction.wait(forDuration: 0.10)

        officeDoor.warpGeometry = uprightDoorWarp
        officeDoorThickness.warpGeometry = uprightDoorWarp
        officeDoor.subdivisionLevels = 1
        officeDoorThickness.subdivisionLevels = 1
        officeDoor.move(toParent: depthWorldRoot)
        officeDoorThickness.move(toParent: depthWorldRoot)
        updateDepth(of: officeDoor, bias: 24)
        officeDoorThickness.zPosition = officeDoor.zPosition - 2

        officeDoorFallShadow?.removeFromParent()
        let shadow = makeDoorFallShadow(at: fallenDoorRestPosition)
        shadow.xScale = 0.62
        shadow.yScale = 0.72
        officeDoorFallShadow = shadow
        let landedTransition = makeGeneratedFallenDoorTransition()

        let warpFall = SKAction.animate(
            withWarps: [uprightDoorWarp, tippingDoorWarp, floorDoorWarp],
            times: [0.0, 0.26, 0.68]
        ) ?? .wait(forDuration: fallDuration)
        let fall = SKAction.group([
            warpFall,
            // The leaf is anchored near its threshold edge. A modest clockwise
            // turn makes the camera-near top sweep diagonally across the floor
            // instead of only collapsing vertically like a shrinking card.
            .rotate(toAngle: -0.34, duration: fallDuration, shortestUnitArc: false),
            .move(to: fallenDoorRestPosition, duration: fallDuration),
            .scale(to: fallenScale, duration: fallDuration)
        ])
        fall.timingMode = .easeIn
        let settle = SKAction.group([
            .moveBy(x: -3 * environment, y: 1.5 * environment, duration: 0.08),
            .rotate(byAngle: 0.012, duration: 0.08)
        ])
        settle.timingMode = .easeOut
        let rest = SKAction.group([
            .moveBy(x: 3 * environment, y: -1.5 * environment, duration: 0.07),
            // The generated landed texture already owns the exact floor angle.
            .rotate(toAngle: 0, duration: 0.07, shortestUnitArc: false)
        ])
        rest.timingMode = .easeIn
        let landedArtwork = SKAction.run { [weak self, weak officeDoor, weak officeDoorThickness] in
            guard
                let self,
                let officeDoor,
                let officeDoorThickness
            else { return }
            _ = self.presentGeneratedFallenDoor(
                officeDoor,
                thickness: officeDoorThickness
            )
            landedTransition?.removeFromParent()
            // Threshold is open once the upright leaf is gone.
            self.navigation = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: false)
        }
        let motion = SKAction.sequence([
            wait,
            // Keep the old leaf visible beneath the transition art through
            // impact. This overlap behaves like motion blur and guarantees
            // there can never be a one-frame disappearance between textures.
            fall,
            landedArtwork,
            settle,
            rest
        ])
        officeDoor.run(motion, withKey: "officeDoorMotion")
        officeDoorThickness.run(
            .sequence([
                wait,
                .group([
                    fall,
                    .sequence([
                        .fadeAlpha(to: 0.92, duration: 0.20),
                        .wait(forDuration: 0.30),
                        .fadeOut(withDuration: 0.14)
                    ])
                ])
            ]),
            withKey: "officeDoorThicknessMotion"
        )
        landedTransition?.run(.sequence([
            wait,
            .wait(forDuration: preImpactDuration),
            .group([
                .fadeIn(withDuration: crossfadeDuration),
                .scale(to: 1, duration: crossfadeDuration),
                .move(to: fallenDoorRestPosition, duration: crossfadeDuration)
            ])
        ]))
        shadow.run(.sequence([
            wait,
            .wait(forDuration: preImpactDuration - 0.10),
            .group([
                .fadeAlpha(to: 0.44, duration: crossfadeDuration + 0.08),
                .scaleX(to: 1.12, duration: crossfadeDuration + 0.08),
                .scaleY(to: 1.0, duration: crossfadeDuration + 0.08)
            ])
        ]))
    }

    /// The door is restored only after Lila has finished her exit path and
    /// cleared the room, ready for the next visitor.
    private func animateDoorReturning() {
        guard let officeDoor, let officeDoorThickness else { return }

        officeDoor.removeAction(forKey: "officeDoorMotion")
        officeDoorThickness.removeAction(forKey: "officeDoorThicknessMotion")
        prepareWarpedDoorForReturn(
            officeDoor,
            thickness: officeDoorThickness
        )
        let uprightPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf)
        let warpReturn = SKAction.animate(
            withWarps: [floorDoorWarp, tippingDoorWarp, uprightDoorWarp],
            times: [0.0, 0.18, 0.36]
        ) ?? .wait(forDuration: 0.36)
        let returnToFrame = SKAction.group([
            warpReturn,
            .rotate(toAngle: 0, duration: 0.34, shortestUnitArc: false),
            .move(to: uprightPosition, duration: 0.34),
            .scaleX(
                to: OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleX,
                duration: 0.34
            ),
            .scaleY(
                to: OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleY,
                duration: 0.34
            )
        ])
        returnToFrame.timingMode = .easeOut
        officeDoor.run(
            .sequence([
                returnToFrame,
                .run { [weak self, weak officeDoor] in
                    guard let self, let officeDoor else { return }
                    officeDoor.warpGeometry = self.uprightDoorWarp
                    officeDoor.move(toParent: self.rearFixtureRoot)
                    officeDoor.zPosition = 0
                    // Leaf is upright again — block the exterior threshold.
                    self.navigation = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
                }
            ]),
            withKey: "officeDoorMotion"
        )
        officeDoorThickness.run(
            .sequence([
                .group([
                    returnToFrame,
                    .fadeOut(withDuration: 0.24)
                ]),
                .run { [weak self, weak officeDoorThickness] in
                    guard let self, let officeDoorThickness else { return }
                    officeDoorThickness.warpGeometry = self.uprightDoorWarp
                    officeDoorThickness.move(toParent: self.rearFixtureRoot)
                    officeDoorThickness.zPosition = 0
                    officeDoorThickness.alpha = 0
                }
            ]),
            withKey: "officeDoorThicknessMotion"
        )
        officeDoorFallShadow?.run(.sequence([
            .fadeOut(withDuration: 0.24),
            .removeFromParent()
        ]))
        officeDoorFallShadow = nil
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
        // Canvas centers for the NE-facing V4 top plane (visitor face toward door).
        // Working detective layout: lamp and phone on Voss's writing side,
        // typewriter as the central silhouette, then active papers, ashtray, and
        // one case stack. Domestic odds and ends are deliberately omitted.
        let itemCenters: [(name: String, center: CGPoint, hotspotID: String?)] = [
            ("office_desk_lamp", CGPoint(x: 245, y: 185), nil),
            ("office_desk_phone", CGPoint(x: 340, y: 260), "office.phone"),
            ("office_desk_typewriter", CGPoint(x: 475, y: 215), nil),
            ("office_desk_notebook", CGPoint(x: 520, y: 310), nil),
            ("office_desk_papers", CGPoint(x: 600, y: 270), nil),
            ("office_desk_ashtray", CGPoint(x: 655, y: 325), nil),
            ("office_desk_files", CGPoint(x: 735, y: 245), "office.files")
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
            // Desk-native depth while standing. While seated, `updateDetectiveDepth`
            // lifts these above the writing-surface occluder (coat stays under wood).
            updateDepth(of: node)
            depthWorldRoot.addChild(node)
            deskItemNodes.append(node)
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

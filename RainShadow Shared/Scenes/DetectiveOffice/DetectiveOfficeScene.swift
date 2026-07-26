import SpriteKit
#if os(macOS)
import AppKit
#endif

@MainActor
final class DetectiveOfficeScene: BaseGameScene {
    private let detective = DetectiveActorNode()
    private let client = ClientActorNode()
    private var officeDoor: SKSpriteNode?
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

        let standardPropScale = OfficeInteriorScale.standardPropDisplayScale
        let smallPropScale = OfficeInteriorScale.smallPropDisplayScale

        // Stage 1+: one pre-rendered suite plate replaces shell + partition overlays.
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

        // Doorway architecture is baked into the shell; only the leaf is a separate prop.
        officeDoor = addRearFixture(
            named: "office_door_leaf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf),
            scale: OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
        )
        if let officeDoor {
            registerHoverSprite(officeDoor, for: "office.door")
        }

        // MARK: Entrance / waiting nook (rack + two chairs + table)
        addDepthProp(
            named: "office_coat_rack",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.coatRack),
            scale: OfficeInteriorScale.coatRackDisplayScale
        )
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
        addDepthProp(
            named: "office_personal_washbasin",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.personalWashbasin),
            scale: OfficeInteriorScale.standardPropDisplayScale * 0.82,
            bias: -8
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
            scale: OfficeInteriorScale.visitorArmchairDisplayScale
        )
        addDepthProp(
            named: "office_visitor_armchair",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.visitorArmchairB),
            scale: OfficeInteriorScale.visitorArmchairDisplayScale * 0.96
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

        if let clientStart = OfficeNavigationLayout.clientArrivalPath.first {
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
            bias: -40
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
        addNodePositionMarkersIfRequested()
    }

    override func sceneDidBecomeReady() {
        guard !caseIntroductionStarted else { return }
        // QA hook: leave the office idle so art/layout can be inspected.
        if ProcessInfo.processInfo.environment["RAINSHADOW_SKIP_INTRO"] == "1" {
            caseIntroductionStarted = true
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
                moveDetective(
                    to: hotspot.approachPoint,
                    requiresExactDestination: true
                ) { [weak self] in
                    self?.context.router.showCityDistrict()
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
        // Every HUD node is a child of `gameCamera`, so camera zoom is cancelled
        // from its inherited transform. Lay out all HUD in physical scene points;
        // using the world-visible size here made the dialogue and overlays grow
        // whenever the play camera zoomed out.
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
                deskFrontOccluder.zPosition = detective.zPosition + 55
            }
            if let deskTopOccluder {
                updateDepth(of: deskTopOccluder, bias: -40)
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
                updateDepth(of: deskFrontOccluder, bias: 40)
            }
            if let deskTopOccluder {
                updateDepth(of: deskTopOccluder, bias: -40)
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
        // Monologue first: do not start door/entrance until the authored cue node is shown.
        // VO is intentionally off for now (re-enable when opener clips return).
        clientEntranceStarted = false
        caseIntroductionPresenter.onNodeShown = { [weak self] node in
            self?.handleCaseIntroductionNodeShown(node)
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
        if EmptyCoatCaseIntroduction.shouldStartClientEntrance(whenShowing: node.id) {
            beginClientEntranceIfNeeded()
        }
    }

    private func beginClientEntranceIfNeeded() {
        guard !clientEntranceStarted else { return }
        clientEntranceStarted = true
        animateDoorFalling()
        client.performEntrance(along: OfficeNavigationLayout.clientArrivalPath) { [weak self] in
            guard let self else { return }
            let dialogueCameraPosition = OfficeNavigationLayout.DialogueCameraFraming.dialogueCameraWorldPosition
            let cameraLift = SKAction.move(to: dialogueCameraPosition, duration: 0.3)
            cameraLift.timingMode = .easeOut
            self.gameCamera.run(cameraLift, withKey: "dialogueCameraLift")
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
                entry.sprite.texture = entry.normalTexture
            }
        }
        guard presentation.isVisible,
              let id = presentation.hotspotID else {
            return
        }
        for entry in hotspotHoverSprites[id] ?? [] {
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
        window.setScale(OfficeInteriorScale.windowDisplayScale)
        window.texture?.filteringMode = .linear
        rearFixtureRoot.addChild(window)
        registerHoverSprite(window, for: "office.window")

        if let blindsTex = GameArt.texture(named: "office_window_blinds") {
            let blinds = SKSpriteNode(texture: blindsTex)
            blinds.name = "office_window_blinds"
            blinds.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.windowBlinds)
            blinds.zRotation = OfficeNavigationLayout.AuthoredPlacement.windowRotation
            blinds.setScale(OfficeInteriorScale.windowDisplayScale * 0.92)
            blinds.alpha = 0.88
            blinds.texture?.filteringMode = .linear
            blinds.zPosition = window.zPosition + 1
            rearFixtureRoot.addChild(blinds)
        }
    }

    /// Dense records-wall art — board, map, and photos clustered (not evenly spaced).
    private func addRecordsWallArt() {
        let wallScale = OfficeInteriorScale.standardPropDisplayScale * 0.72
        let wallProps: [(String, CGPoint)] = [
            ("office_case_board", OfficeNavigationLayout.AuthoredPlacement.caseBoard),
            ("office_wall_city_map", OfficeNavigationLayout.AuthoredPlacement.wallCityMap),
            ("office_wall_photos", OfficeNavigationLayout.AuthoredPlacement.wallPhotos)
        ]
        for (name, authored) in wallProps {
            guard let texture = GameArt.texture(named: name) else { continue }
            let node = SKSpriteNode(texture: texture)
            node.name = name
            node.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            node.position = OfficeInteriorScale.mapPoint(authored)
            node.setScale(wallScale)
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
            // Match office_room_plan.authored: REAR + a*NW + b*NE, y flipped.
            let x = 2_446 + a * arch.axisNW.dx + b * arch.axisNE.dx
            let yDown = 200 + a * arch.axisNW.dy + b * arch.axisNE.dy
            return CGPoint(x: x, y: 2_304 - yDown)
        }
        let face0 = mapAuthored(planAuthored(a: aFace, b: -0.01))
        let face1 = mapAuthored(planAuthored(a: aFace, b: 0.58))
        let back0 = mapAuthored(planAuthored(a: aBack, b: -0.01))
        let back1 = mapAuthored(planAuthored(a: aBack, b: 0.58))
        line(from: face0, to: face1, color: SKColor(red: 0.95, green: 0.9, blue: 0.2, alpha: 0.9), width: 2)
        line(from: back0, to: back1, color: SKColor(red: 0.95, green: 0.9, blue: 0.2, alpha: 0.55), width: 1.5)
        line(from: face0, to: back0, color: SKColor(red: 1, green: 0.3, blue: 0.7, alpha: 0.9), width: 2)
        line(from: face1, to: back1, color: SKColor(red: 1, green: 0.3, blue: 0.7, alpha: 0.55), width: 1.5)

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

    /// Frosted internal door, swung open into the private office. The sprite is
    /// authored in shell art pixels, so it draws at the plate's own scale.
    private func addInternalOfficeDoor() {
        guard let door = addDepthProp(
            named: "office_internal_door_leaf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.internalDoorLeaf),
            scale: OfficeInteriorScale.environment
        ) else { return }
        door.name = "office_internal_door_leaf"
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
            stripes.alpha = 0.55
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
            wallStripes.alpha = 0.28
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
            pool.alpha = 0.58
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
            vignette.alpha = 0.85
            vignette.blendMode = .alpha
            vignette.zPosition = 1
            vignette.texture?.filteringMode = .linear
            // Sit above the shell plate but under floor props / actors.
            backgroundRoot.addChild(vignette)
        }
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
        // Matches compose_office_redesign_preview.RUG_FACTOR so art and game agree.
        rug.setScale(OfficeInteriorScale.floorDecalDisplayScale * 1.45)
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

    /// Lila's entrance knocks the already damaged leaf off its hinges. Keeping
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

    /// The door is restored only after Lila has finished her exit path and
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
        // Canvas centers for the NE-facing V4 top plane (visitor face toward door).
        // Working detective layout: lamp/phone on Voss's SW writing side; papers +
        // mug/ashtray/pencil center; files + photo toward the NE visitor/door side.
        let itemCenters: [(name: String, center: CGPoint, hotspotID: String?)] = [
            ("office_desk_lamp", CGPoint(x: 280, y: 190), nil),
            ("office_desk_typewriter", CGPoint(x: 360, y: 230), nil),
            ("office_desk_phone", CGPoint(x: 430, y: 255), "office.phone"),
            ("office_desk_notebook", CGPoint(x: 500, y: 300), nil),
            ("office_desk_papers", CGPoint(x: 540, y: 250), nil),
            ("office_pencil_tray", CGPoint(x: 580, y: 310), nil),
            ("office_desk_mug", CGPoint(x: 480, y: 330), nil),
            ("office_desk_ashtray", CGPoint(x: 600, y: 325), nil),
            ("office_desk_files", CGPoint(x: 680, y: 265), "office.files"),
            ("office_framed_photo", CGPoint(x: 720, y: 195), nil)
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

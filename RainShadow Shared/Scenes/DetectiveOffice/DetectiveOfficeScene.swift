import SpriteKit
import simd
#if os(macOS)
import AppKit
#endif

@MainActor
final class DetectiveOfficeScene: BaseGameScene, CutsceneStage {
    private let client = ClientActorNode()
    private var officeDoor: SKSpriteNode?
    private enum OfficeDoorVisualState {
        case closed
        case mid
        case open
    }
    private var officeDoorVisualState: OfficeDoorVisualState = .closed
    private var deskActorOccluder: SKSpriteNode?
    private var deskFrontOccluder: SKSpriteNode?
    /// Writing-surface mask above seated torso (coat under wood).
    private var deskTopOccluder: SKSpriteNode?
    /// Loose desk props — lifted above the top occluder while seated.
    private var deskItemNodes: [SKSpriteNode] = []
    private var fogOfWar: OfficeFogOfWarNode?
    /// The office as an area record plus its navigation and waypoint queue.
    /// Plate, props, regions, door registration and travel all resolve from it.
    private var runtime: AreaRuntime {
        guard let areaRuntime else {
            preconditionFailure(
                "DetectiveOfficeScene read its area before loadArea ran; "
                    + "the runtime is built in init so this cannot depend on buildScene order"
            )
        }
        return areaRuntime
    }
    private var area: AreaDefinition { runtime.area }
    private var navigation: NavigationMap { runtime.navigation }
    private var movement: MovementOrderQueue { runtime.movement }
    private var hotspots: [OfficeHotspot] = []
    /// BG:EE Enhanced Path Search — last corrective repath wall-clock time.
    /// Ordered player goals (BG:EE waypoint queue). Index 0 is the current leg.
    private let barks = MovementBarkPlayer()
    private var pendingBumpReturn: [String: CGPoint] = [:]
    private static let clientActorID = "client.lila"
    /// Within this much projected travel of the goal the mover abandons rather
    /// than shoving a blocker aside (`DoStep`'s `WithinPersonalRange` cut-off).
    private static let bumpAbandonDistance: CGFloat = 24
    /// Ticks to wait when a blocker cannot be bumped. GemRB draws from
    /// `RAND(MAX_PATH_TRIES, MAX_PATH_TRIES * 2)`; the literal is not exposed in
    /// its public headers, so this is the same shape — a randomised half-to-one
    /// second at 15 Hz — chosen to read as "pause and let them pass".
    private static let backoffTickRange = 8...16
    private struct HotspotHoverSprite {
        let sprite: SKSpriteNode
        let normalTexture: SKTexture
        let hoverTexture: SKTexture
        let normalAlpha: CGFloat
        let hoverAlpha: CGFloat
    }

    /// Office hover art is pre-baked; hovering only swaps complete PNG textures.
    private var hotspotHoverSprites: [String: [HotspotHoverSprite]] = [:]
    private var hoveredHotspotID: String?
    private var caseIntroductionStarted = false
    /// Hotspot/container currently feeding the non-modal loot strip.
    private var activeLootContainerID: String?
    /// Tracks a pointer sequence that began inside the loot strip, including its
    /// painted gaps, so a cancelled control press never leaks through to the world.
    private var lootContainerPanelOwnsPointerPress = false
    /// Phase 4: second graph — desk monologue after Empty Coat is open (once).
    private var deskCaseFileMonologuePlayed = false
    private var clientEntranceStarted = false
    /// Wall-clock origin of the forced/authored entrance (QA seek + pacing).
    private var clientEntranceStartedAt: TimeInterval?
    private var clientEntrancePath: [CGPoint] = []
    /// Dialogue node to show after the BG-style entrance cinematic (deferred Continue).
    private var pendingPostEntranceNodeID: String?
    // `dialogueIsActive` is inherited; the office starts with the panel up.
    /// Infinity Engine–style cutscene chrome: hide party/action rails while an
    /// authored NPC enter/exit sequence runs (dialogue panel is suppressed separately).
    ///
    /// The gates, the skip latch, and the letterbox that used to sit beside this
    /// are all `CutsceneDirector`'s now — this flag is only the office's own
    /// answer to "are the rails down", which the room's pause policy still reads.
    private var cutsceneChromeSuppressed = false
    /// True only while the post-dialogue ease back to the follow camera plays.
    private var cameraRestoreInProgress = false

    override var referenceVisibleHeight: CGFloat { OfficeInteriorScale.cameraVisibleHeight }

    private let entranceName: String?

    /// Where the player stands on arrival. Walking in off Harbor Street lands on
    /// the inside face of the street door rather than at the desk, which is what
    /// naming an entrance buys: the office no longer has to guess where you came
    /// from, and it no longer throws the answer away.
    private var arrivalPoint: CGPoint {
        area.spawnPoint(entrance: entranceName) ?? OfficeNavigationLayout.actorStart
    }

    init(context: GameContext, entrance: String? = nil) {
        self.entranceName = entrance
        super.init(context: context, artSize: OfficeInteriorScale.sourceArtSize)
        // Before `buildScene`, deliberately. The area answers where the player
        // arrives, and `buildScene` positions the detective long before it
        // reaches navigation setup — loading the area there instead crashed the
        // office on every entry.
        // Navigation comes from the area record now, including its 96,000-node
        // path budget, so the room is described in one place rather than half in
        // data and half in scene setup.
        loadArea(AreaRuntime(
            area: HarborpointAreas.requireArea(HarborpointAreas.office),
            playerActorID: Self.detectiveActorID
        ))
        // The office opens straight into the Empty Coat intro, so the panel owns input
        // from the first frame. Other scenes start in free play (the inherited default);
        // `applyCompletedOfficeCaseIntroFreeplayState` clears this on a replay visit.
        dialogueIsActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DetectiveOfficeScene is created programmatically")
    }

    override func buildScene() {
        buildAmbients(from: area)

        // Stage 1+: one pre-rendered suite plate replaces shell + partition overlays.
        // Keep the plate intact — do not punch door columns or strip baked artwork.
        let usingSuitePlate: Bool
        if let texture = GameArt.texture(named: area.plateTextureName) {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
            background.name = area.plateTextureName
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

        addShellVignette()
        // V08 is one open room. The retired debug partition must not be able to
        // reintroduce a second doorway over the production plate.
        if !usingSuitePlate {
            addForegroundCutaway()
        }
        addScaleReferenceStandsIfRequested()
        addArchitectureDebugOverlayIfRequested()

        // Every piece of scenery in the room, in the order the record lists it.
        //
        // That order is not decoration: within a flat layer the props would
        // otherwise share one zPosition, and `buildProps` separates them by
        // their position in the record so that order is what actually gets
        // drawn. The record was baked from the scene graph, so it is the order
        // the sixty imperative calls produced.
        let props = buildProps(from: area)
        bindPlacedProps(props)
        buildRegisteredDoorVisual()
        addBakedWindowHoverOverlay()
        addWindowRain()

        detective.position = arrivalPoint
        // Warm desk-lamp grade (actors default here; re-assert for scene clarity).
        detective.applySceneLighting(.officeInterior)
        updateDetectiveDepth()
        depthWorldRoot.addChild(detective)

        if let clientStart = OfficeNavigationLayout.clientDoorwayPath.first {
            client.position = clientStart
        }
        client.applySceneLighting(.officeInterior)
        updateDepth(of: client)
        // Bind the client as a talkable actor. Dormant in the shipped Act-I flow (she is
        // hidden once her visit ends), but it is the binding a persistent NPC needs.
        client.dialogueOwnerID = EmptyCoatCaseIntroduction.lilaOwnerID
        client.dialogueGraphID = EmptyCoatDialogueKeys.graphID
        depthWorldRoot.addChild(client)

        addFogOfWar()

        configureNavigation()
        configureHotspots()
        context.session.resolveOfficeLootIfNeeded()

        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth,
            animated: false
        )
        hudRoot.addChild(portraitBar)
        hudRoot.addChild(actionBar)
        inventoryOverlay.zPosition = 100
        inventoryOverlay.onDismiss = { [weak self] in
            self?.setInventoryPresented(false)
        }
        inventoryOverlay.onEquipCarriedItem = { [weak self] index, slot in
            guard let self else { return nil }
            let refusal = context.session.equipCarriedItem(at: index, to: slot)
            refreshInventoryOverlay()
            return refusal
        }
        inventoryOverlay.onUnequipItem = { [weak self] slot in
            guard let self else { return nil }
            let refusal = context.session.unequipItem(from: slot)
            refreshInventoryOverlay()
            return refusal
        }
        inventoryOverlay.onMoveEquippedItem = { [weak self] source, destination in
            guard let self else { return nil }
            let refusal = context.session.moveEquippedItem(from: source, to: destination)
            refreshInventoryOverlay()
            return refusal
        }
        inventoryOverlay.onMoveCarriedStack = { [weak self] source, destination in
            guard let self else { return false }
            let moved = context.session.moveCarriedStack(from: source, to: destination)
            refreshInventoryOverlay()
            return moved
        }
        inventoryOverlay.onSplitCarriedStack = { [weak self] index, count in
            guard let self else { return false }
            let split = context.session.splitCarriedStack(at: index, count: count)
            refreshInventoryOverlay()
            return split
        }
        inventoryOverlay.onIdentifyCarriedItem = { [weak self] index in
            guard let self else { return false }
            let identified = context.session.identifyCarriedItem(at: index)
            refreshInventoryOverlay()
            return identified
        }
        inventoryOverlay.onDropCarriedItem = { [weak self] index in
            guard let self else { return nil }
            var name: String?
            if let stack = context.session.carriedInventory.stack(at: index) {
                name = InventoryItemPresentation.displayName(
                    forItemID: stack.id,
                    catalog: context.session.itemCatalog,
                    identified: stack.isIdentified
                )
            }
            guard context.session.dropCarriedItem(
                at: index,
                in: groundAreaID,
                at: detective.position
            ) != nil else { return nil }
            refreshInventoryOverlay()
            refreshQuickLootBar()
            return name
        }
        quickLootBar.onTakeGroundStack = { [weak self] entry in
            guard let self else { return }
            _ = context.session.takeGroundStack(entry, in: groundAreaID)
            refreshQuickLootBar()
            refreshInventoryOverlay()
        }
        hudRoot.addChild(inventoryOverlay)
        lootContainerPanel.onTakeSourceStackAtIndex = { [weak self] sourceIndex in
            self?.takeLootStack(atSourceIndex: sourceIndex)
        }
        lootContainerPanel.onTakeAllLoot = { [weak self] in
            self?.takeAllLootFromActiveContainer()
        }
        lootContainerPanel.onReturnCarriedStackAtIndex = { [weak self] acquiredIndex in
            self?.returnCarriedStack(atAcquiredIndex: acquiredIndex)
        }
        areaMapOverlay.zPosition = 110
        areaMapOverlay.onDismiss = { [weak self] in
            self?.setMapPresented(false)
        }
        areaMapOverlay.onRequestWorldMap = { [weak self] in
            self?.presentWorldMapFromAreaMap()
        }
        hudRoot.addChild(areaMapOverlay)
        worldMapOverlay.zPosition = 115
        worldMapOverlay.onDismiss = { [weak self] in
            self?.setWorldMapPresented(false)
        }
        hudRoot.addChild(worldMapOverlay)
        journalOverlay.zPosition = 120
        journalOverlay.onDismiss = { [weak self] in
            self?.setJournalPresented(false)
        }
        hudRoot.addChild(journalOverlay)
        // At the BG1 play density the viewport no longer spans the whole room, so
        // the office pans with Voss like a BG area instead of sitting fixed on the
        // authored framing. Authored placement is the pre-follow fallback.
        gameCamera.position = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.camera)
        updateCameraPosition()
        syncHudToCamera()
        addNodePositionMarkersIfRequested()
    }

    override func sceneDidBecomeReady() {
        syncDetectiveEncumbrance()
        // QA hook: hold the tactical pause from launch so the capture harness can
        // frame the paused presentation (clock state, desaturation) without a
        // keystroke.
        if ProcessInfo.processInfo.environment["RAINSHADOW_FORCE_PAUSE"] == "1" {
            handleTacticalPauseInput()
        }
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
                navigation.setEntranceDoorBlocking(false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.beginClientEntranceIfNeeded()
                }
            }
            let capturesLootUI = ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_LOOT_PANEL"] == "1"
                || ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_INVENTORY"] == "1"
                || ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_QUICK_LOOT"] != nil
            if capturesLootUI {
                // These captures represent free play. Do not let the office's
                // normal launch-time dialogue lock pause the world behind them.
                dialogueIsActive = false
            }
            if let dropCount = ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_QUICK_LOOT"],
               let count = Int(dropCount) {
                // QA hook: put a few stacks on the floor around Voss and open the
                // strip, through the same session API a real drop uses.
                for index in 0..<count {
                    // From the back of the bag: the notebook near the front is
                    // undroppable and would refuse every time.
                    guard let slot = context.session.carriedInventory.stacks.indices.last
                    else { break }
                    let angle = CGFloat(index) * 0.7
                    let offset = CGPoint(
                        x: detective.position.x + cos(angle) * CGFloat(40 + index * 18),
                        y: detective.position.y + sin(angle) * CGFloat(30 + index * 12)
                    )
                    context.session.dropCarriedItem(at: slot, in: groundAreaID, at: offset)
                }
                toggleQuickLootBar()
                return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_LOOT_PANEL"] == "1",
               let desk = hotspots.first(where: { $0.id == "office.desk" }) {
                presentLootContainerPanelIfNeeded(for: desk)
            } else if ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_INVENTORY"] == "1" {
                // QA hook: ready the revolver first, so a capture can show the
                // equipped state without a click. Uses the same session API the
                // window calls, so the proof is of the shipping path.
                if ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_EQUIPPED"] == "1",
                   let index = context.session.carriedInventory.stacks
                       .firstIndex(where: { $0.id == "service-revolver" }) {
                    context.session.equipCarriedItem(at: index, to: .weapon1)
                }
                setInventoryPresented(true)
            }
            return
        }
        // BG:EE one-shot: finished intro does not replay on re-enter (city → office).
        if context.session.hasCompletedOfficeCaseIntro {
            applyCompletedOfficeCaseIntroFreeplayState()
            return
        }
        caseIntroductionStarted = true
        run(.sequence([
            .wait(forDuration: 0.8),
            .run { [weak self] in self?.startCaseIntroduction() }
        ]), withKey: "caseIntroductionDelay")
    }

    /// Restore free-play office after the Empty Coat visit has already run once.
    private func applyCompletedOfficeCaseIntroFreeplayState() {
        caseIntroductionStarted = true
        clientEntranceStarted = true
        dialogueIsActive = false
        cutsceneChromeSuppressed = false
        cutsceneDirector.tearDown()
        client.isHidden = true
        client.alpha = 1
        navigation.setEntranceDoorBlocking(false)
        // Post-visit free play keeps the leaf open for city exit (sequencer contract).
        setDoorFallenForReview()
        setCutsceneChromeSuppressed(false, animated: false)
        showOfficeHintIfNeeded()
    }

    override func handlePointerDown(_ event: GamePointerEvent) {
        lootContainerPanelOwnsPointerPress = false
        let lootPoint = lootContainerPanel.convert(event.location, from: self)
        if lootContainerPanel.containsPanel(at: lootPoint) {
            lootContainerPanelOwnsPointerPress = true
            lootContainerPanel.beginPress(at: lootPoint)
            actionBar.cancelPress()
            portraitBar.cancelUtilityPress()
            clearHotspotHoverHighlight()
            return
        }
        if !lootContainerPanel.isHidden {
            dismissLootContainerPanel()
        }

        guard dialogueIsActive else {
            guard !mapIsPresented, !worldMapIsPresented, !journalIsPresented, !inventoryIsPresented else { return }
            let hudPoint = hudRoot.convert(event.location, from: self)
            actionBar.beginPress(at: actionBar.convert(hudPoint, from: hudRoot))
            portraitBar.beginUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
            // Touch has no pointer-move phase, and synthetic/rapid clicks may not deliver
            // one on macOS. Apply the same selection feedback immediately on press.
            updateHotspotHoverHighlight(at: event.location)
            return
        }
        let dialoguePoint = dialoguePanelPoint(for: event.location)
        _ = dialoguePresenter.handlePointerDown(at: dialoguePoint)
    }

    override func handlePointerDragged(_ event: GamePointerEvent) {
        if lootContainerPanelOwnsPointerPress {
            let lootPoint = lootContainerPanel.convert(event.location, from: self)
            lootContainerPanel.updatePress(at: lootPoint)
            return
        }
        guard dialogueIsActive else {
            let hudPoint = hudRoot.convert(event.location, from: self)
            actionBar.updatePress(at: actionBar.convert(hudPoint, from: hudRoot))
            portraitBar.updateUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
            return
        }
        let dialoguePoint = dialoguePanelPoint(for: event.location)
        _ = dialoguePresenter.handlePointerDragged(at: dialoguePoint)
    }

    override func handlePointerCancelled(_ event: GamePointerEvent) {
        if lootContainerPanelOwnsPointerPress {
            lootContainerPanel.cancelPress()
            lootContainerPanelOwnsPointerPress = false
            return
        }
        guard dialogueIsActive else {
            actionBar.cancelPress()
            portraitBar.cancelUtilityPress()
            return
        }
        let dialoguePoint = dialoguePanelPoint(for: event.location)
        _ = dialoguePresenter.handlePointerUp(at: dialoguePoint)
    }

    override func handlePointerUp(_ event: GamePointerEvent) {
        let lootPoint = lootContainerPanel.convert(event.location, from: self)
        if lootContainerPanelOwnsPointerPress {
            lootContainerPanel.endPress(at: lootPoint)
            lootContainerPanelOwnsPointerPress = false
            return
        }
        let quickLootPoint = quickLootBar.convert(event.location, from: self)
        if quickLootBar.containsBar(at: quickLootPoint) {
            quickLootBar.activate(at: quickLootPoint)
            return
        }
        if lootContainerPanel.containsPanel(at: lootPoint) {
            // Pointer-up-only activation keeps synthetic/rapid macOS clicks usable.
            lootContainerPanel.beginPress(at: lootPoint)
            lootContainerPanel.endPress(at: lootPoint)
            return
        }
        if !lootContainerPanel.isHidden {
            // The strip is non-modal: dismiss it, then let this same HUD/world
            // command continue through the normal click path below.
            dismissLootContainerPanel()
        }

        // BG:EE SetCutSceneBreakable: tap skips entrance/exit after grace.
        if trySkipActiveClientCutscene() {
            return
        }
        if dialogueIsActive {
            let dialoguePoint = dialoguePanelPoint(for: event.location)
            if !dialoguePresenter.handlePointerUp(at: dialoguePoint) {
                dialoguePresenter.handlePointer(at: dialoguePoint)
            }
            return
        }

        let hudPoint = hudRoot.convert(event.location, from: self)
        if journalIsPresented {
            let journalPoint = journalOverlay.convert(hudPoint, from: hudRoot)
            journalOverlay.handlePointer(at: journalPoint)
            return
        }
        if worldMapIsPresented {
            let mapPoint = worldMapOverlay.convert(hudPoint, from: hudRoot)
            worldMapOverlay.handlePointer(at: mapPoint)
            return
        }
        if mapIsPresented {
            let mapPoint = areaMapOverlay.convert(hudPoint, from: hudRoot)
            areaMapOverlay.handlePointer(at: mapPoint)
            return
        }
        if inventoryIsPresented {
            let overlayPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            inventoryOverlay.handlePointer(at: overlayPoint, splitModifier: event.isWaypointQueue)
            return
        }

        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint) {
            // BG:EE: double-clicking a portrait centres the view on that character.
            // This is the way back once the player has scrolled the viewport away.
            if event.isDoubleClick {
                followCamera()
            } else {
                setInventoryPresented(true)
            }
            return
        }

        let actionPoint = actionBar.convert(hudPoint, from: hudRoot)
        if portraitBar.endUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot)) == .search {
            toggleQuickLootBar()
            return
        }
        let activatedButton = actionBar.endPress(at: actionPoint)
        if activatedButton == .clock {
            handleTacticalPauseInput()
            return
        }
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

        // Talk to a person before inspecting scenery behind them (BG:EE click priority).
        if let talkable = talkableActor(at: event.location) {
            approachAndTalk(to: talkable)
            return
        }

        if let hotspot = hotspots.first(where: { $0.hitArea.contains(event.location) }) {
            // Interactions abandon any queued waypoints (BG:EE replace-on-interact).
            if let travel = hotspot.travel {
                moveDetective(
                    to: hotspot.approachPoint,
                    requiresExactDestination: true
                ) { [weak self] in
                    self?.context.router.travel(
                        to: travel.destination,
                        entrance: travel.entrance
                    )
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

        moveDetective(to: event.location, queueWaypoint: event.isWaypointQueue)
        // BG:EE double-click also recentres the viewport on the click
        // (`MoveViewportTo(p, true)`), so the camera holds the destination while
        // the detective walks into frame instead of trailing him there.
        if event.isDoubleClick {
            recenterCamera(on: event.location)
        }
    }

    override func handleDirectionalInput(_ direction: CGVector) -> Bool {
        if dialogueIsActive {
            let selectionDirection = direction.dx < 0 || direction.dy > 0 ? -1 : 1
            if !dialoguePresenter.moveSelection(selectionDirection) {
                let scrollStep: CGFloat = direction.dx < 0 || direction.dy > 0 ? -44 : 44
                _ = dialoguePresenter.scrollContent(by: scrollStep)
            }
            return true
        }
        if mapIsPresented || worldMapIsPresented { return true }
        if journalIsPresented {
            journalOverlay.handleDirectionalInput(direction)
            return true
        }
        if inventoryIsPresented {
            let previous = direction.dx < 0 || direction.dy > 0
            inventoryOverlay.moveSelection(previous ? -1 : 1)
            return true
        }
        // No overlay: the key belongs to the viewport, not the detective.
        return false
    }

    override func handlePointerMoved(_ event: GamePointerEvent) {
        #if os(macOS)
        let hudPoint = hudRoot.convert(event.location, from: self)
        // Stop any running edge scroll up front; it is re-armed at the bottom only
        // when the pointer is over the world rather than an overlay or HUD rail.
        setCameraScroll(.zero)
        let quickLootHoverPoint = quickLootBar.convert(event.location, from: self)
        if quickLootBar.containsBar(at: quickLootHoverPoint) {
            let target = quickLootBar.updateHover(at: quickLootHoverPoint)
            clearHotspotHoverHighlight()
            actionBar.setHighlightedButton(nil)
            (target == nil ? NSCursor.arrow : NSCursor.pointingHand).set()
            return
        }
        let lootPoint = lootContainerPanel.convert(event.location, from: self)
        let lootTarget = lootContainerPanel.updateHover(at: lootPoint)
        if lootContainerPanel.containsPanel(at: lootPoint) {
            clearHotspotHoverHighlight()
            actionBar.setHighlightedButton(nil)
            (lootTarget == nil ? NSCursor.arrow : NSCursor.pointingHand).set()
            return
        }
        if dialogueIsActive {
            clearHotspotHoverHighlight()
            let dialoguePoint = dialoguePresenter.convert(hudPoint, from: hudRoot)
            let isInteractive = dialoguePresenter.updatePointer(at: dialoguePoint)
            (isInteractive ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if worldMapIsPresented {
            clearHotspotHoverHighlight()
            let mapPoint = worldMapOverlay.convert(hudPoint, from: hudRoot)
            worldMapOverlay.handleHover(at: mapPoint)
            (worldMapOverlay.isInteractive(at: mapPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
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
            // A lifted item rides the cursor, so the window needs every move.
            inventoryOverlay.updateHover(at: overlayPoint)
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

        // BG:EE edge scrolling: the viewport drifts while the cursor rests against
        // the frame (`GameControl::OnGlobalMouseMove`). Suppressed whenever an
        // overlay is up, which the early returns above already guarantee.
        setCameraScroll(edgeScrollVector(forHudPoint: hudPoint))

        // Image #1 cyan silhouette + teal wash before click; same hit list as inspect/door.
        updateHotspotHoverHighlight(at: event.location)

        // One search-map sample drives both the hover feedback and the order
        // decision, which is what keeps them from disagreeing. See `WorldCursor`.
        applyWorldCursor(WorldCursorState.resolve(
            isPassable: isFloorOrderable(event.location),
            isTravel: hoveredHotspotID.flatMap { id in
                hotspots.first { $0.id == id }
            }?.travel != nil,
            hasInteractable: hoveredHotspotID != nil,
            hasTalkableActor: talkableActor(at: event.location) != nil
        ))
        #endif
    }

    #if os(macOS)
    /// Whether a floor click here could produce a move order.
    ///
    /// This is a search-map sample, not a path search — the same thing
    /// `GameControl::UpdateCursor` does via `Map::GetBlocked`. It runs on every
    /// mouse-move, so it must stay O(footprint); a walled-off but passable tile
    /// still reads as orderable here and is refused at click time instead.
    private func isFloorOrderable(_ point: CGPoint) -> Bool {
        navigation.searchMap.isPassable(
            at: point,
            radius: navigation.agentProfile.radius
        )
    }
    #endif

    /// The bag, the loot strip and the quick-loot bar are mutually exclusive
    /// surfaces over the same inventory, so opening a window closes the others.
    override func willPresentOverlay(_ overlay: GameOverlay) {
        dismissLootContainerPanel()
        if overlay == .inventory { quickLootBar.dismiss() }
    }

    override func clearHoverHighlight() {
        clearHotspotHoverHighlight()
    }

    override var chromeIsSuppressedByScene: Bool { cutsceneChromeSuppressed }

    /// BG:EE tactical pause. Orders issued while frozen are accepted and walked
    /// on unpause, which is the point of it.
    override func handleTacticalPauseInput() {
        pause.togglePlayerPause()
        applyPlayerPauseFeedback()
    }

    private func applyPlayerPauseFeedback() {
        actionBar.setClockPaused(pause.isPausedByPlayer)
        syncWorldNodePause()
        // A stale sub-tick remainder would otherwise spend an extra step the
        // instant the world resumes.
        if !pause.isPaused {
            detective.resetLocomotionClock()
            client.resetLocomotionClock()
        }
    }

    override func handleCancelInput() {
        // Escape is *the* cutscene skip in BG:EE — a breakable walk owns it before
        // any overlay or the movement cancel below.
        if trySkipActiveClientCutscene() {
            return
        }
        if dismissLootContainerPanel() {
            return
        }
        if journalIsPresented {
            setJournalPresented(false)
        } else if worldMapIsPresented {
            setWorldMapPresented(false)
        } else if mapIsPresented {
            setMapPresented(false)
        } else if inventoryIsPresented {
            setInventoryPresented(false)
        } else if !dialogueIsActive {
            clearMovementFeedback()
            clearWaypointPips()
            movement.finish()
            detective.cancelMovement()
        }
    }

    /// BG:EE right-click / two-finger tap. The engine drops the targeting mode
    /// and resets the action bar here; it never stops the walk. Overlays are our
    /// nearest equivalent of that targeting state, so they close — but an active
    /// path keeps running. Stopping is Escape's job (`handleCancelInput`).

    override func handleSecondaryPointer(at point: CGPoint) -> Bool {
        guard inventoryIsPresented else { return false }
        return inventoryOverlay.handleSecondaryPointer(
            at: inventoryOverlay.convert(hudRoot.convert(point, from: self), from: hudRoot)
        )
    }

    override func handleClearTargetingInput() {
        if dismissLootContainerPanel() {
            return
        }
        if journalIsPresented {
            setJournalPresented(false)
        } else if worldMapIsPresented {
            setWorldMapPresented(false)
        } else if mapIsPresented {
            setMapPresented(false)
        } else if inventoryIsPresented {
            setInventoryPresented(false)
        } else if !dialogueIsActive {
            clearMovementFeedback()
        }
    }

    override func handleScrollInput(_ deltaY: CGFloat) -> Bool {
        if journalIsPresented {
            journalOverlay.moveSelection(deltaY > 0 ? -1 : 1)
            return true
        }
        if dialogueIsActive {
            _ = dialoguePresenter.scrollContent(by: -deltaY)
            return true
        }
        return false
    }

    override func handleConfirmInput() {
        if journalIsPresented {
            setJournalPresented(false)
            return
        }
        if worldMapIsPresented {
            setWorldMapPresented(false)
            return
        }
        if mapIsPresented {
            setMapPresented(false)
            return
        }
        // Confirm / Escape-style confirm also skips breakable walks (match exterior).
        if trySkipActiveClientCutscene() {
            return
        }
        if dialogueIsActive {
            // Space/Return: Continue/End only — never auto-pick a PC reply (BG:EE).
            dialoguePresenter.activateCommandControl()
            return
        }
        guard inventoryIsPresented else { return }
        setInventoryPresented(false)
    }

    override func handleDialogueChoiceDigit(_ digit: Int) {
        guard dialogueIsActive else { return }
        // Digit 1 → first visible reply (BG:EE number keys).
        dialoguePresenter.selectChoice(at: digit - 1)
    }

    override func layoutViewport() {
        super.layoutViewport()
        // After `super`, `size` matches the live SKView. Frame all chrome in those
        // points (not world-visible size, which inflated HUD when the camera zoomed).
        let hudViewportSize = size
        inventoryOverlay.layout(for: hudViewportSize)
        areaMapOverlay.layout(for: hudViewportSize)
        worldMapOverlay.layout(for: hudViewportSize)
        journalOverlay.layout(for: hudViewportSize)
        dialoguePresenter.layout(for: hudViewportSize)
        portraitBar.layout(for: hudViewportSize)
        actionBar.layout(for: hudViewportSize)
    }

    override func update(_ currentTime: TimeInterval) {
        cutsceneDirector.update(currentTime)
        // BG:EE semantics: dialogue pauses the world, but CutSceneMode does not —
        // scripted actors (Lila's entrance/exit walks) keep moving while only
        // player input is locked. `cutsceneChromeSuppressed` is true for the
        // whole authored visit, so it stands in for CutSceneMode here.
        let cutsceneActive = cutsceneChromeSuppressed
        tickAreaScript()
        pause.setModal(
            dialogue: dialogueIsActive && !cutsceneActive,
            overlay: anyOverlayIsPresented
        )
        let worldIsPaused = pause.isPaused
        // BG silences footsteps while dialogue holds the world (`Actor::Update`
        // checks DF_IN_DIALOG before it ever reaches PlayWalkSound), which matters
        // here because a cutscene keeps scripted actors walking.
        detective.isAudioSilenced = dialogueIsActive
        client.isAudioSilenced = dialogueIsActive
        // Boards, read off the ground rather than left at the actor's default,
        // so an area that mixes surfaces needs no scene change to sound right.
        detective.footstepSurface = FootstepSurface(
            navigation.searchMap.surface(at: detective.position) ?? .wood
        )
        client.footstepSurface = FootstepSurface(
            navigation.searchMap.surface(at: client.position) ?? .wood
        )
        detective.updateLocomotion(at: currentTime, worldIsPaused: worldIsPaused)
        client.updateLocomotion(at: currentTime, worldIsPaused: worldIsPaused)
        if !worldIsPaused {
            pruneCompletedQueuedGoals()
            updateActorOccupancy()
            performCorrectiveRepathIfNeeded(at: currentTime)
            processBumpRequests()
        }
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth
        )
        areaMapOverlay.updateCurrentPosition(detective.position)
        updateDetectiveDepth()
        updateDepth(of: client)
        fogOfWar?.reveal(at: detective.position)
        updateCameraPosition(at: currentTime)
        // Follow dialogue camera lifts / restores every frame.
        syncHudToCamera()
    }

    /// The camera pans inside the *painted room*, not the plate: the plate rect
    /// would let a followed camera swing out over the baked black margin. At play
    /// density the room is smaller than the viewport in both axes, so the clamp
    /// centres it and the office camera does not pan at all — zoom is the only
    /// camera freedom this scene has.
    override var cameraClampBounds: CGRect { OfficeInteriorScale.paintedRoomBounds }
    /// The zoom-out ceiling measures against the plate instead, because that is
    /// what the art actually covers. Using the room rect here would compute a
    /// nonsense limit — it is smaller than the viewport to begin with.
    override var cameraPlateBounds: CGRect { OfficeInteriorScale.worldBounds }

    /// Drives the office viewport — following Voss, or free-scrolling under the
    /// player — clamped to the painted plate. Suspended while a dialogue lift
    /// owns the camera so the per-frame update does not fight the `SKAction`.
    private func updateCameraPosition(at currentTime: TimeInterval = 0) {
        // A running cutscene owns the viewport outright. This used to be a bare
        // `cameraFollowSuspended` Bool with no owner, so two overlapping camera
        // beats would race for it.
        if let framing = cutsceneDirector.cameraOverride(in: cameraClampBounds) {
            gameCamera.position = framing
            return
        }
        guard !cameraRestoreInProgress else { return }
        updateCamera(
            following: detective.position,
            in: cameraClampBounds,
            at: currentTime
        )
    }

    /// Seated NE rear-view: torso/head above the front apron.
    /// Actor occluder stays desk-native — elevating it stamped a wood rectangle
    /// over the chair feet (the floor-band clipping under the seat).
    /// Desk-top stays desk-native. Bare desk stays at -500.
    /// Standing: front apron rises for walk-past.
    private func updateDetectiveDepth() {
        // Wall-polygon cover, applied after the normal sort so the lift is
        // relative to wherever depth put the actor. Skipped while seated: the
        // desk cluster has its own hand-tuned apron ordering, and lifting the
        // body out of it would put Voss on top of his own desk.
        let covered = !detective.isDeskRegistered
            && (areaRuntime?.isCovered(detective.position) ?? false)
        defer {
            let lift = ActorCover.apply(to: detective, covered: covered)
            if lift != 0 { detective.zPosition += lift }
        }
        if detective.isDeskRegistered {
            // Pin the sort key to the desk ground anchor so local upper z and
            // apron bias form a stable order. The nav root sits on the chair-side
            // aisle (camera-near of the kneehole); a plain y-sort would bury the
            // seated body under the desk apron.
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
    }

    private func startCaseIntroduction() {
        // Monologue first. Entrance is BG-style: Continue *from* the heels cue starts
        // a no-dialogue cinematic, then dialogue resumes on the next monologue page.
        // Grok Voice: play each monologue / Lila node clip on show (stops prior VO).
        clientEntranceStarted = false
        pendingPostEntranceNodeID = nil
        cutsceneDirector.tearDown()
        dialoguePresenter.shouldDeferAdvance = { [weak self] from, toDestinationID in
            guard let self else { return false }
            // Presentation cue from dialogue data (not Empty Coat node-id helpers).
            guard let cue = from.onLeaveCue,
                  let handler = self.deferringLeaveCueHandler(for: cue) else {
                return false
            }
            // Baldur’s Gate: dismiss dialogue, play walk cinematic, then continue.
            self.pendingPostEntranceNodeID = toDestinationID
            RainAudio.stopVoiceOver(on: self)
            handler()
            return true
        }
        // Shipped Empty Coat intro: noir monologue (with late entrance cue) + Lila March triad dialogue.
        presentDialogue(
            EmptyCoatCaseIntroduction.graph,
            ownerID: EmptyCoatCaseIntroduction.lilaOwnerID
        ) { [weak self] in
            self?.finishCaseIntroduction()
        }
    }

    /// The one door for presenting authored dialogue.
    ///
    /// Seeding and merging are a pair. A conversation that is not seeded from the live
    /// case cannot evaluate `hasFlag` / `hasEvidence` / `hasKnowledge` gates at all, and
    /// one that is not merged back discards everything it granted. Both used to be
    /// per-call-site decisions and two of the three sites got it wrong: the intro seeded
    /// nothing, and hotspot inspect merged nothing.
    override func dialogueNodeDidShow(_ node: CaseDialogueNode) {
        if let voice = node.voiceAssetName {
            RainAudio.playVoiceOver(fileNamed: voice, on: self)
        } else {
            RainAudio.stopVoiceOver(on: self)
        }
        if let cue = node.onShowCue {
            handleDialogueShowCue(cue)
        }
    }

    /// Cues that fire as a node appears and let dialogue continue underneath.
    ///
    /// No shipped node authors one yet — the entrance is leave-gated. The point of the
    /// lookup is that an authored cue with no handler now trips in debug instead of
    /// being decoded, carried onto `CaseDialogueNode`, and silently dropped, which is
    /// what `onShowCue` did for its whole life.
    private func handleDialogueShowCue(_ cue: String) {
        assertionFailure("Dialogue node authored onShowCue \"\(cue)\" with no scene handler")
    }

    /// Cues that suspend the dialogue panel, play a cinematic, then resume the graph.
    /// Data names the cue; the scene owns what it means.
    private func deferringLeaveCueHandler(for cue: String) -> (() -> Void)? {
        switch cue {
        case OfficeDialogueCues.clientEntrance:
            return { [weak self] in self?.beginClientEntranceIfNeeded() }
        default:
            return nil
        }
    }

    private func beginClientEntranceIfNeeded() {
        guard !clientEntranceStarted else { return }
        clientEntranceStarted = true
        clientEntranceStartedAt = ProcessInfo.processInfo.systemUptime

        // The first leg is authored across the actual exterior threshold (its
        // start is outside the nav floor). Exact interior anchors then clear the
        // waiting furniture and cross the shipping painted partition door.
        let route = OfficeNavigationLayout.clientArrivalRoute(in: navigation)
        clientEntrancePath = route
        navigation.registerActor(
            id: Self.clientActorID,
            kind: .npc,
            at: route.first ?? OfficeNavigationLayout.actorStart,
            radius: NavigationAgentProfile.officeClient.radius,
            isMoving: true
        )

        let resumeNodeID = pendingPostEntranceNodeID
            ?? EmptyCoatCaseIntroduction.nodes
                .first(where: { $0.id == EmptyCoatCaseIntroduction.clientEntranceCueNodeID })?
                .nextNodeID
        pendingPostEntranceNodeID = nil
        cutsceneDirector.play(
            CutsceneCatalog.clientEntrance(route: route, resumeDialogueNodeID: resumeNodeID),
            on: self
        )
    }

    /// Attempts skip on whichever breakable cutscene is running.
    ///
    /// This used to need a break-requested flag latched around the snap, because
    /// `performEntrance`'s completion always reported `.natural` — locomotion
    /// cannot know why it stopped. The runner does know, so the reason now
    /// travels with the completion and the latch is gone.
    @discardableResult
    private func trySkipActiveClientCutscene() -> Bool {
        cutsceneDirector.trySkip()
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
        // The one-shot gate that stops the next office load replaying the
        // monologue and the entrance is authored on the exit cutscene now
        // (`SetGlobal`), so there is exactly one place that sets it.
        for action in OfficeClientVisitSequencer.actions(for: .finishCaseIntroductionStarted) {
            applyClientVisitAction(action)
        }
    }

    private func applyClientVisitAction(_ action: OfficeClientVisitSequencer.Action) {
        switch action {
        case .restoreCamera:
            // Ease back to wherever the follow camera would now be sitting, then
            // hand control back to it — returning to the authored framing would
            // snap the moment the follow resumed.
            let followPosition = clampedCameraPosition(
                following: detective.position,
                in: cameraClampBounds
            )
            let cameraRestore = SKAction.move(to: followPosition, duration: 0.3)
            cameraRestore.timingMode = .easeInEaseOut
            cameraRestoreInProgress = true
            gameCamera.run(
                .sequence([cameraRestore, .run { [weak self] in self?.cameraRestoreInProgress = false }]),
                withKey: "dialogueCameraLift"
            )
        case .beginClientExit:
            cutsceneDirector.play(
                CutsceneCatalog.clientExit(
                    route: OfficeNavigationLayout.clientDepartureRoute(in: navigation)
                ),
                on: self
            )
        case .returnDoor:
            // After Lila has finished the departure path and faded out.
            animateDoorReturning()
        case .unlockPlayerControl:
            dialogueIsActive = false
            showOfficeHintIfNeeded()
        }
    }

    // MARK: - CutsceneStage

    /// The office is the only scene with actors a cutscene can drive.
    func cutsceneActor(_ id: CutsceneActorID) -> CutsceneActorDriving? {
        switch id {
        case .detective: detective
        case .client: client
        }
    }

    /// BG:EE clears a door's search-map cells before a creature paths through it,
    /// so the leaf and the navigation stamp move together and in that order.
    func cutsceneSetDoor(_ door: CutsceneDoorID, open: Bool, reason: CutsceneCompletionReason) {
        guard door == .officeEntrance else { return }
        // QA fallen-door captures already rest the leaf; replaying the fall would
        // reset it upright under the walk and stall SpriteKit timing.
        let capturing = ProcessInfo.processInfo.environment["RAINSHADOW_CAPTURE_FALLEN_DOOR"] == "1"
        if open {
            if !capturing {
                // A broken cutscene cuts the leaf to its resting pose instead of
                // playing the fall out under a camera that has already arrived.
                reason == .skipped ? setDoorFallenForReview() : animateDoorFalling()
            }
            navigation.setEntranceDoorBlocking(false)
        } else {
            animateDoorReturning()
        }
    }

    /// `SetGlobal` — the guard that stops the intro replaying on the next load.
    func cutsceneSetFlag(_ flag: String) {
        guard flag == CutsceneCatalog.CutsceneFlags.officeCaseIntroCompleted else { return }
        context.session.markOfficeCaseIntroCompleted()
    }

    /// `StartCutSceneMode` / `EndCutSceneMode`.
    func cutsceneSetMode(_ active: Bool, reason: CutsceneCompletionReason) {
        setCutsceneChromeSuppressed(active, animated: reason == .natural)
    }

    func cutsceneSuppressDialogue() {
        RainAudio.stopVoiceOver(on: self)
        dialoguePresenter.setCutsceneSuppressed(true)
    }

    func cutsceneResumeDialogue(nodeID: String?) {
        dialoguePresenter.resumeAfterCutscene(advancingTo: nodeID)
    }

    func cutscenePlayVoiceOver(_ assetName: String) {
        RainAudio.playVoiceOver(fileNamed: assetName, on: self)
    }

    func cutsceneText(forKey key: String) -> String? {
        DialogueStringTable.shipped.stringIfPresent(for: key)
    }

    func cutsceneDidComplete(id: String, reason: CutsceneCompletionReason) {
        updateActorOccupancy()
        updateDepth(of: client)
        guard id == CutsceneCatalog.ID.clientExit else { return }
        for next in OfficeClientVisitSequencer.actions(for: .clientExitCompleted) {
            applyClientVisitAction(next)
        }
    }

    /// Baldur's Gate–style free-play chrome hide for the authored client visit.
    /// Dialogue panel visibility is owned by `DialoguePresenter.setCutsceneSuppressed`.
    private func setCutsceneChromeSuppressed(_ suppressed: Bool, animated: Bool = true) {
        guard cutsceneChromeSuppressed != suppressed else {
            updateGameplayChromeVisibility(animated: animated)
            return
        }
        cutsceneChromeSuppressed = suppressed
        updateGameplayChromeVisibility(animated: animated)
    }

    /// A visible NPC bound to a dialogue graph under the click, if any.
    ///
    /// Lila is bound below, but in the shipped Act-I flow she is hidden the moment her
    /// visit ends (`applyClientVisitAction` → `client.isHidden = true`) and the panel owns
    /// input while she is on screen. So this path is dormant today by construction — it
    /// is the generalisation the next NPC needs, not a change to the intro.
    private func talkableActor(at point: CGPoint) -> ClientActorNode? {
        guard !dialogueIsActive, !client.isHidden, client.dialogueGraphID != nil else { return nil }
        return client.interactionFrame.contains(point) ? client : nil
    }

    /// BG: walk into conversation range, turn to face, then open the graph.
    private func approachAndTalk(to actor: ClientActorNode) {
        guard let graphID = actor.dialogueGraphID else { return }
        guard let approach = DialogueApproach.approachPoint(
            toActorAt: actor.position,
            from: detective.position,
            in: navigation
        ) else { return }

        moveDetective(to: approach, requiresExactDestination: true) { [weak self] in
            guard let self else { return }
            self.detective.turnToFace(actor.position)
            guard let graph = try? DialogueGraphLoader.loadCached(id: graphID) else { return }
            self.dialogueIsActive = true
            self.presentDialogue(graph, ownerID: actor.dialogueOwnerID) { [weak self] in
                self?.dialogueIsActive = false
            }
        }
    }

    private func presentInspection(_ hotspot: OfficeHotspot) {
        dismissLootContainerPanel()
        clearHotspotHoverHighlight()
        dialogueIsActive = true

        // Shared multi-graph presenter: desk monologue after the case is retained.
        if hotspot.id == "office.desk",
           !deskCaseFileMonologuePlayed,
           context.session.caseState.hasFlag(EmptyCoatDialogueKeys.clientRetained)
        {
            deskCaseFileMonologuePlayed = true
            presentDialogue(OfficeCaseFileMonologue.graph) { [weak self] in
                guard let self else { return }
                self.dialogueIsActive = false
                self.presentLootContainerPanelIfNeeded(for: hotspot)
            }
            return
        }

        // PR4: inspect prose is an authored one-node graph, not an ad-hoc constructor.
        // The hotspot is its own conversation owner, so a second look can open on a
        // different node (IE `NumTimesTalkedTo` applied to observation).
        let graph = OfficeHotspotDialogue.graph(forHotspotID: hotspot.id)
        presentDialogue(graph, ownerID: hotspot.id) { [weak self] in
            guard let self else { return }
            self.dialogueIsActive = false
            self.presentLootContainerPanelIfNeeded(for: hotspot)
        }
    }

    /// After observation text, show every remaining stack in source order. Coins
    /// bypass the bag; items transfer between the source and persisted case bag.
    private func presentLootContainerPanelIfNeeded(for hotspot: OfficeHotspot) {
        guard context.session.hasLootContainer(for: hotspot.id) else { return }
        let entries = lootPanelEntries(for: hotspot.id)
        guard !entries.isEmpty else { return }
        activeLootContainerID = hotspot.id
        lootContainerPanel.present(
            sourceArtName: lootSourceArtName(for: hotspot.id),
            entries: entries,
            walletPence: context.session.walletPence,
            carriedInventory: context.session.carriedInventory
        )
    }

    private func takeLootStack(atSourceIndex sourceIndex: Int) {
        guard let containerID = activeLootContainerID else { return }
        guard let result = context.session.takeLootStack(at: sourceIndex, from: containerID) else {
            return
        }
        switch result {
        case .coins(let pence):
            refreshActiveLootContainer(feedback: .coins(pence: pence))
        case .item(let item):
            refreshActiveLootContainer(feedback: .item(id: item.id, quantity: item.quantity))
        case .inventoryFull:
            refreshActiveLootContainer(feedback: .bagFull)
        }
    }

    private func takeAllLootFromActiveContainer() {
        guard let containerID = activeLootContainerID,
              let result = context.session.takeAllLoot(from: containerID) else { return }
        let hasItemOverflowAtFullCapacity = context.session.carriedInventory.isFull
            && context.session.lootContents(for: containerID).contains(where: { stack in
                if case .item(_, let quantity) = stack { return quantity > 0 }
                return false
            })
        if result.didTransferAnything {
            refreshActiveLootContainer(feedback: .batch(
                pence: result.creditedPence,
                itemStackCount: result.itemStacks.count,
                bagIsFull: hasItemOverflowAtFullCapacity
            ))
        } else if hasItemOverflowAtFullCapacity {
            refreshActiveLootContainer(feedback: .bagFull)
        }
    }

    private func returnCarriedStack(atAcquiredIndex acquiredIndex: Int) {
        guard let containerID = activeLootContainerID,
              context.session.returnCarriedItem(at: acquiredIndex, to: containerID) != nil else {
            return
        }
        refreshActiveLootContainer()
    }


    // MARK: - Ground piles

    /// Area key for the ground pile. One pile per area, as in BG.
    private var groundAreaID: String { "office" }

    /// Re-read the ground near Voss and push it into the quick-loot bar.
    private func refreshQuickLootBar() {
        guard quickLootBar.isPresented else { return }
        quickLootBar.refresh(
            entries: context.session.groundStacks(
                in: groundAreaID,
                near: detective.position
            )
        )
    }

    /// BG:EE's Search control: show everything on the ground within reach.
    private func toggleQuickLootBar() {
        let showing = quickLootBar.toggle(
            entries: context.session.groundStacks(in: groundAreaID, near: detective.position),
            catalog: context.session.itemCatalog
        )
        if showing { refreshQuickLootBar() }
    }

    /// Weight decides the walk. BG divides the movement *rate* by the encumbrance
    /// factor (`Actor::CalculateSpeedFromRate`), so an overloaded detective is
    /// exactly half speed and an immobile one holds position. Called on every
    /// path that can change what Voss is carrying.

    private func refreshActiveLootContainer(feedback: LootContainerPanelFeedback? = nil) {
        syncDetectiveEncumbrance()
        guard let containerID = activeLootContainerID else { return }
        let entries = lootPanelEntries(for: containerID)
        refreshInventoryOverlay()
        lootContainerPanel.refresh(
            entries: entries,
            walletPence: context.session.walletPence,
            carriedInventory: context.session.carriedInventory,
            feedback: feedback
        )
        if entries.isEmpty && !lootContainerPanel.keepsEmptySourceOpenForReverseTransfer {
            activeLootContainerID = nil
        }
    }

    private func lootPanelEntries(for containerID: String) -> [LootContainerPanelEntry] {
        context.session.lootContents(for: containerID).enumerated().map { index, stack in
            LootContainerPanelEntry(sourceIndex: index, stack: stack)
        }
    }

    private func lootSourceArtName(for containerID: String) -> String {
        switch containerID {
        case "office.files": return "office_filing_cabinet_open"
        default: return "office_desk_bare"
        }
    }

    /// Hides only presentation state. Container contents remain authoritative in
    /// `GameSession`, so reinspection shows every untransferred stack in source order.
    @discardableResult
    private func dismissLootContainerPanel() -> Bool {
        let wasPresented = !lootContainerPanel.isHidden || activeLootContainerID != nil
        guard wasPresented else { return false }
        lootContainerPanel.cancelPress()
        lootContainerPanel.dismiss()
        lootContainerPanelOwnsPointerPress = false
        activeLootContainerID = nil
        return true
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

    // MARK: - Movement
    //
    // Policy lives in `MovementOrderQueue`; this is the SpriteKit half.

    private func moveDetective(
        to target: CGPoint,
        requiresExactDestination: Bool = false,
        queueWaypoint: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        switch movement.order(
            actorAt: detective.position,
            to: target,
            requiresExactDestination: requiresExactDestination,
            queueWaypoint: queueWaypoint
        ) {
        case .turnInPlace:
            clearWaypointPips()
            detective.turnToFace(target)

        case .refused:
            showMovementFeedback(at: target, isValid: false)
            clearWaypointPips()

        case .ignored:
            break

        case .walk(let path):
            clearWaypointPips()
            showMovementFeedback(at: target, isValid: true)
            // BG:EE `Actor::CommandActor`: an accepted order gets a spoken
            // acknowledgement, frequency-gated. A refused one does not.
            barks.play(.command, silenced: dialogueIsActive)
            showWaypointPip(at: target)
            detective.walk(path: path, completion: { [weak self] in
                self?.finishQueuedMovement(completion: completion)
            })

        case .append(let path):
            showMovementFeedback(at: target, isValid: true)
            showWaypointPip(at: target)
            detective.walk(appending: path, completion: { [weak self] in
                self?.finishQueuedMovement()
            })
        }
    }

    private func finishQueuedMovement(completion: (() -> Void)? = nil) {
        clearWaypointPips()
        movement.finish()
        completion?()
    }

    private func pruneCompletedQueuedGoals() {
        for reached in movement.pruneReachedGoals(actorAt: detective.position) {
            removeWaypointPip(nearest: reached)
        }
    }

    private func updateActorOccupancy() {
        navigation.updateActor(
            id: Self.detectiveActorID,
            position: detective.position,
            isMoving: detective.movementDestination != nil
        )
        if !client.isHidden {
            navigation.updateActor(
                id: Self.clientActorID,
                position: client.position,
                isMoving: client.isLocomoting
            )
        } else {
            navigation.unregisterActor(id: Self.clientActorID)
        }
    }

    private func performCorrectiveRepathIfNeeded(at currentTime: TimeInterval) {
        switch movement.correctiveRepath(
            actorAt: detective.position,
            remainingRoute: detective.remainingRouteWaypoints,
            isMoving: detective.movementDestination != nil,
            at: currentTime
        ) {
        case .keepWalking:
            break
        case .abandon:
            clearWaypointPips()
            detective.cancelMovement()
        case .walk(let path):
            detective.walk(path: path, completion: { [weak self] in
                self?.finishQueuedMovement()
            })
        }
    }

    /// BG:EE actor bumping, `Movable::DoStep`.
    ///
    /// The engine probes for a blocker *along the direction of travel* rather
    /// than in a ring around the mover — "we want to only check directly along
    /// the way and not be blocked by actors who are on the sides" — so an idle
    /// NPC starts stepping aside before the walker reaches them instead of
    /// after the two have already interpenetrated.
    ///
    /// When the blocker cannot be bumped the engine either abandons the path
    /// (if it is nearly at its goal, so close-range approaches do not shove) or
    /// backs off and waits.
    private func processBumpRequests() {
        guard detective.movementDestination != nil, !detective.isBackingOff else { return }

        let moverRadius = navigation.agentProfile.radius
        let probe = detectiveCollisionProbe(radius: moverRadius)

        if let bump = navigation.occupancy.bumpRequest(
            forMover: Self.detectiveActorID,
            at: probe,
            moverRadius: moverRadius
        ) {
            pendingBumpReturn[bump.actorID] = bump.returnPoint
            if bump.actorID == Self.clientActorID, !client.isHidden {
                client.walk(path: [bump.sidestepPoint]) { [weak self] in
                    guard let self,
                          let returnPoint = self.pendingBumpReturn.removeValue(forKey: bump.actorID)
                    else { return }
                    self.client.walk(path: [returnPoint])
                }
            }
            return
        }

        guard navigation.occupancy.isBlockedByUnbumpableActor(
            at: probe,
            radius: moverRadius,
            exceptID: Self.detectiveActorID
        ) else {
            return
        }

        // "Give up instead of bumping if you are close to the goal."
        if movement.goals.count == 1,
           let goal = movement.currentGoal,
           ActorLocomotionPacing.projectedDistance(from: detective.position, to: goal)
               <= Self.bumpAbandonDistance {
            clearWaypointPips()
            movement.finish()
            detective.cancelMovement()
            return
        }

        detective.beginMovementBackoff(ticks: Self.backoffTickRange.randomElement() ?? 8)
    }

    /// Point the mover would collide at, one look-ahead step along the current
    /// heading. GemRB scales this by `circleSize`; our office footprint is well
    /// under one search cell, so the probe reaches one cell ahead — far enough
    /// to react before contact, short enough not to trip on distant actors.
    private func detectiveCollisionProbe(radius: CGFloat) -> CGPoint {
        let heading = detective.currentHeading
        guard heading != .zero else { return detective.position }
        let reach = max(navigation.searchMap.cellSize.width, radius * 2)
        return CGPoint(
            x: detective.position.x + heading.dx * reach,
            y: detective.position.y + heading.dy * reach
        )
    }

    private func configureNavigation() {
        navigation.registerActor(
            id: Self.detectiveActorID,
            kind: .player,
            at: OfficeNavigationLayout.actorStart,
            radius: NavigationAgentProfile.officeDetective.radius
        )
    }

    private func configureHotspots() {
        hotspots = area.regions.compactMap { region in
            guard region.kind == .info || region.kind == .travel,
                  let approachPoint = region.approachPoint else {
                return nil
            }
            return OfficeHotspot(
                id: region.id,
                name: region.label ?? region.id,
                hitArea: region.boundingBox,
                approachPoint: approachPoint.cgPoint,
                observation: region.observation ?? "",
                travel: region.travel
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
                hoverTexture: hoverTexture,
                normalAlpha: sprite.alpha,
                hoverAlpha: sprite.alpha
            )
        )
    }

    /// Applies the shipped hover presentation contract for free exploration.
    private func updateHotspotHoverHighlight(at worldPoint: CGPoint) {
        let blocked = dialogueIsActive || mapIsPresented || worldMapIsPresented || inventoryIsPresented || journalIsPresented
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
                if let officeDoor, entry.sprite === officeDoor {
                    entry.sprite.texture = doorTexture(for: officeDoorVisualState, hovered: false)
                } else {
                    entry.sprite.texture = entry.normalTexture
                }
                entry.sprite.alpha = entry.normalAlpha
            }
        }
        guard presentation.isVisible,
              let id = presentation.hotspotID else {
            return
        }
        for entry in hotspotHoverSprites[id] ?? [] {
            if let officeDoor, entry.sprite === officeDoor {
                entry.sprite.texture = doorTexture(for: officeDoorVisualState, hovered: true)
            } else {
                entry.sprite.texture = entry.hoverTexture
            }
            entry.sprite.alpha = entry.hoverAlpha
        }
    }

    /// Hook up the handful of placed props the scene still has to drive.
    ///
    /// Everything else is drawn and forgotten, which is the point of moving the
    /// room into a record. What survives here needs a reference because it
    /// *changes*: the entrance leaf swaps registered hinge states, the desk occluders
    /// re-sort against Voss every frame, and the desk items lift above the
    /// writing surface the moment he sits down.
    private func bindPlacedProps(_ props: [String: SKSpriteNode]) {
        deskActorOccluder = props["office_desk_actor_occluder"]
        deskFrontOccluder = props["office_desk_front_occluder_v04"]
        deskTopOccluder = props["office_desk_top_occluder"]
        deskItemNodes = Self.deskItemPropIDs.compactMap { props[$0] }

        for binding in Self.hoverBindings {
            guard let sprite = props[binding.prop] else { continue }
            registerHoverSprite(sprite, for: binding.hotspot)
        }
    }

    /// Build the entrance leaf from the door section, never from the general
    /// prop list. Its pixels, hover state and collision remain independently
    /// registered, but all three resolve through the same `office.door` id.
    private func buildRegisteredDoorVisual() {
        guard let door = area.doors.first(where: { $0.id == "office.door" }),
              let registration = door.visual,
              let normalTexture = GameArt.texture(named: registration.closedTextureName)
        else { return }

        normalTexture.filteringMode = .linear
        let hoverTexture = registration.closedHoverTextureName
            .flatMap(GameArt.texture(named:)) ?? normalTexture
        hoverTexture.filteringMode = .linear

        let sprite = SKSpriteNode(texture: normalTexture)
        sprite.name = "office.door.visual"
        sprite.anchorPoint = registration.canvasAnchor.cgPoint
        sprite.position = registration.position.cgPoint
        sprite.setScale(registration.scale)
        depthWorldRoot.addChild(sprite)
        updateDepth(of: sprite, bias: 24)
        officeDoor = sprite
        hotspotHoverSprites[door.id, default: []].append(
            HotspotHoverSprite(
                sprite: sprite,
                normalTexture: normalTexture,
                hoverTexture: hoverTexture,
                normalAlpha: 1,
                hoverAlpha: 1
            )
        )

        let state: OfficeDoorVisualState = door.startsClosed ? .closed : .open
        applyDoorVisualState(state, entranceBlocking: door.startsClosed)
    }

    /// The near window is baked into the opaque plate. Its highlight therefore
    /// has no ordinary prop to texture-swap: V11 supplies one plate-registered
    /// transparent overlay whose non-transparent pixels cover only that window.
    private func addBakedWindowHoverOverlay() {
        guard let texture = GameArt.texture(named: "office_window_hover_overlay") else {
            return
        }
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
        sprite.name = "office.window.hoverOverlay"
        sprite.anchorPoint = .zero
        sprite.position = OfficeInteriorScale.shellOrigin
        sprite.alpha = 0
        sprite.zPosition = SceneLayer.rearFixtures.rawValue + 5_000
        rearFixtureRoot.addChild(sprite)
        hotspotHoverSprites["office.window", default: []].append(
            HotspotHoverSprite(
                sprite: sprite,
                normalTexture: texture,
                hoverTexture: texture,
                normalAlpha: 0,
                hoverAlpha: 1
            )
        )
    }

    /// Desk-native props that `updateDetectiveDepth` lifts above the writing
    /// surface while Voss is seated, so his coat stays under the wood but the
    /// lamp and papers do not.
    private static let deskItemPropIDs = [
        "office_desk_lamp",
        "office_desk_phone",
        "office_desk_typewriter",
        "office_desk_notebook",
        "office_desk_papers",
        "office_desk_ashtray",
        "office_desk_files"
    ]

    /// Props that swap to their `_hover` artwork when a hotspot is under the
    /// cursor. Four sprites share `office.desk` and all of them have to light
    /// together, or the desk highlights in pieces.
    private static let hoverBindings: [(prop: String, hotspot: String)] = [
        ("office_desk_bare", "office.desk"),
        ("office_desk_phone", "office.phone"),
        ("office_desk_files", "office.files"),
        ("office_desk_actor_occluder", "office.desk"),
        ("office_desk_front_occluder_v04", "office.desk"),
        ("office_desk_top_occluder", "office.desk")
    ]

    private func addWindowRain() {
        let crop = SKCropNode()
        let usesRegisteredMask: Bool
        if let texture = GameArt.texture(named: "office_window_glass_mask"),
           texture.size().width >= OfficeInteriorScale.sourceArtSize.width * 0.95,
           texture.size().height >= OfficeInteriorScale.sourceArtSize.height * 0.95 {
            texture.filteringMode = .linear
            let mask = SKSpriteNode(texture: texture, size: OfficeInteriorScale.scaledArtSize)
            mask.name = "office.window.glassMask"
            mask.anchorPoint = .zero
            mask.position = OfficeInteriorScale.shellOrigin
            crop.maskNode = mask
            usesRegisteredMask = true
        } else {
            // Rollback compatibility for pre-V11 plates, whose mask asset was a
            // small window-local source rather than a full-plate registration.
            let maskRect = OfficeInteriorScale.mapRect(
                OfficeNavigationLayout.AuthoredPlacement.windowRainMask
            )
            let mask = SKShapeNode(rect: maskRect)
            mask.fillColor = .white
            mask.strokeColor = .clear
            crop.maskNode = mask
            usesRegisteredMask = false
        }

        let rain = RainSystem.makeEmitter(
            width: usesRegisteredMask
                ? OfficeInteriorScale.scaledArtSize.width
                : 850 * OfficeInteriorScale.environment,
            height: usesRegisteredMask
                ? OfficeInteriorScale.scaledArtSize.height
                : 760 * OfficeInteriorScale.environment,
            birthRate: 150,
            speed: 520 * OfficeInteriorScale.environment,
            scale: 0.38 * OfficeInteriorScale.environment,
            alpha: 0.42
        )
        if usesRegisteredMask {
            rain.position = CGPoint(
                x: OfficeInteriorScale.shellOrigin.x
                    + OfficeInteriorScale.scaledArtSize.width / 2,
                y: OfficeInteriorScale.shellOrigin.y
                    + OfficeInteriorScale.scaledArtSize.height
            )
        } else {
            rain.position = OfficeInteriorScale.mapPoint(
                OfficeNavigationLayout.AuthoredPlacement.windowRainEmitter
            )
        }
        crop.addChild(rain)
        // Rain runs down the glass, so it has to draw over the window's own art.
        // The old code got that by adding it straight after the window and
        // relying on child order, which the view does not honour: it runs with
        // `ignoresSiblingOrder = true`, so two nodes at one zPosition draw in
        // whichever order batches best. Half an ordering step above the window
        // says it in the only terms SpriteKit reads.
        crop.name = "office.window.rain"
        crop.zPosition = SceneLayer.rearFixtures.rawValue + 5_000 + Self.propOrderStep * 0.5
        rearFixtureRoot.addChild(crop)
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

    /// QA hook: park idle stand-ins at the entrance, desk, and waiting group.
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

    /// The one thing over the plate that is not a prop.
    ///
    /// It is a full-plate darkening pass at the plate's own origin and size,
    /// sitting above the background and below everything else — part of how the
    /// room is lit rather than something standing in it. A `.WED` would carry
    /// this as an overlay layer, not as a tiled object, and the same split is
    /// why it stays here while the other fifty-five pieces moved into the
    /// record.
    private func addShellVignette() {
        guard let vignetteTex = GameArt.texture(named: "office_shadow_vignette") else { return }
        let vignette = SKSpriteNode(texture: vignetteTex, size: OfficeInteriorScale.scaledArtSize)
        vignette.name = "office_shadow_vignette"
        vignette.anchorPoint = .zero
        vignette.position = OfficeInteriorScale.shellOrigin
        vignette.alpha = 0.9
        vignette.blendMode = .alpha
        vignette.zPosition = 1
        vignette.texture?.filteringMode = .linear
        // Above the shell plate, under floor props and actors.
        backgroundRoot.addChild(vignette)
    }

    private func addFogOfWar() {
        let fog = OfficeFogOfWarNode(
            size: OfficeInteriorScale.scaledArtSize,
            origin: OfficeInteriorScale.shellOrigin,
            initialReveal: arrivalPoint
        )
        // The opening conversation starts with Lila crossing from the door,
        // so her authored entrance is part of the initially explored office.
        for point in OfficeNavigationLayout.clientArrivalPath {
            fog.reveal(at: point, forceTrailPoint: true)
        }
        weatherRoot.addChild(fog)
        fogOfWar = fog
    }

    /// The BG:EE reference only exposes the entrance leaf edge-on against the
    /// black cutaway. Every state shares one hinge registration and swaps a
    /// purpose-painted silhouette; no front-elevation warp is used.
    private func doorTexture(
        for state: OfficeDoorVisualState,
        hovered: Bool
    ) -> SKTexture? {
        guard let registration = area.doors.first(where: { $0.id == "office.door" })?.visual
        else { return nil }
        let normalName: String
        let hoverName: String?
        switch state {
        case .closed:
            normalName = registration.closedTextureName
            hoverName = registration.closedHoverTextureName
        case .mid:
            normalName = registration.midTextureName
            hoverName = registration.midHoverTextureName
        case .open:
            normalName = registration.openTextureName
            hoverName = registration.openHoverTextureName
        }
        let texture = hovered
            ? hoverName.flatMap(GameArt.texture(named:))
                ?? GameArt.texture(named: normalName)
            : GameArt.texture(named: normalName)
        texture?.filteringMode = .linear
        return texture
    }

    private func presentDoorVisualState(_ state: OfficeDoorVisualState) {
        guard let officeDoor,
              let registration = area.doors.first(where: { $0.id == "office.door" })?.visual,
              let texture = doorTexture(for: state, hovered: false) else {
            return
        }
        officeDoor.texture = texture
        officeDoor.size = texture.size()
        if officeDoor.parent !== depthWorldRoot {
            officeDoor.move(toParent: depthWorldRoot)
        }
        officeDoor.anchorPoint = registration.canvasAnchor.cgPoint
        officeDoor.position = registration.position.cgPoint
        officeDoor.setScale(registration.scale)
        officeDoor.zRotation = 0
        officeDoor.warpGeometry = nil
        officeDoor.alpha = 1
        updateDepth(of: officeDoor, bias: 24)
        officeDoorVisualState = state
    }

    private func applyDoorVisualState(
        _ state: OfficeDoorVisualState,
        entranceBlocking: Bool
    ) {
        officeDoor?.removeAction(forKey: "officeDoorMotion")
        presentDoorVisualState(state)
        navigation.setEntranceDoorBlocking(entranceBlocking)
    }

    private func animateDoor(
        to target: OfficeDoorVisualState,
        entranceBlockingAtEnd: Bool
    ) {
        guard let officeDoor else { return }
        officeDoor.removeAction(forKey: "officeDoorMotion")

        // Opening clears the threshold immediately; closing stamps it only
        // after the dark edge has tucked back into the cutaway.
        if target == .open {
            navigation.setEntranceDoorBlocking(false)
        }
        let motion = SKAction.sequence([
            .run { [weak self] in self?.presentDoorVisualState(.mid) },
            .wait(forDuration: 0.16),
            .run { [weak self] in self?.presentDoorVisualState(target) },
            .run { [weak self] in
                self?.navigation.setEntranceDoorBlocking(entranceBlockingAtEnd)
            }
        ])
        officeDoor.run(motion, withKey: "officeDoorMotion")
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

    #if LEGACY_FALLEN_OFFICE_DOOR
    // Retained only as source provenance for pre-V08 captures. This branch is
    // deliberately not compiled; V08 uses registered closed/mid/open images.
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
        applyDoorVisualState(.open, entranceBlocking: false)
        return

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
        navigation.setEntranceDoorBlocking(false)
    }

    /// Lila's entrance knocks the already damaged leaf free. A projective warp
    /// tips the leaf into the floor plane; the dark extrusion and contact shadow
    /// keep it from reading as a flat card rotating in screen space.
    private func animateDoorFalling() {
        animateDoor(to: .open, entranceBlockingAtEnd: false)
        return

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
            self.navigation.setEntranceDoorBlocking(false)
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
        animateDoor(to: .closed, entranceBlockingAtEnd: true)
        return

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
                    self.navigation.setEntranceDoorBlocking(true)
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
    #endif

    /// Compatibility entry points used by the existing cutscene sequencer.
    /// Their presentation is now a hinged edge-state swap, never a fallen leaf.
    private func setDoorFallenForReview() {
        applyDoorVisualState(.open, entranceBlocking: false)
    }

    private func animateDoorFalling() {
        animateDoor(to: .open, entranceBlockingAtEnd: false)
    }

    private func animateDoorReturning() {
        animateDoor(to: .closed, entranceBlockingAtEnd: true)
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

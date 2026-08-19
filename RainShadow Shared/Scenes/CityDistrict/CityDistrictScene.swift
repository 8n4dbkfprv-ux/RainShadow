import SpriteKit
#if os(macOS)
import AppKit
#endif

/// Playable Act I outdoor district. Loads a `CityDistrictDefinition` with modular
/// V2 art, fog-of-war, building portals, and BG Classic edge exits → World Map.
@MainActor
final class CityDistrictScene: BaseGameScene {
    private struct EdgeExit {
        let edge: CityMapEdge
        let hitArea: CGRect
        let approachPoint: CGPoint
    }

    private let district: CityDistrictDefinition
    private let entranceName: String?
    private let detective = DetectiveActorNode()
    private let inventoryOverlay = InventoryOverlay()
    private let portraitBar = PortraitBarNode()
    private let actionBar = ActionBarNode()
    private lazy var areaMapOverlay = AreaMapOverlay(configuration: makeMapConfiguration())
    private let worldMapOverlay = WorldMapOverlay()
    private let journalOverlay = JournalOverlay()
    private var fogOfWar: CityFogOfWarNode?
    private var edgeExits: [EdgeExit] = []
    private var inventoryIsPresented = false
    private var mapIsPresented = false
    private var worldMapIsPresented = false
    private var journalIsPresented = false
    private var hasShownArrivalHint = false
    private var inspectBanner: SKLabelNode?
    /// The district as an area record plus its navigation and waypoint queue.
    /// Props, obstacles and art still come from `district` until Phase 5.
    private var runtime: AreaRuntime {
        guard let areaRuntime else {
            preconditionFailure(
                "CityDistrictScene read its area before loadArea ran; "
                    + "the runtime is built in init so this cannot depend on buildScene order"
            )
        }
        return areaRuntime
    }
    private var area: AreaDefinition { runtime.area }
    private var navigation: NavigationMap { runtime.navigation }
    private var movement: MovementOrderQueue { runtime.movement }
    private let barks = MovementBarkPlayer()
    private static let detectiveActorID = "detective.voss"

    override var referenceVisibleHeight: CGFloat { CityDistrictDefinition.cameraVisibleHeight }

    init(context: GameContext, districtID: CityDistrictID = .sableRow, entrance: String? = nil) {
        self.district = CityDistrictCatalog.definition(for: districtID)
        self.entranceName = entrance
        super.init(context: context, artSize: CityDistrictDefinition.worldArtSize)
        // In `init` rather than `buildScene`, so nothing can read the area
        // before it exists. The office crashed exactly that way.
        loadArea(AreaRuntime(
            area: HarborpointAreas.requireArea(CityDistrictAreaAdapter.areaID(for: districtID)),
            playerActorID: Self.detectiveActorID
        ))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CityDistrictScene is created programmatically")
    }

    override func buildScene() {
        buildAmbients(from: area)

        let groundName = district.groundTextureName
        if let texture = GameArt.texture(named: groundName)
            ?? GameArt.texture(named: "city_district_ground_v02") {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: CityDistrictDefinition.worldArtSize)
            background.anchorPoint = .zero
            background.position = .zero
            backgroundRoot.addChild(background)
        } else {
            assertionFailure("Missing city ground texture \(groundName)")
        }
        addModularDistrictSprites()

        edgeExits = makeEdgeExits()
        detective.position = area.spawnPoint(entrance: entranceName) ?? district.actorStart
        detective.beginOpenWorldStanding()
        // Neutral bake is office-bright; cool night grade seats him in wet cobbles.
        detective.applySceneLighting(.cityNight)
        navigation.registerActor(
            id: Self.detectiveActorID,
            kind: .player,
            at: detective.position,
            radius: NavigationAgentProfile.detective.radius
        )
        context.session.recordCityFogReveal(district.id, point: detective.position)
        updateDepth(of: detective)
        depthWorldRoot.addChild(detective)

        addFogOfWar()
        addCityRain()
        buildHud()
        updateCameraPosition()
    }


    /// Push current session state into the open inventory window. Every mutation
    /// goes through `GameSession`, so the window never holds authoritative state —
    /// it redraws from what was actually committed.
    private func refreshInventoryOverlay() {
        inventoryOverlay.applyInventory(
            walletPence: context.session.walletPence,
            inventory: context.session.characterInventory,
            catalog: context.session.itemCatalog,
            currentHealth: context.session.currentHealth,
            maximumHealth: context.session.maximumHealth
        )
        detective.movementProfile = context.session.detectiveMovementProfile
    }

    override func sceneDidBecomeReady() {
        // See DetectiveOfficeScene.syncDetectiveEncumbrance: a save loaded with a
        // heavy bag must walk heavy from the first step, not from the first pickup.
        detective.movementProfile = context.session.detectiveMovementProfile
        guard !hasShownArrivalHint else { return }
        hasShownArrivalHint = true
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = area.arrivalHint ?? district.arrivalHint
        hint.fontSize = 17
        hint.fontColor = SKColor(white: 0.86, alpha: 0.90)
        hint.position = CGPoint(x: 0, y: 292)
        hint.alpha = 0
        hudRoot.addChild(hint)
        hint.run(.sequence([
            .wait(forDuration: 0.35),
            .fadeIn(withDuration: 0.30),
            .wait(forDuration: 4.5),
            .fadeOut(withDuration: 0.7),
            .removeFromParent()
        ]))
    }

    override func handlePointerDown(_ event: GamePointerEvent) {
        guard !mapIsPresented, !worldMapIsPresented, !journalIsPresented, !inventoryIsPresented else { return }
        let hudPoint = hudRoot.convert(event.location, from: self)
        actionBar.beginPress(at: actionBar.convert(hudPoint, from: hudRoot))
        portraitBar.beginUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
    }

    override func handlePointerDragged(_ event: GamePointerEvent) {
        let hudPoint = hudRoot.convert(event.location, from: self)
        actionBar.updatePress(at: actionBar.convert(hudPoint, from: hudRoot))
        portraitBar.updateUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
    }

    override func handlePointerCancelled(_ event: GamePointerEvent) {
        actionBar.cancelPress()
        portraitBar.cancelUtilityPress()
    }

    override func handlePointerUp(_ event: GamePointerEvent) {
        let hudPoint = hudRoot.convert(event.location, from: self)
        if journalIsPresented {
            journalOverlay.handlePointer(at: journalOverlay.convert(hudPoint, from: hudRoot))
            return
        }
        if worldMapIsPresented {
            worldMapOverlay.handlePointer(at: worldMapOverlay.convert(hudPoint, from: hudRoot))
            return
        }
        if mapIsPresented {
            areaMapOverlay.handlePointer(at: areaMapOverlay.convert(hudPoint, from: hudRoot))
            return
        }
        if inventoryIsPresented {
            inventoryOverlay.handlePointer(
                at: inventoryOverlay.convert(hudPoint, from: hudRoot),
                splitModifier: event.isWaypointQueue
            )
            return
        }

        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint) {
            // BG:EE: double-clicking a portrait centres the view on that character.
            if event.isDoubleClick {
                followCamera()
            } else {
                setInventoryPresented(true)
            }
            return
        }
        let actionPoint = actionBar.convert(hudPoint, from: hudRoot)
        _ = portraitBar.endUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot))
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

        guard CityDistrictDefinition.worldBounds.contains(event.location) else {
            return
        }

        if let region = area.region(at: event.location) {
            handleRegion(region)
            return
        }

        if let exit = edgeExits.first(where: { $0.hitArea.contains(event.location) }) {
            handleEdgeExit(exit)
            return
        }

        moveDetective(to: event.location, queueWaypoint: event.isWaypointQueue)
        // BG:EE double-click also recentres the viewport on the click.
        if event.isDoubleClick {
            recenterCamera(on: event.location)
        }
    }

    override func handleDirectionalInput(_ direction: CGVector) -> Bool {
        if mapIsPresented || worldMapIsPresented { return true }
        if journalIsPresented {
            journalOverlay.handleDirectionalInput(direction)
            return true
        }
        if inventoryIsPresented {
            inventoryOverlay.moveSelection(direction.dx < 0 || direction.dy > 0 ? -1 : 1)
            return true
        }
        // No overlay: the key belongs to the viewport, not the detective.
        return false
    }

    override func handlePointerMoved(_ event: GamePointerEvent) {
        #if os(macOS)
        let hudPoint = hudRoot.convert(event.location, from: self)
        // Stop any running edge scroll up front; re-armed below only when the
        // pointer is over the world rather than an overlay or HUD rail.
        setCameraScroll(.zero)
        if journalIsPresented {
            let journalPoint = journalOverlay.convert(hudPoint, from: hudRoot)
            (journalOverlay.isInteractive(at: journalPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if worldMapIsPresented {
            let mapPoint = worldMapOverlay.convert(hudPoint, from: hudRoot)
            worldMapOverlay.handleHover(at: mapPoint)
            (worldMapOverlay.isInteractive(at: mapPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if mapIsPresented {
            let mapPoint = areaMapOverlay.convert(hudPoint, from: hudRoot)
            (areaMapOverlay.isInteractive(at: mapPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if inventoryIsPresented {
            let inventoryPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            inventoryOverlay.updateHover(at: inventoryPoint)
            (inventoryOverlay.isInteractive(at: inventoryPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        let actionPoint = actionBar.convert(hudPoint, from: hudRoot)
        let hoveredAction = actionBar.hitTest(actionPoint)
        actionBar.setHighlightedButton(hoveredAction)
        if let hoveredAction, hoveredAction.isInteractive {
            NSCursor.pointingHand.set()
            return
        }
        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint)
            || portraitBar.hitTestUtility(portraitPoint) != nil {
            NSCursor.pointingHand.set()
            return
        }
        // Same region lookup the click uses, so the cursor cannot promise a way
        // out that the click then declines to take.
        let isTravel = area.region(at: event.location) != nil
            || edgeExits.contains(where: { $0.hitArea.contains(event.location) })

        // BG:EE edge scrolling (`GameControl::OnGlobalMouseMove`).
        setCameraScroll(edgeScrollVector(forHudPoint: hudPoint))

        // One search-map sample drives hover and the order decision alike; a
        // portal now reads as a way out rather than as scenery. See `WorldCursor`.
        applyWorldCursor(WorldCursorState.resolve(
            isPassable: isFloorOrderable(event.location),
            isTravel: isTravel
        ))
        #endif
    }

    #if os(macOS)
    /// Search-map sample only — this runs on every mouse-move, so it never
    /// path-searches. Mirrors `Map::GetBlocked` behind `UpdateCursor`.
    private func isFloorOrderable(_ point: CGPoint) -> Bool {
        navigation.searchMap.isPassable(
            at: point,
            radius: navigation.agentProfile.radius
        )
    }
    #endif

    override func handleInventoryInput() {
        guard !mapIsPresented, !worldMapIsPresented, !journalIsPresented else { return }
        setInventoryPresented(!inventoryIsPresented)
    }

    override func handleMapInput() {
        guard !inventoryIsPresented, !journalIsPresented, !worldMapIsPresented else { return }
        setMapPresented(!mapIsPresented)
    }

    override func handleJournalInput() {
        guard !inventoryIsPresented, !mapIsPresented, !worldMapIsPresented else { return }
        setJournalPresented(!journalIsPresented)
    }

    var anyOverlayIsPresented: Bool {
        mapIsPresented || worldMapIsPresented || journalIsPresented || inventoryIsPresented
    }

    override var isModalInputActive: Bool { anyOverlayIsPresented }

    override func handleTacticalPauseInput() {
        pause.togglePlayerPause()
        actionBar.setClockPaused(pause.isPausedByPlayer)
        refreshOverlayPauseState()
        if !pause.isPaused {
            detective.resetLocomotionClock()
        }
    }

    override func handleCancelInput() {
        if journalIsPresented {
            setJournalPresented(false)
        } else if worldMapIsPresented {
            setWorldMapPresented(false)
        } else if mapIsPresented {
            setMapPresented(false)
        } else if inventoryIsPresented {
            setInventoryPresented(false)
        } else {
            clearMovementFeedback()
            clearWaypointPips()
            movement.finish()
            detective.cancelMovement()
        }
    }

    /// BG:EE right-click / two-finger tap: clear targeting state without stopping
    /// the walk. Escape remains the only Stop (`handleCancelInput`).

    override func handleSecondaryPointer(at point: CGPoint) -> Bool {
        guard inventoryIsPresented else { return false }
        return inventoryOverlay.handleSecondaryPointer(
            at: inventoryOverlay.convert(hudRoot.convert(point, from: self), from: hudRoot)
        )
    }

    override func handleClearTargetingInput() {
        if journalIsPresented {
            setJournalPresented(false)
        } else if worldMapIsPresented {
            setWorldMapPresented(false)
        } else if mapIsPresented {
            setMapPresented(false)
        } else if inventoryIsPresented {
            setInventoryPresented(false)
        } else {
            clearMovementFeedback()
        }
    }

    override func handleScrollInput(_ deltaY: CGFloat) -> Bool {
        guard journalIsPresented else { return false }
        journalOverlay.moveSelection(deltaY > 0 ? -1 : 1)
        return true
    }

    override func handleConfirmInput() {
        if journalIsPresented {
            setJournalPresented(false)
        } else if worldMapIsPresented {
            setWorldMapPresented(false)
        } else if mapIsPresented {
            setMapPresented(false)
        } else if inventoryIsPresented {
            setInventoryPresented(false)
        }
    }

    override func layoutViewport() {
        super.layoutViewport()
        // Same contract as the office: chrome uses post-sync `size` (live view points).
        let hudViewportSize = size
        inventoryOverlay.layout(for: hudViewportSize)
        areaMapOverlay.layout(for: hudViewportSize)
        worldMapOverlay.layout(for: hudViewportSize)
        journalOverlay.layout(for: hudViewportSize)
        portraitBar.layout(for: hudViewportSize)
        actionBar.layout(for: hudViewportSize)
        updateCameraPosition()
    }

    override func update(_ currentTime: TimeInterval) {
        tickAreaScript()
        pause.setModal(dialogue: false, overlay: anyOverlayIsPresented)
        let worldIsPaused = pause.isPaused
        // The ground says what it is. This was `.wetStone` unconditionally,
        // which is right for a paved ward and wrong the moment an area mixes
        // surfaces — a quay, a boardwalk, an interior reached without a load.
        detective.footstepSurface = FootstepSurface(
            navigation.searchMap.surface(at: detective.position) ?? .stone
        )
        detective.updateLocomotion(at: currentTime, worldIsPaused: worldIsPaused)
        if !worldIsPaused {
            pruneCompletedQueuedGoals()
            navigation.updateActor(
                id: Self.detectiveActorID,
                position: detective.position,
                isMoving: detective.movementDestination != nil
            )
            performCorrectiveRepathIfNeeded(at: currentTime)
        }
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth
        )
        areaMapOverlay.updateCurrentPosition(detective.position)
        areaMapOverlay.updateExploredPoints(context.session.cityFogRevealPoints(for: district.id))
        updateDepth(of: detective)
        if fogOfWar?.reveal(at: detective.position) == true {
            context.session.recordCityFogReveal(district.id, point: detective.position)
        }
        updateCameraPosition(at: currentTime)
    }

    private func buildHud() {
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth,
            animated: false
        )
        hudRoot.addChild(portraitBar)
        hudRoot.addChild(actionBar)

        inventoryOverlay.zPosition = 100
        inventoryOverlay.onDismiss = { [weak self] in self?.setInventoryPresented(false) }
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
        hudRoot.addChild(inventoryOverlay)

        areaMapOverlay.zPosition = 110
        areaMapOverlay.onDismiss = { [weak self] in self?.setMapPresented(false) }
        areaMapOverlay.onRequestWorldMap = { [weak self] in
            self?.presentWorldMapFromAreaMap()
        }
        hudRoot.addChild(areaMapOverlay)

        worldMapOverlay.zPosition = 115
        worldMapOverlay.onDismiss = { [weak self] in self?.setWorldMapPresented(false) }
        worldMapOverlay.onTravel = { [weak self] destinationID, arrivalKey in
            self?.travelViaWorldMap(to: destinationID, arrivalKey: arrivalKey)
        }
        worldMapOverlay.onStatusLine = { [weak self] line in
            self?.showInspectLine(line)
        }
        hudRoot.addChild(worldMapOverlay)

        journalOverlay.zPosition = 120
        journalOverlay.onDismiss = { [weak self] in self?.setJournalPresented(false) }
        hudRoot.addChild(journalOverlay)
    }

    private func makeEdgeExits() -> [EdgeExit] {
        CityWorldMap.travelableExitEdges(from: district.id).map { edge in
            EdgeExit(
                edge: edge,
                hitArea: CityWorldMap.exitHitArea(for: edge),
                approachPoint: CityWorldMap.exitApproachPoint(for: edge)
            )
        }
    }

    private func handleEdgeExit(_ exit: EdgeExit) {
        guard context.session.isCityTravelOpen else {
            showInspectLine("The street stays closed until the case leaves the office.")
            return
        }
        // BG Classic: reaching a map edge opens the World Map for travel.
        moveDetective(to: exit.approachPoint, requiresExactDestination: false) { [weak self] in
            self?.setWorldMapPresented(true, mode: .travel, exitEdge: exit.edge)
        }
    }

    private func presentWorldMapFromAreaMap() {
        setMapPresented(false)
        setWorldMapPresented(true, mode: .view)
    }

    private func travelViaWorldMap(to destinationID: CityDistrictID, arrivalKey: String) {
        setWorldMapPresented(false)
        context.router.travel(
            to: CityDistrictAreaAdapter.areaID(for: destinationID),
            entrance: arrivalKey
        )
    }

    /// Walk up to a region, then do what its kind says.
    ///
    /// The player is sent with `requiresExactDestination` because an approach
    /// point is authored to be stood on: `AGENTS.md` records that every city
    /// portal approach once sat on the door sprite, which is painted on the
    /// facade and therefore inside the building's obstacle, so a snapped
    /// arrival would have hidden five unreachable doors.
    private func handleRegion(_ region: AreaRegion) {
        let box = region.boundingBox
        let target = region.approachPoint?.cgPoint
            ?? CGPoint(x: box.midX, y: box.midY)

        if let flag = region.requiresFlag, !isFlagSet(flag) {
            moveDetective(to: target, requiresExactDestination: true) { [weak self] in
                self?.showInspectLine(region.lockedLine ?? "")
            }
            return
        }

        switch region.kind {
        case .info:
            moveDetective(to: target, requiresExactDestination: true) { [weak self] in
                self?.context.session.markInspected(region.id)
                self?.showInspectLine(region.observation ?? region.lockedLine ?? "")
            }
        case .trigger:
            // Area scripts arrive in Phase 6; until then a trigger is inert.
            break
        case .travel:
            guard let travel = region.travel else { return }
            // District-to-district doors are retired; Harborpoint keeps its
            // wards on the World Map, reached by walking to a street edge.
            guard travel.destination != area.id,
                  CityDistrictAreaAdapter.district(for: travel.destination) == nil
            else {
                moveDetective(to: target, requiresExactDestination: true) { [weak self] in
                    self?.showInspectLine("Walk the street edge. Harborpoint keeps its wards on the World Map.")
                }
                return
            }
            moveDetective(to: target, requiresExactDestination: true) { [weak self] in
                self?.context.router.travel(to: travel.destination, entrance: travel.entrance)
            }
        }
    }

    /// Bridge until Phase 6 gives areas a real variable namespace. Today the one
    /// authored gate is the city-travel flag, which lives on `GameSession`.
    private func isFlagSet(_ flag: String) -> Bool {
        switch flag {
        case CityDistrictAreaAdapter.cityTravelOpenFlag:
            context.session.isCityTravelOpen
        default:
            context.session.caseState.flags.contains(flag)
        }
    }

    private func showInspectLine(_ text: String) {
        guard !text.isEmpty else { return }
        inspectBanner?.removeFromParent()
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = 16
        label.fontColor = SKColor(white: 0.88, alpha: 0.94)
        label.position = CGPoint(x: 0, y: -300)
        label.alpha = 0
        label.preferredMaxLayoutWidth = 920
        label.numberOfLines = 3
        label.verticalAlignmentMode = .center
        hudRoot.addChild(label)
        inspectBanner = label
        label.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 3.6),
            .fadeOut(withDuration: 0.45),
            .removeFromParent()
        ]))
    }

    // MARK: - Movement
    //
    // Policy lives in `MovementOrderQueue`; this is the SpriteKit half — pips,
    // barks, the blocked marker, and driving the actor.

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
            // BG:EE `Actor::CommandActor` — accepted orders acknowledge, refused
            // ones stay quiet.
            barks.play(.command)
            // BG draws a reticle at every queued waypoint *and* unconditionally
            // at the destination (`DrawTargetReticles` ends with "always draw
            // last step"), or the primary goal only ever gets the transient move
            // marker and nothing on the ground says where you are headed.
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

    private func setInventoryPresented(_ presented: Bool) {
        guard inventoryIsPresented != presented else { return }
        inventoryIsPresented = presented
        refreshOverlayPauseState()
        if presented {
            inventoryOverlay.present(
                walletPence: context.session.walletPence,
                inventory: context.session.characterInventory,
                catalog: context.session.itemCatalog,
                currentHealth: context.session.currentHealth,
                maximumHealth: context.session.maximumHealth
            )
        } else {
            inventoryOverlay.hideAnimated()
        }
    }

    private func setMapPresented(_ presented: Bool) {
        guard mapIsPresented != presented else { return }
        mapIsPresented = presented
        refreshOverlayPauseState()
        if presented {
            areaMapOverlay.present(currentPosition: detective.position)
        } else {
            areaMapOverlay.hideAnimated()
        }
    }

    private func setWorldMapPresented(
        _ presented: Bool,
        mode: WorldMapOverlay.Mode = .view,
        exitEdge: CityMapEdge? = nil
    ) {
        guard worldMapIsPresented != presented else { return }
        worldMapIsPresented = presented
        refreshOverlayPauseState()
        if presented {
            worldMapOverlay.present(
                mode: mode,
                currentDistrict: district.id,
                visited: context.session.visitedCityDistricts,
                exitEdge: exitEdge
            )
        } else {
            worldMapOverlay.hideAnimated()
        }
    }

    private func refreshOverlayPauseState() {
        let anyOverlay = anyOverlayIsPresented
        // A player pause freezes the node trees too, otherwise the rain keeps
        // falling in a stopped world. The HUD stays up for it — unlike an overlay,
        // the point of a tactical pause is to keep issuing orders.
        setWorldPaused(anyOverlay || pause.isPausedByPlayer)
        portraitBar.isHidden = anyOverlay
        actionBar.isHidden = anyOverlay
    }

    private func setJournalPresented(_ presented: Bool) {
        guard journalIsPresented != presented else { return }
        journalIsPresented = presented
        refreshOverlayPauseState()
        if presented {
            journalOverlay.present(input: context.session.journalProjectionInput)
        } else {
            journalOverlay.hideAnimated()
        }
    }

    private func setWorldPaused(_ paused: Bool) {
        [backgroundRoot, floorEffectRoot, rearFixtureRoot, depthWorldRoot, occlusionRoot, weatherRoot, cinematicRoot]
            .forEach { $0.isPaused = paused }
    }

    private func addFogOfWar() {
        let fog = CityFogOfWarNode(
            size: CityDistrictDefinition.worldArtSize,
            revealedPoints: context.session.cityFogRevealPoints(for: district.id),
            initialReveal: detective.position
        )
        fog.zPosition = 10
        weatherRoot.addChild(fog)
        fogOfWar = fog
    }

    private func addCityRain() {
        let rain = RainSystem.makeEmitter(
            width: CityDistrictDefinition.worldArtSize.width + 280,
            height: CityDistrictDefinition.worldArtSize.height + 380,
            birthRate: 500,
            speed: 950,
            scale: 0.58,
            alpha: 0.28
        )
        rain.position = CGPoint(
            x: CityDistrictDefinition.worldArtSize.width / 2,
            y: CityDistrictDefinition.worldArtSize.height + 160
        )
        rain.zPosition = 1
        weatherRoot.addChild(rain)
    }

    /// Build the district's scenery from its area record.
    ///
    /// The plain props go through `BaseGameScene.makeProp`, which is the same
    /// path the office's record will take. Depth-sliced facades stay here
    /// because slicing needs `CityDistrictLayout.IsoLot` to find the lot's
    /// street-facing kerb, which is city geometry rather than anything an area
    /// record should know — Wharf Ladder has 92 props and none of them sliced;
    /// Sable Row has two.
    private func addModularDistrictSprites() {
        for prop in area.props {
            if let worldSize = prop.worldSize,
               let sliceWidth = prop.depthSliceWidth,
               let lotName = prop.depthSortLot,
               let lot = CityDistrictLayout.IsoLot(rawValue: lotName),
               sliceWidth > 0,
               let texture = GameArt.texture(named: prop.textureName) {
                texture.filteringMode = .linear
                addDepthSlicedSprite(
                    prop,
                    texture: texture,
                    worldSize: worldSize.cgSize,
                    lot: lot,
                    sliceWidth: sliceWidth
                )
                continue
            }
            makeProp(prop)
        }
    }

    /// Office-style vertical strips. Each strip keeps the painted foot but
    /// depth-sorts as if it stood on the lot's street-facing kerb, so an actor
    /// on Harbor Street draws in front of the near-side wall.
    private func addDepthSlicedSprite(
        _ visual: AreaProp,
        texture: SKTexture,
        worldSize: CGSize,
        lot: CityDistrictLayout.IsoLot,
        sliceWidth: CGFloat
    ) {
        let left = visual.groundPoint.cgPoint.x - worldSize.width / 2
        var cursor = left
        while cursor < left + worldSize.width - 0.5 {
            let width = min(sliceWidth, left + worldSize.width - cursor)
            let midX = cursor + width / 2
            let crop = CGRect(
                x: (cursor - left) / worldSize.width,
                y: 0,
                width: width / worldSize.width,
                height: 1
            )
            let slice = SKSpriteNode(
                texture: SKTexture(rect: crop, in: texture),
                size: CGSize(width: width, height: worldSize.height)
            )
            slice.name = "city.modular.\(visual.textureName)"
            slice.anchorPoint = CGPoint(x: 0.5, y: visual.anchorY)
            slice.position = CGPoint(x: midX, y: visual.groundPoint.cgPoint.y)
            slice.texture?.filteringMode = .linear
            let northY = lot.northKerbY(atX: midX)
            updateDepth(of: slice, bias: visual.depthBias - northY * 0.5)
            depthWorldRoot.addChild(slice)
            cursor += width
        }
    }

    /// Unlike the office, a district plate is larger than the viewport in both
    /// axes, so the camera really pans and the same rect serves as both the
    /// position clamp and the zoom-out ceiling.
    override var cameraClampBounds: CGRect { CityDistrictDefinition.worldBounds }
    override var cameraPlateBounds: CGRect { CityDistrictDefinition.worldBounds }

    /// Drives the district viewport — following Voss, or free-scrolling under the
    /// player — clamped to the district plate.
    private func updateCameraPosition(at currentTime: TimeInterval = 0) {
        updateCamera(
            following: detective.position,
            in: cameraClampBounds,
            at: currentTime
        )
        syncHudToCamera()
    }

    private func makeMapConfiguration() -> AreaMapOverlay.Configuration {
        let mapPoints = district.pointsOfInterest.map {
            let (r, g, b, a) = $0.colorRGBA
            return AreaMapOverlay.PointOfInterest(
                label: $0.label,
                worldPoint: $0.worldPoint,
                color: SKColor(red: r, green: g, blue: b, alpha: a)
            )
        }
        return AreaMapOverlay.Configuration(
            textureName: district.mapTextureName,
            locationName: district.locationName,
            worldBounds: CityDistrictDefinition.worldBounds,
            pointsOfInterest: mapPoints,
            fogRevealRadius: CityDistrictDefinition.fogRevealRadius
        )
    }
}

@MainActor
private final class CityFogOfWarNode: SKSpriteNode {
    private static let revealRadius = CityDistrictDefinition.fogRevealRadius
    private static let revealSpacing: CGFloat = 72
    private static let maskPixelSize = CGSize(width: 1_024, height: 512)

    private var revealedPoints: [CGPoint]

    init(size: CGSize, revealedPoints: [CGPoint], initialReveal: CGPoint) {
        self.revealedPoints = revealedPoints.isEmpty ? [initialReveal] : revealedPoints
        if self.revealedPoints.last != initialReveal {
            self.revealedPoints.append(initialReveal)
        }
        super.init(texture: nil, color: .black, size: size)
        anchorPoint = .zero
        updateFogTexture()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CityFogOfWarNode is created programmatically")
    }

    @discardableResult
    func reveal(at worldPoint: CGPoint) -> Bool {
        guard let last = revealedPoints.last,
              hypot(worldPoint.x - last.x, worldPoint.y - last.y) >= Self.revealSpacing else {
            return false
        }
        revealedPoints.append(worldPoint)
        updateFogTexture()
        return true
    }

    private func updateFogTexture() {
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
        for (index, point) in revealedPoints.enumerated() {
            let center = CGPoint(x: point.x * pixelScale, y: point.y * pixelScale)
            let phase = CGFloat(index) * 0.61
            for layer in [(1.10, 0.12), (1.055, 0.20), (1.015, 0.38), (0.965, 1.0)] {
                context.addPath(Self.irregularRevealPath(
                    center: center,
                    radius: Self.revealRadius * pixelScale * layer.0,
                    phase: phase
                ))
                context.setFillColor(CGColor(gray: 1, alpha: layer.1))
                context.fillPath()
            }
        }

        guard let image = context.makeImage() else { return }
        let mask = SKTexture(cgImage: image)
        mask.filteringMode = .linear
        texture = mask
    }

    private static func irregularRevealPath(center: CGPoint, radius: CGFloat, phase: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let segments = 72
        for segment in 0..<segments {
            let angle = CGFloat(segment) / CGFloat(segments) * .pi * 2
            let variation = sin(angle * 7 + phase) * 5
                + sin(angle * 17 - phase * 0.8) * 2.3
            let point = CGPoint(
                x: center.x + cos(angle) * (radius + variation),
                y: center.y + sin(angle) * (radius + variation)
            )
            segment == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

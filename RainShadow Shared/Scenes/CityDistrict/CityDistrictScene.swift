import SpriteKit
#if os(macOS)
import AppKit
#endif

/// Playable Act I outdoor district. Plate, props, doors, cover and ambients
/// come from the area bundle; the world map still needs a district id for the
/// edge-exit graph.
@MainActor
final class CityDistrictScene: GameAreaScene {
    private struct EdgeExit {
        let edge: CityMapEdge
        let hitArea: CGRect
        let approachPoint: CGPoint
    }

    /// `nil` for a small city-building interior. The same ARE runtime and input
    /// path serve both; only exterior world-map exits, highlights and rain need
    /// a district identity.
    private let districtID: CityDistrictID?
    private var fogOfWar: FogOfWarNode?
    private var edgeExits: [EdgeExit] = []
    private var hasShownArrivalHint = false
    private var inspectBanner: SKLabelNode?
    private var movement: MovementOrderQueue {
        guard let areaRuntime else {
            preconditionFailure("CityDistrictScene read movement before loadArea ran")
        }
        return areaRuntime.movement
    }
    private let barks = MovementBarkPlayer()

    override var referenceCameraScale: CGFloat { CityDistrictDefinition.cameraScaleAt100Percent }

    init(context: GameContext, districtID: CityDistrictID = .sableRow, entrance: String? = nil) {
        self.districtID = districtID
        super.init(
            context: context,
            areaID: CityDistrictAreaAdapter.areaID(for: districtID),
            entrance: entrance,
            artSize: CityDistrictDefinition.worldArtSize
        )
    }

    init(context: GameContext, interiorID: CityInteriorID, entrance: String? = nil) {
        self.districtID = nil
        super.init(
            context: context,
            areaID: interiorID.areaID,
            entrance: entrance,
            artSize: CityInteriorAreaAdapter.worldSize
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CityDistrictScene is created programmatically")
    }

    override func buildScene() {
        buildAreaBundle()
        buildAreaDoorVisuals()
        addModularDistrictSprites()

        edgeExits = makeEdgeExits()
        if let districtID {
            installHighlightables(CityHighlightOutlines.objects(for: districtID))
        }
        detective.position = area.spawnPoint(entrance: areaEntranceName) ?? .zero
        detective.beginOpenWorldStanding()
        // Daylight is the default outdoor look; rain is an overlay, not a grade.
        detective.applySceneLighting(.cityDay)
        navigation.registerActor(
            id: Self.detectiveActorID,
            kind: .player,
            at: detective.position,
            radius: NavigationAgentProfile.detective.radius
        )
        detective.attachNavigation(navigation, id: Self.detectiveActorID)
        updateDepth(of: detective)
        depthWorldRoot.addChild(detective)
        installGroundCircleActors([detective])

        addFogOfWar()
        if districtID != nil {
            addCityRain()
        }
        buildHud()
        updateCameraPosition()
    }


    override func sceneDidBecomeReady() {
        // A save loaded with a heavy bag must walk heavy from the first step, not
        // from the first pickup.
        syncDetectiveEncumbrance()
        guard !hasShownArrivalHint else { return }
        hasShownArrivalHint = true
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = area.arrivalHint
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
        setHighlightHoverPoint(event.location)
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
        if portraitBar.endUtilityPress(at: portraitBar.convert(hudPoint, from: hudRoot)) == .lantern {
            toggleHighlightReveal()
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
            clearHoverHighlight()
            let journalPoint = journalOverlay.convert(hudPoint, from: hudRoot)
            (journalOverlay.isInteractive(at: journalPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if worldMapIsPresented {
            clearHoverHighlight()
            let mapPoint = worldMapOverlay.convert(hudPoint, from: hudRoot)
            worldMapOverlay.handleHover(at: mapPoint)
            (worldMapOverlay.isInteractive(at: mapPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if mapIsPresented {
            clearHoverHighlight()
            let mapPoint = areaMapOverlay.convert(hudPoint, from: hudRoot)
            (areaMapOverlay.isInteractive(at: mapPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if inventoryIsPresented {
            clearHoverHighlight()
            let inventoryPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            inventoryOverlay.updateHover(at: inventoryPoint)
            (inventoryOverlay.isInteractive(at: inventoryPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        let actionPoint = actionBar.convert(hudPoint, from: hudRoot)
        let hoveredAction = actionBar.hitTest(actionPoint)
        actionBar.setHighlightedButton(hoveredAction)
        if let hoveredAction, hoveredAction.isInteractive {
            clearHoverHighlight()
            NSCursor.pointingHand.set()
            return
        }
        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        if portraitBar.hitTestPortrait(portraitPoint)
            || portraitBar.hitTestUtility(portraitPoint) != nil {
            clearHoverHighlight()
            NSCursor.pointingHand.set()
            return
        }
        // Same region lookup the click uses, so the cursor cannot promise a way
        // out that the click then declines to take.
        setHighlightHoverPoint(event.location)
        let isTravel = hoveredHighlightID != nil
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

    override func handleTacticalPauseInput() {
        pause.togglePlayerPause()
        actionBar.setClockPaused(pause.isPausedByPlayer)
        overlayPresentationDidChange()
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
        tickAreaSystems(listenerAt: detective.position, currentTime: currentTime)
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
            syncWaypointPips()
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
        updateDepth(of: detective)
        applyActorCover(to: detective, at: detective.position)
        updateFogGating(fogOfWar)
        if let fog = fogOfWar, fog.look(from: detective.position) {
            recordExploredFog(fog)
        }
        updateCameraPosition(at: currentTime)
        updateGroundCircles(at: currentTime)
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
        guard let districtID else { return [] }
        return CityWorldMap.travelableExitEdges(from: districtID).map { edge in
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
        moveDetective(
            to: exit.approachPoint,
            minDistance: MovementOrderQueue.defaultInteractionDistance
        ) { [weak self] in
            self?.setWorldMapPresented(true, mode: .travel, exitEdge: exit.edge)
        }
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
    /// Interaction movement uses GemRB's `MinDistance` contract: get within its
    /// 40-unit operating distance of the authored approach, then use the region.
    /// The reachability suites still require every approach itself to be connected;
    /// proximity must not hide a point authored inside a facade or sealed pocket.
    private func handleRegion(_ region: AreaRegion) {
        let box = region.boundingBox
        let target = door(matching: region.id)?.walkTarget(
            from: detective.position,
            fallback: region.approachPoint?.cgPoint
                ?? CGPoint(x: box.midX, y: box.midY)
        ) ?? region.approachPoint?.cgPoint
            ?? CGPoint(x: box.midX, y: box.midY)

        if let flag = region.requiresFlag, !isFlagSet(flag) {
            moveDetective(
                to: target,
                minDistance: MovementOrderQueue.defaultInteractionDistance
            ) { [weak self] in
                self?.showInspectLine(region.lockedLine ?? "")
            }
            return
        }

        switch region.kind {
        case .info:
            moveDetective(
                to: target,
                minDistance: MovementOrderQueue.defaultInteractionDistance
            ) { [weak self] in
                self?.context.session.markInspected(region.id)
                self?.showInspectLine(region.observation ?? region.lockedLine ?? "")
            }
        case .trigger:
            break
        case .travel:
            guard let travel = region.travel else { return }
            // Exterior district-to-district doors are retired; Harborpoint
            // keeps its wards on the World Map, reached by walking to a street
            // edge. An interior's street door must still be allowed to return
            // to the district whose exact entrance name it carries.
            if districtID != nil,
               CityDistrictAreaAdapter.district(for: travel.destination) != nil {
                moveDetective(
                    to: target,
                    minDistance: MovementOrderQueue.defaultInteractionDistance
                ) { [weak self] in
                    self?.showInspectLine("Walk the street edge. Harborpoint keeps its wards on the World Map.")
                }
                return
            }
            guard travel.destination != area.id else { return }
            if let door = door(matching: region.id) {
                let used = useDoor(door, from: detective.position, fallback: target)
                if let locked = used.lockedLine {
                    moveDetective(
                        to: used.walkTo,
                        minDistance: MovementOrderQueue.defaultInteractionDistance
                    ) { [weak self] in
                        self?.showInspectLine(locked)
                    }
                    return
                }
                moveDetective(
                    to: used.walkTo,
                    minDistance: MovementOrderQueue.defaultInteractionDistance
                ) { [weak self] in
                    self?.openDoor(door)
                    self?.context.router.travel(to: travel.destination, entrance: travel.entrance)
                }
                return
            }
            moveDetective(
                to: target,
                minDistance: MovementOrderQueue.defaultInteractionDistance
            ) { [weak self] in
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
            context.session.areaVariables.isSet(flag, in: area.id)
                || context.session.caseState.flags.contains(flag)
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
        minDistance: CGFloat = 0,
        queueWaypoint: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        let outcome = detective.issueOrder(
            via: movement,
            to: target,
            minDistance: minDistance,
            queueWaypoint: queueWaypoint,
            completion: { [weak self] in
                self?.finishQueuedMovement(completion: completion)
            }
        )

        switch outcome {
        case .turnInPlace:
            clearWaypointPips()
            detective.turnToFace(target)

        case .alreadyInRange:
            clearWaypointPips()
            detective.turnToFace(target)
            completion?()

        case .refused:
            showMovementFeedback(at: target, isValid: false)
            clearWaypointPips()

        case .ignored:
            break

        case .walk:
            showMovementFeedback(at: target, isValid: true)
            // BG:EE `Actor::CommandActor`: an accepted order gets a spoken
            // acknowledgement, frequency-gated. A refused one does not.
            barks.play(.command)
            refreshWaypointPips(destination: target)

        case .append:
            showMovementFeedback(at: target, isValid: true)
            refreshWaypointPips(destination: target)
        }
    }

    /// Retire pips as their goals are walked through — see the office scene.
    private func syncWaypointPips() {
        guard let destination = detective.movementDestination else { return }
        refreshWaypointPips(destination: destination)
    }

    /// `DrawTargetReticles`: a reticle at every ordered waypoint still ahead,
    /// then one unconditionally at the destination ("always draw last step").
    ///
    /// The waypoints come from the path itself — `AddWayPoint` marks the node it
    /// extends from and `DoStep` clears the mark on arrival — so there is no
    /// separate queue to keep in step, and a pip cannot outlive its goal.
    private func refreshWaypointPips(destination: CGPoint) {
        clearWaypointPips()
        for waypoint in detective.pendingWaypoints {
            showWaypointPip(at: waypoint)
        }
        showWaypointPip(at: destination)
    }

    private func finishQueuedMovement(completion: (() -> Void)? = nil) {
        clearWaypointPips()
        completion?()
    }

    private func performCorrectiveRepathIfNeeded(at currentTime: TimeInterval) {
        detective.syncMovablePosition()
        switch movement.correctiveRepath(
            &detective.movable,
            at: currentTime,
            ticks: detective.currentTick
        ) {
        case .keepWalking:
            break
        case .abandon:
            clearWaypointPips()
            detective.cancelMovement()
        case .replanned:
            if let destination = detective.movementDestination {
                refreshWaypointPips(destination: destination)
            }
        }
    }

    private func addFogOfWar() {
        let grid = FogGrid(searchMap: navigation.searchMap)
        let fog = FogOfWarNode(
            searchMap: navigation.searchMap,
            visualRangeInCells: area.agentProfile.visualRangeInCells,
            // Outdoor IE: closed street doors are fog-only shrouds, not room floods.
            outdoorDoorShroud: outdoorDoorShroud,
            // What this area has shown the player before, whenever that was.
            remembering: context.session.exploredFogCells(for: area.id, on: grid),
            standingAt: detective.position
        )
        fog.zPosition = 10
        weatherRoot.addChild(fog)
        fogOfWar = fog
        recordExploredFog(fog)
    }

    /// Fold what the fog now knows into the game's memory of this area, and keep
    /// the HUD map showing the same bitmap.
    private func recordExploredFog(_ fog: FogOfWarNode) {
        context.session.recordExploredFog(
            area.id,
            cells: fog.exploredCells,
            on: fog.fogGrid
        )
        areaMapOverlay.updateExploredFog(fog.exploredMapTexture())
    }

    override func doorVisibilityDidChange() {
        guard let fog = fogOfWar else { return }
        if fog.invalidateSight(from: detective.position) {
            recordExploredFog(fog)
        }
    }

    private func addCityRain() {
        // Rain is weather, not the street's identity. Keep a light overlay so
        // the day plate still reads as a 1950s American street in daylight.
        let rain = RainSystem.makeEmitter(
            width: CityDistrictDefinition.worldArtSize.width + 280,
            height: CityDistrictDefinition.worldArtSize.height + 380,
            birthRate: 180,
            speed: 900,
            scale: 0.50,
            alpha: 0.14
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
        for (order, prop) in area.props.enumerated() {
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
            makeProp(prop, order: order)
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
    /// axes at every step in the band, so the camera really pans and the
    /// authored rect is the area outright.
    override var cameraClampBounds: CGRect { area.cameraClampBounds }

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

    override var areaMapConfiguration: AreaMapOverlay.Configuration {
        let mapPoints = area.notes.map { note -> AreaMapOverlay.PointOfInterest in
            let rgba = note.colorRGBA
            return AreaMapOverlay.PointOfInterest(
                label: note.label,
                worldPoint: note.point.cgPoint,
                color: SKColor(
                    red: rgba.count > 0 ? rgba[0] : 1,
                    green: rgba.count > 1 ? rgba[1] : 1,
                    blue: rgba.count > 2 ? rgba[2] : 1,
                    alpha: rgba.count > 3 ? rgba[3] : 1
                )
            )
        }
        return AreaMapOverlay.Configuration(
            textureName: area.mapTextureName ?? "",
            locationName: area.displayName,
            worldBounds: area.worldBounds,
            pointsOfInterest: mapPoints,
            showsExplorationFog: true
        )
    }
}

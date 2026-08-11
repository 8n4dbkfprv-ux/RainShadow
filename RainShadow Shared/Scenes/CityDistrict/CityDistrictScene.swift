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
    private let arrivalKey: String?
    private let detective = DetectiveActorNode()
    private let inventoryOverlay = InventoryOverlay()
    private let portraitBar = PortraitBarNode()
    private let actionBar = ActionBarNode()
    private lazy var areaMapOverlay = AreaMapOverlay(configuration: makeMapConfiguration())
    private let worldMapOverlay = WorldMapOverlay()
    private let journalOverlay = JournalOverlay()
    private var fogOfWar: CityFogOfWarNode?
    private var navigation: NavigationMap!
    private var edgeExits: [EdgeExit] = []
    private var inventoryIsPresented = false
    private var mapIsPresented = false
    private var worldMapIsPresented = false
    private var journalIsPresented = false
    private var hasShownArrivalHint = false
    private var inspectBanner: SKLabelNode?
    /// Ordered player goals (BG:EE waypoint queue). Index 0 is the current leg.
    private var queuedMovementGoals: [CGPoint] = []
    private let barks = MovementBarkPlayer()
    private var lastCorrectiveRepathTime: TimeInterval = 0
    private static let detectiveActorID = "detective.voss"
    private static let correctiveRepathInterval: TimeInterval = 0.75

    override var referenceVisibleHeight: CGFloat { CityDistrictDefinition.cameraVisibleHeight }

    init(context: GameContext, districtID: CityDistrictID = .sableRow, arrivalKey: String? = nil) {
        self.district = CityDistrictCatalog.definition(for: districtID)
        self.arrivalKey = arrivalKey
        super.init(context: context, artSize: CityDistrictDefinition.worldArtSize)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CityDistrictScene is created programmatically")
    }

    override func buildScene() {
        addChild(RainAudio.loopingAmbience(fileNamed: "amb_rain_exterior.m4a", volume: 0.34))

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

        navigation = district.makeGrid()
        edgeExits = makeEdgeExits()
        detective.position = district.spawnPoint(arrivalKey: arrivalKey)
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

    override func sceneDidBecomeReady() {
        guard !hasShownArrivalHint else { return }
        hasShownArrivalHint = true
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text = district.arrivalHint
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
            inventoryOverlay.handlePointer(at: inventoryOverlay.convert(hudPoint, from: hudRoot))
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

        if let portal = district.portals.first(where: { $0.hitArea.contains(event.location) }) {
            handlePortal(portal)
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
        let isTravel = district.portals.contains(where: { $0.hitArea.contains(event.location) })
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
            queuedMovementGoals.removeAll(keepingCapacity: true)
            detective.cancelMovement()
        }
    }

    /// BG:EE right-click / two-finger tap: clear targeting state without stopping
    /// the walk. Escape remains the only Stop (`handleCancelInput`).
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

    override func handleScrollInput(_ deltaY: CGFloat) {
        guard journalIsPresented else { return }
        journalOverlay.moveSelection(deltaY > 0 ? -1 : 1)
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
        pause.setModal(dialogue: false, overlay: anyOverlayIsPresented)
        let worldIsPaused = pause.isPaused
        detective.footstepSurface = .wetStone
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
        context.router.showCityDistrict(destinationID, arrivalKey: arrivalKey)
    }

    private func handlePortal(_ portal: CityDistrictDefinition.Portal) {
        let cityOpen = context.session.isCityTravelOpen
        if portal.requiresCityOpen && !cityOpen {
            moveDetective(to: portal.approachPoint, requiresExactDestination: true) { [weak self] in
                self?.showInspectLine(portal.lockedInspectLine)
            }
            return
        }

        switch portal.destination {
        case .inspect:
            moveDetective(to: portal.approachPoint, requiresExactDestination: true) { [weak self] in
                self?.context.session.markInspected(portal.id)
                self?.showInspectLine(portal.lockedInspectLine)
            }
        case .office:
            moveDetective(to: portal.approachPoint, requiresExactDestination: true) { [weak self] in
                self?.context.router.showOffice(arrivalKey: "from.city")
            }
        case .district:
            // District-to-district portals are retired; travel is edge → World Map.
            moveDetective(to: portal.approachPoint, requiresExactDestination: true) { [weak self] in
                self?.showInspectLine("Walk the street edge. Harborpoint keeps its wards on the World Map.")
            }
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

    private func moveDetective(
        to target: CGPoint,
        requiresExactDestination: Bool = false,
        queueWaypoint: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        let shouldQueue = queueWaypoint && !requiresExactDestination && !queuedMovementGoals.isEmpty

        if shouldQueue {
            appendQueuedWaypoint(to: target)
            return
        }

        // BG:EE: a click inside the search cell you already occupy is a head turn,
        // not a move order (`Movable::WalkTo`).
        if !requiresExactDestination,
           navigation.searchMap.cell(for: detective.position)
               == navigation.searchMap.cell(for: target) {
            clearWaypointPips()
            queuedMovementGoals.removeAll(keepingCapacity: true)
            detective.turnToFace(target)
            return
        }

        // Orders onto impassable ground are refused outright, as the engine does
        // with `IE_CURSOR_BLOCKED`, rather than snapped to a nearby tile. The
        // two-tier search is `Movable::WalkTo`: route around other actors first,
        // fall back to a route through them only when nothing clear exists.
        guard let waypoints = navigation.pathAvoidingActors(from: detective.position, to: target)
            ?? navigation.path(from: detective.position, to: target) else {
            showMovementFeedback(at: target, isValid: false)
            clearWaypointPips()
            queuedMovementGoals.removeAll(keepingCapacity: true)
            return
        }

        clearWaypointPips()
        showMovementFeedback(at: target, isValid: true)
        // BG:EE `Actor::CommandActor` — accepted orders acknowledge, refused ones
        // stay quiet.
        barks.play(.command)
        // BG draws a reticle at every queued waypoint *and* unconditionally at
        // the destination — `DrawTargetReticles` ends with "always draw last
        // step". Without this the primary goal only ever got the transient
        // move marker, so once it faded there was nothing on the ground saying
        // where the detective was ultimately headed.
        showWaypointPip(at: target)
        // A fresh order restarts the replan budget, as `Actor::WalkTo` resets
        // `pathTries` before planning.
        navigation.occupancy.clearCongestion(for: Self.detectiveActorID)
        queuedMovementGoals = [target]
        detective.walk(path: waypoints, completion: { [weak self] in
            self?.finishQueuedMovement(completion: completion)
        })
    }

    private func appendQueuedWaypoint(to target: CGPoint) {
        guard let origin = queuedMovementGoals.last else {
            moveDetective(to: target, queueWaypoint: false)
            return
        }
        guard let waypoints = navigation.path(from: origin, to: target) else {
            showMovementFeedback(at: target, isValid: false)
            return
        }
        // `[]` is the three-valued search's "already there", not a route. BG's
        // `AddWayPoint` returns without appending in exactly this case — "if the
        // waypoint is too close to the current position, no path is generated" —
        // and it has to be rejected explicitly here, or the queue gains a goal
        // the route has no waypoints for and a pip nothing will consume.
        //
        // No blocked marker: the ground is walkable, the order is simply empty.
        guard !waypoints.isEmpty else { return }

        showMovementFeedback(at: target, isValid: true)
        showWaypointPip(at: target)
        queuedMovementGoals.append(target)
        detective.walk(appending: waypoints, completion: { [weak self] in
            self?.finishQueuedMovement()
        })
    }

    private func finishQueuedMovement(completion: (() -> Void)? = nil) {
        clearWaypointPips()
        queuedMovementGoals.removeAll(keepingCapacity: true)
        completion?()
    }

    private func pruneCompletedQueuedGoals() {
        let arrivalSlop: CGFloat = 18
        while queuedMovementGoals.count > 1,
              let goal = queuedMovementGoals.first,
              hypot(detective.position.x - goal.x, detective.position.y - goal.y) <= arrivalSlop {
            removeWaypointPip(nearest: goal)
            queuedMovementGoals.removeFirst()
        }
    }

    /// BG:EE Enhanced Path Search — repath the current leg; keep later queued goals.
    /// Skip adoption when the new route is not meaningfully shorter and the live
    /// route is still clear, so mid-walk kinks from near-identical replacements
    /// do not show.
    private func performCorrectiveRepathIfNeeded(at currentTime: TimeInterval) {
        guard let destination = queuedMovementGoals.first,
              detective.movementDestination != nil,
              currentTime - lastCorrectiveRepathTime >= Self.correctiveRepathInterval else {
            return
        }
        lastCorrectiveRepathTime = currentTime
        guard let repath = navigation.repath(from: detective.position, to: destination),
              !repath.isEmpty else {
            // BG:EE `Actor::NewPath`: count consecutive failed replans toward the
            // same goal and abandon past `MAX_PATH_TRIES`, rather than retrying
            // forever against geometry that is not going to open. Without this an
            // actor whose goal became unreachable mid-walk keeps grinding a search
            // every 0.75 s for the rest of the scene.
            if navigation.occupancy.recordCongestion(for: Self.detectiveActorID) {
                navigation.occupancy.clearCongestion(for: Self.detectiveActorID)
                clearWaypointPips()
                queuedMovementGoals.removeAll(keepingCapacity: true)
                detective.cancelMovement()
            }
            return
        }
        navigation.occupancy.clearCongestion(for: Self.detectiveActorID)
        let currentLeg = currentLegWaypoints(to: destination)
        let remainingLength = Self.polylineLength(currentLeg, from: detective.position)
        let newLength = Self.polylineLength(repath, from: detective.position)
        let meaningfullyShorter = remainingLength > 0 && newLength < remainingLength * 0.9
        let currentBlocked = isRouteBlocked(currentLeg)
        guard meaningfullyShorter || currentBlocked else {
            return
        }
        let remainingGoals = Array(queuedMovementGoals.dropFirst())
        var combined = repath
        var cursor = destination
        for goal in remainingGoals {
            if let leg = navigation.path(from: cursor, to: goal) {
                combined.append(contentsOf: leg)
                cursor = goal
            }
        }
        detective.walk(path: combined, completion: { [weak self] in
            self?.finishQueuedMovement()
        })
    }

    /// Waypoints for the active queued goal only (excludes later Shift-click legs).
    private func currentLegWaypoints(to destination: CGPoint) -> [CGPoint] {
        let arrivalSlop: CGFloat = 18
        var points: [CGPoint] = []
        for point in detective.remainingRouteWaypoints {
            points.append(point)
            if hypot(point.x - destination.x, point.y - destination.y) <= arrivalSlop {
                break
            }
        }
        return points
    }

    private func isRouteBlocked(_ points: [CGPoint]) -> Bool {
        var cursor = detective.position
        for point in points {
            if !navigation.searchMap.isWalkableLine(
                from: cursor,
                to: point,
                radius: navigation.agentProfile.radius,
                treatActorsAsBlocking: true
            ) {
                return true
            }
            cursor = point
        }
        return false
    }

    /// Route length in the projected metric the actor walks, so the corrective
    /// repath compares travel time rather than raw screen distance.
    private static func polylineLength(_ points: [CGPoint], from origin: CGPoint) -> CGFloat {
        guard let first = points.first else { return 0 }
        var length = ActorLocomotionPacing.projectedDistance(from: origin, to: first)
        var previous = first
        for point in points.dropFirst() {
            length += ActorLocomotionPacing.projectedDistance(from: previous, to: point)
            previous = point
        }
        return length
    }

    private func setInventoryPresented(_ presented: Bool) {
        guard inventoryIsPresented != presented else { return }
        inventoryIsPresented = presented
        refreshOverlayPauseState()
        if presented {
            inventoryOverlay.present(walletPence: context.session.walletPence)
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

    private func addModularDistrictSprites() {
        for visual in district.visualSprites {
            guard let texture = GameArt.texture(named: visual.textureName) else { continue }
            let sprite = SKSpriteNode(texture: texture)
            sprite.name = "city.modular.\(visual.textureName)"
            sprite.anchorPoint = CGPoint(x: 0.5, y: visual.anchorY)
            sprite.position = visual.groundPoint
            sprite.setScale(visual.scale)
            sprite.texture?.filteringMode = .linear
            updateDepth(of: sprite, bias: visual.depthBias)
            depthWorldRoot.addChild(sprite)
        }
    }

    /// Drives the district viewport — following Voss, or free-scrolling under the
    /// player — clamped to the district plate.
    private func updateCameraPosition(at currentTime: TimeInterval = 0) {
        updateCamera(
            following: detective.position,
            in: CGRect(origin: .zero, size: CityDistrictDefinition.worldArtSize),
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

import SpriteKit
#if os(macOS)
import AppKit
#endif

/// Playable Act I outdoor district. Loads a `CityDistrictDefinition` (hub or spoke)
/// with modular V2 art, fog-of-war, and portal travel back to the office / hub.
@MainActor
final class CityDistrictScene: BaseGameScene {
    private let district: CityDistrictDefinition
    private let arrivalKey: String?
    private let detective = DetectiveActorNode()
    private let inventoryOverlay = InventoryOverlay()
    private let portraitBar = PortraitBarNode()
    private let actionBar = ActionBarNode()
    private lazy var areaMapOverlay = AreaMapOverlay(configuration: makeMapConfiguration())
    private let journalOverlay = JournalOverlay()
    private var fogOfWar: CityFogOfWarNode?
    private var navigation: NavigationMap!
    private var inventoryIsPresented = false
    private var mapIsPresented = false
    private var journalIsPresented = false
    private var hasShownArrivalHint = false
    private var inspectBanner: SKLabelNode?
    /// Ordered player goals (BG:EE waypoint queue). Index 0 is the current leg.
    private var queuedMovementGoals: [CGPoint] = []
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
        detective.position = district.spawnPoint(arrivalKey: arrivalKey)
        detective.beginOpenWorldStanding()
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
        guard !mapIsPresented, !journalIsPresented, !inventoryIsPresented else { return }
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

        guard CityDistrictDefinition.worldBounds.contains(event.location) else {
            return
        }

        if let portal = district.portals.first(where: { $0.hitArea.contains(event.location) }) {
            handlePortal(portal)
            return
        }

        moveDetective(to: event.location, queueWaypoint: event.isWaypointQueue)
    }

    override func handleDirectionalInput(_ direction: CGVector) {
        if mapIsPresented { return }
        if journalIsPresented {
            journalOverlay.handleDirectionalInput(direction)
            return
        }
        if inventoryIsPresented {
            inventoryOverlay.moveSelection(direction.dx < 0 || direction.dy > 0 ? -1 : 1)
            return
        }

        let step: CGFloat = 72
        let candidate = CGPoint(
            x: detective.position.x + direction.dx * step,
            y: detective.position.y + direction.dy * (step * 0.5)
        )
        moveDetective(to: candidate)
    }

    override func handlePointerMoved(_ event: GamePointerEvent) {
        #if os(macOS)
        let hudPoint = hudRoot.convert(event.location, from: self)
        if journalIsPresented {
            let journalPoint = journalOverlay.convert(hudPoint, from: hudRoot)
            (journalOverlay.isInteractive(at: journalPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
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
        if district.portals.contains(where: { $0.hitArea.contains(event.location) }) {
            NSCursor.pointingHand.set()
            return
        }
        NSCursor.arrow.set()
        #endif
    }

    override func handleInventoryInput() {
        guard !mapIsPresented, !journalIsPresented else { return }
        setInventoryPresented(!inventoryIsPresented)
    }

    override func handleMapInput() {
        guard !inventoryIsPresented, !journalIsPresented else { return }
        setMapPresented(!mapIsPresented)
    }

    override func handleJournalInput() {
        guard !inventoryIsPresented, !mapIsPresented else { return }
        setJournalPresented(!journalIsPresented)
    }

    override func handleCancelInput() {
        if journalIsPresented {
            setJournalPresented(false)
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

    override func handleScrollInput(_ deltaY: CGFloat) {
        guard journalIsPresented else { return }
        journalOverlay.moveSelection(deltaY > 0 ? -1 : 1)
    }

    override func handleConfirmInput() {
        if journalIsPresented {
            setJournalPresented(false)
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
        journalOverlay.layout(for: hudViewportSize)
        portraitBar.layout(for: hudViewportSize)
        actionBar.layout(for: hudViewportSize)
        updateCameraPosition()
    }

    override func update(_ currentTime: TimeInterval) {
        let worldIsPaused = mapIsPresented || journalIsPresented || inventoryIsPresented
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
        updateCameraPosition()
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
        hudRoot.addChild(areaMapOverlay)

        journalOverlay.zPosition = 120
        journalOverlay.onDismiss = { [weak self] in self?.setJournalPresented(false) }
        hudRoot.addChild(journalOverlay)
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
        case .district(let destinationID):
            let arrival = "from.\(district.id.rawValue)"
            moveDetective(to: portal.approachPoint, requiresExactDestination: true) { [weak self] in
                self?.context.router.showCityDistrict(destinationID, arrivalKey: arrival)
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

        guard let route = navigation.route(from: detective.position, to: target) else {
            showMovementFeedback(at: target, isValid: false)
            if !queueWaypoint {
                clearWaypointPips()
                queuedMovementGoals.removeAll(keepingCapacity: true)
            }
            return
        }
        guard !requiresExactDestination || !route.destinationWasAdjusted else {
            showMovementFeedback(at: target, isValid: false)
            clearWaypointPips()
            queuedMovementGoals.removeAll(keepingCapacity: true)
            return
        }

        clearWaypointPips()
        showMovementFeedback(at: route.resolvedDestination, isValid: true)
        queuedMovementGoals = [route.resolvedDestination]
        detective.walk(path: route.waypoints, completion: { [weak self] in
            self?.finishQueuedMovement(completion: completion)
        })
    }

    private func appendQueuedWaypoint(to target: CGPoint) {
        guard let origin = queuedMovementGoals.last else {
            moveDetective(to: target, queueWaypoint: false)
            return
        }
        guard let route = navigation.route(from: origin, to: target) else {
            showMovementFeedback(at: target, isValid: false)
            return
        }
        showMovementFeedback(at: route.resolvedDestination, isValid: true)
        showWaypointPip(at: route.resolvedDestination)
        queuedMovementGoals.append(route.resolvedDestination)
        detective.walk(appending: route.waypoints, completion: { [weak self] in
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
    private func performCorrectiveRepathIfNeeded(at currentTime: TimeInterval) {
        guard let destination = queuedMovementGoals.first,
              detective.movementDestination != nil,
              currentTime - lastCorrectiveRepathTime >= Self.correctiveRepathInterval else {
            return
        }
        lastCorrectiveRepathTime = currentTime
        guard let repath = navigation.repath(from: detective.position, to: destination),
              !repath.isEmpty else {
            return
        }
        let remainingGoals = Array(queuedMovementGoals.dropFirst())
        var combined = repath
        var cursor = destination
        for goal in remainingGoals {
            if let leg = navigation.route(from: cursor, to: goal) {
                combined.append(contentsOf: leg.waypoints)
                cursor = leg.resolvedDestination
            }
        }
        detective.walk(path: combined, completion: { [weak self] in
            self?.finishQueuedMovement()
        })
    }

    private func setInventoryPresented(_ presented: Bool) {
        guard inventoryIsPresented != presented else { return }
        inventoryIsPresented = presented
        setWorldPaused(presented)
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
        setWorldPaused(presented)
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
        setWorldPaused(presented)
        portraitBar.isHidden = presented
        actionBar.isHidden = presented
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

    private func updateCameraPosition() {
        guard size.width > 0, size.height > 0 else { return }
        let halfWidth = size.width * baseCameraScale / 2
        let halfHeight = referenceVisibleHeight / 2
        let world = CityDistrictDefinition.worldArtSize
        gameCamera.position = CGPoint(
            x: min(max(detective.position.x, halfWidth), world.width - halfWidth),
            y: min(max(detective.position.y, halfHeight), world.height - halfHeight)
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

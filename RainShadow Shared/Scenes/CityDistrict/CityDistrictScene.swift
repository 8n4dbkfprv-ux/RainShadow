import SpriteKit
#if os(macOS)
import AppKit
#endif

/// The first open area beyond the detective's office. The city plate is much
/// larger than the office and is paired with a persistent, tight fog reveal so
/// discovery happens block by block instead of exposing oversized scenery.
@MainActor
final class CityDistrictScene: BaseGameScene {
    private let detective = DetectiveActorNode()
    private let inventoryOverlay = InventoryOverlay()
    private let portraitBar = PortraitBarNode()
    private let actionBar = ActionBarNode()
    private lazy var areaMapOverlay = AreaMapOverlay(configuration: makeMapConfiguration())
    private let journalOverlay = JournalOverlay()
    private var fogOfWar: CityFogOfWarNode?
    private var navigation: NavigationGrid!
    private var inventoryIsPresented = false
    private var mapIsPresented = false
    private var journalIsPresented = false
    private var hasShownArrivalHint = false

    override var referenceVisibleHeight: CGFloat { CityDistrictLayout.cameraVisibleHeight }

    init(context: GameContext) {
        super.init(context: context, artSize: CityDistrictLayout.worldArtSize)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CityDistrictScene is created programmatically")
    }

    override func buildScene() {
        addChild(RainAudio.loopingAmbience(fileNamed: "amb_rain_exterior.m4a", volume: 0.34))

        if let texture = GameArt.texture(named: "city_district_ground_v01") {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: CityDistrictLayout.worldArtSize)
            background.anchorPoint = .zero
            background.position = .zero
            backgroundRoot.addChild(background)
        } else {
            buildFallbackCity()
        }
        addModularDistrictSprites()

        navigation = CityDistrictLayout.makeGrid()
        detective.position = CityDistrictLayout.actorStart
        detective.beginOpenWorldStanding()
        context.session.recordCityFogReveal(detective.position)
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
        hint.text = "SABLE ROW  •  Explore the streets. Unseen ground stays under fog."
        hint.fontSize = 18
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
    }

    override func handlePointerDragged(_ event: GamePointerEvent) {
        let hudPoint = hudRoot.convert(event.location, from: self)
        actionBar.updatePress(at: actionBar.convert(hudPoint, from: hudRoot))
    }

    override func handlePointerCancelled(_ event: GamePointerEvent) {
        actionBar.cancelPress()
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
        let activatedButton = actionBar.endPress(at: actionPoint)
        if activatedButton == .map {
            setMapPresented(true)
            return
        }
        if activatedButton == .journal {
            setJournalPresented(true)
            return
        }

        guard CityDistrictLayout.worldBounds.contains(event.location) else {
            return
        }
        moveDetective(to: event.location)
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

        // The 2:1 camera sees a north/south block as half its screen height.
        let step: CGFloat = 112
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
        let mapIsHighlighted = actionBar.hitTestMap(actionPoint)
        actionBar.setMapButtonHighlighted(mapIsHighlighted)
        actionBar.setJournalButtonHighlighted(false)
        if mapIsHighlighted {
            NSCursor.pointingHand.set()
            return
        }
        let journalIsHighlighted = actionBar.hitTestJournal(actionPoint)
        actionBar.setJournalButtonHighlighted(journalIsHighlighted)
        if journalIsHighlighted {
            NSCursor.pointingHand.set()
            return
        }
        let portraitPoint = portraitBar.convert(hudPoint, from: hudRoot)
        (portraitBar.hitTestPortrait(portraitPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
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
        // Camera-child HUD geometry is screen-space and must not change when the
        // world camera zoom changes between the office and the district.
        let hudViewportSize = size
        inventoryOverlay.layout(for: hudViewportSize)
        areaMapOverlay.layout(for: hudViewportSize)
        journalOverlay.layout(for: hudViewportSize)
        portraitBar.layout(for: hudViewportSize)
        actionBar.layout(for: hudViewportSize)
        updateCameraPosition()
    }

    override func update(_ currentTime: TimeInterval) {
        detective.updateLocomotion(
            at: currentTime,
            worldIsPaused: mapIsPresented || journalIsPresented || inventoryIsPresented
        )
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth
        )
        areaMapOverlay.updateCurrentPosition(detective.position)
        areaMapOverlay.updateExploredPoints(context.session.cityFogRevealPoints)
        updateDepth(of: detective)
        if fogOfWar?.reveal(at: detective.position) == true {
            context.session.recordCityFogReveal(detective.position)
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

    private func moveDetective(to target: CGPoint) {
        guard let route = navigation.route(from: detective.position, to: target) else {
            showMovementFeedback(at: target, isValid: false)
            return
        }
        showMovementFeedback(at: route.resolvedDestination, isValid: true)
        detective.walk(path: route.waypoints)
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
            journalOverlay.present(inspectedHotspotIDs: context.session.inspectedHotspotIDs)
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
            size: CityDistrictLayout.worldArtSize,
            revealedPoints: context.session.cityFogRevealPoints,
            initialReveal: detective.position
        )
        fog.zPosition = 10
        weatherRoot.addChild(fog)
        fogOfWar = fog
    }

    private func addCityRain() {
        let rain = RainSystem.makeEmitter(
            width: CityDistrictLayout.worldArtSize.width + 280,
            height: CityDistrictLayout.worldArtSize.height + 380,
            birthRate: 500,
            speed: 950,
            scale: 0.58,
            alpha: 0.28
        )
        rain.position = CGPoint(
            x: CityDistrictLayout.worldArtSize.width / 2,
            y: CityDistrictLayout.worldArtSize.height + 160
        )
        rain.zPosition = 1
        weatherRoot.addChild(rain)
    }

    /// Buildings and street furniture are deliberately independent nodes. This
    /// retains the city plate's authored density while allowing each object to
    /// participate in the same south-to-north depth sorting as the detective.
    private func addModularDistrictSprites() {
        for visual in CityDistrictLayout.visualSprites {
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
        gameCamera.position = CGPoint(
            x: min(max(detective.position.x, halfWidth), CityDistrictLayout.worldArtSize.width - halfWidth),
            y: min(max(detective.position.y, halfHeight), CityDistrictLayout.worldArtSize.height - halfHeight)
        )
    }

    private func makeMapConfiguration() -> AreaMapOverlay.Configuration {
        // Do not leak the rest of the district through the map before it has
        // been discovered; only the office entrance is marked at arrival.
        let mapPoints = CityDistrictLayout.pointsOfInterest
            .filter { $0.kind == .office }
            .map { point in
                let color: SKColor
                switch point.kind {
                case .office: color = SKColor(red: 0.72, green: 0.22, blue: 0.18, alpha: 1)
                case .square: color = SKColor(red: 0.79, green: 0.55, blue: 0.26, alpha: 1)
                case .alley: color = SKColor(red: 0.32, green: 0.51, blue: 0.66, alpha: 1)
                case .exit: color = SKColor(red: 0.58, green: 0.20, blue: 0.48, alpha: 1)
                }
                return AreaMapOverlay.PointOfInterest(
                    label: point.label,
                    worldPoint: point.worldPoint,
                    color: color
                )
            }
        return AreaMapOverlay.Configuration(
            textureName: "city_district_block_v01",
            locationName: "SABLE ROW — LOWER WARD",
            worldBounds: CityDistrictLayout.worldBounds,
            pointsOfInterest: mapPoints,
            fogRevealRadius: 260
        )
    }

    private func buildFallbackCity() {
        let ground = SKShapeNode(rect: CityDistrictLayout.worldBounds)
        ground.fillColor = SKColor(red: 0.035, green: 0.052, blue: 0.07, alpha: 1)
        ground.strokeColor = .clear
        backgroundRoot.addChild(ground)

        for building in CityDistrictLayout.obstacles {
            let block = SKShapeNode(rect: building, cornerRadius: 8)
            block.fillColor = SKColor(red: 0.075, green: 0.055, blue: 0.052, alpha: 1)
            block.strokeColor = SKColor(red: 0.20, green: 0.16, blue: 0.13, alpha: 1)
            block.lineWidth = 4
            backgroundRoot.addChild(block)
        }
    }
}

/// Persistent city exploration mask. The local reveal is deliberately only
/// 2.6 actor-heights in radius: streets are discovered at human scale, and the
/// generated buildings never need to be shown as huge, distant set pieces.
@MainActor
private final class CityFogOfWarNode: SKSpriteNode {
    private static let revealRadius: CGFloat = 260
    private static let revealSpacing: CGFloat = 56
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

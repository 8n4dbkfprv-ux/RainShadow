import SpriteKit
#if os(macOS)
import AppKit
#endif

@MainActor
final class DetectiveOfficeScene: BaseGameScene {
    private let detective = DetectiveActorNode()
    private let client = ClientActorNode()
    private let observationPresenter = ObservationPresenter()
    private let caseIntroductionPresenter = CaseIntroductionPresenter()
    private let inventoryOverlay = InventoryOverlay()
    private let inventoryButton = InventoryToggleButton()
    private let portraitBar = PortraitBarNode()
    private var fogOfWar: OfficeFogOfWarNode?
    private var navigation: NavigationGrid!
    private var hotspots: [OfficeHotspot] = []
    private var inventoryIsPresented = false
    private var caseIntroductionStarted = false
    private var caseIntroductionIsActive = true

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

        addWindowRain()
        addLampAtmosphere()

        addRearFixture(
            named: "office_radiator",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.radiator),
            scale: env
        )
        addRearFixture(
            named: "office_door_leaf",
            at: OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf),
            scale: env
        )

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
        addDepthProp(named: "office_desk_bare", at: deskPosition, scale: deskScale, bias: -500)
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
        addDepthProp(
            named: "office_desk_actor_occluder",
            at: deskPosition,
            scale: deskScale,
            bias: -70
        )

        addDepthProp(
            named: "office_desk_front_occluder_v03",
            at: deskPosition,
            scale: deskScale,
            bias: 10
        )

        addFogOfWar()

        configureNavigation()
        configureHotspots()

        hudRoot.addChild(observationPresenter)
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth,
            animated: false
        )
        hudRoot.addChild(portraitBar)
        caseIntroductionPresenter.zPosition = 60
        caseIntroductionPresenter.onComplete = { [weak self] in
            self?.finishCaseIntroduction()
        }
        hudRoot.addChild(caseIntroductionPresenter)
        inventoryOverlay.zPosition = 100
        inventoryOverlay.onDismiss = { [weak self] in
            self?.setInventoryPresented(false)
        }
        hudRoot.addChild(inventoryOverlay)

        inventoryButton.zPosition = 20
        inventoryButton.isHidden = true
        hudRoot.addChild(inventoryButton)
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
        guard caseIntroductionIsActive else { return }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerDown(at: dialoguePoint)
    }

    override func handlePointerDragged(_ event: GamePointerEvent) {
        guard caseIntroductionIsActive else { return }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerDragged(at: dialoguePoint)
    }

    override func handlePointerCancelled(_ event: GamePointerEvent) {
        guard caseIntroductionIsActive else { return }
        let hudPoint = hudRoot.convert(event.location, from: self)
        let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
        _ = caseIntroductionPresenter.handlePointerUp(at: dialoguePoint)
    }

    override func handlePointerUp(_ event: GamePointerEvent) {
        if caseIntroductionIsActive {
            let hudPoint = hudRoot.convert(event.location, from: self)
            let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
            if !caseIntroductionPresenter.handlePointerUp(at: dialoguePoint) {
                caseIntroductionPresenter.handlePointer(at: dialoguePoint)
            }
            return
        }

        let hudPoint = hudRoot.convert(event.location, from: self)
        if inventoryIsPresented {
            let overlayPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            inventoryOverlay.handlePointer(at: overlayPoint)
            return
        }

        let buttonPoint = inventoryButton.convert(hudPoint, from: hudRoot)
        if inventoryButton.hitTest(buttonPoint) {
            setInventoryPresented(true)
            return
        }

        if let hotspot = hotspots.first(where: { $0.hitArea.contains(event.location) }) {
            moveDetective(to: hotspot.approachPoint) { [weak self] in
                guard let self else { return }
                self.context.session.markInspected(hotspot.id)
                self.observationPresenter.show(name: hotspot.name, observation: hotspot.observation)
            }
            return
        }

        guard let target = navigation.nearestWalkablePoint(to: event.location) else { return }
        moveDetective(to: target)
    }

    override func handleDirectionalInput(_ direction: CGVector) {
        if caseIntroductionIsActive {
            let selectionDirection = direction.dx < 0 || direction.dy > 0 ? -1 : 1
            if !caseIntroductionPresenter.moveSelection(selectionDirection) {
                let scrollStep: CGFloat = direction.dx < 0 || direction.dy > 0 ? -44 : 44
                _ = caseIntroductionPresenter.scrollContent(by: scrollStep)
            }
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
        if caseIntroductionIsActive {
            let dialoguePoint = caseIntroductionPresenter.convert(hudPoint, from: hudRoot)
            let isInteractive = caseIntroductionPresenter.updatePointer(at: dialoguePoint)
            (isInteractive ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }
        if inventoryIsPresented {
            let overlayPoint = inventoryOverlay.convert(hudPoint, from: hudRoot)
            (inventoryOverlay.isInteractive(at: overlayPoint) ? NSCursor.pointingHand : NSCursor.arrow).set()
            return
        }

        let buttonPoint = inventoryButton.convert(hudPoint, from: hudRoot)
        let isInventoryButton = inventoryButton.hitTest(buttonPoint)
        inventoryButton.setHovered(isInventoryButton)
        if isInventoryButton {
            NSCursor.pointingHand.set()
            return
        }

        let isInteractive = hotspots.contains { $0.hitArea.contains(event.location) }
        (isInteractive ? NSCursor.pointingHand : NSCursor.arrow).set()
        #endif
    }

    override func handleInventoryInput() {
        guard !caseIntroductionIsActive else { return }
        setInventoryPresented(!inventoryIsPresented)
    }

    override func handleScrollInput(_ deltaY: CGFloat) {
        guard caseIntroductionIsActive else { return }
        _ = caseIntroductionPresenter.scrollContent(by: -deltaY)
    }

    override func handleConfirmInput() {
        if caseIntroductionIsActive {
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
        caseIntroductionPresenter.layout(for: visibleSize)
        // Camera children use screen-space points. The other overlays intentionally
        // follow the authored visible-world canvas, while the edge rail must span
        // the physical viewport from top to bottom.
        portraitBar.layout(for: size)
        inventoryButton.position = CGPoint(
            x: -visibleSize.width / 2 + 150,
            y: -visibleSize.height / 2 + 62
        )
    }

    override func update(_ currentTime: TimeInterval) {
        portraitBar.setHealth(
            current: context.session.currentHealth,
            maximum: context.session.maximumHealth
        )
        updateDepth(of: detective)
        updateDepth(of: client)
        fogOfWar?.reveal(at: detective.position)
    }

    private func startCaseIntroduction() {
        client.performEntrance(along: OfficeNavigationLayout.clientArrivalPath) { [weak self] in
            guard let self else { return }
            let normalCameraPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.camera)
            let dialogueCameraPosition = CGPoint(
                x: normalCameraPosition.x,
                y: normalCameraPosition.y - 55
            )
            let cameraLift = SKAction.move(to: dialogueCameraPosition, duration: 0.3)
            cameraLift.timingMode = .easeOut
            self.gameCamera.run(cameraLift, withKey: "dialogueCameraLift")
            self.caseIntroductionPresenter.present([
                CaseDialogueNode(
                    id: "vivian.opening",
                    speaker: "Vivian Hart",
                    text: "Mr. Vale? My sister Lillian vanished Tuesday night.",
                    portraitName: "dialogue_portrait_vivian_hart_v01",
                    choices: [
                        CaseDialogueChoice(
                            text: "And the police?",
                            destinationID: "vivian.police"
                        ),
                        CaseDialogueChoice(
                            text: "Why are you certain she didn't go into the river?",
                            destinationID: "vivian.doubt"
                        )
                    ]
                ),
                CaseDialogueNode(
                    id: "vivian.police",
                    speaker: "Vivian Hart",
                    text: "They found her coat by the river. Said that was answer enough.",
                    portraitName: "dialogue_portrait_vivian_hart_v01",
                    nextNodeID: "vivian.key"
                ),
                CaseDialogueNode(
                    id: "vivian.doubt",
                    speaker: "Vivian Hart",
                    text: "Because Lillian hated the river, and because whoever left that coat wanted the police to stop looking.",
                    portraitName: "dialogue_portrait_vivian_hart_v01",
                    nextNodeID: "vivian.key"
                ),
                CaseDialogueNode(
                    id: "vivian.key",
                    speaker: "Vivian Hart",
                    text: "This brass key was sewn inside the lining. Since I found it, a man has been following me.",
                    portraitName: "dialogue_portrait_vivian_hart_v01",
                    choices: [
                        CaseDialogueChoice(
                            text: "Leave the key. I'll find out what it opens.",
                            destinationID: "vivian.plea"
                        ),
                        CaseDialogueChoice(
                            text: "Describe the man who's been following you.",
                            destinationID: "vivian.follower"
                        )
                    ]
                ),
                CaseDialogueNode(
                    id: "vivian.follower",
                    speaker: "Vivian Hart",
                    text: "Gray overcoat. Black gloves. He waits across the street and turns away whenever I look at him.",
                    portraitName: "dialogue_portrait_vivian_hart_v01",
                    nextNodeID: "elias.accept"
                ),
                CaseDialogueNode(
                    id: "elias.accept",
                    speaker: "Elias Vale",
                    text: "Leave the key. I'll find out what it opens.",
                    portraitName: "dialogue_portrait_elias_vale_v01",
                    nextNodeID: "vivian.plea"
                ),
                CaseDialogueNode(
                    id: "vivian.plea",
                    speaker: "Vivian Hart",
                    text: "Please find her, Mr. Vale.",
                    portraitName: "dialogue_portrait_vivian_hart_v01",
                    nextNodeID: "case.opened"
                ),
                CaseDialogueNode(
                    id: "case.opened",
                    speaker: "Case opened",
                    text: "THE EMPTY COAT",
                    portraitName: "dialogue_portrait_elias_vale_v01",
                    endsDialogue: true
                )
            ], startingAt: "vivian.opening")
        }
    }

    private func finishCaseIntroduction() {
        let normalCameraPosition = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.camera)
        let cameraRestore = SKAction.move(to: normalCameraPosition, duration: 0.3)
        cameraRestore.timingMode = .easeInEaseOut
        gameCamera.run(cameraRestore, withKey: "dialogueCameraLift")
        client.performExit(along: OfficeNavigationLayout.clientDeparturePath) { [weak self] in
            guard let self else { return }
            self.caseIntroductionIsActive = false
            self.inventoryButton.isHidden = false
            self.showOfficeHintIfNeeded()
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
        inventoryButton.isHidden = presented
        portraitBar.isHidden = presented

        if presented {
            observationPresenter.removeAllActions()
            observationPresenter.alpha = 0
            inventoryOverlay.present()
        } else {
            inventoryOverlay.hideAnimated()
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

    private func addRearFixture(named textureName: String, at position: CGPoint, scale: CGFloat) {
        guard let texture = GameArt.texture(named: textureName) else { return }
        let fixture = SKSpriteNode(texture: texture)
        fixture.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        fixture.position = position
        fixture.setScale(scale)
        fixture.texture?.filteringMode = .linear
        rearFixtureRoot.addChild(fixture)
    }

    private func addDepthProp(
        named textureName: String,
        at position: CGPoint,
        scale: CGFloat = 1,
        bias: CGFloat = 0
    ) {
        guard let texture = GameArt.texture(named: textureName) else { return }
        let prop = SKSpriteNode(texture: texture)
        prop.name = textureName
        prop.anchorPoint = CGPoint(x: 0.5, y: 0.04)
        prop.position = position
        prop.setScale(scale)
        prop.texture?.filteringMode = .linear
        updateDepth(of: prop, bias: bias)
        depthWorldRoot.addChild(prop)
    }

    /// Desk items are independent sprites registered to the 932x780 bare-desk texture.
    /// Their native content sizes deliberately reproduce the tiny BG-era room scale.
    private func addDeskItems(at deskPosition: CGPoint, scale: CGFloat) {
        let itemCenters: [(name: String, center: CGPoint)] = [
            ("office_desk_papers", CGPoint(x: 423, y: 224)),
            ("office_desk_files", CGPoint(x: 186, y: 301)),
            ("office_desk_lamp", CGPoint(x: 716, y: 120)),
            ("office_desk_phone", CGPoint(x: 648, y: 213)),
            ("office_desk_mug", CGPoint(x: 391, y: 298)),
            ("office_desk_ashtray", CGPoint(x: 502, y: 313))
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

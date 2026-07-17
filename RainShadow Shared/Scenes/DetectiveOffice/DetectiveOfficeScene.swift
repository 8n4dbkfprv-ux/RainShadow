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

        configureNavigation()
        configureHotspots()

        hudRoot.addChild(observationPresenter)
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

    override func handlePointerUp(_ event: GamePointerEvent) {
        if caseIntroductionIsActive {
            caseIntroductionPresenter.advance()
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
        guard !caseIntroductionIsActive else { return }
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
        guard !caseIntroductionIsActive else {
            NSCursor.arrow.set()
            return
        }
        let hudPoint = hudRoot.convert(event.location, from: self)
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

    override func handleConfirmInput() {
        if caseIntroductionIsActive {
            caseIntroductionPresenter.advance()
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
        inventoryButton.position = CGPoint(
            x: -visibleSize.width / 2 + 150,
            y: -visibleSize.height / 2 + 62
        )
    }

    override func update(_ currentTime: TimeInterval) {
        updateDepth(of: detective)
        updateDepth(of: client)
    }

    private func startCaseIntroduction() {
        client.performEntrance(along: OfficeNavigationLayout.clientArrivalPath) { [weak self] in
            guard let self else { return }
            self.caseIntroductionPresenter.present([
                CaseDialogueLine(
                    speaker: "Vivian Hart",
                    text: "Mr. Vale? My sister Lillian vanished Tuesday night."
                ),
                CaseDialogueLine(
                    speaker: "Elias Vale",
                    text: "And the police?"
                ),
                CaseDialogueLine(
                    speaker: "Vivian Hart",
                    text: "They found her coat by the river. Said that was answer enough."
                ),
                CaseDialogueLine(
                    speaker: "Vivian Hart",
                    text: "This brass key was sewn inside the lining. Since I found it, a man has been following me."
                ),
                CaseDialogueLine(
                    speaker: "Elias Vale",
                    text: "Leave the key. I'll find out what it opens."
                ),
                CaseDialogueLine(
                    speaker: "Vivian Hart",
                    text: "Please find her, Mr. Vale."
                ),
                CaseDialogueLine(
                    speaker: "Case opened",
                    text: "THE EMPTY COAT"
                )
            ])
        }
    }

    private func finishCaseIntroduction() {
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

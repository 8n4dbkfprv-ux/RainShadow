import SpriteKit

@MainActor
final class OpeningExteriorScene: BaseGameScene {
    private var cinematicStarted = false
    private var transitionStarted = false
    private var inputUnlockTime: TimeInterval = 0

    init(context: GameContext) {
        super.init(context: context, artSize: CGSize(width: 3_072, height: 1_728))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("OpeningExteriorScene is created programmatically")
    }

    override func buildScene() {
        addChild(RainAudio.loopingAmbience(fileNamed: "amb_rain_exterior.m4a", volume: 0.52))

        if let texture = GameArt.texture(named: "ext_apartment_base") {
            texture.filteringMode = .linear
            let background = SKSpriteNode(texture: texture, size: artSize)
            background.anchorPoint = .zero
            backgroundRoot.addChild(background)
        } else {
            buildFallbackExterior()
        }

        GameArt.preloadOfficeAssets()

        let far = RainSystem.makeEmitter(width: 3_200, height: 1_900, birthRate: 330, speed: 760, scale: 0.45, alpha: 0.32)
        far.position = CGPoint(x: 1_536, y: 1_820)
        rearFixtureRoot.addChild(far)

        let middle = RainSystem.makeEmitter(width: 3_300, height: 2_000, birthRate: 520, speed: 1_020, scale: 0.72, alpha: 0.5)
        middle.position = CGPoint(x: 1_536, y: 1_860)
        weatherRoot.addChild(middle)

        let near = RainSystem.makeEmitter(width: 3_500, height: 2_100, birthRate: 120, speed: 1_280, scale: 1.2, alpha: 0.58)
        near.position = CGPoint(x: 1_536, y: 1_900)
        weatherRoot.addChild(near)

        gameCamera.position = CGPoint(x: 1_536, y: 760)
        syncHudToCamera()

        let title = SKLabelNode(fontNamed: "AvenirNextCondensed-DemiBold")
        title.text = "RAINSHADOW"
        title.fontSize = 54
        title.fontColor = SKColor(white: 0.78, alpha: 0.8)
        title.position = CGPoint(x: 0, y: 360)
        title.alpha = 0
        hudRoot.addChild(title)
        title.run(.sequence([.wait(forDuration: 1.2), .fadeIn(withDuration: 1.4), .wait(forDuration: 3.2), .fadeOut(withDuration: 1.2)]))
    }

    override func update(_ currentTime: TimeInterval) {
        // Opening pans/zooms the camera; keep title HUD locked to the view.
        syncHudToCamera()
    }

    override func sceneDidBecomeReady() {
        guard !cinematicStarted else { return }
        cinematicStarted = true
        inputUnlockTime = CACurrentMediaTime() + 1

        let startScale = baseCameraScale * 1.08
        gameCamera.setScale(startScale)
        let cameraMove = SKAction.move(to: CGPoint(x: 1_650, y: 1_000), duration: 11.5)
        let cameraZoom = SKAction.scale(to: baseCameraScale * 0.82, duration: 11.5)
        cameraMove.timingMode = .easeInEaseOut
        cameraZoom.timingMode = .easeInEaseOut
        gameCamera.run(.group([cameraMove, cameraZoom]))

        run(.sequence([
            .wait(forDuration: 12.0),
            .run { [weak self] in self?.completeCinematic() }
        ]), withKey: "openingTimeline")
    }

    override func handlePointerUp(_ event: GamePointerEvent) {
        guard CACurrentMediaTime() >= inputUnlockTime else { return }
        completeCinematic()
    }

    override func handleConfirmInput() {
        guard CACurrentMediaTime() >= inputUnlockTime else { return }
        completeCinematic()
    }

    private func completeCinematic() {
        guard !transitionStarted else { return }
        transitionStarted = true
        removeAction(forKey: "openingTimeline")

        let windowBloom = SKShapeNode(rectOf: CGSize(width: 330, height: 250), cornerRadius: 14)
        windowBloom.fillColor = SKColor(red: 0.78, green: 0.48, blue: 0.2, alpha: 1)
        windowBloom.strokeColor = .clear
        windowBloom.blendMode = .add
        windowBloom.position = CGPoint(x: 58, y: 34)
        windowBloom.alpha = 0
        hudRoot.addChild(windowBloom)

        let bloom = SKAction.group([
            .fadeAlpha(to: 0.34, duration: 0.72),
            .scale(to: 11, duration: 0.72)
        ])
        bloom.timingMode = .easeIn
        windowBloom.run(.sequence([
            bloom,
            .run { [weak self] in self?.context.router.showOffice() }
        ]))

        let finalPush = SKAction.scale(to: baseCameraScale * 0.68, duration: 0.8)
        finalPush.timingMode = .easeIn
        gameCamera.run(finalPush)
    }

    private func buildFallbackExterior() {
        let sky = SKShapeNode(rect: CGRect(origin: .zero, size: artSize))
        sky.fillColor = SKColor(red: 0.018, green: 0.026, blue: 0.043, alpha: 1)
        sky.strokeColor = .clear
        backgroundRoot.addChild(sky)

        let building = SKShapeNode(rect: CGRect(x: 370, y: 330, width: 2_330, height: 1_280))
        building.fillColor = SKColor(red: 0.075, green: 0.075, blue: 0.082, alpha: 1)
        building.strokeColor = SKColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1)
        building.lineWidth = 10
        backgroundRoot.addChild(building)

        for row in 0..<4 {
            for column in 0..<7 {
                let frame = CGRect(x: 505 + column * 300, y: 520 + row * 245, width: 142, height: 118)
                let window = SKShapeNode(rect: frame)
                let officeWindow = row == 2 && column == 4
                window.fillColor = officeWindow
                    ? SKColor(red: 0.62, green: 0.35, blue: 0.12, alpha: 0.88)
                    : SKColor(red: 0.055, green: 0.075, blue: 0.095, alpha: 1)
                window.strokeColor = SKColor(white: 0.12, alpha: 1)
                window.lineWidth = 8
                backgroundRoot.addChild(window)
                if officeWindow {
                    window.run(.repeatForever(.sequence([
                        .fadeAlpha(to: 0.72, duration: 1.9),
                        .fadeAlpha(to: 1.0, duration: 2.6)
                    ])))
                }
            }
        }

        let street = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 3_072, height: 360))
        street.fillColor = SKColor(red: 0.025, green: 0.035, blue: 0.052, alpha: 1)
        street.strokeColor = .clear
        backgroundRoot.addChild(street)
    }
}

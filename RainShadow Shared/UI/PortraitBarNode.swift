import SpriteKit

/// A compact, camera-fixed party rail: portrait first, vitals readable at a glance.
/// The information hierarchy follows classic isometric CRPGs while the artwork and
/// construction remain specific to RainShadow's noir interface language.
@MainActor
final class PortraitBarNode: SKNode {
    private enum Metrics {
        static let railWidth: CGFloat = 162
        static let frameSize = CGSize(width: 142, height: 190)
        static let portraitWindowSize = CGSize(width: 104, height: 142)
        static let topInset: CGFloat = 22
    }

    private enum Palette {
        static let rail = SKColor(red: 0.012, green: 0.016, blue: 0.019, alpha: 0.97)
        static let railInset = SKColor(red: 0.022, green: 0.027, blue: 0.031, alpha: 0.96)
        static let steel = SKColor(red: 0.28, green: 0.31, blue: 0.31, alpha: 0.76)
        static let steelDark = SKColor(red: 0.055, green: 0.065, blue: 0.066, alpha: 1)
        static let oxblood = SKColor(red: 0.19, green: 0.055, blue: 0.06, alpha: 0.78)
        static let brass = SKColor(red: 0.58, green: 0.40, blue: 0.20, alpha: 0.88)
        static let healthy = SKColor(red: 0.18, green: 0.74, blue: 0.35, alpha: 1)
        static let wounded = SKColor(red: 0.86, green: 0.58, blue: 0.18, alpha: 1)
        static let critical = SKColor(red: 0.82, green: 0.16, blue: 0.13, alpha: 1)
    }

    private let railShadow = SKShapeNode()
    private let railBackground = SKShapeNode()
    private let railInset = SKShapeNode()
    private let leftSpine = SKShapeNode()
    private let rightSpine = SKShapeNode()
    private let portraitRoot = SKNode()
    private let portraitBacking = SKShapeNode(
        rectOf: Metrics.portraitWindowSize,
        cornerRadius: 2
    )
    private let portraitCrop = SKCropNode()
    private let portraitMask = SKShapeNode(
        rectOf: Metrics.portraitWindowSize,
        cornerRadius: 2
    )
    private let portrait = SKSpriteNode()
    private let statusBorder = SKShapeNode(
        rectOf: Metrics.portraitWindowSize,
        cornerRadius: 2
    )
    private let portraitFrame = SKSpriteNode()
    private let healthShadow = SKLabelNode(fontNamed: "Palatino-Bold")
    private let healthLabel = SKLabelNode(fontNamed: "Palatino-Bold")
    private let separatorShadow = SKShapeNode()
    private let separator = SKShapeNode()
    private let rivetLeft = SKShapeNode(circleOfRadius: 2.6)
    private let rivetRight = SKShapeNode(circleOfRadius: 2.6)
    private let scratches = SKShapeNode()

    private var displayedHealth = 0
    private var displayedMaximumHealth = 0

    override init() {
        super.init()
        name = "hud.portrait-bar"
        buildRail()
        buildPortraitCell()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PortraitBarNode is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let railHeight = visibleSize.height + 12
        position = CGPoint(x: visibleSize.width / 2 - Metrics.railWidth / 2, y: 0)

        railShadow.path = CGPath(
            rect: CGRect(
                x: -Metrics.railWidth / 2 - 7,
                y: -railHeight / 2,
                width: Metrics.railWidth + 7,
                height: railHeight
            ),
            transform: nil
        )
        railBackground.path = CGPath(
            rect: CGRect(
                x: -Metrics.railWidth / 2,
                y: -railHeight / 2,
                width: Metrics.railWidth,
                height: railHeight
            ),
            transform: nil
        )
        railInset.path = CGPath(
            rect: CGRect(
                x: -Metrics.railWidth / 2 + 12,
                y: -railHeight / 2,
                width: Metrics.railWidth - 22,
                height: railHeight
            ),
            transform: nil
        )
        leftSpine.path = CGPath(
            rect: CGRect(
                x: -Metrics.railWidth / 2 + 2,
                y: -railHeight / 2,
                width: 8,
                height: railHeight
            ),
            transform: nil
        )
        rightSpine.path = CGPath(
            rect: CGRect(
                x: Metrics.railWidth / 2 - 5,
                y: -railHeight / 2,
                width: 5,
                height: railHeight
            ),
            transform: nil
        )

        let frameCenterY = visibleSize.height / 2 - Metrics.topInset - Metrics.frameSize.height / 2
        portraitRoot.position = CGPoint(x: 1, y: frameCenterY)

        let separatorY = frameCenterY - Metrics.frameSize.height / 2 - 8
        let separatorPath = CGMutablePath()
        separatorPath.move(to: CGPoint(x: -Metrics.railWidth / 2 + 13, y: separatorY))
        separatorPath.addLine(to: CGPoint(x: Metrics.railWidth / 2 - 9, y: separatorY))
        separatorShadow.path = separatorPath
        separator.path = separatorPath
        separatorShadow.position.y = -2
        rivetLeft.position = CGPoint(x: -Metrics.railWidth / 2 + 17, y: separatorY)
        rivetRight.position = CGPoint(x: Metrics.railWidth / 2 - 13, y: separatorY)

        layoutScratches(railHeight: railHeight, below: separatorY)
    }

    func setHealth(current: Int, maximum: Int, animated: Bool = true) {
        let safeMaximum = max(1, maximum)
        let safeCurrent = min(max(0, current), safeMaximum)
        guard safeCurrent != displayedHealth || safeMaximum != displayedMaximumHealth else { return }
        let tookDamage = safeCurrent < displayedHealth && displayedMaximumHealth > 0

        displayedHealth = safeCurrent
        displayedMaximumHealth = safeMaximum

        let text = "\(safeCurrent)/\(safeMaximum)"
        healthShadow.text = text
        healthLabel.text = text

        let ratio = CGFloat(safeCurrent) / CGFloat(safeMaximum)
        let conditionColor: SKColor
        switch ratio {
        case 0.51...:
            conditionColor = Palette.healthy
        case 0.26...:
            conditionColor = Palette.wounded
        default:
            conditionColor = Palette.critical
        }
        statusBorder.strokeColor = conditionColor
        healthLabel.fontColor = ratio > 0.25
            ? SKColor(white: 0.96, alpha: 1)
            : SKColor(red: 1, green: 0.74, blue: 0.66, alpha: 1)

        guard animated, tookDamage else { return }
        portraitRoot.removeAction(forKey: "damagePulse")
        portraitRoot.run(.sequence([
            .scale(to: 1.035, duration: 0.08),
            .wait(forDuration: 0.06),
            .scale(to: 1, duration: 0.20)
        ]), withKey: "damagePulse")
        statusBorder.removeAction(forKey: "damageFlash")
        statusBorder.run(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.06),
            .fadeAlpha(to: 1, duration: 0.18)
        ]), withKey: "damageFlash")
    }

    func hitTestPortrait(_ point: CGPoint) -> Bool {
        let portraitPoint = portraitRoot.convert(point, from: self)
        return CGRect(
            x: -Metrics.frameSize.width / 2,
            y: -Metrics.frameSize.height / 2,
            width: Metrics.frameSize.width,
            height: Metrics.frameSize.height
        ).contains(portraitPoint)
    }

    private func buildRail() {
        zPosition = 18

        railShadow.fillColor = SKColor(white: 0, alpha: 0.62)
        railShadow.strokeColor = .clear
        railShadow.zPosition = -8
        addChild(railShadow)

        railBackground.fillColor = Palette.rail
        railBackground.strokeColor = Palette.steel
        railBackground.lineWidth = 2
        railBackground.zPosition = -7
        addChild(railBackground)

        railInset.fillColor = Palette.railInset
        railInset.strokeColor = Palette.steelDark
        railInset.lineWidth = 2
        railInset.zPosition = -6
        addChild(railInset)

        leftSpine.fillColor = Palette.steelDark
        leftSpine.strokeColor = Palette.steel
        leftSpine.lineWidth = 1
        leftSpine.zPosition = -5
        addChild(leftSpine)

        rightSpine.fillColor = Palette.steelDark
        rightSpine.strokeColor = Palette.steel
        rightSpine.lineWidth = 1
        rightSpine.zPosition = -5
        addChild(rightSpine)

        scratches.fillColor = .clear
        scratches.strokeColor = SKColor(white: 0.38, alpha: 0.08)
        scratches.lineWidth = 1
        scratches.zPosition = -4
        addChild(scratches)

        separatorShadow.fillColor = .clear
        separatorShadow.strokeColor = SKColor(white: 0, alpha: 0.8)
        separatorShadow.lineWidth = 4
        addChild(separatorShadow)

        separator.fillColor = .clear
        separator.strokeColor = Palette.steel
        separator.lineWidth = 1.5
        addChild(separator)

        for rivet in [rivetLeft, rivetRight] {
            rivet.fillColor = Palette.brass
            rivet.strokeColor = SKColor(red: 0.16, green: 0.09, blue: 0.045, alpha: 1)
            rivet.lineWidth = 1
            addChild(rivet)
        }
    }

    private func buildPortraitCell() {
        portraitRoot.name = "hud.detective-portrait"
        addChild(portraitRoot)

        portraitBacking.fillColor = SKColor(white: 0.005, alpha: 1)
        portraitBacking.strokeColor = Palette.oxblood
        portraitBacking.lineWidth = 5
        portraitBacking.zPosition = 0
        portraitRoot.addChild(portraitBacking)

        portraitMask.fillColor = .white
        portraitMask.strokeColor = .clear
        portraitCrop.maskNode = portraitMask
        portraitCrop.zPosition = 1
        portraitRoot.addChild(portraitCrop)

        if let texture = GameArt.texture(named: "dialogue_portrait_harlan_voss_v01") {
            texture.filteringMode = .linear
            portrait.texture = texture
            portrait.size = CGSize(
                width: Metrics.portraitWindowSize.height,
                height: Metrics.portraitWindowSize.height
            )
            portraitCrop.addChild(portrait)
        } else {
            let fallback = SKShapeNode(rectOf: Metrics.portraitWindowSize)
            fallback.fillColor = SKColor(red: 0.085, green: 0.09, blue: 0.095, alpha: 1)
            fallback.strokeColor = .clear
            portraitCrop.addChild(fallback)
        }

        statusBorder.fillColor = .clear
        statusBorder.strokeColor = Palette.healthy
        statusBorder.lineWidth = 2
        statusBorder.zPosition = 2
        portraitRoot.addChild(statusBorder)

        if let texture = GameArt.texture(named: "hud_portrait_frame_v01") {
            texture.filteringMode = .linear
            portraitFrame.texture = texture
            portraitFrame.size = Metrics.frameSize
            portraitFrame.zPosition = 3
            portraitRoot.addChild(portraitFrame)
        }

        for label in [healthShadow, healthLabel] {
            label.text = "12/12"
            label.fontSize = 22
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 5
            portraitRoot.addChild(label)
        }
        let labelPosition = CGPoint(
            x: -Metrics.portraitWindowSize.width / 2 + 6,
            y: Metrics.portraitWindowSize.height / 2 - 4
        )
        healthShadow.position = CGPoint(x: labelPosition.x + 2, y: labelPosition.y - 2)
        healthShadow.fontColor = SKColor(white: 0, alpha: 0.92)
        healthShadow.zPosition = 4
        healthLabel.position = labelPosition
        healthLabel.fontColor = SKColor(white: 0.96, alpha: 1)
    }

    private func layoutScratches(railHeight: CGFloat, below separatorY: CGFloat) {
        let bottom = -railHeight / 2 + 20
        let top = separatorY - 24
        guard top > bottom else {
            scratches.path = nil
            return
        }

        let path = CGMutablePath()
        let lines: [(CGFloat, CGFloat, CGFloat)] = [
            (-49, 0.08, 0.38),
            (-34, 0.54, 0.87),
            (-8, 0.19, 0.58),
            (17, 0.02, 0.26),
            (39, 0.43, 0.75),
            (55, 0.69, 0.96)
        ]
        let span = top - bottom
        for (x, start, end) in lines {
            path.move(to: CGPoint(x: x, y: bottom + span * start))
            path.addLine(to: CGPoint(x: x - 2, y: bottom + span * end))
        }
        scratches.path = path
    }
}

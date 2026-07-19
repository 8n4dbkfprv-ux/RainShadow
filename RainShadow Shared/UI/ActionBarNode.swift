import SpriteKit

/// Camera-fixed primary actions. The rail borrows only the compact vertical
/// hierarchy of classic isometric CRPGs; its steel, leather, and compass design
/// belongs to RainShadow's noir interface language.
@MainActor
final class ActionBarNode: SKNode {
    private enum Metrics {
        static let railWidth: CGFloat = 142
        static let buttonSize = CGSize(width: 108, height: 108)
        static let topInset: CGFloat = 30
    }

    private enum Palette {
        static let rail = SKColor(red: 0.012, green: 0.016, blue: 0.019, alpha: 0.97)
        static let railInset = SKColor(red: 0.022, green: 0.027, blue: 0.031, alpha: 0.96)
        static let steel = SKColor(red: 0.30, green: 0.33, blue: 0.33, alpha: 0.82)
        static let steelDark = SKColor(red: 0.052, green: 0.061, blue: 0.063, alpha: 1)
        static let oxblood = SKColor(red: 0.22, green: 0.058, blue: 0.064, alpha: 0.86)
        static let brass = SKColor(red: 0.68, green: 0.47, blue: 0.23, alpha: 1)
        static let paper = SKColor(red: 0.78, green: 0.77, blue: 0.69, alpha: 1)
    }

    private let railShadow = SKShapeNode()
    private let railBackground = SKShapeNode()
    private let railInset = SKShapeNode()
    private let leftSpine = SKShapeNode()
    private let rightSpine = SKShapeNode()
    private let scratches = SKShapeNode()
    private let mapButtonRoot = SKNode()
    private let mapButtonShadow = SKShapeNode(rectOf: Metrics.buttonSize, cornerRadius: 7)
    private let mapButtonOuter = SKShapeNode(rectOf: Metrics.buttonSize, cornerRadius: 7)
    private let mapButtonWell = SKShapeNode(
        rectOf: CGSize(width: Metrics.buttonSize.width - 14, height: Metrics.buttonSize.height - 14),
        cornerRadius: 4
    )
    private let mapGlow = SKShapeNode(circleOfRadius: 37)
    private let separatorShadow = SKShapeNode()
    private let separator = SKShapeNode()
    private let rivetLeft = SKShapeNode(circleOfRadius: 2.6)
    private let rivetRight = SKShapeNode(circleOfRadius: 2.6)

    override init() {
        super.init()
        name = "hud.action-bar"
        buildRail()
        buildMapButton()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ActionBarNode is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let railHeight = visibleSize.height + 12
        position = CGPoint(x: -visibleSize.width / 2 + Metrics.railWidth / 2, y: 0)

        railShadow.path = CGPath(
            rect: CGRect(
                x: -Metrics.railWidth / 2,
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
                x: -Metrics.railWidth / 2 + 10,
                y: -railHeight / 2,
                width: Metrics.railWidth - 22,
                height: railHeight
            ),
            transform: nil
        )
        leftSpine.path = CGPath(
            rect: CGRect(
                x: -Metrics.railWidth / 2,
                y: -railHeight / 2,
                width: 5,
                height: railHeight
            ),
            transform: nil
        )
        rightSpine.path = CGPath(
            rect: CGRect(
                x: Metrics.railWidth / 2 - 10,
                y: -railHeight / 2,
                width: 8,
                height: railHeight
            ),
            transform: nil
        )

        let buttonCenterY = visibleSize.height / 2 - Metrics.topInset - Metrics.buttonSize.height / 2
        mapButtonRoot.position = CGPoint(x: -1, y: buttonCenterY)

        let separatorY = buttonCenterY - Metrics.buttonSize.height / 2 - 13
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -Metrics.railWidth / 2 + 11, y: separatorY))
        path.addLine(to: CGPoint(x: Metrics.railWidth / 2 - 13, y: separatorY))
        separatorShadow.path = path
        separator.path = path
        separatorShadow.position.y = -2
        rivetLeft.position = CGPoint(x: -Metrics.railWidth / 2 + 15, y: separatorY)
        rivetRight.position = CGPoint(x: Metrics.railWidth / 2 - 17, y: separatorY)

        layoutScratches(railHeight: railHeight, below: separatorY)
    }

    func hitTestMap(_ point: CGPoint) -> Bool {
        let localPoint = mapButtonRoot.convert(point, from: self)
        return CGRect(
            x: -Metrics.buttonSize.width / 2,
            y: -Metrics.buttonSize.height / 2,
            width: Metrics.buttonSize.width,
            height: Metrics.buttonSize.height
        ).contains(localPoint)
    }

    func setMapButtonHighlighted(_ highlighted: Bool) {
        mapButtonRoot.removeAction(forKey: "hover")
        mapButtonRoot.run(.scale(to: highlighted ? 1.035 : 1, duration: 0.10), withKey: "hover")
        mapButtonOuter.strokeColor = highlighted ? Palette.paper : Palette.steel
        mapGlow.fillColor = highlighted
            ? SKColor(red: 0.40, green: 0.10, blue: 0.09, alpha: 0.30)
            : Palette.oxblood.withAlphaComponent(0.16)
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

        for spine in [leftSpine, rightSpine] {
            spine.fillColor = Palette.steelDark
            spine.strokeColor = Palette.steel
            spine.lineWidth = 1
            spine.zPosition = -5
            addChild(spine)
        }

        scratches.fillColor = .clear
        scratches.strokeColor = SKColor(white: 0.40, alpha: 0.08)
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

    private func buildMapButton() {
        mapButtonRoot.name = "hud.map-button"
        addChild(mapButtonRoot)

        mapButtonShadow.fillColor = SKColor(white: 0, alpha: 0.88)
        mapButtonShadow.strokeColor = .clear
        mapButtonShadow.position = CGPoint(x: 3, y: -4)
        mapButtonShadow.zPosition = -3
        mapButtonRoot.addChild(mapButtonShadow)

        mapButtonOuter.fillColor = Palette.steelDark
        mapButtonOuter.strokeColor = Palette.steel
        mapButtonOuter.lineWidth = 3
        mapButtonOuter.zPosition = -2
        mapButtonRoot.addChild(mapButtonOuter)

        mapButtonWell.fillColor = SKColor(red: 0.010, green: 0.013, blue: 0.016, alpha: 1)
        mapButtonWell.strokeColor = Palette.oxblood
        mapButtonWell.lineWidth = 3
        mapButtonWell.zPosition = -1
        mapButtonRoot.addChild(mapButtonWell)

        mapGlow.fillColor = Palette.oxblood.withAlphaComponent(0.16)
        mapGlow.strokeColor = Palette.brass.withAlphaComponent(0.46)
        mapGlow.lineWidth = 2
        mapButtonRoot.addChild(mapGlow)

        let cardinalPath = CGMutablePath()
        cardinalPath.move(to: CGPoint(x: 0, y: 42))
        cardinalPath.addLine(to: CGPoint(x: 9, y: 13))
        cardinalPath.addLine(to: CGPoint(x: 37, y: 0))
        cardinalPath.addLine(to: CGPoint(x: 9, y: -13))
        cardinalPath.addLine(to: CGPoint(x: 0, y: -38))
        cardinalPath.addLine(to: CGPoint(x: -9, y: -13))
        cardinalPath.addLine(to: CGPoint(x: -37, y: 0))
        cardinalPath.addLine(to: CGPoint(x: -9, y: 13))
        cardinalPath.closeSubpath()
        let cardinal = SKShapeNode(path: cardinalPath)
        cardinal.fillColor = SKColor(red: 0.15, green: 0.17, blue: 0.17, alpha: 1)
        cardinal.strokeColor = Palette.paper.withAlphaComponent(0.86)
        cardinal.lineWidth = 2
        mapButtonRoot.addChild(cardinal)

        let northNeedlePath = CGMutablePath()
        northNeedlePath.move(to: CGPoint(x: 0, y: 37))
        northNeedlePath.addLine(to: CGPoint(x: 8, y: 3))
        northNeedlePath.addLine(to: CGPoint(x: 0, y: 9))
        northNeedlePath.addLine(to: CGPoint(x: -8, y: 3))
        northNeedlePath.closeSubpath()
        let northNeedle = SKShapeNode(path: northNeedlePath)
        northNeedle.fillColor = Palette.brass
        northNeedle.strokeColor = SKColor(red: 0.20, green: 0.11, blue: 0.05, alpha: 1)
        northNeedle.lineWidth = 1
        mapButtonRoot.addChild(northNeedle)

        let labelShadow = SKLabelNode(fontNamed: "Palatino-Bold")
        labelShadow.text = "N"
        labelShadow.fontSize = 38
        labelShadow.fontColor = .black
        labelShadow.verticalAlignmentMode = .center
        labelShadow.position = CGPoint(x: 2, y: -2)
        mapButtonRoot.addChild(labelShadow)

        let label = SKLabelNode(fontNamed: "Palatino-Bold")
        label.text = "N"
        label.fontSize = 38
        label.fontColor = Palette.paper
        label.verticalAlignmentMode = .center
        mapButtonRoot.addChild(label)
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
            (-43, 0.12, 0.46),
            (-22, 0.51, 0.84),
            (4, 0.18, 0.56),
            (27, 0.03, 0.31),
            (46, 0.61, 0.94)
        ]
        let span = top - bottom
        for (x, start, end) in lines {
            path.move(to: CGPoint(x: x, y: bottom + span * start))
            path.addLine(to: CGPoint(x: x + 2, y: bottom + span * end))
        }
        scratches.path = path
    }
}

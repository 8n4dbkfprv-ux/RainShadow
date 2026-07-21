import SpriteKit

/// Camera-fixed primary actions. The rail borrows only the compact vertical
/// hierarchy of classic isometric CRPGs; its steel, leather, and compass design
/// belongs to RainShadow's noir interface language.
@MainActor
final class ActionBarNode: SKNode {
    private enum Metrics {
        static let railWidth: CGFloat = 128
        static let mapButtonHitSize = CGSize(width: 100, height: 92)
        static let mapButtonArtworkSize = CGSize(width: 96, height: 64)
        static let journalButtonHitSize = CGSize(width: 100, height: 80)
        static let journalButtonArtworkSize = CGSize(width: 96, height: 64)
        static let topInset: CGFloat = 22
        static let buttonSpacing: CGFloat = 6
    }

    private enum Palette {
        static let rail = SKColor(red: 0.012, green: 0.016, blue: 0.019, alpha: 0.97)
        static let railInset = SKColor(red: 0.022, green: 0.027, blue: 0.031, alpha: 0.96)
        static let steel = SKColor(red: 0.30, green: 0.33, blue: 0.33, alpha: 0.82)
        static let steelDark = SKColor(red: 0.052, green: 0.061, blue: 0.063, alpha: 1)
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
    private let mapButtonShadow = SKShapeNode(rectOf: Metrics.mapButtonArtworkSize, cornerRadius: 7)
    private let mapButtonArtwork = SKSpriteNode()
    private let mapButtonHighlight = SKShapeNode(rectOf: Metrics.mapButtonArtworkSize, cornerRadius: 7)
    private let journalButtonRoot = SKNode()
    private let journalButtonArtwork = SKSpriteNode()
    private let journalButtonHighlight = SKShapeNode(rectOf: Metrics.journalButtonArtworkSize, cornerRadius: 5)
    private let separatorShadow = SKShapeNode()
    private let separator = SKShapeNode()
    private let rivetLeft = SKShapeNode(circleOfRadius: 2.6)
    private let rivetRight = SKShapeNode(circleOfRadius: 2.6)

    override init() {
        super.init()
        name = "hud.action-bar"
        buildRail()
        buildMapButton()
        buildJournalButton()
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

        let buttonCenterY = visibleSize.height / 2 - Metrics.topInset - Metrics.mapButtonHitSize.height / 2
        mapButtonRoot.position = CGPoint(x: -1, y: buttonCenterY)
        journalButtonRoot.position = CGPoint(
            x: -1,
            y: buttonCenterY
                - Metrics.mapButtonHitSize.height / 2
                - Metrics.journalButtonHitSize.height / 2
                - Metrics.buttonSpacing
        )

        let separatorY = journalButtonRoot.position.y - Metrics.journalButtonHitSize.height / 2 - 9
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
            x: -Metrics.mapButtonHitSize.width / 2,
            y: -Metrics.mapButtonHitSize.height / 2,
            width: Metrics.mapButtonHitSize.width,
            height: Metrics.mapButtonHitSize.height
        ).contains(localPoint)
    }

    func hitTestJournal(_ point: CGPoint) -> Bool {
        let localPoint = journalButtonRoot.convert(point, from: self)
        return CGRect(
            x: -Metrics.journalButtonHitSize.width / 2,
            y: -Metrics.journalButtonHitSize.height / 2,
            width: Metrics.journalButtonHitSize.width,
            height: Metrics.journalButtonHitSize.height
        ).contains(localPoint)
    }

    func setMapButtonHighlighted(_ highlighted: Bool) {
        mapButtonRoot.removeAction(forKey: "hover")
        mapButtonRoot.run(.scale(to: highlighted ? 1.035 : 1, duration: 0.10), withKey: "hover")
        mapButtonArtwork.color = highlighted ? Palette.paper : .white
        mapButtonArtwork.colorBlendFactor = highlighted ? 0.08 : 0
        mapButtonHighlight.strokeColor = highlighted
            ? Palette.paper.withAlphaComponent(0.82)
            : .clear
        mapButtonHighlight.glowWidth = highlighted ? 1.5 : 0
    }

    func setJournalButtonHighlighted(_ highlighted: Bool) {
        journalButtonRoot.removeAction(forKey: "hover")
        journalButtonRoot.run(.scale(to: highlighted ? 1.04 : 1, duration: 0.10), withKey: "hover")
        journalButtonArtwork.alpha = highlighted ? 1 : 0.82
        journalButtonHighlight.strokeColor = highlighted
            ? Palette.paper.withAlphaComponent(0.88)
            : .clear
        journalButtonHighlight.glowWidth = highlighted ? 1.5 : 0
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

        if let texture = GameArt.texture(named: "map_icon_noir_v03") {
            texture.filteringMode = .linear
            mapButtonArtwork.texture = texture
            mapButtonArtwork.size = Metrics.mapButtonArtworkSize
            mapButtonRoot.addChild(mapButtonArtwork)
        } else {
            assertionFailure("Missing map_icon_noir_v03.png")
        }

        mapButtonHighlight.fillColor = .clear
        mapButtonHighlight.strokeColor = .clear
        mapButtonHighlight.lineWidth = 2
        mapButtonHighlight.zPosition = 1
        mapButtonRoot.addChild(mapButtonHighlight)
    }

    private func buildJournalButton() {
        journalButtonRoot.name = "hud.journal-button"
        addChild(journalButtonRoot)

        let shadow = SKShapeNode(rectOf: Metrics.journalButtonArtworkSize, cornerRadius: 5)
        shadow.fillColor = SKColor(white: 0, alpha: 0.84)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -4)
        shadow.zPosition = -3
        journalButtonRoot.addChild(shadow)

        if let texture = GameArt.texture(named: "journal_icon_noir_v02") {
            texture.filteringMode = .linear
            journalButtonArtwork.texture = texture
            journalButtonArtwork.size = Metrics.journalButtonArtworkSize
        } else {
            assertionFailure("Missing journal_icon_noir_v02.png")
        }
        journalButtonRoot.addChild(journalButtonArtwork)

        journalButtonHighlight.fillColor = .clear
        journalButtonHighlight.strokeColor = .clear
        journalButtonHighlight.lineWidth = 2
        journalButtonHighlight.zPosition = 2
        journalButtonRoot.addChild(journalButtonHighlight)
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

import SpriteKit

/// Camera-fixed primary actions. The rail borrows only the compact vertical
/// hierarchy of classic isometric CRPGs; its steel, leather, and compass design
/// belongs to RainShadow's noir interface language.
@MainActor
final class ActionBarNode: SKNode {
    enum Button {
        case map
        case journal
    }

    private enum Metrics {
        static let railWidth: CGFloat = 128
        static let mapButtonHitSize = CGSize(width: 100, height: 72)
        static let mapButtonArtworkSize = CGSize(width: 88, height: 64)
        static let journalButtonHitSize = CGSize(width: 100, height: 72)
        static let journalButtonArtworkSize = CGSize(width: 88, height: 64)
        static let topInset: CGFloat = 22
        static let buttonSpacing: CGFloat = 8
    }

    private enum Palette {
        static let rail = SKColor(red: 0.012, green: 0.016, blue: 0.019, alpha: 0.97)
        static let railInset = SKColor(red: 0.022, green: 0.027, blue: 0.031, alpha: 0.96)
        static let steel = SKColor(red: 0.30, green: 0.33, blue: 0.33, alpha: 0.82)
        static let steelDark = SKColor(red: 0.052, green: 0.061, blue: 0.063, alpha: 1)
        static let brass = SKColor(red: 0.68, green: 0.47, blue: 0.23, alpha: 1)
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
    private let journalButtonRoot = SKNode()
    private let journalButtonArtwork = SKSpriteNode()
    private let separatorShadow = SKShapeNode()
    private let separator = SKShapeNode()
    private let rivetLeft = SKShapeNode(circleOfRadius: 2.6)
    private let rivetRight = SKShapeNode(circleOfRadius: 2.6)
    private var mapTextures: (normal: SKTexture, hover: SKTexture, pressed: SKTexture)?
    private var journalTextures: (normal: SKTexture, hover: SKTexture, pressed: SKTexture)?
    private var mapIsHighlighted = false
    private var journalIsHighlighted = false
    private var pressedButton: Button?
    private var pressIsInside = false

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
                - Metrics.mapButtonArtworkSize.height / 2
                - Metrics.journalButtonArtworkSize.height / 2
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
        mapIsHighlighted = highlighted
        updateButtonTextures()
    }

    func setJournalButtonHighlighted(_ highlighted: Bool) {
        journalIsHighlighted = highlighted
        updateButtonTextures()
    }

    func beginPress(at point: CGPoint) {
        if hitTestMap(point) {
            pressedButton = .map
        } else if hitTestJournal(point) {
            pressedButton = .journal
        } else {
            pressedButton = nil
        }
        pressIsInside = pressedButton != nil
        updateButtonTextures()
    }

    func updatePress(at point: CGPoint) {
        switch pressedButton {
        case .map: pressIsInside = hitTestMap(point)
        case .journal: pressIsInside = hitTestJournal(point)
        case nil: return
        }
        updateButtonTextures()
    }

    @discardableResult
    func endPress(at point: CGPoint) -> Button? {
        updatePress(at: point)
        let activated = pressIsInside ? pressedButton : nil
        pressedButton = nil
        pressIsInside = false
        updateButtonTextures()
        return activated
    }

    func cancelPress() {
        pressedButton = nil
        pressIsInside = false
        updateButtonTextures()
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

        if let normal = GameArt.texture(named: "map_icon_noir_v03"),
           let hover = GameArt.texture(named: "map_icon_noir_v03_hover"),
           let pressed = GameArt.texture(named: "map_icon_noir_v03_pressed") {
            for texture in [normal, hover, pressed] { texture.filteringMode = .linear }
            mapTextures = (normal, hover, pressed)
            mapButtonArtwork.texture = normal
            mapButtonArtwork.size = Metrics.mapButtonArtworkSize
            mapButtonRoot.addChild(mapButtonArtwork)
        } else {
            assertionFailure("Missing map_icon_noir_v03.png")
        }

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

        if let normal = GameArt.texture(named: "journal_icon_noir_v02"),
           let hover = GameArt.texture(named: "journal_icon_noir_v02_hover"),
           let pressed = GameArt.texture(named: "journal_icon_noir_v02_pressed") {
            for texture in [normal, hover, pressed] { texture.filteringMode = .linear }
            journalTextures = (normal, hover, pressed)
            journalButtonArtwork.texture = normal
            journalButtonArtwork.size = Metrics.journalButtonArtworkSize
        } else {
            assertionFailure("Missing journal_icon_noir_v02.png")
        }
        journalButtonRoot.addChild(journalButtonArtwork)

    }

    private func updateButtonTextures() {
        if let textures = mapTextures {
            mapButtonArtwork.texture = pressedButton == .map && pressIsInside
                ? textures.pressed
                : (mapIsHighlighted ? textures.hover : textures.normal)
        }
        if let textures = journalTextures {
            journalButtonArtwork.texture = pressedButton == .journal && pressIsInside
                ? textures.pressed
                : (journalIsHighlighted ? textures.hover : textures.normal)
        }
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

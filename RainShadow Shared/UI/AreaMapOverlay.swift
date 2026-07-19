import SpriteKit

/// Full-screen local map for the detective office. The generated texture owns
/// the painted location; labels, explored-state language, markers, and input
/// remain deterministic SpriteKit UI.
@MainActor
final class AreaMapOverlay: SKNode {
    private enum Metrics {
        static let canvas = CGSize(width: 1_920, height: 1_080)
        /// Preserve the generated plate's 1847:851 aspect ratio so the room's
        /// dimetric floor and furniture registration are not stretched.
        static let mapSize = CGSize(width: 1_660, height: 765)
    }

    private enum Palette {
        static let ink = SKColor(red: 0.016, green: 0.019, blue: 0.024, alpha: 0.97)
        static let panel = SKColor(red: 0.030, green: 0.034, blue: 0.039, alpha: 0.96)
        static let raised = SKColor(red: 0.064, green: 0.069, blue: 0.075, alpha: 0.98)
        static let steel = SKColor(red: 0.46, green: 0.49, blue: 0.50, alpha: 0.62)
        static let paper = SKColor(red: 0.82, green: 0.80, blue: 0.72, alpha: 1)
        static let quiet = SKColor(red: 0.53, green: 0.55, blue: 0.55, alpha: 1)
        static let amber = SKColor(red: 0.79, green: 0.55, blue: 0.26, alpha: 1)
        static let oxblood = SKColor(red: 0.50, green: 0.13, blue: 0.12, alpha: 1)
        static let rain = SKColor(red: 0.32, green: 0.51, blue: 0.66, alpha: 1)
        static let party = SKColor(red: 0.14, green: 0.78, blue: 0.26, alpha: 1)
    }

    var onDismiss: (() -> Void)?

    private let sheet = SKNode()
    private let mapContent = SKNode()
    private let positionMarker = SKNode()
    private let markerPulse = SKShapeNode(ellipseOf: CGSize(width: 38, height: 19))

    override init() {
        super.init()
        name = "map.overlay"
        isUserInteractionEnabled = false
        buildInterface()
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("AreaMapOverlay is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let horizontalFit = (visibleSize.width - 28) / Metrics.canvas.width
        let verticalFit = (visibleSize.height - 24) / Metrics.canvas.height
        setScale(min(1, horizontalFit, verticalFit))
    }

    func present(currentPosition: CGPoint) {
        updateCurrentPosition(currentPosition)
        removeAllActions()
        isHidden = false
        alpha = 0
        sheet.setScale(0.985)
        sheet.run(.scale(to: 1, duration: 0.20))
        run(.fadeIn(withDuration: 0.17))

        markerPulse.removeAllActions()
        markerPulse.setScale(0.92)
        markerPulse.alpha = 0.36
        markerPulse.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.12, duration: 1.15),
                .fadeAlpha(to: 0.10, duration: 1.15)
            ]),
            .run { [weak markerPulse] in
                markerPulse?.setScale(0.92)
                markerPulse?.alpha = 0.36
            }
        ])))
    }

    func hideAnimated() {
        removeAllActions()
        markerPulse.removeAllActions()
        run(.sequence([
            .fadeOut(withDuration: 0.13),
            .run { [weak self] in self?.isHidden = true }
        ]))
    }

    func updateCurrentPosition(_ worldPosition: CGPoint) {
        positionMarker.position = mapPosition(forWorldPoint: worldPosition)
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        if targetName(at: point) == "map.close" {
            onDismiss?()
        }
        return true
    }

    func isInteractive(at point: CGPoint) -> Bool {
        targetName(at: point) == "map.close"
    }

    private func buildInterface() {
        let veil = SKShapeNode(rectOf: CGSize(width: 3_400, height: 1_900))
        veil.fillColor = SKColor(white: 0.002, alpha: 0.89)
        veil.strokeColor = .clear
        veil.zPosition = -30
        addChild(veil)

        let shadow = SKShapeNode(rectOf: Metrics.canvas, cornerRadius: 16)
        shadow.fillColor = SKColor(white: 0, alpha: 0.72)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 11, y: -14)
        shadow.zPosition = -12
        sheet.addChild(shadow)

        let backing = SKShapeNode(rectOf: Metrics.canvas, cornerRadius: 14)
        backing.fillColor = Palette.ink
        backing.strokeColor = Palette.steel
        backing.lineWidth = 2
        backing.zPosition = -11
        sheet.addChild(backing)

        if let texture = GameArt.texture(named: "inventory_outer_frame_overlay_v01") {
            texture.filteringMode = .linear
            let frame = SKSpriteNode(texture: texture, size: Metrics.canvas)
            frame.name = "map.outer-frame"
            frame.zPosition = -10
            sheet.addChild(frame)
        }

        buildHeader()
        buildMapWell()
        buildLegend()
        buildCloseButton()
        addChild(sheet)
    }

    private func buildHeader() {
        let band = SKShapeNode(
            rectOf: CGSize(width: Metrics.mapSize.width - 36, height: 72),
            cornerRadius: 3
        )
        band.fillColor = SKColor(white: 0.004, alpha: 0.80)
        band.strokeColor = Palette.steel
        band.lineWidth = 1.5
        band.position = CGPoint(x: 0, y: 300)
        band.zPosition = 30
        sheet.addChild(band)

        let title = Self.label(size: 29, color: Palette.paper, font: "Palatino-Bold")
        title.text = "AREA MAP"
        title.position = CGPoint(x: 0, y: 307)
        title.zPosition = 31
        sheet.addChild(title)

        let location = Self.label(size: 13, color: Palette.amber, font: "AvenirNext-DemiBold")
        location.text = "ELIAS VALE'S OFFICE"
        location.position = CGPoint(x: 0, y: 281)
        location.zPosition = 31
        sheet.addChild(location)
    }

    private func buildMapWell() {
        let wellSize = CGSize(width: Metrics.mapSize.width + 22, height: Metrics.mapSize.height + 22)
        let well = SKShapeNode(rectOf: wellSize, cornerRadius: 5)
        well.fillColor = Palette.panel
        well.strokeColor = Palette.steel
        well.lineWidth = 2
        well.position = CGPoint(x: 0, y: -12)
        sheet.addChild(well)

        let inner = SKShapeNode(rectOf: Metrics.mapSize, cornerRadius: 2)
        inner.fillColor = .black
        inner.strokeColor = SKColor(white: 0.06, alpha: 1)
        inner.lineWidth = 2
        inner.position = CGPoint(x: 0, y: -12)
        sheet.addChild(inner)

        mapContent.position = CGPoint(x: 0, y: -12)
        mapContent.zPosition = 2
        sheet.addChild(mapContent)

        if let texture = GameArt.texture(named: "map_detective_office_v02") {
            texture.filteringMode = .linear
            let map = SKSpriteNode(texture: texture, size: Metrics.mapSize)
            map.name = "map.office-art"
            mapContent.addChild(map)
        } else {
            let fallback = SKShapeNode(rectOf: Metrics.mapSize)
            fallback.fillColor = SKColor(red: 0.07, green: 0.055, blue: 0.042, alpha: 1)
            fallback.strokeColor = .clear
            mapContent.addChild(fallback)
        }

        addPointOfInterest("WINDOW", authoredPoint: CGPoint(x: 640, y: 1_380), color: Palette.rain)
        addPointOfInterest("DESK", authoredPoint: CGPoint(x: 1_435, y: 760), color: Palette.amber)
        addPointOfInterest("EXIT", authoredPoint: CGPoint(x: 2_450, y: 875), color: Palette.oxblood)
        buildCurrentPositionMarker()
    }

    private func buildCurrentPositionMarker() {
        markerPulse.fillColor = .clear
        markerPulse.strokeColor = Palette.party
        markerPulse.lineWidth = 1.5
        positionMarker.addChild(markerPulse)

        // Infinity-era area maps mark party ground positions with thin 2:1
        // ellipses. The dark under-stroke keeps that language readable against
        // both the amber desk pool and the rain-blue floor reflection.
        let underStroke = SKShapeNode(ellipseOf: CGSize(width: 30, height: 15))
        underStroke.fillColor = .clear
        underStroke.strokeColor = SKColor(white: 0.005, alpha: 0.92)
        underStroke.lineWidth = 4
        positionMarker.addChild(underStroke)

        let groundRing = SKShapeNode(ellipseOf: CGSize(width: 30, height: 15))
        groundRing.fillColor = .clear
        groundRing.strokeColor = Palette.party
        groundRing.lineWidth = 2
        positionMarker.addChild(groundRing)

        positionMarker.zPosition = 20
        mapContent.addChild(positionMarker)
    }

    private func addPointOfInterest(_ text: String, authoredPoint: CGPoint, color: SKColor) {
        let root = SKNode()
        root.position = mapPosition(forWorldPoint: OfficeInteriorScale.mapPoint(authoredPoint))
        root.zPosition = 12

        let diamondPath = CGMutablePath()
        diamondPath.move(to: CGPoint(x: 0, y: 7))
        diamondPath.addLine(to: CGPoint(x: 7, y: 0))
        diamondPath.addLine(to: CGPoint(x: 0, y: -7))
        diamondPath.addLine(to: CGPoint(x: -7, y: 0))
        diamondPath.closeSubpath()
        let diamond = SKShapeNode(path: diamondPath)
        diamond.fillColor = color
        diamond.strokeColor = Palette.paper.withAlphaComponent(0.82)
        diamond.lineWidth = 1.5
        root.addChild(diamond)

        let plate = SKShapeNode(rectOf: CGSize(width: 70, height: 21), cornerRadius: 2)
        plate.fillColor = SKColor(white: 0.005, alpha: 0.76)
        plate.strokeColor = color.withAlphaComponent(0.58)
        plate.lineWidth = 1
        plate.position = CGPoint(x: 0, y: -20)
        root.addChild(plate)

        let label = Self.label(size: 10, color: Palette.paper, font: "AvenirNext-DemiBold")
        label.text = text
        label.verticalAlignmentMode = .center
        label.position.y = 1
        plate.addChild(label)
        mapContent.addChild(root)
    }

    private func buildLegend() {
        let band = SKShapeNode(
            rectOf: CGSize(width: Metrics.mapSize.width - 36, height: 42),
            cornerRadius: 3
        )
        band.fillColor = SKColor(white: 0.004, alpha: 0.76)
        band.strokeColor = Palette.steel.withAlphaComponent(0.62)
        band.lineWidth = 1
        band.position = CGPoint(x: 0, y: -300)
        band.zPosition = 30
        sheet.addChild(band)

        let explored = Self.label(size: 13, color: Palette.quiet, font: "AvenirNext-DemiBold")
        explored.text = "EXPLORED AREA"
        explored.horizontalAlignmentMode = .left
        explored.position = CGPoint(x: -650, y: -305)
        explored.zPosition = 31
        sheet.addChild(explored)

        let currentDot = SKShapeNode(ellipseOf: CGSize(width: 18, height: 9))
        currentDot.fillColor = .clear
        currentDot.strokeColor = Palette.party
        currentDot.lineWidth = 1.5
        currentDot.position = CGPoint(x: -510, y: -300)
        currentDot.zPosition = 31
        sheet.addChild(currentDot)

        let current = Self.label(size: 13, color: Palette.quiet, font: "AvenirNext-DemiBold")
        current.text = "CURRENT POSITION"
        current.horizontalAlignmentMode = .left
        current.position = CGPoint(x: -495, y: -305)
        current.zPosition = 31
        sheet.addChild(current)
    }

    private func buildCloseButton() {
        let button = SKShapeNode(rectOf: CGSize(width: 126, height: 54), cornerRadius: 3)
        button.name = "map.close"
        button.fillColor = Palette.raised
        button.strokeColor = Palette.steel
        button.lineWidth = 2
        button.position = CGPoint(x: 620, y: 300)
        button.zPosition = 32
        sheet.addChild(button)

        let label = Self.label(size: 15, color: Palette.paper, font: "AvenirNext-DemiBold")
        label.text = "CLOSE  ×"
        label.name = "map.close"
        label.verticalAlignmentMode = .center
        label.position.y = 1
        button.addChild(label)
    }

    private func mapPosition(forWorldPoint worldPoint: CGPoint) -> CGPoint {
        let authored = CGPoint(
            x: OfficeInteriorScale.layoutFocus.x
                + (worldPoint.x - OfficeInteriorScale.layoutFocus.x) / OfficeInteriorScale.environment,
            y: OfficeInteriorScale.layoutFocus.y
                + (worldPoint.y - OfficeInteriorScale.layoutFocus.y) / OfficeInteriorScale.environment
        )
        let normalizedX = (authored.x - OfficeInteriorScale.sourceArtOrigin.x)
            / OfficeInteriorScale.sourceArtSize.width
        let normalizedY = (authored.y - OfficeInteriorScale.sourceArtOrigin.y)
            / OfficeInteriorScale.sourceArtSize.height
        let x = min(max(normalizedX, 0.035), 0.965)
        let y = min(max(normalizedY, 0.055), 0.945)
        return CGPoint(
            x: (x - 0.5) * Metrics.mapSize.width,
            y: (y - 0.5) * Metrics.mapSize.height
        )
    }

    private func targetName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            var candidate: SKNode? = node
            while let current = candidate, current !== self {
                if let name = current.name, name.hasPrefix("map.") {
                    return name
                }
                candidate = current.parent
            }
        }
        return nil
    }

    private static func label(size: CGFloat, color: SKColor, font: String) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .baseline
        return label
    }
}

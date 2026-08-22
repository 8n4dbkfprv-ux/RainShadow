import SpriteKit

/// RainShadow's interpretation of the classic Mac OS 9 close box: a compact,
/// square, bevelled control with no modern X glyph. The visible box remains
/// period-sized while the transparent hit area stays comfortable for touch.
@MainActor
final class ClassicMacCloseButtonNode: SKNode {
    private enum Metrics {
        static let hitExtent: CGFloat = 100
        static let outerExtent: CGFloat = 34
        static let innerExtent: CGFloat = 18
    }

    init(
        targetName: String,
        fill: SKColor,
        stroke: SKColor,
        highlight: SKColor,
        accent: SKColor,
        artworkName: String = "ui_close_box_macos9_noir_v04",
        artworkSize: CGSize = CGSize(width: 44, height: 44)
    ) {
        _ = (fill, stroke, highlight, accent)
        super.init()
        name = targetName

        let hitArea = SKShapeNode(
            rectOf: CGSize(width: Metrics.hitExtent, height: Metrics.hitExtent)
        )
        hitArea.fillColor = SKColor(white: 1, alpha: 0.001)
        hitArea.strokeColor = .clear
        addChild(hitArea)

        let texture = GameArt.texture(named: artworkName)
            ?? (artworkName == "ui_close_box_macos9_noir_v04"
                ? GameArt.texture(named: "ui_close_box_noir_v03")
                    ?? GameArt.texture(named: "ui_close_box_noir_v02")
                : nil)
        if let texture {
            texture.filteringMode = .linear
            let artwork = SKSpriteNode(texture: texture, size: artworkSize)
            artwork.zPosition = 1
            addChild(artwork)
            return
        }

        assertionFailure("Missing \(artworkName).png")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ClassicMacCloseButtonNode is created programmatically")
    }
}

/// Full-screen local-area map. The generated texture owns the painted location;
/// labels, markers, and input remain deterministic SpriteKit UI.
@MainActor
final class AreaMapOverlay: SKNode {
    struct PointOfInterest {
        let label: String
        let worldPoint: CGPoint
        let color: SKColor
    }

    struct Configuration {
        let textureName: String
        let locationName: String
        let worldBounds: CGRect
        /// Painted room inside the map plate, in SpriteKit UV (origin bottom-left).
        /// World points map into this rect so black void margins do not skew markers.
        let mapContentUV: CGRect
        let pointsOfInterest: [PointOfInterest]
        /// Whether the map is fogged at all. What it shows is the area's own
        /// explored bitmap, pushed in by the scene — the map does not compute
        /// exploration, and used to, from a radius around the player.
        let showsExplorationFog: Bool

        init(
            textureName: String,
            locationName: String,
            worldBounds: CGRect,
            mapContentUV: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1),
            pointsOfInterest: [PointOfInterest],
            showsExplorationFog: Bool = false
        ) {
            self.textureName = textureName
            self.locationName = locationName
            self.worldBounds = worldBounds
            self.mapContentUV = mapContentUV
            self.pointsOfInterest = pointsOfInterest
            self.showsExplorationFog = showsExplorationFog
        }
    }

    private enum Metrics {
        static let canvas = CGSize(width: 1_920, height: 1_080)
        /// Preserve the layout-locked plate's 1847:1040 aspect so the cramped
        /// suite footprint is not stretched.
        static let mapSize = CGSize(width: 1_500, height: 845)
        /// Shared vertical anchor for the map well, top strip, and legend.
        static let mapWellCenterY: CGFloat = -12
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
        static let party = SKColor(red: 0.79, green: 0.55, blue: 0.26, alpha: 1)
    }

    var onDismiss: (() -> Void)?
    /// Fired when the player activates the BG Classic WORLD MAP control.
    var onRequestWorldMap: (() -> Void)?

    private let configuration: Configuration
    private let sheet = SKNode()
    private let mapContent = SKNode()
    private let positionMarker = SKNode()
    private let markerPulse = SKShapeNode(ellipseOf: CGSize(width: 38, height: 19))
    private var explorationFog: LocalMapFogNode?

    override init() {
        configuration = Self.detectiveOffice
        super.init()
        finishInitialization()
    }

    init(configuration: Configuration) {
        self.configuration = configuration
        super.init()
        finishInitialization()
    }

    private func finishInitialization() {
        name = "map.overlay"
        isUserInteractionEnabled = false
        buildInterface()
        isHidden = true
    }

    static let detectiveOffice = Configuration(
        textureName: "map_detective_office_v08",
        locationName: "HARLAN VOSS'S OFFICE",
        // V11 registered opaque room extent in authored y-up plate space.
        worldBounds: OfficeInteriorScale.paintedRoomBounds,
        // Measured non-black V11 map content (stable runtime texture alias).
        mapContentUV: CGRect(x: 0.2063, y: 0.0558, width: 0.5679, height: 0.8990),
        pointsOfInterest: [
            PointOfInterest(
                label: "WINDOW",
                worldPoint: OfficeInteriorScale.mapPoint(
                    OfficeNavigationLayout.Architecture.windowAnchor
                ),
                color: Palette.rain
            ),
            PointOfInterest(
                label: "DESK",
                worldPoint: OfficeInteriorScale.mapPoint(
                    OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
                ),
                color: Palette.amber
            ),
            PointOfInterest(
                label: "WAITING",
                worldPoint: OfficeInteriorScale.mapPoint(
                    OfficeNavigationLayout.AuthoredPlacement.waitingTable
                ),
                color: Palette.quiet
            ),
            PointOfInterest(
                label: "EXIT",
                // Leaf anchor matches the painted NE-wall door, not the
                // floor-threshold plan point (which sat short of the aperture).
                worldPoint: OfficeInteriorScale.mapPoint(
                    OfficeNavigationLayout.Architecture.entranceLeafAnchor
                ),
                color: Palette.oxblood
            )
        ]
    )

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

    /// Show the area's explored bitmap. The same bitmap the world view draws,
    /// at map size — which is what BG's automap is.
    func updateExploredFog(_ texture: SKTexture?) {
        explorationFog?.texture = texture
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        switch targetName(at: point) {
        case "map.close":
            onDismiss?()
        case "map.world":
            onRequestWorldMap?()
        default:
            break
        }
        return true
    }

    func isInteractive(at point: CGPoint) -> Bool {
        let name = targetName(at: point)
        return name == "map.close" || name == "map.world"
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

        if let texture = GameArt.texture(named: "inventory_outer_frame_v06")
            ?? GameArt.texture(named: "inventory_outer_frame_v05") {
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
        // Baldur's Gate Classic area-map chrome: one thin framed strip over the
        // map well — title left, stacked options center, World Map right.
        let stripWidth = Metrics.mapSize.width - 48
        let stripHeight: CGFloat = 78
        let mapTopY = Metrics.mapWellCenterY + Metrics.mapSize.height / 2
        let stripY = mapTopY - stripHeight / 2 - 12

        let panel = SKShapeNode(
            rectOf: CGSize(width: stripWidth, height: stripHeight),
            cornerRadius: 0
        )
        panel.fillColor = SKColor(white: 0.015, alpha: 0.94)
        panel.strokeColor = SKColor(red: 0.70, green: 0.72, blue: 0.73, alpha: 0.82)
        panel.lineWidth = 1.5
        panel.name = "map.top-bar"
        panel.position = CGPoint(x: 0, y: stripY)
        panel.zPosition = 30
        sheet.addChild(panel)

        let inset = SKShapeNode(
            rectOf: CGSize(width: stripWidth - 5, height: stripHeight - 5),
            cornerRadius: 0
        )
        inset.fillColor = .clear
        inset.strokeColor = SKColor(white: 0.42, alpha: 0.28)
        inset.lineWidth = 1
        inset.position = CGPoint(x: 0, y: stripY)
        inset.zPosition = 30.5
        sheet.addChild(inset)

        let leftX = -stripWidth / 2 + 22
        let titleBlockY = stripY + 6
        let title = Self.label(size: 24, color: Palette.paper, font: UITheme.Font.overlayTitle)
        title.text = "Area Map"
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: leftX, y: titleBlockY)
        title.zPosition = 31
        sheet.addChild(title)

        let location = Self.label(size: 11, color: Palette.amber, font: UITheme.Font.overlayBodyBold)
        location.text = configuration.locationName
        location.horizontalAlignmentMode = .left
        location.verticalAlignmentMode = .center
        location.position = CGPoint(x: leftX, y: stripY - 16)
        location.zPosition = 31
        sheet.addChild(location)

        // Center column: stacked toggles (BG Classic hierarchy).
        let optionX: CGFloat = -90
        addMapOptionRow(
            title: "Area Map Background",
            checked: false,
            position: CGPoint(x: optionX, y: stripY + 14)
        )
        addMapOptionRow(
            title: "Map Notes",
            checked: true,
            position: CGPoint(x: optionX, y: stripY - 12)
        )

        let buttonSize = CGSize(width: 158, height: 40)
        let buttonX = stripWidth / 2 - 22 - buttonSize.width / 2
        let worldPlate = SKShapeNode(rectOf: buttonSize, cornerRadius: 1)
        worldPlate.name = "map.world"
        worldPlate.fillColor = SKColor(red: 0.09, green: 0.095, blue: 0.10, alpha: 0.98)
        worldPlate.strokeColor = SKColor(red: 0.62, green: 0.64, blue: 0.65, alpha: 0.92)
        worldPlate.lineWidth = 1.25
        worldPlate.position = CGPoint(x: buttonX, y: stripY)
        worldPlate.zPosition = 31
        sheet.addChild(worldPlate)

        let worldInset = SKShapeNode(
            rectOf: CGSize(width: buttonSize.width - 5, height: buttonSize.height - 5),
            cornerRadius: 0
        )
        worldInset.fillColor = .clear
        worldInset.strokeColor = SKColor(white: 0.35, alpha: 0.45)
        worldInset.lineWidth = 1
        worldInset.position = CGPoint(x: buttonX, y: stripY)
        worldInset.zPosition = 31.5
        sheet.addChild(worldInset)

        let worldLabel = Self.label(size: 14, color: Palette.paper, font: UITheme.Font.overlayCondensed)
        worldLabel.text = "WORLD MAP"
        worldLabel.verticalAlignmentMode = .center
        worldLabel.position = CGPoint(x: buttonX, y: stripY)
        worldLabel.zPosition = 32
        sheet.addChild(worldLabel)

        // Transparent hit plate above chrome so the whole button is clickable.
        let worldHit = SKShapeNode(rectOf: buttonSize, cornerRadius: 1)
        worldHit.name = "map.world"
        worldHit.fillColor = SKColor(white: 1, alpha: 0.001)
        worldHit.strokeColor = .clear
        worldHit.position = CGPoint(x: buttonX, y: stripY)
        worldHit.zPosition = 33
        sheet.addChild(worldHit)
    }

    private func addMapOptionRow(title: String, checked: Bool, position: CGPoint) {
        let box = SKShapeNode(rectOf: CGSize(width: 13, height: 13), cornerRadius: 1)
        box.fillColor = .clear
        box.strokeColor = checked ? Palette.paper : Palette.quiet
        box.lineWidth = 1.4
        box.position = position
        box.zPosition = 31
        sheet.addChild(box)

        if checked {
            let mark = Self.label(size: 13, color: UITheme.Color.oxbloodHot, font: UITheme.Font.overlayBodyBold)
            mark.text = "✓"
            mark.verticalAlignmentMode = .center
            mark.position = position
            mark.zPosition = 32
            sheet.addChild(mark)
        }

        let caption = Self.label(
            size: 13,
            color: checked ? Palette.paper : Palette.quiet,
            font: UITheme.Font.overlayBody
        )
        caption.text = title
        caption.horizontalAlignmentMode = .left
        caption.verticalAlignmentMode = .center
        caption.position = CGPoint(x: position.x + 14, y: position.y)
        caption.zPosition = 31
        sheet.addChild(caption)
    }

    private func buildMapWell() {
        let wellY = Metrics.mapWellCenterY
        let wellSize = CGSize(width: Metrics.mapSize.width + 22, height: Metrics.mapSize.height + 22)
        let well = SKShapeNode(rectOf: wellSize, cornerRadius: 5)
        well.fillColor = Palette.panel
        well.strokeColor = Palette.steel
        well.lineWidth = 2
        well.position = CGPoint(x: 0, y: wellY)
        sheet.addChild(well)

        let inner = SKShapeNode(rectOf: Metrics.mapSize, cornerRadius: 2)
        inner.fillColor = .black
        inner.strokeColor = SKColor(white: 0.06, alpha: 1)
        inner.lineWidth = 2
        inner.position = CGPoint(x: 0, y: wellY)
        sheet.addChild(inner)

        mapContent.position = CGPoint(x: 0, y: wellY)
        mapContent.zPosition = 2
        sheet.addChild(mapContent)

        if let texture = GameArt.texture(named: configuration.textureName) {
            texture.filteringMode = .linear
            let map = SKSpriteNode(texture: texture, size: Metrics.mapSize)
            map.name = "map.area-art"
            mapContent.addChild(map)
        } else {
            let fallback = SKShapeNode(rectOf: Metrics.mapSize)
            fallback.fillColor = SKColor(red: 0.07, green: 0.055, blue: 0.042, alpha: 1)
            fallback.strokeColor = .clear
            mapContent.addChild(fallback)
        }

        for point in configuration.pointsOfInterest {
            addPointOfInterest(point)
        }
        if configuration.showsExplorationFog {
            let fog = LocalMapFogNode(size: Metrics.mapSize, contentUV: configuration.mapContentUV)
            fog.zPosition = 10
            mapContent.addChild(fog)
            explorationFog = fog
        }
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

    private func addPointOfInterest(_ pointOfInterest: PointOfInterest) {
        let root = SKNode()
        root.position = mapPosition(forWorldPoint: pointOfInterest.worldPoint)
        root.zPosition = 12

        let diamondPath = CGMutablePath()
        diamondPath.move(to: CGPoint(x: 0, y: 7))
        diamondPath.addLine(to: CGPoint(x: 7, y: 0))
        diamondPath.addLine(to: CGPoint(x: 0, y: -7))
        diamondPath.addLine(to: CGPoint(x: -7, y: 0))
        diamondPath.closeSubpath()
        let diamond = SKShapeNode(path: diamondPath)
        diamond.fillColor = pointOfInterest.color
        diamond.strokeColor = Palette.paper.withAlphaComponent(0.82)
        diamond.lineWidth = 1.5
        root.addChild(diamond)

        let plate = SKShapeNode(rectOf: CGSize(width: 70, height: 21), cornerRadius: 2)
        plate.fillColor = SKColor(white: 0.005, alpha: 0.76)
        plate.strokeColor = pointOfInterest.color.withAlphaComponent(0.58)
        plate.lineWidth = 1
        plate.position = CGPoint(x: 0, y: -20)
        root.addChild(plate)

        let label = Self.label(size: 10, color: Palette.paper, font: "AvenirNext-DemiBold")
        label.text = pointOfInterest.label
        label.verticalAlignmentMode = .center
        label.position.y = 1
        plate.addChild(label)
        mapContent.addChild(root)
    }

    private func buildLegend() {
        let bandWidth = Metrics.mapSize.width - 48
        let bandHeight: CGFloat = 40
        let mapBottomY = Metrics.mapWellCenterY - Metrics.mapSize.height / 2
        let bandY = mapBottomY + bandHeight / 2 + 14

        let band = SKShapeNode(
            rectOf: CGSize(width: bandWidth, height: bandHeight),
            cornerRadius: 0
        )
        band.fillColor = SKColor(white: 0.012, alpha: 0.88)
        band.strokeColor = SKColor(red: 0.55, green: 0.57, blue: 0.58, alpha: 0.55)
        band.lineWidth = 1
        band.position = CGPoint(x: 0, y: bandY)
        band.zPosition = 30
        sheet.addChild(band)

        let leftX = -bandWidth / 2 + 24
        let explored = Self.label(size: 12, color: Palette.quiet, font: "AvenirNext-DemiBold")
        explored.text = "EXPLORED AREA"
        explored.horizontalAlignmentMode = .left
        explored.verticalAlignmentMode = .center
        explored.position = CGPoint(x: leftX, y: bandY)
        explored.zPosition = 31
        sheet.addChild(explored)

        let currentDot = SKShapeNode(ellipseOf: CGSize(width: 18, height: 9))
        currentDot.fillColor = .clear
        currentDot.strokeColor = Palette.party
        currentDot.lineWidth = 1.5
        currentDot.position = CGPoint(x: leftX + 168, y: bandY)
        currentDot.zPosition = 31
        sheet.addChild(currentDot)

        let current = Self.label(size: 12, color: Palette.quiet, font: "AvenirNext-DemiBold")
        current.text = "CURRENT POSITION"
        current.horizontalAlignmentMode = .left
        current.verticalAlignmentMode = .center
        current.position = CGPoint(x: leftX + 186, y: bandY)
        current.zPosition = 31
        sheet.addChild(current)
    }

    private func buildCloseButton() {
        let button = ClassicMacCloseButtonNode(
            targetName: "map.close",
            fill: Palette.raised,
            stroke: Palette.steel,
            highlight: Palette.paper,
            accent: Palette.oxblood
        )
        // Sit just outside the top strip's left edge, aligned to its midline.
        let stripWidth = Metrics.mapSize.width - 48
        let stripHeight: CGFloat = 78
        let mapTopY = Metrics.mapWellCenterY + Metrics.mapSize.height / 2
        let stripY = mapTopY - stripHeight / 2 - 12
        button.position = CGPoint(x: -stripWidth / 2 - 36, y: stripY)
        button.zPosition = 32
        sheet.addChild(button)
    }

    private func mapPosition(forWorldPoint worldPoint: CGPoint) -> CGPoint {
        let bounds = configuration.worldBounds
        let content = configuration.mapContentUV
        let normalizedX = (worldPoint.x - bounds.minX) / max(bounds.width, 1)
        let normalizedY = (worldPoint.y - bounds.minY) / max(bounds.height, 1)
        let clampedX = min(max(normalizedX, 0), 1)
        let clampedY = min(max(normalizedY, 0), 1)
        // Authored y-up: higher values are toward the rear wall / top of the
        // plate PNG, which is the top of the SpriteKit map sprite.
        let u = content.minX + clampedX * content.width
        let v = content.minY + clampedY * content.height
        return CGPoint(
            x: (u - 0.5) * Metrics.mapSize.width,
            y: (v - 0.5) * Metrics.mapSize.height
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

/// The area map's fog: the same explored bitmap the world view draws, at map
/// size.
///
/// It used to compute its own exploration — wobbled circles of a fixed radius
/// around every point the player had stood in — which meant the map and the
/// world could and did disagree about what had been seen. Now it displays what
/// it is handed and decides nothing, which is the arrangement BG's automap has:
/// one explored bitmask per area, drawn twice.
@MainActor
private final class LocalMapFogNode: SKSpriteNode {
    init(size: CGSize, contentUV: CGRect) {
        // Sized to the painted room inside the plate rather than the whole
        // plate, so the bitmap lands on the ground it describes and not on the
        // black margin baked around it.
        super.init(
            texture: nil,
            color: .black,
            size: CGSize(
                width: size.width * contentUV.width,
                height: size.height * contentUV.height
            )
        )
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        position = CGPoint(
            x: (contentUV.midX - 0.5) * size.width,
            y: (contentUV.midY - 0.5) * size.height
        )
        // Unexplored streets stay black without going jet, which is the value
        // the painted version used and the one the plate was drawn against.
        alpha = 0.94
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("LocalMapFogNode is created programmatically")
    }
}

import SpriteKit

/// Baldur's Gate Classic–style city World Map for Harborpoint.
/// Travel mode (edge exit) lets the player pick a revealed district; view mode
/// (Area Map → WORLD MAP) is look-only.
@MainActor
final class WorldMapOverlay: SKNode {
    enum Mode: Equatable {
        case view
        case travel
    }

    private enum Metrics {
        static let canvas = CGSize(width: 1_920, height: 1_080)
        /// Preserves the 3:2 plate so the compass rose and cartouche stay round.
        static let mapSize = CGSize(width: 1_320, height: 880)
        static let mapWellCenterY: CGFloat = -12
        static let textureName = "map_world_harborpoint_v04"
    }

    private enum Palette {
        static let ink = SKColor(red: 0.016, green: 0.019, blue: 0.024, alpha: 0.97)
        static let panel = SKColor(red: 0.030, green: 0.034, blue: 0.039, alpha: 0.96)
        static let raised = SKColor(red: 0.064, green: 0.069, blue: 0.075, alpha: 0.98)
        static let steel = SKColor(red: 0.46, green: 0.49, blue: 0.50, alpha: 0.62)
        static let paper = SKColor(red: 0.86, green: 0.78, blue: 0.58, alpha: 1)
        static let quiet = SKColor(red: 0.53, green: 0.55, blue: 0.55, alpha: 1)
        static let amber = SKColor(red: 0.79, green: 0.55, blue: 0.26, alpha: 1)
        static let oxblood = SKColor(red: 0.50, green: 0.13, blue: 0.12, alpha: 1)
        static let travel = SKColor(red: 0.32, green: 0.58, blue: 0.38, alpha: 1)
        static let party = SKColor(red: 0.62, green: 0.16, blue: 0.14, alpha: 1)
        /// Unsurveyed wash reads as aged blank paper, not a black hole.
        static let fog = SKColor(red: 0.55, green: 0.44, blue: 0.28, alpha: 0.80)
        static let plate = SKColor(red: 0.90, green: 0.80, blue: 0.55, alpha: 0.94)
        static let plateInk = SKColor(red: 0.18, green: 0.12, blue: 0.07, alpha: 1)
        static let plateEdge = SKColor(red: 0.32, green: 0.24, blue: 0.14, alpha: 0.90)
    }

    var onDismiss: (() -> Void)?
    var onTravel: ((CityDistrictID, String) -> Void)?
    var onStatusLine: ((String) -> Void)?

    private let sheet = SKNode()
    private let mapContent = SKNode()
    private var mode: Mode = .view
    private var currentDistrict: CityDistrictID = .sableRow
    private var visited: Set<CityDistrictID> = []
    private var exitEdge: CityMapEdge?
    private var cellNodes: [String: SKNode] = [:]
    private var hoveredDistrict: CityDistrictID?
    private let partyMarker = SKNode()

    override init() {
        super.init()
        name = "worldmap.overlay"
        isUserInteractionEnabled = false
        AreaLoadTrace.measure("init.WorldMapOverlay") { buildInterface() }
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("WorldMapOverlay is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let horizontalFit = (visibleSize.width - 28) / Metrics.canvas.width
        let verticalFit = (visibleSize.height - 24) / Metrics.canvas.height
        setScale(min(1, horizontalFit, verticalFit))
    }

    func present(
        mode: Mode,
        currentDistrict: CityDistrictID,
        visited: Set<CityDistrictID>,
        exitEdge: CityMapEdge? = nil
    ) {
        self.mode = mode
        self.currentDistrict = currentDistrict
        self.visited = visited
        self.exitEdge = exitEdge
        hoveredDistrict = nil
        refreshCells()
        placePartyMarker()

        removeAllActions()
        isHidden = false
        alpha = 0
        sheet.setScale(0.985)
        sheet.run(.scale(to: 1, duration: 0.20))
        run(.fadeIn(withDuration: 0.17))
    }

    func hideAnimated() {
        hoveredDistrict = nil
        removeAllActions()
        run(.sequence([
            .fadeOut(withDuration: 0.13),
            .run { [weak self] in self?.isHidden = true }
        ]))
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        if targetName(at: point) == "worldmap.close" {
            onDismiss?()
            return true
        }
        if let districtID = districtHit(at: point) {
            handleDistrictSelection(districtID)
            return true
        }
        if lockedWardHit(at: point) {
            onStatusLine?("That ward stays off the books for now.")
            return true
        }
        return true
    }

    func isInteractive(at point: CGPoint) -> Bool {
        if targetName(at: point) == "worldmap.close" { return true }
        if districtHit(at: point) != nil { return true }
        if lockedWardHit(at: point) { return true }
        return false
    }

    func handleHover(at point: CGPoint) {
        guard !isHidden else { return }
        let candidate = districtHit(at: point)
        let next = candidate.flatMap { districtID in
            CityWorldMap.isTravelable(districtID, visited: visited)
                ? districtID
                : nil
        }
        guard hoveredDistrict != next else { return }
        hoveredDistrict = next
        refreshMarkerHighlights()
    }

    // MARK: - Build

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
            frame.name = "worldmap.outer-frame"
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
        panel.position = CGPoint(x: 0, y: stripY)
        panel.zPosition = 30
        sheet.addChild(panel)

        let leftX = -stripWidth / 2 + 22
        let title = Self.label(size: 24, color: Palette.paper, font: UITheme.Font.overlayTitle)
        title.text = "World Map"
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: leftX, y: stripY + 6)
        title.zPosition = 31
        sheet.addChild(title)

        let location = Self.label(size: 11, color: Palette.amber, font: UITheme.Font.overlayBodyBold)
        location.text = "HARBORPOINT"
        location.horizontalAlignmentMode = .left
        location.verticalAlignmentMode = .center
        location.position = CGPoint(x: leftX, y: stripY - 16)
        location.zPosition = 31
        sheet.addChild(location)

        let note = Self.label(size: 13, color: Palette.quiet, font: UITheme.Font.overlayBody)
        note.text = "City wards  •  adjacent travel"
        note.horizontalAlignmentMode = .right
        note.verticalAlignmentMode = .center
        note.position = CGPoint(x: stripWidth / 2 - 22, y: stripY)
        note.zPosition = 31
        sheet.addChild(note)
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

        if let texture = GameArt.texture(named: Metrics.textureName) {
            texture.filteringMode = .linear
            let map = SKSpriteNode(texture: texture, size: Metrics.mapSize)
            map.name = "worldmap.art"
            mapContent.addChild(map)
        } else {
            let fallback = SKShapeNode(rectOf: Metrics.mapSize)
            fallback.fillColor = SKColor(red: 0.52, green: 0.46, blue: 0.35, alpha: 1)
            fallback.strokeColor = .clear
            mapContent.addChild(fallback)
        }

        buildCellOverlays()
        buildPartyMarker()
    }

    private func buildCellOverlays() {
        let cellWidth = Metrics.mapSize.width / CGFloat(CityWorldMap.gridColumns)
        let cellHeight = Metrics.mapSize.height / CGFloat(CityWorldMap.gridRows)

        for visualRow in 0..<CityWorldMap.gridRows {
            for col in 0..<CityWorldMap.gridColumns {
                let cell = CityWorldMap.cells[visualRow][col]
                let key = cellKey(cell)
                let root = SKNode()
                root.name = "worldmap.cell.\(key)"
                root.position = CGPoint(
                    x: -Metrics.mapSize.width / 2 + cellWidth * (CGFloat(col) + 0.5),
                    y: Metrics.mapSize.height / 2 - cellHeight * (CGFloat(visualRow) + 0.5)
                )
                if case .district(let id) = cell {
                    let offset = markerOffset(for: id)
                    root.position.x += offset.x
                    root.position.y += offset.y
                }
                root.zPosition = 8

                if case .district(let id) = cell {
                    let icon = SKSpriteNode(
                        texture: GameArt.texture(named: id.worldMapIconTextureName),
                        size: CGSize(width: 148, height: 148)
                    )
                    icon.name = "worldmap.cell.icon"
                    icon.position = CGPoint(x: 0, y: 25)
                    icon.zPosition = 1
                    root.addChild(icon)

                    let label = Self.label(size: 17, color: Palette.plateInk, font: UITheme.Font.overlayCondensed)
                    label.name = "worldmap.cell.label"
                    label.text = cell.shortLabel
                    label.verticalAlignmentMode = .center
                    label.position = CGPoint(x: 0, y: -57)
                    label.zPosition = 2
                    root.addChild(label)

                    let type = Self.label(size: 12, color: Palette.plateInk, font: UITheme.Font.overlayBodyBold)
                    type.name = "worldmap.cell.type"
                    type.text = id.worldMapShortType.uppercased()
                    type.verticalAlignmentMode = .center
                    type.position = CGPoint(x: 0, y: -77)
                    type.zPosition = 2
                    root.addChild(type)
                }

                // The reference uses compact location-sized targets, not visible
                // rectangular ward cells.
                let hit = SKShapeNode(rectOf: CGSize(width: 196, height: 206))
                hit.name = "worldmap.hit.\(key)"
                hit.fillColor = SKColor(white: 1, alpha: 0.001)
                hit.strokeColor = .clear
                hit.zPosition = 3
                root.addChild(hit)

                mapContent.addChild(root)
                cellNodes[key] = root
            }
        }
    }

    private func buildPartyMarker() {
        let underStroke = SKShapeNode(ellipseOf: CGSize(width: 34, height: 17))
        underStroke.fillColor = .clear
        underStroke.strokeColor = SKColor(white: 0.005, alpha: 0.92)
        underStroke.lineWidth = 4
        partyMarker.addChild(underStroke)

        let groundRing = SKShapeNode(ellipseOf: CGSize(width: 34, height: 17))
        groundRing.fillColor = .clear
        groundRing.strokeColor = Palette.party
        groundRing.lineWidth = 2.2
        partyMarker.addChild(groundRing)

        partyMarker.zPosition = 20
        mapContent.addChild(partyMarker)
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
        let currentDot = SKShapeNode(ellipseOf: CGSize(width: 18, height: 9))
        currentDot.fillColor = .clear
        currentDot.strokeColor = Palette.party
        currentDot.lineWidth = 1.5
        currentDot.position = CGPoint(x: leftX + 8, y: bandY)
        currentDot.zPosition = 31
        sheet.addChild(currentDot)

        let current = Self.label(size: 12, color: Palette.quiet, font: "AvenirNext-DemiBold")
        current.text = "CURRENT WARD"
        current.horizontalAlignmentMode = .left
        current.verticalAlignmentMode = .center
        current.position = CGPoint(x: leftX + 24, y: bandY)
        current.zPosition = 31
        sheet.addChild(current)

        let travelBox = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 2)
        travelBox.fillColor = .clear
        travelBox.strokeColor = Palette.travel
        travelBox.lineWidth = 2
        travelBox.position = CGPoint(x: leftX + 190, y: bandY)
        travelBox.zPosition = 31
        sheet.addChild(travelBox)

        let travel = Self.label(size: 12, color: Palette.quiet, font: "AvenirNext-DemiBold")
        travel.text = "TRAVELABLE"
        travel.horizontalAlignmentMode = .left
        travel.verticalAlignmentMode = .center
        travel.position = CGPoint(x: leftX + 204, y: bandY)
        travel.zPosition = 31
        sheet.addChild(travel)

        let fogBox = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 2)
        fogBox.fillColor = Palette.fog
        fogBox.strokeColor = Palette.quiet
        fogBox.lineWidth = 1
        fogBox.position = CGPoint(x: leftX + 340, y: bandY)
        fogBox.zPosition = 31
        sheet.addChild(fogBox)

        let unknown = Self.label(size: 12, color: Palette.quiet, font: "AvenirNext-DemiBold")
        unknown.text = "UNMAPPED"
        unknown.horizontalAlignmentMode = .left
        unknown.verticalAlignmentMode = .center
        unknown.position = CGPoint(x: leftX + 354, y: bandY)
        unknown.zPosition = 31
        sheet.addChild(unknown)
    }

    private func buildCloseButton() {
        let button = ClassicMacCloseButtonNode(
            targetName: "worldmap.close",
            fill: Palette.raised,
            stroke: Palette.steel,
            highlight: Palette.paper,
            accent: Palette.oxblood
        )
        let stripWidth = Metrics.mapSize.width - 48
        let stripHeight: CGFloat = 78
        let mapTopY = Metrics.mapWellCenterY + Metrics.mapSize.height / 2
        let stripY = mapTopY - stripHeight / 2 - 12
        button.position = CGPoint(x: -stripWidth / 2 - 36, y: stripY)
        button.zPosition = 32
        sheet.addChild(button)
    }

    // MARK: - State

    private func refreshCells() {
        for visualRow in 0..<CityWorldMap.gridRows {
            for col in 0..<CityWorldMap.gridColumns {
                let cell = CityWorldMap.cells[visualRow][col]
                let key = cellKey(cell)
                guard let root = cellNodes[key] else { continue }
                let label = root.childNode(withName: "worldmap.cell.label") as? SKLabelNode
                let type = root.childNode(withName: "worldmap.cell.type") as? SKLabelNode

                switch cell {
                case .district(let id):
                    let travelable = CityWorldMap.isTravelable(id, visited: visited)
                    let isCurrent = id == currentDistrict
                    let isVisited = visited.contains(id)
                    root.isHidden = !travelable
                    root.alpha = 1
                    label?.text = cell.shortLabel
                    label?.fontColor = isCurrent ? Palette.party : Palette.plateInk
                    type?.fontColor = isCurrent ? Palette.party : Palette.plateInk
                    label?.alpha = isVisited ? 1 : 0.78
                    type?.alpha = isVisited ? 1 : 0.78
                case .lockedWard:
                    root.isHidden = true
                }
            }
        }
        refreshMarkerHighlights()
    }

    private func refreshMarkerHighlights() {
        for id in CityDistrictID.allCases {
            let key = cellKey(.district(id))
            guard let icon = cellNodes[key]?.childNode(withName: "worldmap.cell.icon") as? SKSpriteNode else {
                continue
            }
            let highlighted = id == hoveredDistrict
            let textureName = highlighted
                ? id.worldMapIconHoverTextureName
                : id.worldMapIconTextureName
            icon.texture = GameArt.texture(named: textureName)
            // BG:EE Classic: painted stamps stay visible on the parchment;
            // hover swaps to the oxblood treatment and a slight scale-up.
            icon.isHidden = false
            icon.alpha = 1
            icon.setScale(highlighted ? 1.12 : 1)
            let color = highlighted || id == currentDistrict ? Palette.party : Palette.plateInk
            (cellNodes[key]?.childNode(withName: "worldmap.cell.label") as? SKLabelNode)?.fontColor = color
            (cellNodes[key]?.childNode(withName: "worldmap.cell.type") as? SKLabelNode)?.fontColor = color
        }
    }

    private func placePartyMarker() {
        let key = cellKey(.district(currentDistrict))
        guard let marker = cellNodes[key] else { return }
        partyMarker.position = CGPoint(x: marker.position.x, y: marker.position.y - 38)
    }

    private func markerOffset(for _: CityDistrictID) -> CGPoint {
        // V4 drops the baked HARBORPOINT cartouche; grid centres are enough.
        .zero
    }

    private func handleDistrictSelection(_ districtID: CityDistrictID) {
        guard mode == .travel else {
            onStatusLine?("Leave the ward at the street edge to travel.")
            return
        }
        if districtID == currentDistrict {
            onStatusLine?("Already standing in this ward.")
            return
        }
        guard CityWorldMap.isTravelable(districtID, visited: visited) else {
            onStatusLine?("That street is still blank on the map.")
            return
        }
        guard let arrivalKey = CityWorldMap.arrivalKey(from: currentDistrict, to: districtID) else {
            onStatusLine?("No clear road between these wards.")
            return
        }
        onTravel?(districtID, arrivalKey)
    }

    private func districtHit(at point: CGPoint) -> CityDistrictID? {
        guard let name = hitTargetName(at: point),
              name.hasPrefix("worldmap.hit.") else {
            return nil
        }
        let key = String(name.dropFirst("worldmap.hit.".count))
        if key.hasPrefix("district.") {
            let raw = String(key.dropFirst("district.".count))
            return CityDistrictID(rawValue: raw)
        }
        return nil
    }

    private func lockedWardHit(at point: CGPoint) -> Bool {
        guard let name = hitTargetName(at: point),
              name.hasPrefix("worldmap.hit.locked.") else {
            return false
        }
        return true
    }

    private func cellKey(_ cell: CityWorldMapCell) -> String {
        switch cell {
        case .district(let id):
            return "district.\(id.rawValue)"
        case .lockedWard(let key):
            return "locked.\(key)"
        }
    }

    private func targetName(at point: CGPoint) -> String? {
        if let hit = hitTargetName(at: point) { return hit }
        for node in nodes(at: point) {
            var candidate: SKNode? = node
            while let current = candidate, current !== self {
                if let name = current.name,
                   name.hasPrefix("worldmap.") {
                    return name
                }
                candidate = current.parent
            }
        }
        return nil
    }

    /// Prefer explicit hit plates so labels/borders still resolve to the ward cell.
    private func hitTargetName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            var candidate: SKNode? = node
            while let current = candidate, current !== self {
                if let name = current.name, name.hasPrefix("worldmap.hit.") {
                    return name
                }
                if let name = current.name, name == "worldmap.close" {
                    return name
                }
                // Cell root → look for its hit sibling/child.
                if let name = current.name, name.hasPrefix("worldmap.cell.") {
                    let key = String(name.dropFirst("worldmap.cell.".count))
                    return "worldmap.hit.\(key)"
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

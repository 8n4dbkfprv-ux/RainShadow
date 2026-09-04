import CoreGraphics

/// Infinity Engine highlightable kinds (ARE door / container / infopoint).
enum HighlightableKind: Equatable, Sendable {
    case door
    case container
    case infoPoint
    case travel
}

/// One authored outline polygon plus the state GemRB's `Outline*` functions read.
///
/// Doors carry two rings, as they do in the ARE (`0x002c/0x0030` open,
/// `0x0034/0x0032` closed). GemRB reassigns `outline` on every state change —
/// `Door::UpdateDoor` calls `doorTrigger.StatePolygon()`, which is
/// `open ? openTrigger : closedTrigger`. `polygon` resolves the same way here.
struct HighlightableObject: Equatable, Sendable {
    var id: String
    var kind: HighlightableKind
    /// Closed-state ring. Read `polygon`, not this, to draw or hit-test.
    var closedPolygon: [CGPoint]
    /// Open-state ring, where the art gives one. Doors only.
    var openPolygon: [CGPoint]?
    var isOpen: Bool
    var isLocked: Bool
    var isEmpty: Bool
    var isSecretFound: Bool
    var trapIsVisible: Bool
    /// Tab reveal skips containers whose bbox sits behind a closed door.
    var suppressedByClosedDoor: Bool

    /// GemRB `DoorTrigger::StatePolygon`.
    var polygon: [CGPoint] {
        isOpen ? (openPolygon ?? closedPolygon) : closedPolygon
    }

    init(
        id: String,
        kind: HighlightableKind,
        polygon: [CGPoint],
        openPolygon: [CGPoint]? = nil,
        isOpen: Bool = false,
        isLocked: Bool = false,
        isEmpty: Bool = false,
        isSecretFound: Bool = false,
        trapIsVisible: Bool = false,
        suppressedByClosedDoor: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.closedPolygon = polygon
        self.openPolygon = openPolygon
        self.isOpen = isOpen
        self.isLocked = isLocked
        self.isEmpty = isEmpty
        self.isSecretFound = isSecretFound
        self.trapIsVisible = trapIsVisible
        self.suppressedByClosedDoor = suppressedByClosedDoor
    }

    var boundingBox: CGRect { HighlightGeometry.boundingBox(of: polygon) }

    func contains(_ point: CGPoint) -> Bool {
        HighlightGeometry.contains(point, polygon: polygon)
    }

    /// GemRB `UpdateCursor`: door first, then infopoint; a container overrides
    /// an infopoint at the same location but never a visible door.
    static func hit(at point: CGPoint, among objects: [HighlightableObject]) -> HighlightableObject? {
        let hits = objects.filter { $0.contains(point) }
        if let door = hits.first(where: { $0.kind == .door }) {
            return door
        }
        let info = hits.first(where: { $0.kind == .infoPoint || $0.kind == .travel })
        if let container = hits.first(where: { $0.kind == .container }) {
            return container
        }
        return info
    }
}

/// One polygon currently drawn, with the IE outline colour.
struct ObjectHighlight: Equatable, Sendable {
    var id: String
    var color: HighlightColor
}

struct HighlightColor: Equatable, Sendable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Packed `0xRRGGBBAA` as in GemRB `colors.2da`.
    init(rgba: UInt32) {
        red = CGFloat((rgba >> 24) & 0xFF) / 255
        green = CGFloat((rgba >> 16) & 0xFF) / 255
        blue = CGFloat((rgba >> 8) & 0xFF) / 255
        alpha = CGFloat(rgba & 0xFF) / 255
    }
}

/// BG2 `colors.2da` highlight rows.
enum HighlightPalette {
    static let hoverDoor = HighlightColor(rgba: 0x00FF_FFFF)
    static let hoverContainer = HighlightColor(rgba: 0x00FF_FFFF)
    static let trap = HighlightColor(rgba: 0xFF00_00FF)
    static let hoverTargetable = HighlightColor(rgba: 0x00FF_00FF)
    static let hiddenDoor = HighlightColor(rgba: 0xFF00_FFFF)
    static let altDoor = HighlightColor(rgba: 0xFF00_FFFF)
    static let altContainer = HighlightColor(rgba: 0x00FF_FFFF)
    static let emptyContainer = HighlightColor(rgba: 0xD7D7_BEFF)
}

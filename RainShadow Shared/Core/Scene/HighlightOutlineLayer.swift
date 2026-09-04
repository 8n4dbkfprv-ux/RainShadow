import SpriteKit

/// Runtime IE outline draw. One `SKShapeNode` per authored polygon; visibility and
/// colour come from `HighlightResolver`. Drawn above the plate, under actors.
///
/// This is a transliteration of GemRB `Highlightable::DrawOutline`, which makes two
/// passes over the same polygon:
///
/// ```cpp
/// if (!highlightOutlineOnly) {
///     BlitFlags flag = BlitFlags::HALFTRANS | (pstStateFlags ? MOD : BLENDED);
///     VideoDriver->DrawPolygon(outline.get(), origin, outlineColor, true, flag);
/// }
/// if (highlightOutlineOnly || !pstStateFlags) {
///     VideoDriver->DrawPolygon(outline.get(), origin, outlineColor, false);
/// }
/// ```
///
/// A `HALFTRANS` wash across the whole silhouette, then a solid hairline edge. Only
/// IWD2 sets `GFFlags::HIGHLIGHT_OUTLINE_ONLY` and drops the wash; PST swaps the
/// wash to `MOD`. RainShadow is on the BG2 path: alpha-blended wash plus edge.
/// Neither pass is antialiased — the SDL driver rasterises scanline segments and a
/// one-pixel polyline.
@MainActor
final class HighlightOutlineLayer: SKNode {
    /// GemRB `BlitFlags::HALFTRANS`. The fill pass draws the outline colour at half
    /// its alpha; the edge pass draws it whole.
    static let halfTransparent: CGFloat = 0.5

    /// On-screen width of the edge pass, in points. IE strokes one device pixel at
    /// 1x; `lineWidth` is world units here, so it is rescaled with the camera.
    static let edgeScreenPoints: CGFloat = 1

    private struct StatePaths {
        var closed: CGPath?
        var open: CGPath?
    }

    private var nodes: [String: SKShapeNode] = [:]
    private var statePaths: [String: StatePaths] = [:]
    private var drawOrders: [String: CGFloat] = [:]
    private var cameraScale: CGFloat = 1

    override init() {
        super.init()
        name = "world.highlightOutlines"
        zPosition = SceneLayer.highlightOutlines.rawValue
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("HighlightOutlineLayer is created programmatically")
    }

    private static func path(_ polygon: [CGPoint]) -> CGPath? {
        guard polygon.count >= 3 else { return nil }
        let path = CGMutablePath()
        path.move(to: polygon[0])
        for point in polygon.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    func register(_ objects: [HighlightableObject]) {
        removeAllChildren()
        nodes.removeAll()
        statePaths.removeAll()
        for object in objects {
            guard let path = Self.path(object.polygon) else { continue }
            statePaths[object.id] = StatePaths(
                closed: Self.path(object.closedPolygon),
                open: object.openPolygon.flatMap(Self.path)
            )
            let node = SKShapeNode(path: path)
            node.name = object.id
            node.fillColor = .clear
            node.strokeColor = .clear
            // `SKShapeNode` fills a closed path even-odd, which is the same rule
            // `HighlightGeometry.contains` hit-tests with — wash and click agree.
            node.lineWidth = Self.edgeScreenPoints * cameraScale
            node.isAntialiased = false
            node.blendMode = .alpha
            node.isHidden = true
            // Scenes build their door leaves before they install highlightables,
            // so a lift requested earlier has to survive this rebuild.
            if let z = drawOrders[object.id] {
                node.zPosition = z - zPosition
            }
            nodes[object.id] = node
            addChild(node)
        }
    }

    func apply(_ highlights: [ObjectHighlight]) {
        let visible = Dictionary(uniqueKeysWithValues: highlights.map { ($0.id, $0.color) })
        for (id, node) in nodes {
            guard let color = visible[id] else {
                node.isHidden = true
                continue
            }
            node.fillColor = SKColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha * Self.halfTransparent
            )
            node.strokeColor = SKColor(
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            )
            node.isHidden = false
        }
    }

    /// GemRB `Door::UpdateDoor`, which reassigns `outline` from
    /// `DoorTrigger::StatePolygon` — the open ring while open, the closed one
    /// otherwise. Doors whose art gives no open ring keep the closed one.
    func setOpen(_ isOpen: Bool, for id: String) {
        guard let node = nodes[id], let paths = statePaths[id] else { return }
        guard let path = (isOpen ? paths.open : paths.closed) ?? paths.closed else { return }
        node.path = path
    }

    /// Keep the edge a hairline at every zoom step. `scale` is `playCameraScale`,
    /// world units per point, so the product is a constant on-screen width.
    func setCameraScale(_ scale: CGFloat) {
        guard scale > 0, scale != cameraScale else { return }
        cameraScale = scale
        let width = Self.edgeScreenPoints * scale
        for node in nodes.values {
            node.lineWidth = width
        }
    }

    /// Lift one outline out of the layer's own depth.
    ///
    /// The layer sits under `depthWorld`, matching GemRB, which draws
    /// `Map::DrawHighlightables` after the tilemap and before the actor queue. That
    /// is right for baked scenery — but a door leaf drawn as a live sprite would
    /// then cover the very outline that traces it. Child `zPosition` accumulates
    /// onto the layer's, so pass an absolute scene z and it is converted here.
    func setDrawOrder(id: String, zPosition: CGFloat) {
        drawOrders[id] = zPosition
        nodes[id]?.zPosition = zPosition - self.zPosition
    }

    func clear() {
        apply([])
    }
}

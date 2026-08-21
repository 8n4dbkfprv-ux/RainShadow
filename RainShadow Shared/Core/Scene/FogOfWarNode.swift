import CoreGraphics
import SpriteKit

/// An area's fog of war: what has been seen, and what is in sight now.
///
/// The Infinity Engine keeps two bitmaps per area. `ExploredBitmap` is sticky
/// and saved with the area — it never un-explores. `VisibleBitmap` is cleared
/// and refilled from the party's line of sight, and gates whether creatures are
/// drawn at all. Ground in the first but not the second draws as *partial* fog:
/// you keep the terrain and lose whatever is standing on it.
///
/// This used to be two node classes with one mask each, and neither drew that
/// middle state. The office faked memory with a rolling trail of the last eight
/// places Voss stood — the room forgot ground he had already walked, which the
/// engine never does — and a district lit everything it had ever seen as though
/// the player were standing in all of it at once. Once memory is a real layer,
/// the two policies collapse: both areas explore the same way, and the only
/// thing that still differs is whether the caller writes the remembered points
/// to the save. A district does; a room does not.
@MainActor
final class FogOfWarNode: SKSpriteNode {
    private let renderer: FogMaskRenderer
    private let searchMap: SearchMap
    private let worldOrigin: CGPoint

    /// Places the area remembers being seen from. The caller owns whether these
    /// outlive the visit.
    private(set) var rememberedPoints: [CGPoint] = []
    private var rememberedReveals: [FogMaskRenderer.Reveal] = []
    /// The two bitmaps themselves, kept because the mask is only half of what
    /// they are for: the engine also skips drawing any creature outside
    /// `VisibleBitmap`, so the same answer has to be available as a query and
    /// not just as pixels.
    private var exploredCells: Set<SearchMapCell> = []
    private var visibleCells: Set<SearchMapCell> = []
    /// The remembered layer, repainted only when memory grows.
    private var exploredMask: CGImage?
    private var lastSightPoint: CGPoint?

    init(
        worldOrigin: CGPoint,
        worldSize: CGSize,
        style: FogMaskRenderer.Style,
        searchMap: SearchMap,
        remembering points: [CGPoint],
        standingAt viewpoint: CGPoint
    ) {
        renderer = FogMaskRenderer(worldSize: worldSize, style: style)
        self.searchMap = searchMap
        self.worldOrigin = worldOrigin
        super.init(texture: nil, color: .black, size: worldSize)
        anchorPoint = .zero
        position = worldOrigin
        remember(points.isEmpty ? [viewpoint] : points)
        look(from: viewpoint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FogOfWarNode is created programmatically")
    }

    /// Look from here: repaint what is in sight, and commit it to memory once
    /// the player has moved far enough to be worth remembering separately.
    ///
    /// Returns whether memory grew, which is the caller's cue to persist.
    @discardableResult
    func look(from worldPoint: CGPoint) -> Bool {
        let grew = commitToMemoryIfMoved(worldPoint)
        let moved = lastSightPoint.map {
            hypot(worldPoint.x - $0.x, worldPoint.y - $0.y) >= renderer.style.sightStep
        } ?? true
        guard grew || moved else { return grew }
        lastSightPoint = worldPoint
        let sight = sightFrom(worldPoint)
        visibleCells = sight.cells
        texture = renderer.makeTexture(
            exploredMask: exploredMask,
            seeing: sight.reveal
        ) ?? texture
        return grew
    }

    /// Whether the area can see this point right now.
    ///
    /// What the engine gates creature drawing on: a remembered room shows its
    /// furniture and not who is standing in it. Sight that has run ahead of the
    /// last remembered pool counts — the mask lights it, so this must agree.
    func isVisible(_ worldPoint: CGPoint) -> Bool {
        visibleCells.contains(searchMap.cell(for: worldPoint))
    }

    /// Whether the area has ever seen this point.
    ///
    /// Follows the mask rather than every cell sight has ever touched, because a
    /// query that disagreed with the picture would hide something the player can
    /// plainly see, or show something under black.
    func isExplored(_ worldPoint: CGPoint) -> Bool {
        let cell = searchMap.cell(for: worldPoint)
        return exploredCells.contains(cell) || visibleCells.contains(cell)
    }

    /// Add places to memory without the player having stood in them — an
    /// authored entrance path, or the points a save restored.
    func remember(_ worldPoints: [CGPoint]) {
        guard !worldPoints.isEmpty else { return }
        for point in worldPoints {
            let sight = sightFrom(point)
            rememberedPoints.append(point)
            rememberedReveals.append(sight.reveal)
            exploredCells.formUnion(sight.cells)
        }
        exploredMask = renderer.makeExploredMask(remembering: rememberedReveals)
    }

    private func commitToMemoryIfMoved(_ worldPoint: CGPoint) -> Bool {
        if let last = rememberedPoints.last {
            let travelled = hypot(worldPoint.x - last.x, worldPoint.y - last.y)
            guard travelled >= renderer.style.memorySpacing else { return false }
        }
        remember([worldPoint])
        return true
    }

    /// One pool, cut back to what sight reaches from where it stands — and the
    /// cells it reached, which are the bitmap the queries above answer from.
    private func sightFrom(
        _ worldPoint: CGPoint
    ) -> (reveal: FogMaskRenderer.Reveal, cells: Set<SearchMapCell>) {
        let cells = searchMap.visibleCells(
            from: worldPoint,
            radiusInCells: renderer.visibilityRadiusInCells
        )
        let reveal = FogMaskRenderer.Reveal(
            center: CGPoint(
                x: worldPoint.x - worldOrigin.x,
                y: worldPoint.y - worldOrigin.y
            ),
            visibleRects: searchMap.mergedRects(of: cells).map {
                $0.offsetBy(dx: -worldOrigin.x, dy: -worldOrigin.y)
            }
        )
        return (reveal, cells)
    }
}

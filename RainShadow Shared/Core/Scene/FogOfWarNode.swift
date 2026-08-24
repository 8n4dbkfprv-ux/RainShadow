import CoreGraphics
import SpriteKit

/// An area's fog of war: what has been seen, and what is in sight now.
///
/// The Infinity Engine keeps two bitmaps per area. `ExploredBitmap` is sticky and
/// saved with the area — it never un-explores. `VisibleBitmap` is cleared and
/// refilled from the party's line of sight, and gates whether creatures are drawn
/// at all. Ground in the first but not the second draws as *partial* fog: you
/// keep the terrain and lose whatever is standing on it.
///
/// Both are now literally bitmaps. They used to be lists of places the player had
/// stood, re-cast on load and repainted in full every time the list grew, which
/// made a long walk cost more the longer you had walked and left no way to say
/// "this ground was revealed" about anything other than standing on it. Opening
/// a door is exactly that kind of reveal, and so is an authored one.
///
/// The two areas share one drawer and one pair of bitmaps. They part company
/// on indoor fill: an office floods each enclosure LOS reached so a room lights
/// as a diamond; a district keeps range-limited sight, which is outdoor BG.
@MainActor
final class FogOfWarNode: SKSpriteNode {
    private let renderer: FogMaskRenderer
    private let searchMap: SearchMap
    private let visualRangeInCells: Int
    /// Indoor areas flood each enclosure LOS reached so a room lights as a
    /// diamond instead of a disc. City districts leave this off: outdoor BG
    /// *does* show a range-limited, wall-clipped pool.
    private let fillsEnclosedRooms: Bool

    /// The two bitmaps. Kept as sets rather than only as pixels because the mask
    /// is half of what they are for: the engine also skips drawing any creature
    /// outside `VisibleBitmap`, so the same answer has to be available as a query.
    private(set) var exploredCells: Set<FogCell> = []
    private var visibleCells: Set<FogCell> = []
    /// Where sight was last answered from. The engine refills `VisibleBitmap`
    /// every frame; recomputing once per search cell crossed is the same picture
    /// for a fraction of the work, and is finer than any distance threshold —
    /// the old one let the lit edge lag a step behind the player.
    private var lastSightCell: SearchMapCell?
    /// Last cell-level mask uploaded. Walking that does not change three-state
    /// occupancy skips the CGImage / SKTexture rebuild.
    private var lastCellMask: [UInt8] = []
    /// Bumps whenever sight is recomputed, even if the uploaded mask is identical.
    private(set) var sightGeneration: Int = 0

    var fogGrid: FogGrid { renderer.grid }

    init(
        searchMap: SearchMap,
        visualRangeInCells: Int,
        fillsEnclosedRooms: Bool = false,
        remembering explored: Set<FogCell> = [],
        standingAt viewpoint: CGPoint
    ) {
        let grid = FogGrid(searchMap: searchMap)
        renderer = FogMaskRenderer(grid: grid)
        self.searchMap = searchMap
        self.visualRangeInCells = visualRangeInCells
        self.fillsEnclosedRooms = fillsEnclosedRooms
        exploredCells = explored
        super.init(texture: nil, color: .black, size: renderer.worldFrame.size)
        anchorPoint = .zero
        position = renderer.worldFrame.origin
        refresh(from: viewpoint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("FogOfWarNode is created programmatically")
    }

    /// Look from here: refill sight, and fold it into memory.
    ///
    /// Returns whether memory grew, which is the caller's cue to persist.
    @discardableResult
    func look(from worldPoint: CGPoint) -> Bool {
        let cell = searchMap.cell(for: worldPoint)
        guard cell != lastSightCell else { return false }
        return refresh(from: worldPoint)
    }

    /// Recompute sight from here whatever the player has or has not done.
    ///
    /// A door swinging changes what can be seen without anyone moving, and so
    /// does an authored reveal. Without this the fog would wait for the next step
    /// before noticing, which is the one thing an opened door must not do.
    @discardableResult
    func invalidateSight(from worldPoint: CGPoint) -> Bool {
        refresh(from: worldPoint)
    }

    /// Whether the area can see this point right now.
    ///
    /// Targeting and the cursor use the foot point. Creature *drawing* uses
    /// `intersectsVisible`, so a sprite on the fog edge is clipped by the
    /// overlay instead of popped off as a whole.
    func isVisible(_ worldPoint: CGPoint) -> Bool {
        visibleCells.contains(renderer.grid.cell(for: worldPoint))
    }

    /// Whether any fog cell overlapping `worldRect` is currently in sight.
    ///
    /// BG:EE draws the creature and then the fog on top, so a body that
    /// straddles the diamond stays in the graph and is cut by black. Hide the
    /// node only when no part of it is in a visible cell.
    func intersectsVisible(_ worldRect: CGRect) -> Bool {
        guard !worldRect.isNull, !worldRect.isEmpty else { return false }
        let grid = renderer.grid
        let minCell = grid.cell(for: CGPoint(x: worldRect.minX, y: worldRect.minY))
        let maxCell = grid.cell(for: CGPoint(x: worldRect.maxX, y: worldRect.maxY))
        let minColumn = min(minCell.column, maxCell.column)
        let maxColumn = max(minCell.column, maxCell.column)
        let minRow = min(minCell.row, maxCell.row)
        let maxRow = max(minCell.row, maxCell.row)
        for column in minColumn...maxColumn {
            for row in minRow...maxRow {
                if visibleCells.contains(FogCell(column: column, row: row)) {
                    return true
                }
            }
        }
        return false
    }

    /// Whether the area has ever seen this point. Sight counts: the mask lights
    /// it, so a query that said otherwise would hide something plainly on screen.
    func isExplored(_ worldPoint: CGPoint) -> Bool {
        let cell = renderer.grid.cell(for: worldPoint)
        return exploredCells.contains(cell) || visibleCells.contains(cell)
    }

    /// The explored bitmap on its own, for the HUD area map.
    ///
    /// BG's automap draws where the party has *been*, not where it is looking —
    /// so this is the same bitmap at a different size, with the live layer left
    /// out. One store, two pictures.
    ///
    /// Explored ground is handed over as the *clear* level rather than the
    /// remembered one: the world view dims memory because you are standing in
    /// the room and cannot see into it, and a map has no such excuse. On a map,
    /// explored means drawn.
    func exploredMapTexture() -> SKTexture? {
        renderer.makeTexture(explored: [], visible: exploredCells)
    }

    @discardableResult
    private func refresh(from worldPoint: CGPoint) -> Bool {
        lastSightCell = searchMap.cell(for: worldPoint)
        let sight = sightFrom(worldPoint)
        visibleCells = sight.visible
        let before = exploredCells.count
        exploredCells.formUnion(sight.visible)
        exploredCells.formUnion(sight.exploredOnly)
        sightGeneration += 1
        redraw()
        return exploredCells.count != before
    }

    /// Reveal ground nobody has stood in — an authored entrance, a scripted
    /// beat, the engine's own `ExploreArea`.
    @discardableResult
    func remember(seenFrom worldPoints: [CGPoint]) -> Bool {
        guard !worldPoints.isEmpty else { return false }
        let before = exploredCells.count
        for point in worldPoints {
            let sight = sightFrom(point)
            exploredCells.formUnion(sight.visible)
            exploredCells.formUnion(sight.exploredOnly)
        }
        guard exploredCells.count != before else { return false }
        redraw()
        return true
    }

    private func sightFrom(_ worldPoint: CGPoint) -> (visible: Set<FogCell>, exploredOnly: Set<FogCell>) {
        let radius = SearchMapExplore.searchRadius(visualRangeInFogTiles: visualRangeInCells)
        let chunk = searchMap.exploreMapChunk(
            from: worldPoint,
            radiusInCells: radius
        )
        if fillsEnclosedRooms {
            let enclosed = searchMap.enclosedFloor(touching: chunk.visible)
            return (
                visible: renderer.grid.cellsCoveringEnclosedRoom(enclosed, on: searchMap),
                exploredOnly: renderer.grid.cells(for: chunk.exploredOnly)
            )
        }
        return (
            visible: renderer.grid.cells(for: chunk.visible),
            exploredOnly: renderer.grid.cells(for: chunk.exploredOnly)
        )
    }

    private func redraw() {
        let cellMask = renderer.grid.mask(explored: exploredCells, visible: visibleCells)
        guard cellMask != lastCellMask else { return }
        lastCellMask = cellMask
        let display = FogEdgeMask.composite(
            cellLevels: cellMask,
            columns: renderer.grid.columns,
            rows: renderer.grid.rows
        )
        texture = renderer.makeTexture(displayLevels: display) ?? texture
    }
}

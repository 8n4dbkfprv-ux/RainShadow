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
/// stood, re-shadowcast on load and repainted in full every time the list grew,
/// which made a long walk cost more the longer you had walked and left no way to
/// say "this ground was revealed" about anything other than standing on it.
/// Opening a door is exactly that kind of reveal, and so is an authored one.
///
/// The two areas' fog no longer differs in any respect. The office and a district
/// explore identically, draw identically, and part company only where they always
/// should have: whether the caller writes the explored bitmap to the save.
@MainActor
final class FogOfWarNode: SKSpriteNode {
    private let renderer: FogMaskRenderer
    private let searchMap: SearchMap
    private let visualRangeInCells: Int

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

    var fogGrid: FogGrid { renderer.grid }

    init(
        searchMap: SearchMap,
        visualRangeInCells: Int,
        remembering explored: Set<FogCell> = [],
        standingAt viewpoint: CGPoint
    ) {
        let grid = FogGrid(searchMap: searchMap)
        renderer = FogMaskRenderer(grid: grid)
        self.searchMap = searchMap
        self.visualRangeInCells = visualRangeInCells
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
    /// What the engine gates creature drawing on: a remembered room shows its
    /// furniture and not who is standing in it.
    func isVisible(_ worldPoint: CGPoint) -> Bool {
        visibleCells.contains(renderer.grid.cell(for: worldPoint))
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

    /// Reveal ground nobody has stood in — an authored entrance, a scripted
    /// beat, the engine's own `ExploreArea`.
    @discardableResult
    func remember(seenFrom worldPoints: [CGPoint]) -> Bool {
        guard !worldPoints.isEmpty else { return false }
        let before = exploredCells.count
        for point in worldPoints {
            exploredCells.formUnion(sightCells(from: point))
        }
        guard exploredCells.count != before else { return false }
        redraw()
        return true
    }

    @discardableResult
    private func refresh(from worldPoint: CGPoint) -> Bool {
        lastSightCell = searchMap.cell(for: worldPoint)
        visibleCells = sightCells(from: worldPoint)
        let before = exploredCells.count
        exploredCells.formUnion(visibleCells)
        redraw()
        return exploredCells.count != before
    }

    private func sightCells(from worldPoint: CGPoint) -> Set<FogCell> {
        renderer.grid.cells(
            for: searchMap.visibleCells(
                from: worldPoint,
                radiusInCells: visualRangeInCells
            )
        )
    }

    private func redraw() {
        texture = renderer.makeTexture(
            explored: exploredCells,
            visible: visibleCells
        ) ?? texture
    }
}

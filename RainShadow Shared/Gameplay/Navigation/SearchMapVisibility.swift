import CoreGraphics
import Foundation

extension SearchMap {
    /// Every cell sight reaches from `point`, out to `radius` world units.
    ///
    /// This is what an Infinity Engine area's explored bitmap is filled from.
    /// BG does not reveal a disc around the party — it reveals what the party can
    /// *see*, so a street stops at the building on its corner and a room stops at
    /// its walls, while a desk or a railing occludes nothing. `SearchMapTerrain`
    /// has carried the answer since the terrain table landed; nothing asked it
    /// until now.
    ///
    /// Symmetric recursive shadowcasting over eight octants, which is the
    /// standard construction and the reason this is worth having as its own
    /// function: the obvious alternative — walk a ray to every cell in range —
    /// is `O(cells × radius)` and costs a city district roughly three million
    /// steps per reveal, where this costs one visit per cell in range. A
    /// district accumulates reveal points for as long as the player explores it
    /// and recomputes all of them when the save is reloaded, so the difference
    /// is a visible hitch on entering an area rather than a micro-optimisation.
    ///
    /// Range is counted in **search cells, not world units**, which is how the
    /// engine counts it and is the whole reason the cells are 16×12. GemRB walks
    /// a midpoint circle over the cell grid (`Explore::Init`), and 16:12 is the
    /// ground foreshortening this projection is locked to — so a circle on the
    /// cell grid is a circle *on the ground*, drawn as a 16:12 ellipse. Counting
    /// world units instead would draw a circle on the screen, which is a ground
    /// ellipse stretched away from the viewer.
    ///
    /// Out of bounds counts as opaque, matching `terrain(at:)` and the engine's
    /// treatment of the area boundary — sight stops at the edge of the map
    /// rather than escaping through it.
    ///
    /// A closed door is opaque too, which is the one occluder the painted terrain
    /// cannot answer: a leaf baked solid would block sight while standing open,
    /// and one baked as floor would never block it. The engine stamps a door's
    /// impeded cells as it swings and lets flag bit 9 decide whether sight goes
    /// with them, so `.doorSightBlocking` is read here beside the terrain.
    func visibleCells(from point: CGPoint, radiusInCells: Int) -> Set<SearchMapCell> {
        let origin = cell(for: point)
        guard contains(origin), radiusInCells > 0 else { return [] }

        var visible: Set<SearchMapCell> = [origin]
        for octant in Self.visibilityOctants {
            castLight(
                origin: origin,
                radiusInCells: radiusInCells,
                distance: 1,
                start: 1,
                end: 0,
                octant: octant,
                into: &visible
            )
        }
        return visible
    }

    /// The eight (xx, xy, yx, yy) transforms that map one octant's arithmetic
    /// onto the other seven.
    private static let visibilityOctants: [(xx: Int, xy: Int, yx: Int, yy: Int)] = [
        (1, 0, 0, 1), (0, 1, 1, 0), (0, -1, 1, 0), (-1, 0, 0, 1),
        (-1, 0, 0, -1), (0, -1, -1, 0), (0, 1, -1, 0), (1, 0, 0, -1)
    ]

    private func castLight(
        origin: SearchMapCell,
        radiusInCells: Int,
        distance startDistance: Int,
        start: Double,
        end: Double,
        octant: (xx: Int, xy: Int, yx: Int, yy: Int),
        into visible: inout Set<SearchMapCell>
    ) {
        guard start >= end else { return }
        var start = start
        var nextStart = 0.0
        var blocked = false
        var distance = startDistance

        while distance <= radiusInCells && !blocked {
            let deltaY = -distance
            var deltaX = -distance
            while deltaX <= 0 {
                defer { deltaX += 1 }
                // The cell's leading and trailing edges as slopes. Half-cell
                // offsets are what make this symmetric: A sees B whenever B
                // sees A.
                let leftSlope = (Double(deltaX) - 0.5) / (Double(deltaY) + 0.5)
                let rightSlope = (Double(deltaX) + 0.5) / (Double(deltaY) - 0.5)
                if start < rightSlope { continue }
                if end > leftSlope { break }

                let candidate = SearchMapCell(
                    column: origin.column + deltaX * octant.xx + deltaY * octant.xy,
                    row: origin.row + deltaX * octant.yx + deltaY * octant.yy
                )
                let opaque = !contains(candidate)
                    || !terrain(at: candidate).isSeeThrough
                    || doorBlocksSight(at: candidate)

                if contains(candidate), withinRadius(candidate, of: origin, radiusInCells) {
                    visible.insert(candidate)
                }

                if blocked {
                    if opaque {
                        nextStart = rightSlope
                        continue
                    }
                    blocked = false
                    start = nextStart
                } else if opaque, distance < radiusInCells {
                    // Everything behind this cell is in shadow: recurse into the
                    // wedge to its left, then resume scanning to its right.
                    blocked = true
                    castLight(
                        origin: origin,
                        radiusInCells: radiusInCells,
                        distance: distance + 1,
                        start: start,
                        end: leftSlope,
                        octant: octant,
                        into: &visible
                    )
                    nextStart = rightSlope
                }
            }
            distance += 1
        }
    }

    /// A circle on the cell grid, which is a circle on the ground.
    ///
    /// Measured on the placed cell rather than on the octant's own `deltaX` /
    /// `deltaY` so the four axis-swapping transforms cannot disagree with the
    /// four that do not.
    private func withinRadius(
        _ cell: SearchMapCell,
        of origin: SearchMapCell,
        _ radiusInCells: Int
    ) -> Bool {
        let columns = cell.column - origin.column
        let rows = cell.row - origin.row
        return columns * columns + rows * rows <= radiusInCells * radiusInCells
    }

    /// Every see-through floor cell in an enclosure that `seeds` already reached,
    /// plus the opaque wall cells that bound it.
    ///
    /// Indoor BG:EE does not light a disc inside a room. Visual range is larger
    /// than a BG inn, so walls clip sight into room polygons and a doorway is
    /// the only bleed. RainShadow interiors are larger than stat #262, so a
    /// radius-only fill still draws a spotlight. Flooding each enclosure the
    /// cast touched — stopping at `!isSeeThrough` and closed sight-blocking
    /// doors — is the indoor picture: one open room is a diamond, a closed
    /// back room stays black.
    ///
    /// Furniture (`obstacleSeeThrough`) does not split a room. Out of bounds is
    /// opaque, matching `visibleCells`. The blocking cell itself is included,
    /// matching GemRB `Pass = 2`: a room's own walls light, nothing behind them.
    func enclosedFloor(touching seeds: Set<SearchMapCell>) -> Set<SearchMapCell> {
        guard !seeds.isEmpty else { return [] }

        var result: Set<SearchMapCell> = []
        var visited: Set<SearchMapCell> = []
        var queue: [SearchMapCell] = []

        func isRoomFloor(_ cell: SearchMapCell) -> Bool {
            contains(cell) && terrain(at: cell).isSeeThrough && !doorBlocksSight(at: cell)
        }

        for seed in seeds {
            if visited.contains(seed) { continue }
            if !isRoomFloor(seed) {
                // An opaque cell the cast already lit (the wall you are looking
                // at) stays lit, but is not a door into the next enclosure.
                visited.insert(seed)
                result.insert(seed)
                continue
            }
            visited.insert(seed)
            queue.append(seed)
            while let cell = queue.popLast() {
                result.insert(cell)
                let neighbours = [
                    SearchMapCell(column: cell.column - 1, row: cell.row),
                    SearchMapCell(column: cell.column + 1, row: cell.row),
                    SearchMapCell(column: cell.column, row: cell.row - 1),
                    SearchMapCell(column: cell.column, row: cell.row + 1)
                ]
                for neighbour in neighbours {
                    if visited.contains(neighbour) { continue }
                    if isRoomFloor(neighbour) {
                        visited.insert(neighbour)
                        queue.append(neighbour)
                    } else if contains(neighbour) {
                        visited.insert(neighbour)
                        result.insert(neighbour)
                    }
                }
            }
        }
        return result
    }

    /// World rectangles covering `cells`, with each row's runs merged.
    ///
    /// A fog mask clips its lit pool to these, and a city district's pool spans
    /// something like twenty thousand cells. Handing CoreGraphics twenty
    /// thousand rectangles to clip against is an order of magnitude more work
    /// than handing it the couple of hundred horizontal runs they actually form,
    /// and the clipped region is identical either way.
    func mergedRects(of cells: Set<SearchMapCell>) -> [CGRect] {
        guard !cells.isEmpty else { return [] }
        var byRow: [Int: [Int]] = [:]
        for cell in cells {
            byRow[cell.row, default: []].append(cell.column)
        }

        var rects: [CGRect] = []
        for (row, columns) in byRow {
            let sorted = columns.sorted()
            var runStart = sorted[0]
            var runEnd = sorted[0]
            for column in sorted.dropFirst() {
                if column == runEnd + 1 {
                    runEnd = column
                } else {
                    rects.append(runRect(row: row, from: runStart, through: runEnd))
                    runStart = column
                    runEnd = column
                }
            }
            rects.append(runRect(row: row, from: runStart, through: runEnd))
        }
        return rects
    }

    private func runRect(row: Int, from first: Int, through last: Int) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(first) * cellSize.width,
            y: origin.y + CGFloat(row) * cellSize.height,
            width: CGFloat(last - first + 1) * cellSize.width,
            height: cellSize.height
        )
    }

    /// World-space rectangle covering a cell — what a fog mask paints.
    func rect(of cell: SearchMapCell) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell.column) * cellSize.width,
            y: origin.y + CGFloat(cell.row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
    }
}

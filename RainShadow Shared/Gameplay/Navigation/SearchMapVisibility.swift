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
    /// The grid's cells are 16×12, so `radius` is measured in world units
    /// against the cell *centres* and the lit region comes out a true circle
    /// rather than an ellipse stretched along the grid. Slopes stay in cell
    /// space, which is exact: world space is a uniform scale of it per axis, and
    /// a straight line in one is a straight line in the other.
    ///
    /// Out of bounds counts as opaque, matching `terrain(at:)` and the engine's
    /// treatment of the area boundary — sight stops at the edge of the map
    /// rather than escaping through it.
    func visibleCells(from point: CGPoint, radius: CGFloat) -> Set<SearchMapCell> {
        let origin = cell(for: point)
        guard contains(origin), radius > 0 else { return [] }

        var visible: Set<SearchMapCell> = [origin]
        // Rows are counted in cells, and the shorter axis decides how many can
        // fit inside the radius. The circle test below culls the rest.
        let rowLimit = Int(ceil(radius / min(cellSize.width, cellSize.height)))
        for octant in Self.visibilityOctants {
            castLight(
                origin: origin,
                radius: radius,
                distance: 1,
                start: 1,
                end: 0,
                octant: octant,
                rowLimit: rowLimit,
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
        radius: CGFloat,
        distance startDistance: Int,
        start: Double,
        end: Double,
        octant: (xx: Int, xy: Int, yx: Int, yy: Int),
        rowLimit: Int,
        into visible: inout Set<SearchMapCell>
    ) {
        guard start >= end else { return }
        var start = start
        var nextStart = 0.0
        var blocked = false
        var distance = startDistance

        while distance <= rowLimit && !blocked {
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
                let opaque = !contains(candidate) || !terrain(at: candidate).isSeeThrough

                if contains(candidate), withinRadius(candidate, of: origin, radius: radius) {
                    visible.insert(candidate)
                }

                if blocked {
                    if opaque {
                        nextStart = rightSlope
                        continue
                    }
                    blocked = false
                    start = nextStart
                } else if opaque, distance < rowLimit {
                    // Everything behind this cell is in shadow: recurse into the
                    // wedge to its left, then resume scanning to its right.
                    blocked = true
                    castLight(
                        origin: origin,
                        radius: radius,
                        distance: distance + 1,
                        start: start,
                        end: leftSlope,
                        octant: octant,
                        rowLimit: rowLimit,
                        into: &visible
                    )
                    nextStart = rightSlope
                }
            }
            distance += 1
        }
    }

    /// A true world-space circle, not a cell-count square: the cells are 16×12,
    /// so counting rows would reach a third further vertically than horizontally.
    ///
    /// Measured on the placed cell rather than on the octant's own `deltaX` /
    /// `deltaY`, because four of the eight transforms swap the axes — and with
    /// non-square cells a swapped delta is a different world distance.
    private func withinRadius(
        _ cell: SearchMapCell,
        of origin: SearchMapCell,
        radius: CGFloat
    ) -> Bool {
        let worldX = CGFloat(cell.column - origin.column) * cellSize.width
        let worldY = CGFloat(cell.row - origin.row) * cellSize.height
        return worldX * worldX + worldY * worldY <= radius * radius
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

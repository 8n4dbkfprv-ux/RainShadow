import CoreGraphics
import Foundation

/// GemRB `Explore`: a midpoint-circle of rays out to `maxVisibility` search cells.
///
/// The Infinity Engine does not shadowcast. `Explore::Init` walks a midpoint
/// circle at radius 30 and `AddLOS` fills each ray with integer-interpolated
/// offsets. `Map::ExploreMapChunk` then walks those rays from the actor.
enum SearchMapExplore {
    /// GemRB `Explore::MaxVisibility`. Visual range is clamped to this.
    static let maxVisibility = 30

    /// `VisibilityMasks[distance][ray]` — offsets from the origin cell.
    static let visibilityMasks: [[(dx: Int, dy: Int)]] = buildMasks()

    private static func buildMasks() -> [[(dx: Int, dy: Int)]] {
        let maxV = maxVisibility
        var x = maxV
        var y = 0
        var xc = 1 - 2 * maxV
        var yc = 1
        var re = 0
        var perimeter = 0
        while x >= y {
            perimeter += 8
            y += 1
            re += yc
            yc += 2
            if (2 * re + xc) > 0 {
                x -= 1
                re += xc
                xc += 2
            }
        }

        var masks = Array(
            repeating: Array(repeating: (dx: 0, dy: 0), count: perimeter),
            count: maxV
        )

        x = maxV
        y = 0
        xc = 1 - 2 * maxV
        yc = 1
        re = 0
        var slot = 0
        while x >= y {
            addLOS(destX: x, destY: y, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: -x, destY: y, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: -x, destY: -y, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: x, destY: -y, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: y, destY: x, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: -y, destY: x, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: -y, destY: -x, slot: slot, into: &masks)
            slot += 1
            addLOS(destX: y, destY: -x, slot: slot, into: &masks)
            slot += 1
            y += 1
            re += yc
            yc += 2
            if (2 * re + xc) > 0 {
                x -= 1
                re += xc
                xc += 2
            }
        }
        return masks
    }

    private static func addLOS(
        destX: Int,
        destY: Int,
        slot: Int,
        into masks: inout [[(dx: Int, dy: Int)]]
    ) {
        let maxV = maxVisibility
        for i in 0..<maxV {
            // Truncating toward zero, matching C++ integer division.
            let x = (destX * i + maxV / 2) / maxV
            let y = (destY * i + maxV / 2) / maxV
            masks[i][slot] = (dx: x, dy: y)
        }
    }

    /// Search-map cells to walk for creature stat #262.
    ///
    /// The stat is in 32-px fog tiles (default 14 = 448 area px). The search map
    /// is 16×12, so two search cells per fog tile. GemRB then adds the
    /// selection-circle size; +2 is an adult footprint.
    static func searchRadius(visualRangeInFogTiles: Int) -> Int {
        min(maxVisibility, max(0, visualRangeInFogTiles * 2 + 2))
    }
}

extension SearchMap {
    /// Every cell sight reaches from `point`, out to `radius` search cells.
    ///
    /// This is what an Infinity Engine area's explored bitmap is filled from.
    /// BG does not reveal a disc around the party — it reveals what the party can
    /// *see*, so a street stops at the building on its corner and a room stops at
    /// its walls, while a desk or a railing occludes nothing.
    ///
    /// Range is counted in **search cells**, which is how the engine counts the
    /// walk after converting stat #262 (fog tiles) by doubling. Cells are 16×12,
    /// so a circle on the cell grid is a circle on the ground, drawn as a 16:12
    /// ellipse. Counting world units instead would draw a circle on the screen.
    ///
    /// Out of bounds counts as opaque, matching `terrain(at:)` and the engine's
    /// treatment of the area boundary.
    func visibleCells(from point: CGPoint, radiusInCells: Int) -> Set<SearchMapCell> {
        exploreMapChunk(from: point, radiusInCells: radiusInCells).visible
    }

    /// GemRB `Map::ExploreMapChunk`.
    ///
    /// `visible` is currently in sight. `exploredOnly` is the outdoor-door
    /// shroud: ground the ray reached but must not light (`fogOnly`).
    ///
    /// A ray that meets `NO_SEE` (index 0, or a closed sight-blocking door when
    /// `outdoorDoorShroud` is off) explores that cell, then `Pass` drops; the
    /// next blocked step breaks without exploring. Sidewall (index 10) stays
    /// visible for the run, then the first non-sidewall cell starts that stop.
    /// Outdoors outside a city, a closed impassable door sets `fogOnly` instead
    /// of blocking, so ground beyond is remembered but shrouded.
    func exploreMapChunk(
        from point: CGPoint,
        radiusInCells: Int,
        outdoorDoorShroud: Bool = false
    ) -> (visible: Set<SearchMapCell>, exploredOnly: Set<SearchMapCell>) {
        let origin = cell(for: point)
        guard contains(origin), radiusInCells > 0 else { return ([], []) }

        let range = min(radiusInCells, SearchMapExplore.maxVisibility)
        let masks = SearchMapExplore.visibilityMasks
        let perimeter = masks[0].count

        var visible: Set<SearchMapCell> = [origin]
        var exploredOnly: Set<SearchMapCell> = []

        for ray in 0..<perimeter {
            var pass = 2
            var block = false
            var sidewall = false
            var fogOnly = false
            for distance in 0..<range {
                let offset = masks[distance][ray]
                let tile = SearchMapCell(
                    column: origin.column + offset.dx,
                    row: origin.row + offset.dy
                )

                if !block {
                    let inMap = contains(tile)
                    let terrain = inMap ? self.terrain(at: tile) : SearchMapTerrain.obstacle
                    let door = inMap && doorBlocksSight(at: tile)

                    if !inMap || !terrain.isSeeThrough || (door && !outdoorDoorShroud) {
                        block = true
                    } else if terrain.isSightSidewall {
                        sidewall = true
                    } else if sidewall {
                        block = true
                    } else if door && outdoorDoorShroud {
                        fogOnly = true
                    }
                }
                if block {
                    pass -= 1
                    if pass == 0 { break }
                }
                guard contains(tile) else { continue }
                if fogOnly {
                    exploredOnly.insert(tile)
                } else {
                    visible.insert(tile)
                }
            }
        }
        exploredOnly.subtract(visible)
        return (visible, exploredOnly)
    }

    /// Every see-through floor cell in an enclosure that `seeds` already reached,
    /// plus the opaque wall cells that bound it.
    ///
    /// Indoor BG:EE does not light a disc inside a room. Visual range is larger
    /// than a BG inn, so walls clip sight into room polygons and a doorway is
    /// the only bleed. RainShadow interiors are larger than stat #262, so a
    /// radius-only fill still draws a spotlight. Flooding each enclosure the
    /// cast touched — stopping at `NO_SEE`, sidewall, and closed sight-blocking
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
            contains(cell)
                && terrain(at: cell).isSeeThrough
                && !terrain(at: cell).isSightSidewall
                && !doorBlocksSight(at: cell)
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

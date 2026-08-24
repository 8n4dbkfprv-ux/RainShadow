import CoreGraphics
import Foundation

/// One fog-of-war cell — the unit an area remembers having seen.
struct FogCell: Hashable, Sendable {
    let column: Int
    let row: Int
}

/// The grid an area's fog is quantised to, and the three-level mask drawn from it.
///
/// The Infinity Engine keeps exploration at a coarser resolution than sight. Sight
/// is answered per search cell — one byte per 16×12 pixels in `SR.BMP` — but the
/// `.ARE` explored bitmask and the fog overlay share **one 32×32 screen-pixel
/// cell**. GemRB's `FogRenderer::CELL_SIZE` is that square; `FogPoint` converts a
/// search-map cell with `x * 16 / 32` and `y * 12 / 32`.
///
/// RainShadow used to take 2×2 search cells (32×24) so a fog cell would be square
/// on the *ground*. That is not what the engine draws. The overlay is square on
/// the *screen*, and the 16:12 lock stays on the search map that fills these
/// cells. Mapping a search cell uses its centre, so a 16×12 cell belongs to
/// exactly one 32×32 fog cell even though 12 does not divide 32.
///
/// The state mask is one byte per fog cell. Cell interiors are flat at the three
/// GemRB levels. Softening is not a linear filter on that buffer — `FogEdgeMask`
/// stamps the FOGOWAR-role edge tiles at `texturePixelsPerCell`, which is the
/// only edge treatment in the system. The overlay sprite is then stretched to
/// `worldSize` with nearest sampling, so a walk does not upload a full-plate
/// RGBA texture on every search-cell step.
struct FogGrid: Hashable, Sendable {
    /// GemRB `FogRenderer::CELL_SIZE`. Square on the screen, and the world size
    /// of one fog cell. Not the uploaded texel size — see `texturePixelsPerCell`.
    static let cellPixelSize = 32

    /// Texels per fog cell in the overlay texture. 32 matched GemRB's compositor
    /// 1:1 and rebuilt ~9M texels per step on a 4096×2304 plate. Four texels
    /// keep the 6 px/32 falloff as a one-texel rim after scaling.
    static let texturePixelsPerCell = 4

    // MARK: Mask levels
    //
    // GemRB's two fog constants verbatim: `OPAQUE_FOG` is black at full alpha,
    // `TRANSPARENT_FOG` is black blitted `HALFTRANS`, which is alpha 128. The
    // third level is the absence of both.

    /// Never seen. GemRB's `OPAQUE_FOG`.
    static let unexploredLevel: UInt8 = 255
    /// Seen, not in sight now. GemRB's `TRANSPARENT_FOG` — alpha 128 exactly,
    /// not a tuned fraction. You keep the ground and lose what stands on it.
    static let rememberedLevel: UInt8 = 128
    /// In sight. No fog at all.
    static let visibleLevel: UInt8 = 0

    let origin: CGPoint
    let columns: Int
    let rows: Int
    let searchCellSize: CGSize

    var cellSize: CGSize {
        CGSize(
            width: CGFloat(Self.cellPixelSize),
            height: CGFloat(Self.cellPixelSize)
        )
    }

    /// The grid covering a search map, at 32×32 screen pixels per fog cell.
    init(searchMap: SearchMap) {
        self.init(
            origin: searchMap.origin,
            searchColumns: searchMap.columns,
            searchRows: searchMap.rows,
            searchCellSize: searchMap.cellSize
        )
    }

    /// Geometry-only initialiser, so the grid can be exercised without building
    /// a search map around it.
    init(
        origin: CGPoint,
        searchColumns: Int,
        searchRows: Int,
        searchCellSize: CGSize = SearchMap.defaultCellSize
    ) {
        self.origin = origin
        self.searchCellSize = searchCellSize
        let pixel = Self.cellPixelSize
        let widthPx = max(0, searchColumns) * Int(searchCellSize.width)
        let heightPx = max(0, searchRows) * Int(searchCellSize.height)
        // Rounded up: leftover search-map pixels still have a fog cell. Rounding
        // down would leave a strip of ground that could never be explored.
        columns = widthPx == 0 ? 0 : (widthPx + pixel - 1) / pixel
        rows = heightPx == 0 ? 0 : (heightPx + pixel - 1) / pixel
    }

    // MARK: - Coordinate conversion

    func cell(for point: CGPoint) -> FogCell {
        FogCell(
            column: Int(floor((point.x - origin.x) / cellSize.width)),
            row: Int(floor((point.y - origin.y) / cellSize.height))
        )
    }

    /// The fog cell a search cell's centre falls in.
    ///
    /// Integer division on the centre's pixel, not a trip through `cell(for:
    /// point)`, so the two grids cannot disagree at a boundary from float
    /// rounding. Sight *drawing* uses `cellsOverlapping` instead: 12 does not
    /// divide 32, so a search cell's min and max corners can sit in different
    /// fog rows, and mapping only the centre left 32×32 holes in painted walls.
    func cell(for searchCell: SearchMapCell) -> FogCell {
        let pixel = Self.cellPixelSize
        let searchWidth = Int(searchCellSize.width)
        let searchHeight = Int(searchCellSize.height)
        let x = searchCell.column * searchWidth + searchWidth / 2
        let y = searchCell.row * searchHeight + searchHeight / 2
        return FogCell(column: x / pixel, row: y / pixel)
    }

    /// Every fog cell a search cell's 16×12 rect touches, not just its centre.
    func cellsOverlapping(_ searchCell: SearchMapCell) -> Set<FogCell> {
        let pixel = Self.cellPixelSize
        let searchWidth = Int(searchCellSize.width)
        let searchHeight = Int(searchCellSize.height)
        guard searchWidth > 0, searchHeight > 0 else { return [] }
        let x0 = searchCell.column * searchWidth
        let y0 = searchCell.row * searchHeight
        let x1 = x0 + searchWidth - 1
        let y1 = y0 + searchHeight - 1
        var fog: Set<FogCell> = []
        for column in (x0 / pixel)...(x1 / pixel) {
            for row in (y0 / pixel)...(y1 / pixel) {
                let cell = FogCell(column: column, row: row)
                if contains(cell) {
                    fog.insert(cell)
                }
            }
        }
        return fog
    }

    func cells(for searchCells: some Sequence<SearchMapCell>) -> Set<FogCell> {
        var fog: Set<FogCell> = []
        for searchCell in searchCells {
            fog.formUnion(cellsOverlapping(searchCell))
        }
        return fog
    }

    /// Indoor rooms: light every fog cell the enclosed floor touches, then walk
    /// through wall-only / void fog cells so the painted wall face is not left
    /// as a 32×32 black square. Stop before any fog cell that overlaps
    /// see-through floor the enclosure did not already claim — that is the next
    /// room.
    func cellsCoveringEnclosedRoom(
        _ enclosed: Set<SearchMapCell>,
        on searchMap: SearchMap
    ) -> Set<FogCell> {
        var visible = cells(for: enclosed)
        guard !visible.isEmpty else { return visible }
        var queue = Array(visible)
        while let cell = queue.popLast() {
            let neighbours = [
                FogCell(column: cell.column - 1, row: cell.row),
                FogCell(column: cell.column + 1, row: cell.row),
                FogCell(column: cell.column, row: cell.row - 1),
                FogCell(column: cell.column, row: cell.row + 1)
            ]
            for neighbour in neighbours {
                if !contains(neighbour) || visible.contains(neighbour) { continue }
                if overlapsUnenclosedFloor(neighbour, enclosed: enclosed, on: searchMap) {
                    continue
                }
                visible.insert(neighbour)
                queue.append(neighbour)
            }
        }
        return visible
    }

    private func overlapsUnenclosedFloor(
        _ fogCell: FogCell,
        enclosed: Set<SearchMapCell>,
        on searchMap: SearchMap
    ) -> Bool {
        let rect = rect(of: fogCell)
        let minCell = searchMap.cell(for: rect.origin)
        let maxCell = searchMap.cell(for: CGPoint(x: rect.maxX - 0.001, y: rect.maxY - 0.001))
        let minColumn = max(0, min(minCell.column, maxCell.column))
        let maxColumn = min(searchMap.columns - 1, max(minCell.column, maxCell.column))
        let minRow = max(0, min(minCell.row, maxCell.row))
        let maxRow = min(searchMap.rows - 1, max(minCell.row, maxCell.row))
        guard minColumn <= maxColumn, minRow <= maxRow else { return false }
        for column in minColumn...maxColumn {
            for row in minRow...maxRow {
                let searchCell = SearchMapCell(column: column, row: row)
                if enclosed.contains(searchCell) { continue }
                if searchMap.terrain(at: searchCell).isSeeThrough,
                   !searchMap.doorBlocksSight(at: searchCell) {
                    return true
                }
            }
        }
        return false
    }

    func contains(_ cell: FogCell) -> Bool {
        cell.column >= 0 && cell.column < columns && cell.row >= 0 && cell.row < rows
    }

    func rect(of cell: FogCell) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell.column) * cellSize.width,
            y: origin.y + CGFloat(cell.row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
    }

    /// World extent the mask is stretched over. Taller than the search map when
    /// its pixel height is not a multiple of 32, for the reason `rows` rounds up.
    var worldSize: CGSize {
        CGSize(
            width: CGFloat(columns) * cellSize.width,
            height: CGFloat(rows) * cellSize.height
        )
    }

    // MARK: - The mask

    /// One byte per fog cell. `FogEdgeMask` expands this to `texturePixelsPerCell`.
    var maskWidth: Int { columns }
    var maskHeight: Int { rows }

    /// One byte per cell, three levels, row 0 at the **top** — which is the row
    /// order `CGImage` reads, so the buffer can be handed on without a flip.
    ///
    /// `visible` wins over `explored` wherever they disagree, and neither has to
    /// be a subset of the other: sight that has run ahead of what the area has
    /// committed to memory is still lit.
    func mask(explored: Set<FogCell>, visible: Set<FogCell>) -> [UInt8] {
        var buffer = [UInt8](repeating: Self.unexploredLevel, count: maskWidth * maskHeight)
        guard maskWidth > 0, maskHeight > 0 else { return buffer }

        for cell in explored where contains(cell) {
            buffer[index(of: cell)] = Self.rememberedLevel
        }
        for cell in visible where contains(cell) {
            buffer[index(of: cell)] = Self.visibleLevel
        }
        return buffer
    }

    /// The overlay actually drawn: cell interiors plus FOGOWAR-role edge stamps.
    func displayMask(explored: Set<FogCell>, visible: Set<FogCell>) -> [UInt8] {
        FogEdgeMask.composite(
            cellLevels: mask(explored: explored, visible: visible),
            columns: columns,
            rows: rows
        )
    }

    private func index(of cell: FogCell) -> Int {
        (rows - 1 - cell.row) * columns + cell.column
    }

    // MARK: - Persistence

    /// The explored bitmask for these cells, sized and ready to store.
    func bitmask(of cells: Set<FogCell>) -> FogBitmask {
        FogBitmask(columns: columns, rows: rows, bytes: packed(cells))
    }

    /// Read a stored bitmask back onto this grid.
    ///
    /// A bitmask written against different dimensions is re-read at its own
    /// width and then clipped to this grid, so an area that has been resized
    /// loses the ground that no longer exists instead of shearing every row.
    func cells(from bitmask: FogBitmask) -> Set<FogCell> {
        guard bitmask.columns > 0 else { return [] }
        return bitmask.cells.filter(contains)
    }

    /// One bit per fog cell, which is what the `.ARE` explored bitmask is.
    ///
    /// Bits run in reading order — cell (0, 0) is the low bit of byte 0 — and the
    /// last byte is padded with zeros. Cells outside the grid are dropped rather
    /// than clamped: a save written against a differently sized area should lose
    /// the ground that no longer exists, not smear it onto the edge.
    func packed(_ cells: Set<FogCell>) -> [UInt8] {
        let bitCount = columns * rows
        guard bitCount > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: (bitCount + 7) / 8)
        for cell in cells where contains(cell) {
            let bit = cell.row * columns + cell.column
            bytes[bit / 8] |= UInt8(1 << (bit % 8))
        }
        return bytes
    }

    func unpacked(_ bytes: [UInt8]) -> Set<FogCell> {
        var cells: Set<FogCell> = []
        let bitCount = min(columns * rows, bytes.count * 8)
        for bit in 0..<bitCount where bytes[bit / 8] & UInt8(1 << (bit % 8)) != 0 {
            cells.insert(FogCell(column: bit % columns, row: bit / columns))
        }
        return cells
    }
}

/// An area's explored bitmask as it is stored, carrying the dimensions it was
/// written at.
///
/// The Infinity Engine keeps this in the `.ARE` — "an array of bits, one bit for
/// each 32x32 cell" — and restores it when the player comes back to the area,
/// which is why a place you have walked is still drawn when you return to it and
/// only the creatures in it are hidden again. The dimensions travel with the
/// bytes because a bitmask is meaningless without the width its rows were
/// counted at.
struct FogBitmask: Hashable, Sendable {
    var columns: Int
    var rows: Int
    var bytes: [UInt8]

    init(columns: Int, rows: Int, bytes: [UInt8]) {
        self.columns = max(0, columns)
        self.rows = max(0, rows)
        self.bytes = bytes
    }

    /// The cells this bitmask names, at the width it was written at.
    var cells: Set<FogCell> {
        guard columns > 0, rows > 0 else { return [] }
        var cells: Set<FogCell> = []
        let bitCount = min(columns * rows, bytes.count * 8)
        for bit in 0..<bitCount where bytes[bit / 8] & UInt8(1 << (bit % 8)) != 0 {
            cells.insert(FogCell(column: bit % columns, row: bit / columns))
        }
        return cells
    }

    var isEmpty: Bool { bytes.allSatisfy { $0 == 0 } }
}

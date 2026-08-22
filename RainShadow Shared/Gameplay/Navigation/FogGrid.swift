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
/// `.ARE` explored bitmask stores *one bit for each 32×32 pixel cell*, and the fog
/// is drawn on that coarser grid. The two are deliberately different: a sight test
/// wants to be fine enough to slip between a pillar and a wall, and a drawn fog
/// wants to be coarse enough that a chair leg cannot carve a one-cell slit across
/// a room.
///
/// RainShadow takes **2×2 search cells**, or 32×24 world units. IE's own 32×32 is
/// square in screen pixels, which over 16×12 search cells is a non-integer 2 ×
/// 2.667 — square on the screen and therefore *not* square on the ground. This
/// projection is locked to 16:12 ground foreshortening, so 2×2 cells is the same
/// 4:3 the search grid already is: a fog cell that is square on the floor, which
/// is what IE's square-on-screen cell was approximating.
///
/// The mask this produces is not a painting of the fog — it *is* the two bitmaps,
/// one byte per texel, at `edgeTexelsPerCell` texels to a fog cell. Cell interiors
/// are flat and the boundary is a single-texel step, which linear filtering
/// stretches into a ramp a quarter of a fog cell wide. That ramp is what the
/// engine buys with the edge and corner frames of its `fogowar` BAM; here it is
/// free, and it is the only softening in the system.
struct FogGrid: Hashable, Sendable {
    /// How many search cells make up one fog cell, on each axis.
    static let searchCellsPerFogCell = 2

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
    let cellSize: CGSize

    /// Mask texels per fog cell along each axis. Raising it narrows the edge
    /// ramp; 1 would make the ramp a whole cell wide and the fog a soft blob.
    var edgeTexelsPerCell: Int = 4

    /// The grid covering a search map, two of its cells to one of these.
    init(searchMap: SearchMap, edgeTexelsPerCell: Int = 4) {
        self.init(
            origin: searchMap.origin,
            searchColumns: searchMap.columns,
            searchRows: searchMap.rows,
            searchCellSize: searchMap.cellSize,
            edgeTexelsPerCell: edgeTexelsPerCell
        )
    }

    /// Geometry-only initialiser, so the grid can be exercised without building
    /// a search map around it.
    init(
        origin: CGPoint,
        searchColumns: Int,
        searchRows: Int,
        searchCellSize: CGSize = SearchMap.defaultCellSize,
        edgeTexelsPerCell: Int = 4
    ) {
        let span = Self.searchCellsPerFogCell
        self.origin = origin
        // Rounded up: a search map with an odd column count still has that last
        // column covered, by a fog cell that hangs half off the map. Rounding
        // down would leave a strip of ground that could never be explored.
        columns = (max(0, searchColumns) + span - 1) / span
        rows = (max(0, searchRows) + span - 1) / span
        cellSize = CGSize(
            width: searchCellSize.width * CGFloat(span),
            height: searchCellSize.height * CGFloat(span)
        )
        self.edgeTexelsPerCell = max(1, edgeTexelsPerCell)
    }

    // MARK: - Coordinate conversion

    func cell(for point: CGPoint) -> FogCell {
        FogCell(
            column: Int(floor((point.x - origin.x) / cellSize.width)),
            row: Int(floor((point.y - origin.y) / cellSize.height))
        )
    }

    /// The fog cell a search cell falls in. Integer division rather than a trip
    /// through world coordinates, so the two grids cannot disagree at a boundary.
    func cell(for searchCell: SearchMapCell) -> FogCell {
        let span = Self.searchCellsPerFogCell
        return FogCell(
            column: Int(floor(Double(searchCell.column) / Double(span))),
            row: Int(floor(Double(searchCell.row) / Double(span)))
        )
    }

    func cells(for searchCells: some Sequence<SearchMapCell>) -> Set<FogCell> {
        var fog: Set<FogCell> = []
        for searchCell in searchCells {
            fog.insert(cell(for: searchCell))
        }
        return fog
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

    /// World extent the mask is stretched over. Wider than the search map when
    /// its cell count is odd, for the reason `columns` rounds up.
    var worldSize: CGSize {
        CGSize(
            width: CGFloat(columns) * cellSize.width,
            height: CGFloat(rows) * cellSize.height
        )
    }

    // MARK: - The mask

    var maskWidth: Int { columns * edgeTexelsPerCell }
    var maskHeight: Int { rows * edgeTexelsPerCell }

    /// One byte per texel, three levels, row 0 at the **top** — which is the row
    /// order `CGImage` reads, so the buffer can be handed to a data provider
    /// without a flip in between.
    ///
    /// `visible` wins over `explored` wherever they disagree, and neither has to
    /// be a subset of the other: sight that has run ahead of what the area has
    /// committed to memory is still lit.
    func mask(explored: Set<FogCell>, visible: Set<FogCell>) -> [UInt8] {
        var buffer = [UInt8](repeating: Self.unexploredLevel, count: maskWidth * maskHeight)
        guard maskWidth > 0, maskHeight > 0 else { return buffer }

        for cell in explored where contains(cell) {
            fill(&buffer, cell, Self.rememberedLevel)
        }
        for cell in visible where contains(cell) {
            fill(&buffer, cell, Self.visibleLevel)
        }
        return buffer
    }

    private func fill(_ buffer: inout [UInt8], _ cell: FogCell, _ level: UInt8) {
        let span = edgeTexelsPerCell
        let firstColumn = cell.column * span
        // Row 0 of the buffer is the top of the image, and fog rows count up
        // from the bottom of the world, so the row index inverts here.
        let firstRow = (rows - 1 - cell.row) * span
        for row in firstRow..<(firstRow + span) {
            let start = row * maskWidth + firstColumn
            for index in start..<(start + span) {
                buffer[index] = level
            }
        }
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

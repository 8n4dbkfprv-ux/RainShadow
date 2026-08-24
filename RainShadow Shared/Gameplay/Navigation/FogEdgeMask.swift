import Foundation

/// FOGOWAR-role edge stamps for a fog overlay.
///
/// GemRB's `FogRenderer` fills unexplored / remembered runs with solid black,
/// then blits `FOGOWAR.BAM` frames (N, W, NW, and mirrors) on the boundary of
/// a visible or explored cell. RainShadow cannot ship that BAM. These tiles
/// play the same neighbour-bit role: a short falloff on the outer side of a
/// fog cell, dithered so the edge is a scallop rather than a Gaussian ramp.
///
/// Interiors stay flat. Linear filtering is not part of this compositor.
enum FogEdgeMask {
    static let cellSize = FogGrid.texturePixelsPerCell
    /// Authored falloff at GemRB's 32 px/cell. Scaled with the uploaded cell.
    static let referenceFalloff = 6
    /// Pixels of falloff on the fogged side of an edge. BG:EE indoor clips in a
    /// few pixels; a quarter-cell linear ramp was eight-plus and read as a blob.
    static var falloff: Int {
        max(
            1,
            (referenceFalloff * FogGrid.texturePixelsPerCell + FogGrid.cellPixelSize / 2)
                / FogGrid.cellPixelSize
        )
    }

    /// Expand a one-byte-per-cell state buffer to the overlay texel grid, top row first.
    static func composite(cellLevels: [UInt8], columns: Int, rows: Int) -> [UInt8] {
        let side = cellSize
        let width = columns * side
        let height = rows * side
        let count = width * height
        guard columns > 0, rows > 0, cellLevels.count == columns * rows else {
            return [UInt8](repeating: FogGrid.unexploredLevel, count: max(0, count))
        }

        var buffer = [UInt8](repeating: FogGrid.unexploredLevel, count: count)

        func imageRow(of worldRow: Int) -> Int { rows - 1 - worldRow }

        func level(column: Int, row: Int) -> UInt8 {
            guard column >= 0, column < columns, row >= 0, row < rows else {
                return FogGrid.unexploredLevel
            }
            return cellLevels[imageRow(of: row) * columns + column]
        }

        func fill(column: Int, row: Int, value: UInt8) {
            let x0 = column * side
            let y0 = imageRow(of: row) * side
            for y in y0..<(y0 + side) {
                let start = y * width + x0
                for index in start..<(start + side) {
                    buffer[index] = value
                }
            }
        }

        for row in 0..<rows {
            for column in 0..<columns {
                fill(column: column, row: row, value: level(column: column, row: row))
            }
        }

        for row in 0..<rows {
            for column in 0..<columns {
                let here = level(column: column, row: row)
                if here == FogGrid.visibleLevel {
                    blitEdges(
                        into: &buffer,
                        width: width,
                        column: column,
                        row: row,
                        rows: rows,
                        peak: FogGrid.rememberedLevel,
                        north: level(column: column, row: row + 1) != FogGrid.visibleLevel,
                        south: level(column: column, row: row - 1) != FogGrid.visibleLevel,
                        west: level(column: column - 1, row: row) != FogGrid.visibleLevel,
                        east: level(column: column + 1, row: row) != FogGrid.visibleLevel
                    )
                }
                if here != FogGrid.unexploredLevel {
                    blitEdges(
                        into: &buffer,
                        width: width,
                        column: column,
                        row: row,
                        rows: rows,
                        peak: FogGrid.unexploredLevel,
                        north: level(column: column, row: row + 1) == FogGrid.unexploredLevel,
                        south: level(column: column, row: row - 1) == FogGrid.unexploredLevel,
                        west: level(column: column - 1, row: row) == FogGrid.unexploredLevel,
                        east: level(column: column + 1, row: row) == FogGrid.unexploredLevel
                    )
                }
            }
        }
        return buffer
    }

    private static func blitEdges(
        into buffer: inout [UInt8],
        width: Int,
        column: Int,
        row: Int,
        rows: Int,
        peak: UInt8,
        north: Bool,
        south: Bool,
        west: Bool,
        east: Bool
    ) {
        let side = cellSize
        let x0 = column * side
        let y0 = (rows - 1 - row) * side
        if north { blitNorth(into: &buffer, width: width, x0: x0, y0: y0, peak: peak, flipY: false) }
        if south { blitNorth(into: &buffer, width: width, x0: x0, y0: y0, peak: peak, flipY: true) }
        if west { blitWest(into: &buffer, width: width, x0: x0, y0: y0, peak: peak, flipX: false) }
        if east { blitWest(into: &buffer, width: width, x0: x0, y0: y0, peak: peak, flipX: true) }
    }

    /// N-edge tile: fog along the top of the cell (`y0` is the image top).
    private static func blitNorth(
        into buffer: inout [UInt8],
        width: Int,
        x0: Int,
        y0: Int,
        peak: UInt8,
        flipY: Bool
    ) {
        let side = cellSize
        for y in 0..<side {
            let srcY = flipY ? (side - 1 - y) : y
            let fy = falloff - srcY
            guard fy > 0 else { continue }
            let base = (Int(peak) * fy + falloff / 2) / falloff
            let destY = y0 + y
            for x in 0..<side {
                let dither = ((x ^ srcY) & 1) == 0 ? 0 : -10
                let alpha = UInt8(clamping: base + dither)
                let index = destY * width + x0 + x
                if alpha > buffer[index] {
                    buffer[index] = alpha
                }
            }
        }
    }

    /// W-edge tile: fog along the left of the cell.
    private static func blitWest(
        into buffer: inout [UInt8],
        width: Int,
        x0: Int,
        y0: Int,
        peak: UInt8,
        flipX: Bool
    ) {
        let side = cellSize
        for x in 0..<side {
            let srcX = flipX ? (side - 1 - x) : x
            let fx = falloff - srcX
            guard fx > 0 else { continue }
            let base = (Int(peak) * fx + falloff / 2) / falloff
            let destX = x0 + x
            for y in 0..<side {
                let dither = ((srcX ^ y) & 1) == 0 ? 0 : -10
                let alpha = UInt8(clamping: base + dither)
                let index = (y0 + y) * width + destX
                if alpha > buffer[index] {
                    buffer[index] = alpha
                }
            }
        }
    }
}

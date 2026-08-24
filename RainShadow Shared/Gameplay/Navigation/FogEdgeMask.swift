import Foundation

/// BG:EE corner-smoothed fog overlay.
///
/// The original engine's `BltFogOWar3d` / `GetSubTileCode` builds a 4-bit corner
/// code per 32-px tile from this cell and its east / south / south-east
/// neighbours, then Gouraud-shades a triangle fan: covered corners at the
/// pass's alpha (255 unexplored, 128 shroud), uncovered at 0. The centre vertex
/// is covered when three corners are and clear when only one is. Two, four, or
/// zero covered corners fill the quad from the corners alone.
///
/// Exploration and visibility are separate passes, composited with `max` so
/// unexplored black wins over shroud. Linear filtering is not the edge;
/// interiors stay flat at the three GemRB levels.
enum FogEdgeMask {
    static let cellSize = FogGrid.texturePixelsPerCell

    /// Expand a one-byte-per-cell state buffer to the overlay texel grid, top row first.
    static func composite(cellLevels: [UInt8], columns: Int, rows: Int) -> [UInt8] {
        let side = cellSize
        let width = columns * side
        let height = rows * side
        let count = width * height
        guard columns > 0, rows > 0, cellLevels.count == columns * rows else {
            return [UInt8](repeating: FogGrid.unexploredLevel, count: max(0, count))
        }

        var buffer = [UInt8](repeating: 0, count: count)

        func imageRow(of worldRow: Int) -> Int { rows - 1 - worldRow }

        func level(column: Int, row: Int) -> UInt8 {
            guard column >= 0, column < columns, row >= 0, row < rows else {
                return FogGrid.unexploredLevel
            }
            return cellLevels[imageRow(of: row) * columns + column]
        }

        rasterPass(
            into: &buffer,
            width: width,
            columns: columns,
            rows: rows,
            peak: FogGrid.rememberedLevel,
            covered: { column, row in
                level(column: column, row: row) != FogGrid.visibleLevel
            }
        )
        rasterPass(
            into: &buffer,
            width: width,
            columns: columns,
            rows: rows,
            peak: FogGrid.unexploredLevel,
            covered: { column, row in
                level(column: column, row: row) == FogGrid.unexploredLevel
            }
        )
        return buffer
    }

    private static func rasterPass(
        into buffer: inout [UInt8],
        width: Int,
        columns: Int,
        rows: Int,
        peak: UInt8,
        covered: (Int, Int) -> Bool
    ) {
        let side = cellSize
        let peakValue = Double(peak)
        for row in 0..<rows {
            let y0 = (rows - 1 - row) * side
            for column in 0..<columns {
                // Engine y-down: TL = this tile, TR = east, BL = south, BR = SE.
                // World +row is north, image +y is down, so image-south is world south.
                let nw = covered(column, row)
                let ne = covered(column + 1, row)
                let sw = covered(column, row - 1)
                let se = covered(column + 1, row - 1)
                let corners = [nw, ne, sw, se]
                let count = corners.filter { $0 }.count
                let nwV = nw ? peakValue : 0
                let neV = ne ? peakValue : 0
                let swV = sw ? peakValue : 0
                let seV = se ? peakValue : 0
                let useFan = count == 1 || count == 3
                let centerV = count == 3 ? peakValue : 0.0

                let x0 = column * side
                for dy in 0..<side {
                    for dx in 0..<side {
                        let u = (Double(dx) + 0.5) / Double(side)
                        let v = (Double(dy) + 0.5) / Double(side)
                        let sample: Double
                        if useFan {
                            sample = fanSample(
                                u: u,
                                v: v,
                                nw: nwV,
                                ne: neV,
                                sw: swV,
                                se: seV,
                                center: centerV
                            )
                        } else {
                            sample = (1 - u) * (1 - v) * nwV
                                + u * (1 - v) * neV
                                + (1 - u) * v * swV
                                + u * v * seV
                        }
                        let alpha = UInt8(clamping: Int(sample.rounded()))
                        let index = (y0 + dy) * width + x0 + dx
                        if alpha > buffer[index] {
                            buffer[index] = alpha
                        }
                    }
                }
            }
        }
    }

    /// Triangle fan from the cell centre to the four corners (`BltFogOWar3d`).
    private static func fanSample(
        u: Double,
        v: Double,
        nw: Double,
        ne: Double,
        sw: Double,
        se: Double,
        center: Double
    ) -> Double {
        let du = abs(u - 0.5)
        let dv = abs(v - 0.5)
        if dv >= du {
            if v <= 0.5 {
                return barycentric(u: u, v: v, ax: 0.5, ay: 0.5, av: center, bx: 0, by: 0, bv: nw, cx: 1, cy: 0, cv: ne)
            }
            return barycentric(u: u, v: v, ax: 0.5, ay: 0.5, av: center, bx: 0, by: 1, bv: sw, cx: 1, cy: 1, cv: se)
        }
        if u <= 0.5 {
            return barycentric(u: u, v: v, ax: 0.5, ay: 0.5, av: center, bx: 0, by: 0, bv: nw, cx: 0, cy: 1, cv: sw)
        }
        return barycentric(u: u, v: v, ax: 0.5, ay: 0.5, av: center, bx: 1, by: 0, bv: ne, cx: 1, cy: 1, cv: se)
    }

    private static func barycentric(
        u: Double,
        v: Double,
        ax: Double,
        ay: Double,
        av: Double,
        bx: Double,
        by: Double,
        bv: Double,
        cx: Double,
        cy: Double,
        cv: Double
    ) -> Double {
        let denom = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        guard denom != 0 else { return av }
        let wA = ((by - cy) * (u - cx) + (cx - bx) * (v - cy)) / denom
        let wB = ((cy - ay) * (u - cx) + (ax - cx) * (v - cy)) / denom
        let wC = 1 - wA - wB
        return wA * av + wB * bv + wC * cv
    }
}

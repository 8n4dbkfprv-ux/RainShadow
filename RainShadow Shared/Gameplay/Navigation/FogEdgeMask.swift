import Foundation

/// Software reference for GemRB's raw-geometry fog edge.
///
/// This is a transliteration of GemRB `1c45c185`'s
/// `FogRenderer::DrawFogCellVertices` and `FogRenderer::DrawFogSmoothing`.
/// The runtime copy is GLSL in `FogMaskRenderer`; keeping this copy in the core
/// target makes the topology and alpha arithmetic unit-testable.
///
/// `DrawFogCellVertices` makes four triangles from the centre of a 32×32 cell
/// to its sides. Its cardinal-direction setup is, verbatim:
///
/// ```cpp
/// uint16_t halvingBits = 1 | (1 << 3) | (1 << 6) | (1 << 9);
/// uint16_t fillBits = halvingBits;
/// if ((direction & Direction::N) != Direction::O) {
///     fillBits |= (3 << 1) | (1 << 4) | (1 << 11);
/// }
/// if ((direction & Direction::S) != Direction::O) {
///     fillBits |= (3 << 7) | (1 << 5) | (1 << 10);
/// }
/// if ((direction & Direction::E) != Direction::O) {
///     fillBits |= (3 << 4) | (1 << 2) | (1 << 7);
/// }
/// if ((direction & Direction::W) != Direction::O) {
///     fillBits |= (3 << 10) | (1 << 1) | (1 << 8);
/// }
/// ```
///
/// In other words, every centre duplicate is covered and an outer corner is
/// covered when either incident cardinal direction is fogged. The vertex alpha
/// is then interpolated across the triangle by `DrawRawGeometry`.
///
/// `DrawFogSmoothing` is a second draw. It leaves the centre clear and covers
/// only the duplicate vertices of a diagonally fogged corner. Visibility skips
/// that draw when either incident cardinal edge was already drawn; exploration
/// deliberately does not. North and south corner groups are separate draws, so
/// their overlapping interpolants combine by source-over rather than addition.
/// The two 255/128 passes combine the same way. Using `max`, as the retired
/// raster approximation did, is not the engine's compositor.
enum FogEdgeMask {
    /// `TRANSPARENT_FOG`: byte alpha 128, not the mathematical value 0.5.
    static let rememberedAlpha = Double(FogGrid.rememberedLevel) / 255

    /// Evaluate the final black-overlay alpha in one fog cell.
    ///
    /// `unitX` / `unitY` are local cell coordinates, y-up, in `0...1`.
    /// Cell levels use the three values declared by `FogGrid`; out-of-bounds
    /// neighbours are unexplored, matching `Bitmap::GetAt(p, false)` in GemRB.
    static func alpha(
        cellLevels: [UInt8],
        columns: Int,
        rows: Int,
        column: Int,
        row: Int,
        unitX: Double,
        unitY: Double
    ) -> Double {
        guard columns > 0,
              rows > 0,
              cellLevels.count == columns * rows,
              column >= 0,
              column < columns,
              row >= 0,
              row < rows
        else { return 1 }

        // `FogGrid.mask` is image-row order (top first), while this evaluator
        // and the game's world coordinates are y-up.
        func level(_ x: Int, _ y: Int) -> UInt8 {
            guard x >= 0, x < columns, y >= 0, y < rows else {
                return FogGrid.unexploredLevel
            }
            return cellLevels[(rows - 1 - y) * columns + x]
        }

        let here = level(column, row)
        if here == FogGrid.unexploredLevel { return 1 }

        let x = min(1, max(0, unitX))
        let y = min(1, max(0, unitY))

        let north = level(column, row + 1)
        let east = level(column + 1, row)
        let south = level(column, row - 1)
        let west = level(column - 1, row)
        let northWest = level(column - 1, row + 1)
        let northEast = level(column + 1, row + 1)
        let southEast = level(column + 1, row - 1)
        let southWest = level(column - 1, row - 1)

        var output = here == FogGrid.rememberedLevel ? rememberedAlpha : 0

        // `DrawVisibleCell`: shroud around a currently visible cell.
        if here == FogGrid.visibleLevel {
            let n = north != FogGrid.visibleLevel
            let e = east != FogGrid.visibleLevel
            let s = south != FogGrid.visibleLevel
            let w = west != FogGrid.visibleLevel
            output = sourceOver(
                output,
                cardinalGeometry(
                    x: x, y: y, north: n, east: e, south: s, west: w,
                    peak: rememberedAlpha
                )
            )

            // `DrawFogSmoothing(..., adjacentDir: dirs)`: a diagonal is used
            // only when neither incident cardinal was already used.
            let nw = northWest != FogGrid.visibleLevel && !n && !w
            let ne = northEast != FogGrid.visibleLevel && !n && !e
            let se = southEast != FogGrid.visibleLevel && !s && !e
            let sw = southWest != FogGrid.visibleLevel && !s && !w
            output = sourceOver(
                output,
                cornerGeometry(
                    x: x, y: y, northWest: nw, northEast: ne,
                    southEast: false, southWest: false,
                    peak: rememberedAlpha
                )
            )
            output = sourceOver(
                output,
                cornerGeometry(
                    x: x, y: y, northWest: false, northEast: false,
                    southEast: se, southWest: sw,
                    peak: rememberedAlpha
                )
            )
        }

        // `DrawExploredCell`: opaque fog around every explored cell, including
        // a visible one. Its smoothing calls pass `adjacentDir: O`, so no
        // diagonal is suppressed even when a cardinal draw overlaps it.
        let n = north == FogGrid.unexploredLevel
        let e = east == FogGrid.unexploredLevel
        let s = south == FogGrid.unexploredLevel
        let w = west == FogGrid.unexploredLevel
        output = sourceOver(
            output,
            cardinalGeometry(x: x, y: y, north: n, east: e, south: s, west: w, peak: 1)
        )
        output = sourceOver(
            output,
            cornerGeometry(
                x: x, y: y,
                northWest: northWest == FogGrid.unexploredLevel,
                northEast: northEast == FogGrid.unexploredLevel,
                southEast: false,
                southWest: false,
                peak: 1
            )
        )
        output = sourceOver(
            output,
            cornerGeometry(
                x: x, y: y,
                northWest: false,
                northEast: false,
                southEast: southEast == FogGrid.unexploredLevel,
                southWest: southWest == FogGrid.unexploredLevel,
                peak: 1
            )
        )
        return min(1, max(0, output))
    }

    /// One `DrawFogCellVertices` draw. The centre of all four fan triangles is
    /// at `peak`; each outer corner is at `peak` when either incident cardinal
    /// direction is present and clear otherwise.
    private static func cardinalGeometry(
        x: Double,
        y: Double,
        north: Bool,
        east: Bool,
        south: Bool,
        west: Bool,
        peak: Double
    ) -> Double {
        guard north || east || south || west else { return 0 }
        let dx = abs(x - 0.5)
        let dy = abs(y - 0.5)

        if dy >= dx {
            if y >= 0.5 { // centre, NW, NE
                let center = 2 * (1 - y)
                let nw = y - x
                let ne = x + y - 1
                return peak * (
                    center
                        + ((north || west) ? nw : 0)
                        + ((north || east) ? ne : 0)
                )
            }
            // centre, SE, SW
            let center = 2 * y
            let se = x - y
            let sw = 1 - x - y
            return peak * (
                center
                    + ((south || east) ? se : 0)
                    + ((south || west) ? sw : 0)
            )
        }

        if x >= 0.5 { // centre, NE, SE
            let center = 2 * (1 - x)
            let ne = x + y - 1
            let se = x - y
            return peak * (
                center
                    + ((north || east) ? ne : 0)
                    + ((south || east) ? se : 0)
            )
        }
        // centre, SW, NW
        let center = 2 * x
        let sw = 1 - x - y
        let nw = y - x
        return peak * (
            center
                + ((south || west) ? sw : 0)
                + ((north || west) ? nw : 0)
        )
    }

    /// One `DrawFogSmoothing` draw. The centre is clear; only selected corner
    /// duplicates carry `peak`.
    private static func cornerGeometry(
        x: Double,
        y: Double,
        northWest: Bool,
        northEast: Bool,
        southEast: Bool,
        southWest: Bool,
        peak: Double
    ) -> Double {
        guard northWest || northEast || southEast || southWest else { return 0 }
        let dx = abs(x - 0.5)
        let dy = abs(y - 0.5)

        if dy >= dx {
            if y >= 0.5 {
                return peak * (
                    (northWest ? y - x : 0)
                        + (northEast ? x + y - 1 : 0)
                )
            }
            return peak * (
                (southEast ? x - y : 0)
                    + (southWest ? 1 - x - y : 0)
            )
        }
        if x >= 0.5 {
            return peak * (
                (northEast ? x + y - 1 : 0)
                    + (southEast ? x - y : 0)
            )
        }
        return peak * (
            (southWest ? 1 - x - y : 0)
                + (northWest ? y - x : 0)
        )
    }

    /// Black source-over black. Draw order cannot change this alpha result.
    private static func sourceOver(_ destination: Double, _ source: Double) -> Double {
        destination + source * (1 - destination)
    }
}

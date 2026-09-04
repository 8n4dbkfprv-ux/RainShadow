import CoreGraphics
import Foundation

/// The wall stencil (GemRB `core/Map.cpp`, `Map::DrawStencil`).
///
/// The Infinity Engine does not sort scenery against creatures. Painted mass is
/// marked in the WED by wall polygons, and a creature standing behind one is not
/// hidden — the engine draws the creature *over* the background and masks it
/// through a stencil, so the wall reads as in front while the silhouette still
/// shows. This is that stencil.
///
/// ```cpp
/// void Map::DrawStencil(const VideoBufferPtr& stencilBuffer,
///                       const Region& vp,
///                       const WallPolygonGroup& walls) const
/// {
///     Color stencilcol(0, 0, 0xff, 0x80);
///     VideoDriver->PushDrawingBuffer(stencilBuffer);
///
///     for (const auto& wp : walls) {
///         const Point& origin = wp->BBox.origin - vp.origin;
///
///         if (wp->wallFlag & WF_DITHER) {
///             stencilcol.r = 0x80;
///         } else {
///             stencilcol.r = 0xff;
///         }
///
///         if (wp->wallFlag & WF_COVERANIMS) {
///             stencilcol.g = stencilcol.r;
///         } else {
///             stencilcol.g = 0;
///         }
///
///         VideoDriver->DrawPolygon(wp.get(), origin, stencilcol, true);
///     }
///
///     VideoDriver->PopDrawingBuffer();
/// }
/// ```
///
/// **What RainShadow replaces, and why it is an improvement rather than a
/// rewrite.** `ActorCover` dropped the *whole* actor to alpha 0.42 whenever its
/// ground point fell inside any covering polygon. Upstream masks per pixel, so a
/// character half-behind a pillar keeps their exposed half fully opaque; ours
/// went translucent head to toe. The z-lift `ActorCover` also applied was
/// correct and is kept — upstream likewise draws the actor *after* the
/// background, and the stencil is what puts the wall back in front.
///
/// **One deliberate deviation: this is baked once per area, in area space.**
/// Upstream rebuilds the stencil per viewport every frame because it works in
/// screen space and its walls can be disabled (`WF_DISABLED` doors). RainShadow's
/// covering outlines are authored world-space geometry that never moves, so a
/// per-frame rebuild would recompute a constant. The cost is that a future
/// openable wall polygon would need the mask invalidating; there is none today.
enum AreaWallStencil {
    /// Channel values, straight from `stencilcol`.
    enum Channel {
        /// `stencilcol.r` when `WF_DITHER` is set — the wall only dithers.
        static let dithered: UInt8 = 0x80
        /// `stencilcol.r` when it is not — the wall hides outright.
        static let solid: UInt8 = 0xFF
        /// `stencilcol.b`, always opaque.
        static let blue: UInt8 = 0xFF
        /// `stencilcol.a`, always the 50% dither.
        static let alpha: UInt8 = 0x80
    }

    /// A rasterised mask in area space, row-major from the world's minimum
    /// corner — the same orientation `AreaSearchMapLoader` and `AreaLightMap`
    /// use, so all three index alike.
    struct Mask: Equatable, Sendable {
        let columns: Int
        let rows: Int
        /// World rect the mask spans. Sampling is `(point - origin) / size`.
        let worldFrame: CGRect
        /// RGBA, four bytes per cell, **not** premultiplied: these are flag
        /// channels, not a colour.
        let rgba: [UInt8]

        var isEmpty: Bool { rgba.allSatisfy { $0 == 0 } }

        /// The four channels at a world point, or all-zero outside the mask.
        func sample(at point: CGPoint) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            guard columns > 0, rows > 0, worldFrame.width > 0, worldFrame.height > 0 else {
                return (0, 0, 0, 0)
            }
            let u = (point.x - worldFrame.minX) / worldFrame.width
            let v = (point.y - worldFrame.minY) / worldFrame.height
            guard (0..<1).contains(u), (0..<1).contains(v) else { return (0, 0, 0, 0) }
            let column = min(columns - 1, max(0, Int(u * CGFloat(columns))))
            let row = min(rows - 1, max(0, Int(v * CGFloat(rows))))
            let index = (row * columns + column) * 4
            return (rgba[index], rgba[index + 1], rgba[index + 2], rgba[index + 3])
        }
    }

    /// Finest resolution of the baked mask, in world units per cell.
    ///
    /// One unit per cell, not the search map's 16x12: the search map answers
    /// "can a body stand here", which is a body-sized question, while this
    /// answers "is this *pixel* behind the wall". At 16x12 a wall edge would
    /// staircase in visible 16-unit steps across a silhouette about 70 units
    /// tall.
    static let finestWorldUnitsPerCell: CGFloat = 1

    /// Largest edge of a baked mask, in cells.
    ///
    /// A ward is 5120x3840 world units. At one unit per cell that is 19.7M cells
    /// and a **78 MB** texture — which froze area entry for two minutes before
    /// this cap existed. Coarsening to fit keeps Sable Row near 2.5 units per
    /// cell, about 2.3 points at play zoom, which is a staircase you have to look
    /// for on a wall edge. The office is far smaller than the cap and stays at
    /// one unit per cell.
    ///
    /// The dither itself is screen-space (`gl_FragCoord`), so this resolution
    /// only has to resolve *edges*, not the pattern.
    static let maximumMaskDimension = 2048

    /// Cell size for an area of this size, at or coarser than
    /// ``finestWorldUnitsPerCell``.
    static func worldUnitsPerCell(for worldFrame: CGRect) -> CGFloat {
        let longestEdge = max(worldFrame.width, worldFrame.height)
        guard longestEdge > 0 else { return finestWorldUnitsPerCell }
        let needed = longestEdge / CGFloat(maximumMaskDimension)
        return max(finestWorldUnitsPerCell, needed.rounded(.up))
    }

    /// Rasterise every covering outline into the four-channel encoding.
    ///
    /// Only `coversActors` polygons are drawn at all. Upstream reaches the same
    /// place differently — it collects walls into groups and passes the covering
    /// ones — but the encoding below is the part that has to match, because it is
    /// what the shader reads.
    ///
    /// `actorHeight` exists because ``AreaWallPolygon/height`` does: a kerb or a
    /// safe is a covering outline that is not tall enough to hide a standing
    /// adult, and `coversActor(at:height:)` already encodes that rule. Baking
    /// ignores it and every low wall would stipple anyone who walked past.
    ///
    /// It is a **reference** height rather than a per-actor one, because a
    /// raster cannot answer per-actor questions — which is a real, if narrow,
    /// deviation: a child NPC and an adult get the same mask. Upstream has no
    /// equivalent problem because it uses a wall *baseline* (`PointBehind`) and
    /// asks per object at draw time. If a shorter actor ever needs its own
    /// answer, the fix is a second mask, not a finer encoding.
    static func bake(
        wallPolygons: [AreaWallPolygon],
        worldFrame: CGRect,
        actorHeight: CGFloat = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
    ) -> Mask {
        let covering = wallPolygons.filter { wall in
            wall.coversActors && (wall.height <= 0 || wall.height >= actorHeight * 0.4)
        }
        let cell = worldUnitsPerCell(for: worldFrame)
        let columns = max(1, Int((worldFrame.width / cell).rounded(.up)))
        let rows = max(1, Int((worldFrame.height / cell).rounded(.up)))
        var rgba = [UInt8](repeating: 0, count: columns * rows * 4)

        guard !covering.isEmpty else {
            return Mask(columns: columns, rows: rows, worldFrame: worldFrame, rgba: rgba)
        }

        // One coverage pass per polygon, because the channel values depend on
        // that polygon's own flags — but only over that polygon's own bounding
        // box. Rasterising each one across the whole area instead is what made a
        // ward take two minutes: 86 covering masses times 19.7M cells.
        for wall in covering {
            guard let tile = rasterise(
                polygon: wall.polygon,
                worldFrame: worldFrame,
                cell: cell,
                columns: columns,
                rows: rows
            ) else { continue }

            // `stencilcol.r`
            let red = wall.dithers ? Channel.dithered : Channel.solid
            // `stencilcol.g = stencilcol.r` for WF_COVERANIMS, else 0. Every
            // polygon here is a covering one, so green always follows red.
            let green = red

            for row in 0..<tile.rows {
                for column in 0..<tile.columns where tile.coverage[row * tile.columns + column] != 0 {
                    // Later walls overwrite earlier ones, as upstream's
                    // successive `DrawPolygon` calls into one buffer do.
                    let base = ((tile.originRow + row) * columns + tile.originColumn + column) * 4
                    rgba[base] = red
                    rgba[base + 1] = green
                    rgba[base + 2] = Channel.blue
                    rgba[base + 3] = Channel.alpha
                }
            }
        }

        return Mask(columns: columns, rows: rows, worldFrame: worldFrame, rgba: rgba)
    }

    /// One polygon's coverage, clipped to its own bounding box.
    private struct Tile {
        let originColumn: Int
        let originRow: Int
        let columns: Int
        let rows: Int
        /// 8-bit coverage, y-up from the tile's minimum corner.
        let coverage: [UInt8]
    }

    /// Fill one polygon into an 8-bit coverage buffer covering only its bounding
    /// box, y-up from the world's minimum corner.
    private static func rasterise(
        polygon: [AreaPoint],
        worldFrame: CGRect,
        cell: CGFloat,
        columns: Int,
        rows: Int
    ) -> Tile? {
        guard polygon.count >= 3 else { return nil }
        let bounds = polygon.outlineBoundingBox.intersection(worldFrame)
        guard !bounds.isNull, !bounds.isEmpty else { return nil }

        // Widen by a cell each way so a polygon edge landing mid-cell is not
        // clipped by the tile that is supposed to contain it.
        let originColumn = max(0, Int(((bounds.minX - worldFrame.minX) / cell).rounded(.down)) - 1)
        let originRow = max(0, Int(((bounds.minY - worldFrame.minY) / cell).rounded(.down)) - 1)
        let endColumn = min(columns, Int(((bounds.maxX - worldFrame.minX) / cell).rounded(.up)) + 1)
        let endRow = min(rows, Int(((bounds.maxY - worldFrame.minY) / cell).rounded(.up)) + 1)
        let tileColumns = endColumn - originColumn
        let tileRows = endRow - originRow
        guard tileColumns > 0, tileRows > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: tileColumns * tileRows)
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: tileColumns,
                height: tileRows,
                bitsPerComponent: 8,
                bytesPerRow: tileColumns,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            // No antialiasing: these are flag values. A half-covered edge cell
            // must be in or out, or the shader reads a red channel that is
            // neither 0x80 nor 0xFF and matches no wall state.
            context.setShouldAntialias(false)
            context.setFillColor(gray: 1, alpha: 1)
            let path = CGMutablePath()
            let points = polygon.map { vertex in
                CGPoint(
                    x: (vertex.cgPoint.x - worldFrame.minX) / cell - CGFloat(originColumn),
                    y: (vertex.cgPoint.y - worldFrame.minY) / cell - CGFloat(originRow)
                )
            }
            path.addLines(between: points)
            path.closeSubpath()
            context.addPath(path)
            context.fillPath()
            return true
        }
        guard drawn else { return nil }

        // `CGBitmapContext` stores row 0 as the **top** of the image, while this
        // mask is row-major y-up from the world's minimum corner — the
        // orientation `AreaSearchMapLoader` and `AreaLightMap` already use, so
        // all three index alike. Flip once here rather than compensating at every
        // read: a flipped mask applies cover to the mirror image of the scenery,
        // which looks plausible in a symmetric room and is wrong everywhere else.
        var flipped = [UInt8](repeating: 0, count: buffer.count)
        for row in 0..<tileRows {
            let source = (tileRows - 1 - row) * tileColumns
            let destination = row * tileColumns
            flipped[destination..<(destination + tileColumns)] =
                buffer[source..<(source + tileColumns)]
        }
        return Tile(
            originColumn: originColumn,
            originRow: originRow,
            columns: tileColumns,
            rows: tileRows,
            coverage: flipped
        )
    }
}

extension AreaDefinition {
    /// This area's baked wall stencil, spanning the world the plate covers.
    func makeWallStencil(
        actorHeight: CGFloat = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
    ) -> AreaWallStencil.Mask {
        AreaWallStencil.bake(
            wallPolygons: wallPolygons,
            worldFrame: CGRect(
                origin: worldOrigin.cgPoint,
                size: CGSize(width: worldSize.w, height: worldSize.h)
            ),
            actorHeight: actorHeight
        )
    }
}

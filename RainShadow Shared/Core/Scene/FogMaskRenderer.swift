import CoreGraphics
import Foundation
import os
import SpriteKit

/// Turns an area's two fog bitmaps into the state texture drawn over it.
///
/// The uploaded texture is deliberately *not* a picture of the fog. It is one
/// categorical texel per 32×32 `FogGrid` cell: red 255 / 128 / 0 for unexplored,
/// remembered, and visible, with opaque alpha so `SKDefaultShading().a` carries
/// node opacity independently of state. Nearest sampling is correct for this
/// lookup texture; `FogGeometryShader` evaluates the edge continuously at every
/// output fragment.
///
/// That split replaces the retired 8×8-per-cell mask. The old mask uploaded and
/// enlarged a tiny raster, making one fog texel roughly ten device pixels in an
/// outdoor area. This path uploads fewer texels (one per cell) and has no baked
/// edge resolution at all. A 5120×3840 ward uploads 160×120×4 = 76,800 bytes,
/// versus the former 1,280×960×4 = 4,915,200-byte edge texture (64× smaller).
final class FogMaskRenderer {
    let grid: FogGrid
    private var cellScratch: [UInt8] = []
    private var rgbaScratch: [UInt8] = []

    init(grid: FogGrid) {
        self.grid = grid
    }

    /// Where the mask hangs in the world. The grid rounds up to whole fog cells,
    /// so this can overhang the area's own size by less than a cell — which is
    /// correct, and the alternative is not: squeezing the mask onto the area's
    /// exact extent would slide every state cell off the ground it describes.
    var worldFrame: CGRect {
        CGRect(origin: grid.origin, size: grid.worldSize)
    }

    /// One shader instance per sprite because uniforms belong to the instance.
    func makeShader() -> SKShader {
        Self.makeShader(gridSize: CGSize(width: grid.columns, height: grid.rows))
    }

    /// The local-area map draws the same state bitmap at a different size, so it
    /// uses the same geometry shader with the texture's own cell dimensions.
    static func makeShader(gridSize: CGSize) -> SKShader {
        let shader = SKShader(source: FogGeometryShader.source)
        shader.uniforms = [
            SKUniform(
                name: FogGeometryShader.gridSizeUniform,
                vectorFloat2: vector_float2(Float(gridSize.width), Float(gridSize.height))
            )
        ]
        return shader
    }

    func makeTexture(explored: Set<FogCell>, visible: Set<FogCell>) -> SKTexture? {
        makeTexture(stateLevels: grid.mask(explored: explored, visible: visible))
    }

    /// Rebuild the one-texel-per-cell state texture, reusing the cell and RGBA
    /// scratch buffers. No output-resolution or plate-resolution mask is built.
    func makeTexture(
        explored: Set<FogCell>,
        visible: Set<FogCell>,
        lastCellMask: inout [UInt8]
    ) -> SKTexture? {
        let cellCount = grid.maskWidth * grid.maskHeight
        if cellScratch.count != cellCount {
            cellScratch = [UInt8](repeating: FogGrid.unexploredLevel, count: cellCount)
        } else {
            cellScratch.withUnsafeMutableBufferPointer {
                $0.update(repeating: FogGrid.unexploredLevel)
            }
        }
        grid.writeMask(explored: explored, visible: visible, into: &cellScratch)
        guard cellScratch != lastCellMask else { return nil }
        lastCellMask = cellScratch
        return makeTexture(stateLevels: cellScratch)
    }

    private func makeTexture(stateLevels: [UInt8]) -> SKTexture? {
        #if DEBUG
        let signpostID = OSSignpostID(log: Self.fogLog)
        os_signpost(.begin, log: Self.fogLog, name: "makeTexture", signpostID: signpostID)
        defer {
            os_signpost(.end, log: Self.fogLog, name: "makeTexture", signpostID: signpostID)
        }
        #endif

        let width = grid.columns
        let height = grid.rows
        guard width > 0, height > 0, stateLevels.count == width * height else { return nil }

        let rgbaCount = stateLevels.count * 4
        if rgbaScratch.count != rgbaCount {
            rgbaScratch = [UInt8](repeating: 0, count: rgbaCount)
        } else {
            rgbaScratch.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        }

        // `FogGrid.mask` is image-order (top row first). `SKTexture(data:)` is
        // addressed y-up by `v_tex_coord`, like the baked wall stencil, so flip
        // to world-row order once at the upload boundary.
        for worldRow in 0..<height {
            let sourceRow = height - 1 - worldRow
            for column in 0..<width {
                let source = sourceRow * width + column
                let destination = (worldRow * width + column) * 4
                rgbaScratch[destination] = stateLevels[source]
                rgbaScratch[destination + 3] = 255
            }
        }

        let texture = SKTexture(
            data: Data(rgbaScratch),
            size: CGSize(width: width, height: height)
        )
        // Categorical state lookup, not image reconstruction. The shader owns
        // every interpolated edge value.
        texture.filteringMode = .nearest
        return texture
    }

    #if DEBUG
    private static let fogLog = OSLog(subsystem: "RainShadow", category: "FogMask")
    #endif
}

/// GemRB's raw fog geometry, evaluated as a SpriteKit fragment shader.
///
/// This is the second transliteration of pinned GemRB `1c45c185`:
///
/// - `fogCardinalGeometry` is `FogRenderer::DrawFogCellVertices` after
///   `SetFogVerticesByOrigin` divides the cell into its four triangle fans.
/// - `fogCornerGeometry` is `FogRenderer::DrawFogSmoothing`.
/// - `main` follows `DrawVisibleCell` and then `DrawExploredCell`, including
///   visible-pass diagonal suppression and exploration's unsuppressed diagonal
///   draw.
/// - `fogSourceOver` is successive `DrawRawGeometry(..., BlitFlags::BLENDED)`;
///   the 128 and 255 passes are not a `max` operation.
///
/// `FogEdgeMask` is the readable Swift copy and its tests hold the arithmetic.
/// `ArtSource/Processing/qa_fog_geometry_shader.swift` holds this GLSL copy to
/// an independent upstream-vertex reference through actual SpriteKit readback.
/// This shader exists because SpriteKit has no public raw-vertex node with
/// per-vertex colours. It produces the same interpolated triangle alpha at the
/// output fragment instead of baking those triangles into a texture first.
private enum FogGeometryShader {
    static let gridSizeUniform = "u_fog_grid_size"

    static let source = """
    // SpriteKit injects texture/uniform parameters into main only. Keep helper
    // functions pure and pass their values; sampling a uniform from a helper
    // compiles as undeclared identifiers in SpriteKit's generated Metal.
    float fogState(float sampledState, vec2 cell, vec2 gridSize) {
        if (cell.x < 0.0 || cell.y < 0.0
            || cell.x >= gridSize.x || cell.y >= gridSize.y) {
            // GemRB: mask->GetAt(p, false), so out of bounds is covered.
            return 1.0;
        }
        return sampledState;
    }

    float fogIsUnexplored(float state) {
        // The texture is categorical. Wide thresholds also survive a backend
        // presenting its unorm red channel through an sRGB sampling view.
        return step(0.9, state);
    }

    float fogIsVisible(float state) {
        return 1.0 - step(0.1, state);
    }

    float fogSourceOver(float destination, float source) {
        return destination + source * (1.0 - destination);
    }

    // FogRenderer::DrawFogCellVertices. Centre alpha is always `peak`; an
    // outer corner has `peak` when either incident cardinal bit is present.
    float fogCardinalGeometry(
        vec2 p, float north, float east, float south, float west, float peak
    ) {
        if (north + east + south + west < 0.5) return 0.0;
        vec2 delta = abs(p - vec2(0.5));

        if (delta.y >= delta.x) {
            if (p.y >= 0.5) {
                float center = 2.0 * (1.0 - p.y);
                float nw = p.y - p.x;
                float ne = p.x + p.y - 1.0;
                return peak * (
                    center + max(north, west) * nw + max(north, east) * ne
                );
            }
            float center = 2.0 * p.y;
            float se = p.x - p.y;
            float sw = 1.0 - p.x - p.y;
            return peak * (
                center + max(south, east) * se + max(south, west) * sw
            );
        }

        if (p.x >= 0.5) {
            float center = 2.0 * (1.0 - p.x);
            float ne = p.x + p.y - 1.0;
            float se = p.x - p.y;
            return peak * (
                center + max(north, east) * ne + max(south, east) * se
            );
        }
        float center = 2.0 * p.x;
        float sw = 1.0 - p.x - p.y;
        float nw = p.y - p.x;
        return peak * (
            center + max(south, west) * sw + max(north, west) * nw
        );
    }

    // One FogRenderer::DrawFogSmoothing draw: clear centre, selected corners.
    float fogCornerGeometry(
        vec2 p, float nwOn, float neOn, float seOn, float swOn, float peak
    ) {
        if (nwOn + neOn + seOn + swOn < 0.5) return 0.0;
        vec2 delta = abs(p - vec2(0.5));

        if (delta.y >= delta.x) {
            if (p.y >= 0.5) {
                return peak * (nwOn * (p.y - p.x) + neOn * (p.x + p.y - 1.0));
            }
            return peak * (seOn * (p.x - p.y) + swOn * (1.0 - p.x - p.y));
        }
        if (p.x >= 0.5) {
            return peak * (neOn * (p.x + p.y - 1.0) + seOn * (p.x - p.y));
        }
        return peak * (swOn * (1.0 - p.x - p.y) + nwOn * (p.y - p.x));
    }

    void main() {
        vec2 scaled = v_tex_coord * u_fog_grid_size;
        vec2 bounded = min(
            max(scaled, vec2(0.0)),
            u_fog_grid_size - vec2(0.0001)
        );
        vec2 cell = floor(bounded);
        vec2 p = clamp(scaled - cell, vec2(0.0), vec2(1.0));

        vec2 uv = (cell + vec2(0.5)) / u_fog_grid_size;
        vec2 texel = vec2(1.0) / u_fog_grid_size;
        float here = texture2D(u_texture, uv).r;
        float unexploredHere = fogIsUnexplored(here);
        float visibleHere = fogIsVisible(here);
        float shroudPeak = 128.0 / 255.0;
        float alpha = unexploredHere > 0.5
            ? 1.0
            : (visibleHere > 0.5 ? 0.0 : shroudPeak);

        if (unexploredHere < 0.5) {
            float northState = fogState(
                texture2D(u_texture, uv + vec2(0.0, texel.y)).r,
                cell + vec2(0.0, 1.0), u_fog_grid_size
            );
            float eastState = fogState(
                texture2D(u_texture, uv + vec2(texel.x, 0.0)).r,
                cell + vec2(1.0, 0.0), u_fog_grid_size
            );
            float southState = fogState(
                texture2D(u_texture, uv - vec2(0.0, texel.y)).r,
                cell + vec2(0.0, -1.0), u_fog_grid_size
            );
            float westState = fogState(
                texture2D(u_texture, uv - vec2(texel.x, 0.0)).r,
                cell + vec2(-1.0, 0.0), u_fog_grid_size
            );
            float nwState = fogState(
                texture2D(u_texture, uv + vec2(-texel.x, texel.y)).r,
                cell + vec2(-1.0, 1.0), u_fog_grid_size
            );
            float neState = fogState(
                texture2D(u_texture, uv + texel).r,
                cell + vec2(1.0, 1.0), u_fog_grid_size
            );
            float seState = fogState(
                texture2D(u_texture, uv + vec2(texel.x, -texel.y)).r,
                cell + vec2(1.0, -1.0), u_fog_grid_size
            );
            float swState = fogState(
                texture2D(u_texture, uv - texel).r,
                cell + vec2(-1.0, -1.0), u_fog_grid_size
            );

            // DrawVisibleCell: `dirs` is the non-visible cardinal set.
            if (visibleHere > 0.5) {
                float n = 1.0 - fogIsVisible(northState);
                float e = 1.0 - fogIsVisible(eastState);
                float s = 1.0 - fogIsVisible(southState);
                float w = 1.0 - fogIsVisible(westState);
                alpha = fogSourceOver(
                    alpha,
                    fogCardinalGeometry(p, n, e, s, w, shroudPeak)
                );

                // DrawFogSmoothing(..., adjacentDir: dirs): suppress a corner
                // when either incident cardinal edge already carries shroud.
                float nw = (1.0 - fogIsVisible(nwState)) * (1.0 - n) * (1.0 - w);
                float ne = (1.0 - fogIsVisible(neState)) * (1.0 - n) * (1.0 - e);
                float se = (1.0 - fogIsVisible(seState)) * (1.0 - s) * (1.0 - e);
                float sw = (1.0 - fogIsVisible(swState)) * (1.0 - s) * (1.0 - w);
                alpha = fogSourceOver(
                    alpha,
                    fogCornerGeometry(p, nw, ne, 0.0, 0.0, shroudPeak)
                );
                alpha = fogSourceOver(
                    alpha,
                    fogCornerGeometry(p, 0.0, 0.0, se, sw, shroudPeak)
                );
            }

            // DrawExploredCell: opaque cardinal and unsuppressed diagonal passes.
            float n = fogIsUnexplored(northState);
            float e = fogIsUnexplored(eastState);
            float s = fogIsUnexplored(southState);
            float w = fogIsUnexplored(westState);
            alpha = fogSourceOver(alpha, fogCardinalGeometry(p, n, e, s, w, 1.0));
            alpha = fogSourceOver(
                alpha,
                fogCornerGeometry(
                    p, fogIsUnexplored(nwState), fogIsUnexplored(neState), 0.0, 0.0, 1.0
                )
            );
            alpha = fogSourceOver(
                alpha,
                fogCornerGeometry(
                    p, 0.0, 0.0, fogIsUnexplored(seState), fogIsUnexplored(swState), 1.0
                )
            );
        }

        // Every state texel is opaque, so this is node/tree opacity only.
        float nodeOpacity = SKDefaultShading().a;
        alpha = clamp(alpha * nodeOpacity, 0.0, 1.0);
        gl_FragColor = vec4(0.0, 0.0, 0.0, alpha);
    }
    """
}

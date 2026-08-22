import CoreGraphics
import Foundation
import SpriteKit

/// Turns an area's two fog bitmaps into the texture drawn over it.
///
/// There is no painting here any more, and that is the point. This used to
/// compose a hand-wobbled circle out of four feathered rings, clip it to the
/// cells sight reached, erase it through a remembered layer with
/// `destinationOut`, lift that layer back up with `destinationOver`, and run a
/// Gaussian blur over the result to hide the staircase the clip left behind —
/// two coordinate systems, two shapes, and a blur apologising for the seam
/// between them. The Infinity Engine draws fog by reading its two bitmaps and
/// filling cells, and once the bitmaps are real that is all there is to do: the
/// texture *is* `FogGrid.mask`, one texel per level, and linear filtering turns
/// the one-texel step at a cell boundary into the soft edge the engine gets from
/// the edge and corner frames of its `fogowar` BAM.
///
/// What remains is the pixel format. `FogGrid` answers in levels because levels
/// are testable; a level is an alpha, and the fog is black, so every texel is
/// `(0, 0, 0, level)` premultiplied.
struct FogMaskRenderer {
    let grid: FogGrid

    init(grid: FogGrid) {
        self.grid = grid
    }

    /// Where the mask hangs in the world. The grid rounds up to whole fog cells,
    /// so this can overhang the area's own size by less than a cell — which is
    /// correct, and the alternative is not: squeezing the mask onto the area's
    /// exact extent would slide every texel off the cell it stands for.
    var worldFrame: CGRect {
        CGRect(origin: grid.origin, size: grid.worldSize)
    }

    func makeTexture(explored: Set<FogCell>, visible: Set<FogCell>) -> SKTexture? {
        let levels = grid.mask(explored: explored, visible: visible)
        guard let image = makeImage(levels: levels) else { return nil }
        let texture = SKTexture(cgImage: image)
        // The whole edge treatment, in one line: a fog cell is four texels
        // across and the boundary between two levels is a single texel step, so
        // linear sampling spreads it over a quarter of a cell.
        texture.filteringMode = .linear
        return texture
    }

    private func makeImage(levels: [UInt8]) -> CGImage? {
        let width = grid.maskWidth
        let height = grid.maskHeight
        guard width > 0, height > 0, levels.count == width * height else { return nil }

        var rgba = [UInt8](repeating: 0, count: levels.count * 4)
        for (texel, level) in levels.enumerated() {
            // Black premultiplied by any alpha is still black, so only the
            // alpha byte carries anything.
            rgba[texel * 4 + 3] = level
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}

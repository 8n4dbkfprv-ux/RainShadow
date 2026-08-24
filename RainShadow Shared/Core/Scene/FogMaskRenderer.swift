import CoreGraphics
import Foundation
import os
import SpriteKit

/// Turns an area's two fog bitmaps into the texture drawn over it.
///
/// GemRB's `FogRenderer` fills unexplored and remembered runs with solid black
/// and shades `FOGOWAR` on the boundary. The texture here is that compositor:
/// `FogGrid.displayMask` is `texturePixelsPerCell` screen texels per fog cell,
/// interiors flat at the three GemRB levels, edges from BG:EE corner fans.
/// Linear filtering is not the edge. Nearest sampling keeps the tile the
/// engine drew, stretched over `worldFrame`.
///
/// `FogGrid` answers in levels because levels are testable; a level is an
/// alpha, and the fog is black, so every texel is `(0, 0, 0, level)`
/// premultiplied.
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
        let levels = grid.displayMask(explored: explored, visible: visible)
        return makeTexture(displayLevels: levels)
    }

    func makeTexture(displayLevels: [UInt8]) -> SKTexture? {
        #if DEBUG
        let signpostID = OSSignpostID(log: Self.fogLog)
        os_signpost(.begin, log: Self.fogLog, name: "makeTexture", signpostID: signpostID)
        defer {
            os_signpost(.end, log: Self.fogLog, name: "makeTexture", signpostID: signpostID)
        }
        #endif
        guard let image = makeImage(levels: displayLevels) else { return nil }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }

    private func makeImage(levels: [UInt8]) -> CGImage? {
        let width = grid.columns * FogGrid.texturePixelsPerCell
        let height = grid.rows * FogGrid.texturePixelsPerCell
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
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    #if DEBUG
    private static let fogLog = OSLog(subsystem: "RainShadow", category: "FogMask")
    #endif
}

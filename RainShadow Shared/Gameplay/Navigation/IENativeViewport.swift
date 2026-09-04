import CoreGraphics

/// Presentation adapter: a native world raster followed by ONE whole-buffer
/// zoom. The engine's zoom ladder/clamp are unchanged. Region::Scale truncates
/// viewport dimensions (`int newW = w * percent / 100`); no per-actor zoom or
/// backing-scale factor enters this raster. Camera state itself is not rounded.
struct IENativeViewport: Equatable {
    let width: Int
    let height: Int
    let unitsPerPixel: CGFloat
    let worldRect: CGRect

    init(viewSize: CGSize, cameraCenter: CGPoint, cameraScale: CGFloat, nativeScale: CGFloat) {
        precondition(nativeScale > 0 && cameraScale > 0)
        width = max(1, Int(viewSize.width * cameraScale / nativeScale))
        height = max(1, Int(viewSize.height * cameraScale / nativeScale))
        unitsPerPixel = nativeScale
        // Quantise the viewport origin once, not each object's world position.
        // Nearest is RainShadow's float-world adapter; GemRB's origin is already Int.
        let left = ((cameraCenter.x / nativeScale) - CGFloat(width) / 2).rounded()
        let top = ((cameraCenter.y / nativeScale) + CGFloat(height) / 2).rounded()
        worldRect = CGRect(x: left * nativeScale, y: (top - CGFloat(height)) * nativeScale,
                           width: CGFloat(width) * nativeScale, height: CGFloat(height) * nativeScale)
    }

    func pixel(_ world: CGPoint) -> CGPoint {
        CGPoint(x: (world.x - worldRect.minX) / unitsPerPixel,
                y: (worldRect.maxY - world.y) / unitsPerPixel)
    }

    func worldCenter(x: Int, y: Int) -> CGPoint {
        CGPoint(x: worldRect.minX + (CGFloat(x) + 0.5) * unitsPerPixel,
                y: worldRect.maxY - (CGFloat(y) + 0.5) * unitsPerPixel)
    }
}

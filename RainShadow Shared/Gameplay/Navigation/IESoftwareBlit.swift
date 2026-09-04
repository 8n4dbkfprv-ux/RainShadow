import Foundation

/// Native, top-down, integer-pixel reference for GemRB 1c45c185's decoded RGBA
/// `RGBBlendingPipeline<..., true>` and SDL1 `BlitSpriteClipped` placement.
/// This is NOT an SDL emulator or the shipping SpriteKit framebuffer. It has no
/// implicit scaling, filtering, colour management, stencil construction or RLE.
/// Unsupported blit flags throw rather than quietly claiming a match.
enum IESoftwareBlit {
    struct Point: Equatable, Sendable {
        var x: Int
        var y: Int
    }

    struct Rect: Equatable, Sendable {
        var x: Int
        var y: Int
        var width: Int
        var height: Int

        // GemRB Region::Intersect: half-open integer edges; invalid intersections
        // are normalised by ClippedDrawingRect, not here.
        func intersect(_ other: Rect) -> Rect {
            let left = max(x, other.x)
            let top = max(y, other.y)
            return Rect(x: left, y: top,
                        width: min(x + width, other.x + other.width) - left,
                        height: min(y + height, other.y + other.height) - top)
        }
    }

    enum Failure: Error, Equatable {
        case invalidDimensions
        case invalidPixelCount
        case invalidPalette
        case invalidMask
        case unsupportedFlags(UInt32)
    }

    struct Frame: Sendable {
        let width: Int
        let height: Int
        /// BAM Frame.origin: the pivot measured from the top-left pixel edge.
        /// A centre outside the crop is valid (not a normalised texture anchor).
        let origin: Point
        let indices: [UInt8]

        init(width: Int, height: Int, origin: Point, indices: [UInt8]) throws {
            guard width >= 0, height >= 0,
                  (width == 0) == (height == 0),
                  !width.multipliedReportingOverflow(by: height).overflow else {
                throw Failure.invalidDimensions
            }
            guard indices.count == width * height else { throw Failure.invalidPixelCount }
            self.width = width
            self.height = height
            self.origin = origin
            self.indices = indices
        }
    }

    struct Buffer: Sendable {
        let width: Int
        let height: Int
        private(set) var pixels: [IEColor]

        init(width: Int, height: Int, pixels: [IEColor]) throws {
            guard width > 0, height > 0,
                  !width.multipliedReportingOverflow(by: height).overflow else {
                throw Failure.invalidDimensions
            }
            guard pixels.count == width * height else { throw Failure.invalidPixelCount }
            self.width = width
            self.height = height
            self.pixels = pixels
        }

        /// `BlitGameSprite`: `Region drect(p - spr->Frame.origin, spr->Frame.size)`.
        /// Source and destination dimensions are identical. `mask` is the already
        /// resolved per-destination-pixel alpha iterator, NOT a wall-stencil map.
        /// Mirror traversal follows SDL1's *clipped* source rectangle, even where
        /// that disagrees with mirroring the whole frame before clipping.
        mutating func blit(
            _ frame: Frame, palette: [IEColor], at position: Point,
            clip: Rect? = nil, tint: IEColor = .opaqueWhite,
            flags: IEBlitFlags = .blended,
            mirrorX: Bool = false, mirrorY: Bool = false,
            mask: [UInt8]? = nil
        ) throws {
            let supported: IEBlitFlags = [.blended, .colorMod, .grey, .sepia]
            let unsupported = flags.subtracting(supported)
            guard unsupported.isEmpty else { throw Failure.unsupportedFlags(unsupported.rawValue) }
            guard palette.count == 256 else { throw Failure.invalidPalette }
            if let mask, mask.count != pixels.count { throw Failure.invalidMask }
            guard frame.width > 0, frame.height > 0 else { return }

            let bounds = Rect(x: 0, y: 0, width: width, height: height)
            let dst = Rect(x: position.x - frame.origin.x, y: position.y - frame.origin.y,
                           width: frame.width, height: frame.height)
            var clipped = dst.intersect(clip ?? bounds).intersect(bounds)
            if clipped.width <= 0 || clipped.height <= 0 {
                clipped.width = 0
                clipped.height = 0
            }

            var src = Rect(x: 0, y: 0, width: frame.width, height: frame.height)
            // SDLVideo::BlitSpriteClipped, SDL1 branch, verbatim arithmetic:
            // int trim = dst.h - dclipped.h; src.h -= trim;
            // if (dclipped.y > dst.y) { src.y += trim; }
            // Do NOT replace total trim with top/left delta. When both ends are
            // clipped upstream includes the opposite edge in this displacement.
            var trim = dst.height - clipped.height
            if trim != 0 {
                src.height -= trim
                if clipped.y > dst.y { src.y += trim }
            }
            trim = dst.width - clipped.width
            if trim != 0 {
                src.width -= trim
                if clipped.x > dst.x { src.x += trim }
            }
            guard clipped.width > 0, clipped.height > 0 else { return }

            for row in 0..<clipped.height {
                let sy = src.y + (mirrorY ? src.height - 1 - row : row)
                for column in 0..<clipped.width {
                    let sx = src.x + (mirrorX ? src.width - 1 - column : column)
                    let index = frame.indices[sy * frame.width + sx]
                    // The index key is a storage concern, before palette/shading.
                    if index == IEPalette.colorKeyIndex { continue }
                    let target = (clipped.y + row) * width + clipped.x + column
                    pixels[target] = IESoftwareBlit.pixel(
                        palette[Int(index)], over: pixels[target], tint: tint,
                        flags: flags, mask: mask?[target] ?? 0
                    )
                }
            }
        }

        var rgba: [UInt8] { pixels.flatMap { [$0.r, $0.g, $0.b, $0.a] } }
    }

    /// Pixels.h RGBBlendingPipeline followed by ShaderBlend<true>.
    /// `DIV255` is applied to EACH product separately, not their sum:
    /// `dst.r = DIV255(src.a*src.r) + DIV255((255-src.a)*dst.r);`
    /// ShaderBlend's bytes are compositing values, not unpremultiplied RGBA.
    /// Use an opaque destination for a directly displayable reference image.
    static func pixel(
        _ source: IEColor, over destination: IEColor,
        tint: IEColor, flags: IEBlitFlags, mask: UInt8 = 0
    ) -> IEColor {
        guard source.a != 0 else { return destination }
        var c = source
        // Upstream's FIXME is intentional here, including uint8_t truncation:
        // c.a = mask ? (255 - mask) + (c.a * mask) : c.a;
        if mask != 0 {
            c.a = UInt8(truncatingIfNeeded: (255 - Int(mask)) + Int(c.a) * Int(mask))
        }
        c = IEBlit.shade(c, tint: tint, flags: flags)
        func div255(_ x: Int) -> Int { (x + 1 + (x >> 8)) >> 8 }
        func blend(_ s: UInt8, _ d: UInt8) -> UInt8 {
            UInt8(div255(Int(c.a) * Int(s)) + div255((255 - Int(c.a)) * Int(d)))
        }
        return IEColor(blend(c.r, destination.r), blend(c.g, destination.g),
                       blend(c.b, destination.b),
                       UInt8(Int(c.a) + div255((255 - Int(c.a)) * Int(destination.a))))
    }
}

extension IEIndexedSprite {
    /// Explicit RainShadow-to-BAM adapter, NOT an original-engine operation.
    /// Uses the bundle's ONE source-to-native scale, never fits each pose/crop.
    /// Quantises the pivot to an integer native pixel (nearest, ties away from
    /// zero); the authored registration remains unchanged in the shipped node.
    func softwareFrame(for frame: Frame) throws -> IESoftwareBlit.Frame {
        try IESoftwareBlit.Frame(
            width: frame.nativeSize.width, height: frame.nativeSize.height,
            origin: .init(
                x: Int((frame.pivotFromCropBottomLeft.x / registeredPixelsPerNativePixel).rounded()),
                y: Int(((Double(frame.size.height) - frame.pivotFromCropBottomLeft.y)
                    / registeredPixelsPerNativePixel).rounded())
            ), indices: frame.indices
        )
    }
}

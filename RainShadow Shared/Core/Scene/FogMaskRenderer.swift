import CoreGraphics
import CoreImage
import SpriteKit

/// Paints an area's fog-of-war alpha mask.
///
/// The office and the city do not agree about fog and should not: the office
/// forgets, keeping a rolling trail of the last few places Voss stood, while a
/// district remembers every one and writes them to the save — which is what an
/// Infinity Engine area's explored bitmap is. That difference is policy and
/// stays with each scene. What the two had in common was every line of the
/// painting: the same black-then-`destinationOut` context, the same four
/// feathered rings, the same hand-wobbled circle. Two copies of it, with
/// separately tuned numbers and one of them mapping the world onto the mask
/// wrongly.
///
/// A reveal may carry the cells sight actually reaches, in which case the pool
/// is clipped to them and the fog stops at walls instead of at a radius.
struct FogMaskRenderer {
    /// How a lit pool is painted. The two shipped looks differ in mask
    /// resolution, ring spacing and how ragged the edge is; they are values, not
    /// two implementations.
    struct Style {
        /// Pool radius in world units.
        var revealRadius: CGFloat
        /// Concentric rings, outermost first: a multiple of the radius and the
        /// alpha it erases. The last one at alpha 1 is the clear centre.
        var featherLayers: [(scale: CGFloat, alpha: CGFloat)]
        /// Points around the circle. More is smoother and slower.
        var segmentCount: Int
        /// How far each successive pool's wobble is rotated, so a trail does not
        /// read as one shape stamped repeatedly.
        var phaseStep: CGFloat
        /// The sine terms that make the edge hand-drawn rather than compass-drawn.
        var edgeHarmonics: [(frequency: CGFloat, amplitude: CGFloat, phaseScale: CGFloat)]
        /// Mask resolution. The mask is stretched over the whole area, so this
        /// is a quality knob, not a coordinate system.
        var pixelSize: CGSize
        /// How far, in world units, to soften the sight boundary.
        ///
        /// Sight is answered per search cell, so an unsoftened boundary is a
        /// staircase of 16×12 steps — most obvious in a district, where the
        /// buildings run diagonally and the cells do not. One cell of blur turns
        /// that staircase back into an edge without moving it anywhere, and is
        /// far narrower than the pool's own feathering, which survives intact.
        var clipSoftness: CGFloat = SearchMap.defaultCellSize.width

        /// One room, seen by lamplight.
        static let office = Style(
            revealRadius: 390,
            featherLayers: [(1.045, 0.16), (1.020, 0.24), (0.995, 0.36), (0.965, 1.00)],
            segmentCount: 96,
            phaseStep: 0.83,
            edgeHarmonics: [(9, 7.5, 1.0), (21, 3.5, -0.7), (37, 1.8, 1.3)],
            pixelSize: CGSize(width: 512, height: 256)
        )

        /// A ward at night: a wider, softer pool over four times the ground.
        static let cityDistrict = Style(
            revealRadius: CityDistrictDefinition.fogRevealRadius,
            featherLayers: [(1.10, 0.12), (1.055, 0.20), (1.015, 0.38), (0.965, 1.00)],
            segmentCount: 72,
            phaseStep: 0.61,
            edgeHarmonics: [(7, 5.0, 1.0), (17, 2.3, -0.8)],
            pixelSize: CGSize(width: 1_024, height: 512)
        )
    }

    /// One lit pool.
    struct Reveal {
        /// Where it is centred, in node-local world units.
        var center: CGPoint
        /// World rectangles sight reaches from `center`. Empty means unoccluded,
        /// which is what the fog did before it could ask the search map.
        var visibleRects: [CGRect] = []
    }

    /// The area's extent in world units — what the mask is stretched over.
    let worldSize: CGSize
    let style: Style

    private var pixelsPerWorldX: CGFloat { style.pixelSize.width / worldSize.width }
    private var pixelsPerWorldY: CGFloat { style.pixelSize.height / worldSize.height }

    /// World radius the painted pool can reach, outermost feather ring included.
    ///
    /// The pool is drawn as a circle in *mask* pixels, and the mask is not the
    /// world's aspect, so on the stretched axis it reaches further in world
    /// units than `revealRadius` says. Sight has to be computed out to here or
    /// the clip would cut the pool short of where it would have been painted.
    var visibilityRadius: CGFloat {
        let outermost = style.featherLayers.map(\.scale).max() ?? 1
        let stretch = max(1, pixelsPerWorldX / pixelsPerWorldY)
        return style.revealRadius * outermost * stretch
    }

    func makeTexture(revealing reveals: [Reveal]) -> SKTexture? {
        let pixelWidth = Int(style.pixelSize.width)
        let pixelHeight = Int(style.pixelSize.height)
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setBlendMode(.copy)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: style.pixelSize))
        context.setBlendMode(.destinationOut)

        for (index, reveal) in reveals.enumerated() {
            let phase = CGFloat(index) * style.phaseStep
            let center = CGPoint(
                x: reveal.center.x * pixelsPerWorldX,
                y: reveal.center.y * pixelsPerWorldY
            )
            let clipped = !reveal.visibleRects.isEmpty
            if clipped {
                context.saveGState()
                context.clip(to: reveal.visibleRects.map(pixelRect))
            }
            for layer in style.featherLayers {
                context.addPath(edgePath(
                    center: center,
                    radius: style.revealRadius * pixelsPerWorldX * layer.scale,
                    phase: phase
                ))
                context.setFillColor(CGColor(gray: 1, alpha: layer.alpha))
                context.fillPath()
            }
            if clipped { context.restoreGState() }
        }

        guard let image = context.makeImage() else { return nil }
        let anyClipped = reveals.contains { !$0.visibleRects.isEmpty }
        let mask = SKTexture(cgImage: anyClipped ? softened(image) ?? image : image)
        mask.filteringMode = .linear
        return mask
    }

    /// Shared because a `CIContext` is expensive to build and the fog rebuilds
    /// its mask every time the player crosses a reveal's worth of ground.
    private static let softeningContext = CIContext(options: [.cacheIntermediates: false])

    private func softened(_ image: CGImage) -> CGImage? {
        let sigma = style.clipSoftness * pixelsPerWorldX
        guard sigma > 0 else { return image }
        let input = CIImage(cgImage: image)
        // Clamped before blurring: without it the blur pulls transparency in
        // from beyond the edges and the area's border stops being fogged at all.
        let blurred = input
            .clampedToExtent()
            .applyingGaussianBlur(sigma: Double(sigma))
            .cropped(to: input.extent)
        return Self.softeningContext.createCGImage(blurred, from: input.extent)
    }

    private func pixelRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * pixelsPerWorldX,
            y: rect.minY * pixelsPerWorldY,
            width: rect.width * pixelsPerWorldX,
            height: rect.height * pixelsPerWorldY
        )
    }

    private func edgePath(center: CGPoint, radius: CGFloat, phase: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for segment in 0..<style.segmentCount {
            let angle = CGFloat(segment) / CGFloat(style.segmentCount) * .pi * 2
            let wobble = style.edgeHarmonics.reduce(CGFloat.zero) { total, harmonic in
                total + sin(angle * harmonic.frequency + phase * harmonic.phaseScale)
                    * harmonic.amplitude
            }
            let point = CGPoint(
                x: center.x + cos(angle) * (radius + wobble),
                y: center.y + sin(angle) * (radius + wobble)
            )
            if segment == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

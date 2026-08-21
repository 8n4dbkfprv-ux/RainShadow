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
///
/// The mask holds three levels, because the engine keeps two bitmaps and draws
/// their combination: opaque where the area has never been seen, dimmed where it
/// has been seen but is not in sight now, clear where it is. Painting them into
/// one texture rather than stacking two sprites keeps the live pool able to cut
/// clean through the remembered layer even where it has run ahead of it.
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
        /// How dark ground stays once the player has seen it and looked away.
        ///
        /// The Infinity Engine's `ExploredBitmap` is drawn as *partial* fog: you
        /// keep the terrain and lose what is standing on it. 0 would make memory
        /// indistinguishable from sight, 1 from never having been there.
        var exploredDimming: CGFloat = 0.55
        /// How far the player walks before another pool joins the remembered
        /// layer. Memory is coarser than sight, and a district persists these to
        /// the save, so this is also how much a walked district costs to store.
        var memorySpacing: CGFloat
        /// How far the player walks before the live pool is repainted. Under one
        /// search cell, so the bright edge never visibly lags.
        var sightStep: CGFloat = 12
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
            pixelSize: CGSize(width: 512, height: 256),
            memorySpacing: 390 * 0.42
        )

        /// A ward at night: a wider, softer pool over four times the ground.
        static let cityDistrict = Style(
            revealRadius: CityDistrictDefinition.fogRevealRadius,
            featherLayers: [(1.10, 0.12), (1.055, 0.20), (1.015, 0.38), (0.965, 1.00)],
            segmentCount: 72,
            phaseStep: 0.61,
            edgeHarmonics: [(7, 5.0, 1.0), (17, 2.3, -0.8)],
            pixelSize: CGSize(width: 1_024, height: 512),
            // Kept at 72 because a district writes these points to the save;
            // changing it would change what an existing save means.
            memorySpacing: 72
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

    /// How far sight is asked to carry, in search cells — the unit the engine
    /// measures vision in, and the one `SearchMap.visibleCells` takes.
    ///
    /// Enough to cover the painted pool on *both* axes. The pool is drawn as a
    /// circle in mask pixels and the mask is not the world's aspect ratio, so on
    /// the stretched axis it reaches further in world units than `revealRadius`
    /// says; a cell radius short of that would clip the pool back to a circle
    /// the artist did not paint.
    var visibilityRadiusInCells: Int {
        let outermost = style.featherLayers.map(\.scale).max() ?? 1
        let paintedWorldX = style.revealRadius * outermost
        let paintedWorldY = paintedWorldX * pixelsPerWorldX / pixelsPerWorldY
        let cell = SearchMap.defaultCellSize
        return Int(ceil(max(paintedWorldX / cell.width, paintedWorldY / cell.height)))
    }

    /// The remembered layer: opaque black, with everything ever seen lifted to
    /// `exploredDimming`. Rebuilt only when memory grows, which is rare.
    func makeExploredMask(remembering reveals: [Reveal]) -> CGImage? {
        guard let context = makeContext() else { return nil }
        context.setBlendMode(.copy)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: style.pixelSize))

        context.setBlendMode(.destinationOut)
        for (index, reveal) in reveals.enumerated() {
            erasePool(reveal, phase: CGFloat(index) * style.phaseStep, in: context)
        }

        // Painting the dimming *under* what is left raises every erased pixel
        // from 0 to `exploredDimming` and leaves untouched black at 1, feather
        // and all: `a' = a + d(1 - a)`. Erasing to `d` in the first place would
        // not do this — the four rings overlap, so their erasures compound and
        // the centre would land somewhere below the value asked for.
        context.setBlendMode(.destinationOver)
        context.setFillColor(CGColor(gray: 0, alpha: style.exploredDimming))
        context.fill(CGRect(origin: .zero, size: style.pixelSize))

        return context.makeImage()
    }

    /// The remembered layer with the live pool cut clear through it.
    ///
    /// `seeing` erases to full transparency regardless of what memory holds
    /// underneath, so sight that has run ahead of the last remembered pool is
    /// still lit rather than clipped to it.
    func makeTexture(exploredMask: CGImage?, seeing visible: Reveal?) -> SKTexture? {
        guard let context = makeContext() else { return nil }
        context.setBlendMode(.copy)
        if let exploredMask {
            context.draw(exploredMask, in: CGRect(origin: .zero, size: style.pixelSize))
        } else {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(origin: .zero, size: style.pixelSize))
        }

        var clipped = false
        if let visible {
            context.setBlendMode(.destinationOut)
            erasePool(visible, phase: 0, in: context)
            clipped = !visible.visibleRects.isEmpty
        }

        guard let image = context.makeImage() else { return nil }
        let mask = SKTexture(cgImage: clipped ? softened(image) ?? image : image)
        mask.filteringMode = .linear
        return mask
    }

    private func makeContext() -> CGContext? {
        let pixelWidth = Int(style.pixelSize.width)
        return CGContext(
            data: nil,
            width: pixelWidth,
            height: Int(style.pixelSize.height),
            bitsPerComponent: 8,
            bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    /// One pool, clipped to what sight reaches from it, erased at full strength.
    /// The caller decides what the result means by choosing the blend it is
    /// painted into.
    private func erasePool(_ reveal: Reveal, phase: CGFloat, in context: CGContext) {
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

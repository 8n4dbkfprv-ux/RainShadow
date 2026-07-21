import CoreGraphics
import Foundation

/// Hotspot hover selection presentation for office props.
///
/// Image #1 contract: a **thin pure-cyan alpha rim** on the silhouette border plus a
/// **translucent teal body wash** so original art still reads — never a solid cyan fill
/// and never an axis-aligned hit-rect box.
///
/// Apply path (scene): teal `colorBlendFactor` wash on the prop + a **CPU-built cyan edge
/// overlay texture** (rim pixels only). Custom SKShaders were abandoned after they produced
/// solid-cyan fills / thick shells in the running app (SpriteKit premul / sampling issues).
enum HotspotHoverHighlight {
    struct Target: Equatable {
        let id: String
        let hitArea: CGRect
    }

    // MARK: - Image #1 silhouette edge (pure cyan)

    static let outlineRed: CGFloat = 0.0
    static let outlineGreen: CGFloat = 1.0
    static let outlineBlue: CGFloat = 1.0
    /// Desired edge thickness in world/screen points (capped in texels).
    static let outlineWidth: CGFloat = 2.0
    /// Hard cap on rim thickness in source texels (Image #1 thin edge — not a thick shell).
    static let outlineMaxTexels: CGFloat = 3.0

    // MARK: - Image #1 body wash (translucent teal)

    static let washRed: CGFloat = 0.12
    static let washGreen: CGFloat = 0.48
    static let washBlue: CGFloat = 0.55

    static let legacySubtleColorBlendFactor: CGFloat = 0.42
    /// Body wash strength — art must still read (not solid recolor).
    static let selectedColorBlendFactor: CGFloat = 0.40
    static let clearedColorBlendFactor: CGFloat = 0

    static let opaqueAlphaThreshold: CGFloat = 0.18

    /// Child node name for the cyan rim overlay sprite.
    static let edgeOverlayNodeName = "hoverCyanEdgeOverlay"

    // MARK: - Inclusive bands for regression checks

    static let outlineRedBand: ClosedRange<CGFloat> = 0.0...0.15
    static let outlineGreenBand: ClosedRange<CGFloat> = 0.85...1.0
    static let outlineBlueBand: ClosedRange<CGFloat> = 0.85...1.0
    static let outlineWidthBand: ClosedRange<CGFloat> = 1.0...5.0

    static let washRedBand: ClosedRange<CGFloat> = 0.0...0.30
    static let washGreenBand: ClosedRange<CGFloat> = 0.35...0.80
    static let washBlueBand: ClosedRange<CGFloat> = 0.40...0.85
    static let selectedBlendBand: ClosedRange<CGFloat> = 0.30...0.72

    struct Presentation: Equatable {
        let isVisible: Bool
        let hotspotID: String?

        let washRed: CGFloat
        let washGreen: CGFloat
        let washBlue: CGFloat
        let colorBlendFactor: CGFloat

        let outlineEnabled: Bool
        let outlineRed: CGFloat
        let outlineGreen: CGFloat
        let outlineBlue: CGFloat
        let outlineWidth: CGFloat

        let usesSpriteTint: Bool

        static let hidden = Presentation(
            isVisible: false,
            hotspotID: nil,
            washRed: HotspotHoverHighlight.washRed,
            washGreen: HotspotHoverHighlight.washGreen,
            washBlue: HotspotHoverHighlight.washBlue,
            colorBlendFactor: HotspotHoverHighlight.clearedColorBlendFactor,
            outlineEnabled: false,
            outlineRed: HotspotHoverHighlight.outlineRed,
            outlineGreen: HotspotHoverHighlight.outlineGreen,
            outlineBlue: HotspotHoverHighlight.outlineBlue,
            outlineWidth: HotspotHoverHighlight.outlineWidth,
            usesSpriteTint: true
        )

        var isImageOneSelectionLook: Bool {
            guard isVisible, usesSpriteTint, outlineEnabled else { return false }
            return outlineRedBand.contains(outlineRed)
                && outlineGreenBand.contains(outlineGreen)
                && outlineBlueBand.contains(outlineBlue)
                && outlineWidthBand.contains(outlineWidth)
                && washRedBand.contains(washRed)
                && washGreenBand.contains(washGreen)
                && washBlueBand.contains(washBlue)
                && selectedBlendBand.contains(colorBlendFactor)
                && colorBlendFactor > 0
        }

        var isClearedSelection: Bool {
            !isVisible
                && !outlineEnabled
                && colorBlendFactor == clearedColorBlendFactor
        }

        var red: CGFloat { washRed }
        var green: CGFloat { washGreen }
        var blue: CGFloat { washBlue }
        var isClearedSpriteTint: Bool { isClearedSelection }
    }

    /// Pixel classification for CPU highlight evaluation.
    enum PixelKind: Equatable {
        case clear
        case cyanEdge
        case bodyWash
    }

    /// Premultiplied RGBA sample from the shipped highlight logic.
    struct HighlightSample: Equatable {
        let kind: PixelKind
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

        var isPremultiplied: Bool {
            if a <= 0.0001 {
                return r <= 0.0001 && g <= 0.0001 && b <= 0.0001
            }
            return r <= a + 0.001 && g <= a + 0.001 && b <= a + 0.001
        }

        var isCyanEdgeColor: Bool {
            guard kind == .cyanEdge, a > 0.05 else { return false }
            let nr = r / a
            let ng = g / a
            let nb = b / a
            return nr < 0.2 && ng > 0.8 && nb > 0.8
        }

        var isWashDominatedNotCyan: Bool {
            guard kind == .bodyWash, a > 0.05 else { return false }
            let nr = r / a
            let ng = g / a
            let nb = b / a
            let isPureCyan = nr < 0.15 && ng > 0.85 && nb > 0.85
            return !isPureCyan
        }
    }

    static func selectedID(at point: CGPoint, among targets: [Target]) -> String? {
        targets.first { $0.hitArea.contains(point) }?.id
    }

    static func presentation(
        at point: CGPoint?,
        among targets: [Target],
        worldInteractionBlocked: Bool
    ) -> Presentation {
        guard !worldInteractionBlocked, let point else {
            return .hidden
        }
        guard let id = selectedID(at: point, among: targets) else {
            return .hidden
        }
        return Presentation(
            isVisible: true,
            hotspotID: id,
            washRed: washRed,
            washGreen: washGreen,
            washBlue: washBlue,
            colorBlendFactor: selectedColorBlendFactor,
            outlineEnabled: true,
            outlineRed: outlineRed,
            outlineGreen: outlineGreen,
            outlineBlue: outlineBlue,
            outlineWidth: outlineWidth,
            usesSpriteTint: true
        )
    }

    static func targets(
        from hotspots: [(id: String, hitArea: CGRect)]
    ) -> [Target] {
        hotspots.map { Target(id: $0.id, hitArea: $0.hitArea) }
    }

    /// UV outline step (legacy helper / tests). Capped in texels.
    static func outlineUVThickness(
        worldWidth: CGFloat = outlineWidth,
        spriteSize: CGSize,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> (x: CGFloat, y: CGFloat) {
        let worldW = max(abs(spriteSize.width * scaleX), 0.0001)
        let worldH = max(abs(spriteSize.height * scaleY), 0.0001)
        let rawX = worldWidth / worldW
        let rawY = worldWidth / worldH
        let maxUVX = outlineMaxTexels / max(abs(spriteSize.width), 1)
        let maxUVY = outlineMaxTexels / max(abs(spriteSize.height), 1)
        return (min(rawX, maxUVX), min(rawY, maxUVY))
    }

    /// Integer texel step for rim generation (shared by overlay builder + evaluator).
    static func outlineTexelSteps(
        worldWidth: CGFloat = outlineWidth,
        pixelWidth: Int,
        pixelHeight: Int,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> (x: Int, y: Int) {
        let size = CGSize(width: CGFloat(pixelWidth), height: CGFloat(pixelHeight))
        let uv = outlineUVThickness(
            worldWidth: worldWidth,
            spriteSize: size,
            scaleX: scaleX,
            scaleY: scaleY
        )
        let sx = max(1, Int((uv.x * CGFloat(pixelWidth)).rounded()))
        let sy = max(1, Int((uv.y * CGFloat(pixelHeight)).rounded()))
        // Never exceed the hard texel cap.
        let cap = max(1, Int(outlineMaxTexels.rounded()))
        return (min(sx, cap), min(sy, cap))
    }

    static func localOutlineOffset(
        worldWidth: CGFloat = outlineWidth,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> (x: CGFloat, y: CGFloat) {
        let sx = max(abs(scaleX), 0.0001)
        let sy = max(abs(scaleY), 0.0001)
        return (worldWidth / sx, worldWidth / sy)
    }

    static func silhouetteOutlineLocalOffsets(
        worldWidth: CGFloat = outlineWidth,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> [CGPoint] {
        let local = localOutlineOffset(worldWidth: worldWidth, scaleX: scaleX, scaleY: scaleY)
        let wx = local.x
        let wy = local.y
        return [
            CGPoint(x: -wx, y: 0), CGPoint(x: wx, y: 0),
            CGPoint(x: 0, y: -wy), CGPoint(x: 0, y: wy),
            CGPoint(x: -wx, y: -wy), CGPoint(x: wx, y: -wy),
            CGPoint(x: -wx, y: wy), CGPoint(x: wx, y: wy)
        ]
    }

    // MARK: - CPU edge overlay (shipped apply path)

    /// Builds a **premultiplied** RGBA buffer the same size as the source: pure cyan only on
    /// silhouette rim pixels (inner + thin outer), **clear everywhere else** (body is not filled).
    /// Scene turns this into an `SKTexture` child over the teal-washed prop.
    /// Selected presentation constants used when building overlays without a hit test.
    static var selectedPresentationTemplate: Presentation {
        Presentation(
            isVisible: true,
            hotspotID: "overlay",
            washRed: washRed,
            washGreen: washGreen,
            washBlue: washBlue,
            colorBlendFactor: selectedColorBlendFactor,
            outlineEnabled: true,
            outlineRed: outlineRed,
            outlineGreen: outlineGreen,
            outlineBlue: outlineBlue,
            outlineWidth: outlineWidth,
            usesSpriteTint: true
        )
    }

    static func makeCyanEdgeOverlayPremultipliedRGBA(
        sourceRGBA: [UInt8],
        width: Int,
        height: Int,
        stepX: Int,
        stepY: Int,
        presentation: Presentation = selectedPresentationTemplate
    ) -> [UInt8] {
        precondition(sourceRGBA.count == width * height * 4)
        var alphas = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            alphas[i] = sourceRGBA[i * 4 + 3]
        }
        let thr = opaqueAlphaThreshold
        let sx = max(1, stepX)
        let sy = max(1, stepY)
        var out = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let a = sampleAlpha(alphas: alphas, width: width, height: height, x: x, y: y)
                let nL = sampleAlpha(alphas: alphas, width: width, height: height, x: x - sx, y: y)
                let nR = sampleAlpha(alphas: alphas, width: width, height: height, x: x + sx, y: y)
                let nD = sampleAlpha(alphas: alphas, width: width, height: height, x: x, y: y - sy)
                let nU = sampleAlpha(alphas: alphas, width: width, height: height, x: x, y: y + sy)
                let nLD = sampleAlpha(alphas: alphas, width: width, height: height, x: x - sx, y: y - sy)
                let nRD = sampleAlpha(alphas: alphas, width: width, height: height, x: x + sx, y: y - sy)
                let nLU = sampleAlpha(alphas: alphas, width: width, height: height, x: x - sx, y: y + sy)
                let nRU = sampleAlpha(alphas: alphas, width: width, height: height, x: x + sx, y: y + sy)
                let minN = min(min(min(nL, nR), min(nD, nU)), min(min(nLD, nRD), min(nLU, nRU)))
                let maxN = max(max(max(nL, nR), max(nD, nU)), max(max(nLD, nRD), max(nLU, nRU)))

                let isRim: Bool
                let edgeAlpha: CGFloat
                if a >= thr && minN < thr {
                    // Inner rim (opaque next to clear).
                    isRim = true
                    edgeAlpha = a
                } else if a < thr && maxN >= thr {
                    // Thin outer rim only (clear next to opaque) — Image #1 outer edge.
                    isRim = true
                    edgeAlpha = maxN
                } else {
                    isRim = false
                    edgeAlpha = 0
                }

                let i = (y * width + x) * 4
                if isRim && edgeAlpha > 0.05 {
                    // Premultiplied pure cyan.
                    let ea = min(edgeAlpha, 1)
                    out[i] = UInt8(max(0, min(255, (presentation.outlineRed * ea * 255).rounded())))
                    out[i + 1] = UInt8(max(0, min(255, (presentation.outlineGreen * ea * 255).rounded())))
                    out[i + 2] = UInt8(max(0, min(255, (presentation.outlineBlue * ea * 255).rounded())))
                    out[i + 3] = UInt8(max(0, min(255, (ea * 255).rounded())))
                }
                // else leave zeros (clear) — body never filled with cyan
            }
        }
        return out
    }

    // MARK: - CPU evaluation (tests + shared classification)

    static func sampleAlpha(
        alphas: [UInt8],
        width: Int,
        height: Int,
        x: Int,
        y: Int
    ) -> CGFloat {
        let cx = min(max(x, 0), width - 1)
        let cy = min(max(y, 0), height - 1)
        return CGFloat(alphas[cy * width + cx]) / 255.0
    }

    static func sampleRGB(
        rgba: [UInt8],
        width: Int,
        height: Int,
        x: Int,
        y: Int
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let cx = min(max(x, 0), width - 1)
        let cy = min(max(y, 0), height - 1)
        let i = (cy * width + cx) * 4
        let a = CGFloat(rgba[i + 3]) / 255.0
        return (
            CGFloat(rgba[i]) / 255.0,
            CGFloat(rgba[i + 1]) / 255.0,
            CGFloat(rgba[i + 2]) / 255.0,
            a
        )
    }

    /// Full selected look at one pixel: cyan rim **or** teal body wash (premultiplied).
    static func evaluateHighlightPixel(
        alphas: [UInt8],
        rgba: [UInt8],
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        stepX: Int,
        stepY: Int,
        presentation: Presentation
    ) -> HighlightSample {
        let thr = opaqueAlphaThreshold
        let center = sampleRGB(rgba: rgba, width: width, height: height, x: x, y: y)
        let a = center.a

        let nL = sampleAlpha(alphas: alphas, width: width, height: height, x: x - stepX, y: y)
        let nR = sampleAlpha(alphas: alphas, width: width, height: height, x: x + stepX, y: y)
        let nD = sampleAlpha(alphas: alphas, width: width, height: height, x: x, y: y - stepY)
        let nU = sampleAlpha(alphas: alphas, width: width, height: height, x: x, y: y + stepY)
        let nLD = sampleAlpha(alphas: alphas, width: width, height: height, x: x - stepX, y: y - stepY)
        let nRD = sampleAlpha(alphas: alphas, width: width, height: height, x: x + stepX, y: y - stepY)
        let nLU = sampleAlpha(alphas: alphas, width: width, height: height, x: x - stepX, y: y + stepY)
        let nRU = sampleAlpha(alphas: alphas, width: width, height: height, x: x + stepX, y: y + stepY)
        let minN = min(min(min(nL, nR), min(nD, nU)), min(min(nLD, nRD), min(nLU, nRU)))
        let maxN = max(max(max(nL, nR), max(nD, nU)), max(max(nLD, nRD), max(nLU, nRU)))

        // Rim (inner or thin outer) → cyan.
        if a >= thr && minN < thr {
            return HighlightSample(
                kind: .cyanEdge,
                r: presentation.outlineRed * a,
                g: presentation.outlineGreen * a,
                b: presentation.outlineBlue * a,
                a: a
            )
        }
        if a < thr && maxN >= thr {
            let ea = maxN
            return HighlightSample(
                kind: .cyanEdge,
                r: presentation.outlineRed * ea,
                g: presentation.outlineGreen * ea,
                b: presentation.outlineBlue * ea,
                a: ea
            )
        }
        if a < thr {
            return HighlightSample(kind: .clear, r: 0, g: 0, b: 0, a: 0)
        }

        // Body wash (SpriteKit colorBlendFactor multiply model).
        let blend = presentation.colorBlendFactor
        let mr = center.r * ((1 - blend) + blend * presentation.washRed)
        let mg = center.g * ((1 - blend) + blend * presentation.washGreen)
        let mb = center.b * ((1 - blend) + blend * presentation.washBlue)
        return HighlightSample(
            kind: .bodyWash,
            r: mr * a,
            g: mg * a,
            b: mb * a,
            a: a
        )
    }

    struct HighlightStats: Equatable {
        let opaqueCount: Int
        let edgeCount: Int
        let washCount: Int
        let clearCount: Int
        let edgeFractionOfOpaque: CGFloat
        let washFractionOfOpaque: CGFloat
        let allPremultiplied: Bool
        let allEdgesAreCyan: Bool
        let allWashesNotPureCyan: Bool
        /// Overlay-only: fraction of all pixels that are non-clear cyan rim (must stay small).
        let edgeFractionOfAllPixels: CGFloat
    }

    static func evaluateHighlightStats(
        rgba: [UInt8],
        width: Int,
        height: Int,
        spriteScaleX: CGFloat,
        spriteScaleY: CGFloat,
        presentation: Presentation,
        sampleStride: Int = 2
    ) -> HighlightStats {
        precondition(rgba.count == width * height * 4)
        var alphas = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            alphas[i] = rgba[i * 4 + 3]
        }

        let steps = outlineTexelSteps(
            worldWidth: presentation.outlineWidth,
            pixelWidth: width,
            pixelHeight: height,
            scaleX: spriteScaleX,
            scaleY: spriteScaleY
        )

        var opaque = 0
        var edge = 0
        var wash = 0
        var clear = 0
        var total = 0
        var allPremul = true
        var edgesCyan = true
        var washesOk = true

        let step = max(1, sampleStride)
        for y in Swift.stride(from: 0, to: height, by: step) {
            for x in Swift.stride(from: 0, to: width, by: step) {
                total += 1
                let sample = evaluateHighlightPixel(
                    alphas: alphas,
                    rgba: rgba,
                    width: width,
                    height: height,
                    x: x,
                    y: y,
                    stepX: steps.x,
                    stepY: steps.y,
                    presentation: presentation
                )
                if !sample.isPremultiplied { allPremul = false }
                switch sample.kind {
                case .clear:
                    clear += 1
                case .cyanEdge:
                    // Outer rim may sit on low-alpha texels; still counts as edge not body.
                    if sample.a >= opaqueAlphaThreshold {
                        opaque += 1
                    }
                    edge += 1
                    if !sample.isCyanEdgeColor { edgesCyan = false }
                case .bodyWash:
                    opaque += 1
                    wash += 1
                    if !sample.isWashDominatedNotCyan { washesOk = false }
                }
            }
        }

        let opaqueSafe = max(opaque, 1)
        let totalSafe = max(total, 1)
        return HighlightStats(
            opaqueCount: opaque,
            edgeCount: edge,
            washCount: wash,
            clearCount: clear,
            edgeFractionOfOpaque: CGFloat(edge) / CGFloat(opaqueSafe),
            washFractionOfOpaque: CGFloat(wash) / CGFloat(opaqueSafe),
            allPremultiplied: allPremul,
            allEdgesAreCyan: edgesCyan,
            allWashesNotPureCyan: washesOk,
            edgeFractionOfAllPixels: CGFloat(edge) / CGFloat(totalSafe)
        )
    }

    /// Stats for the **edge overlay alone** (body must be clear — no solid cyan fill).
    static func evaluateEdgeOverlayStats(
        sourceRGBA: [UInt8],
        width: Int,
        height: Int,
        spriteScaleX: CGFloat,
        spriteScaleY: CGFloat,
        presentation: Presentation,
        sampleStride: Int = 2
    ) -> (rimPixels: Int, clearPixels: Int, rimFraction: CGFloat, allRimPremulCyan: Bool) {
        let steps = outlineTexelSteps(
            worldWidth: presentation.outlineWidth,
            pixelWidth: width,
            pixelHeight: height,
            scaleX: spriteScaleX,
            scaleY: spriteScaleY
        )
        let overlay = makeCyanEdgeOverlayPremultipliedRGBA(
            sourceRGBA: sourceRGBA,
            width: width,
            height: height,
            stepX: steps.x,
            stepY: steps.y,
            presentation: presentation
        )
        var rim = 0
        var clear = 0
        var allOk = true
        let step = max(1, sampleStride)
        for y in Swift.stride(from: 0, to: height, by: step) {
            for x in Swift.stride(from: 0, to: width, by: step) {
                let i = (y * width + x) * 4
                let a = CGFloat(overlay[i + 3]) / 255.0
                if a < 0.05 {
                    clear += 1
                } else {
                    rim += 1
                    let r = CGFloat(overlay[i]) / 255.0
                    let g = CGFloat(overlay[i + 1]) / 255.0
                    let b = CGFloat(overlay[i + 2]) / 255.0
                    // Premul + cyan.
                    if r > a + 0.02 || g > a + 0.02 || b > a + 0.02 { allOk = false }
                    if a > 0.05 {
                        let nr = r / a
                        let ng = g / a
                        let nb = b / a
                        if nr > 0.2 || ng < 0.8 || nb < 0.8 { allOk = false }
                    }
                }
            }
        }
        let total = max(rim + clear, 1)
        return (rim, clear, CGFloat(rim) / CGFloat(total), allOk)
    }
}

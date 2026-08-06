import CoreGraphics
import SpriteKit

/// Soft underfoot contact shadow (Infinity Engine–style ground ellipse).
///
/// Sits at local z 0 under the selection ring and body. Character frames stay
/// chroma-clean; the shadow is a separate soft sprite so walk/sit clips never
/// bake a double-shadow.
@MainActor
enum ContactShadowKind {
    /// Detective / party footprint.
    case party
    /// Client / NPC footprint (slightly smaller, lighter).
    case npc

    var name: String {
        switch self {
        case .party: "contact_shadow_party"
        case .npc: "contact_shadow_npc"
        }
    }

    /// On-screen ellipse before `standingScale` is applied. Tracks the sprite
    /// presentation so the blob stays under the feet at any body size.
    var displaySize: CGSize {
        let ratio = OfficeInteriorScale.ActorDisplay.visualBodyRatio
        switch self {
        case .party: return CGSize(width: 54 * ratio, height: 20 * ratio)
        case .npc: return CGSize(width: 44 * ratio, height: 15 * ratio)
        }
    }

    /// Local offset so the blob sits under the shoe soles, not the sprite origin.
    var footPosition: CGPoint {
        let ratio = OfficeInteriorScale.ActorDisplay.visualBodyRatio
        switch self {
        case .party: return CGPoint(x: 0, y: 4 * ratio)
        case .npc: return CGPoint(x: 0, y: 3 * ratio)
        }
    }

    /// Node alpha at standing/walking rest. Texture already carries soft falloff;
    /// this matches the prior shape-node visual weight (fill α 0.38 / 0.32).
    var standingAlpha: CGFloat {
        switch self {
        case .party: 0.42
        case .npc: 0.36
        }
    }
}

@MainActor
enum ContactShadowFactory {
    private static var cachedSoftTexture: SKTexture?

    /// Soft contact shadow sized to the actor footprint.
    /// Prefers painted `det_contact_shadow_soft` (AssetManifest / UI Common);
    /// falls back to a procedural soft ellipse if the PNG is missing.
    static func make(
        kind: ContactShadowKind,
        scale: CGFloat = OfficeInteriorScale.ActorDisplay.standingScale
    ) -> SKSpriteNode {
        let texture = softTexture()
        let shadow = SKSpriteNode(texture: texture, size: kind.displaySize)
        shadow.name = kind.name
        shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        shadow.position = kind.footPosition
        shadow.setScale(scale)
        shadow.alpha = kind.standingAlpha
        shadow.zPosition = 0
        shadow.texture?.filteringMode = .linear
        // Mild dimetric stretch so the blob reads as floor contact, not a
        // screen-space disc. Extra width also sells a slight cast tail.
        shadow.xScale = scale * 1.06
        shadow.yScale = scale
        return shadow
    }

    /// Fade the shadow back to a standing weight (not α = 1).
    /// Pass the scene-scaled standing alpha from the actor (`kind.standingAlpha * scale`).
    static func fadeToStanding(
        _ shadow: SKSpriteNode,
        to alpha: CGFloat,
        duration: TimeInterval
    ) -> SKAction {
        .fadeAlpha(to: alpha, duration: duration)
    }

    /// Soft black ellipse with a gentle outer falloff and a slight directional
    /// bias (key light upper-left → soft cast toward lower-right), matching
    /// the office desk/cabinet procedural shadows.
    static func softTexture() -> SKTexture {
        if let cachedSoftTexture {
            return cachedSoftTexture
        }
        if let painted = GameArt.texture(named: "det_contact_shadow_soft") {
            painted.filteringMode = .linear
            cachedSoftTexture = painted
            return painted
        }

        let texture = makeProceduralSoftTexture(width: 256, height: 128)
        cachedSoftTexture = texture
        return texture
    }

    private static func makeProceduralSoftTexture(width: Int, height: Int) -> SKTexture {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        // Center nudged upper-left so the soft lobe stretches lower-right
        // (room key from the lamp/window upper-left quadrant).
        let cx = Double(width - 1) * 0.46
        let cy = Double(height - 1) * 0.44
        let rx = Double(width) * 0.40
        let ry = Double(height) * 0.34

        for y in 0..<height {
            for x in 0..<width {
                let nx = (Double(x) - cx) / rx
                let ny = (Double(y) - cy) / ry
                // Mild directional anisotropy: elongate toward SE cast.
                let castX = nx * 0.92 + 0.08
                let castY = ny * 1.05 + 0.06
                let r = (castX * castX + castY * castY).squareRoot()
                var t = max(0, 1 - r)
                // Smoothstep, then a slightly steeper outer roll-off so the
                // edge dissolves into the floorboards instead of a hard rim.
                t = t * t * (3 - 2 * t)
                t = pow(t, 1.45)
                let alpha = UInt8(min(255, Int((t * 255).rounded())))
                let i = (y * width + x) * 4
                // Premultiplied black: RGB = 0, A = falloff.
                pixels[i + 0] = 0
                pixels[i + 1] = 0
                pixels[i + 2] = 0
                pixels[i + 3] = alpha
            }
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        if let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let image = context.makeImage() {
            let texture = SKTexture(cgImage: image)
            texture.filteringMode = .linear
            return texture
        }

        // Defensive 1×1 premultiplied black so callers never receive a nil texture.
        var pixel: [UInt8] = [0, 0, 0, 96]
        let fallbackContext = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )!
        let texture = SKTexture(cgImage: fallbackContext.makeImage()!)
        texture.filteringMode = .linear
        return texture
    }
}

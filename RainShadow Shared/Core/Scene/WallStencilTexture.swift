import CoreGraphics
import SpriteKit

/// The baked ``AreaWallStencil/Mask`` as something SpriteKit can sample.
///
/// Upstream's stencil is a `VideoBuffer` the size of the viewport, redrawn each
/// frame by `Map::RedrawScreenStencil`. RainShadow's covering outlines are
/// authored world-space geometry that never moves, so this is baked once per
/// area — see the deviation recorded on ``AreaWallStencil``.
@MainActor
final class WallStencilTexture {
    let texture: SKTexture
    /// World rect the mask spans, for composing the per-sprite UV mapping.
    let worldFrame: CGRect
    let mask: AreaWallStencil.Mask

    private init(texture: SKTexture, worldFrame: CGRect, mask: AreaWallStencil.Mask) {
        self.texture = texture
        self.worldFrame = worldFrame
        self.mask = mask
    }

    /// `nil` when the area has no covering geometry at all — the common case for
    /// an interior, and cheaper than uploading a blank mask every sprite then
    /// samples for nothing.
    static func make(from mask: AreaWallStencil.Mask) -> WallStencilTexture? {
        guard !mask.isEmpty, mask.columns > 0, mask.rows > 0 else { return nil }
        let texture = SKTexture(
            data: Data(mask.rgba),
            size: CGSize(width: mask.columns, height: mask.rows)
        )
        // The stencil is flag channels, not a picture. Linear filtering would
        // average 0x80 and 0xFF across a wall edge into a red value that is
        // neither, which the shader reads as a wall state upstream never
        // produces — same reasoning as `FogMaskRenderer`.
        texture.filteringMode = .nearest
        return WallStencilTexture(texture: texture, worldFrame: mask.worldFrame, mask: mask)
    }

    /// Point one sprite's shader at this mask.
    ///
    /// The sprite's world rect is derived from its own local bounds rather than
    /// `frame`, because `frame` is in parent coordinates and an actor's layers
    /// hang off a node that is itself positioned in the world.
    func apply(to sprite: SKSpriteNode, in scene: SKScene) {
        (sprite as? IEAvatarNode)?.nativeWallStencil = self
        guard let shader = sprite.shader, sprite.parent != nil else { return }
        let size = sprite.size
        let anchor = sprite.anchorPoint
        let lowerLeft = CGPoint(x: -anchor.x * size.width, y: -anchor.y * size.height)
        let upperRight = CGPoint(
            x: (1 - anchor.x) * size.width,
            y: (1 - anchor.y) * size.height
        )
        let a = scene.convert(lowerLeft, from: sprite)
        let b = scene.convert(upperRight, from: sprite)
        let worldRect = CGRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
        IEBlitShader.updateStencil(
            shader,
            texture: texture,
            spriteWorldRect: worldRect,
            stencilFrame: worldFrame
        )
    }

    /// Draw this sprite unmasked — `SetDrawingStencilForScriptable` returning
    /// `BlitFlags::NONE`.
    static func clear(on sprite: SKSpriteNode) {
        (sprite as? IEAvatarNode)?.nativeWallStencil = nil
        guard let shader = sprite.shader else { return }
        IEBlitShader.updateStencil(
            shader,
            texture: nil,
            spriteWorldRect: .zero,
            stencilFrame: .zero
        )
    }
}

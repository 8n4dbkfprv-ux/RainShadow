import CoreGraphics
import SpriteKit

/// How an actor is presented while standing behind covering scenery.
///
/// Baldur's Gate has no scenery sprites to sort against. Its background is flat,
/// and the WED marks which painted geometry stands in front of the floor with
/// wall polygons flagged `Cover animations`. A creature that walks behind one is
/// not hidden — the engine redraws the wall over it and stipples the creature
/// through, which is why a party behind a building reads as translucent
/// silhouettes instead of vanishing.
///
/// Reproducing it used to mean drawing the actor **over** the scenery at a flat
/// alpha of 0.42, because "SpriteKit has no stencil blit". That reasoning was
/// half right. The draw order was correct and is kept. The flat alpha was not:
/// it dropped the *whole* actor whenever their ground point fell inside a
/// covering outline, where upstream masks only the pixels the wall actually
/// overlaps — so a character half-behind a pillar kept an exposed half that
/// RainShadow made translucent along with the rest.
///
/// SpriteKit does have a way to do it per pixel: an `SKShader` sampling a baked
/// mask. See ``AreaWallStencil`` for the mask and ``IEBlitShader`` for the
/// `STENCIL_DITHER` path. What survives here is the depth lift.
/// An actor whose sprite layers can be masked by the area's wall stencil.
///
/// A protocol because `BaseGameScene.applyActorCover` works in `SKNode` and the
/// two actor types own their own layers; the alternative is the scene reaching
/// into their internals.
@MainActor
protocol WallStencilledActor: SKNode {
    func applyWallStencil(_ stencil: WallStencilTexture?, in scene: SKScene)
}

@MainActor
enum ActorCover {
    /// Lift above the covering scenery, in the same units `updateDepth` sorts in.
    ///
    /// Large enough to clear anything on the depth layer — an actor at the far
    /// wall must still rise above scenery at the camera-near edge — while
    /// staying under `SceneLayer.occlusion`, which is authored foreground that
    /// covers unconditionally and is not what a wall polygon means.
    ///
    /// **This half was always right.** Upstream also draws the actor after the
    /// background and lets the stencil put the wall back in front; only the
    /// masking was wrong.
    static let depthLift: CGFloat = 3_000
}

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
/// Reproducing that needed one correction. The obvious reading of "dither the
/// covered actor" is to lower its alpha, and that does nothing: the actor is
/// *behind* an opaque object, so making it more transparent still shows the
/// object. BG's composite is wall pixels interleaved with creature pixels, and
/// the equivalent without a stencil blit is to draw the actor **over** the
/// scenery at partial alpha. A 50% stipple and a 0.42 alpha blend resolve to
/// nearly the same image; the difference is a pattern nobody can see at an
/// 80-pixel body height.
///
/// A screen-door pattern was rejected on those grounds rather than on effort:
/// SpriteKit has no stencil blit, and a per-pixel dither on a body that small
/// reads as noise rather than as transparency.
@MainActor
enum ActorCover {
    /// How much of the actor shows through. BG stipples every other pixel, which
    /// averages to a half; slightly less here because a RainShadow plate is far
    /// busier behind the silhouette than a 1998 tileset is.
    static let coveredAlpha: CGFloat = 0.42

    /// Lift above the covering scenery, in the same units `updateDepth` sorts in.
    ///
    /// Large enough to clear anything on the depth layer — an actor at the far
    /// wall must still rise above scenery at the camera-near edge — while
    /// staying under `SceneLayer.occlusion`, which is authored foreground that
    /// covers unconditionally and is not what a wall polygon means.
    static let depthLift: CGFloat = 3_000

    /// Apply the presentation. Returns the z offset to add to the actor's
    /// normal depth sort.
    @discardableResult
    static func apply(to node: SKNode, covered: Bool) -> CGFloat {
        node.alpha = covered ? coveredAlpha : 1
        return covered ? depthLift : 0
    }
}

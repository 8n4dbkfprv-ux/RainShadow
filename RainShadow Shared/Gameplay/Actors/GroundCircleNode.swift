import CoreGraphics
import SpriteKit

/// The underfoot ground circle, drawn as GemRB draws it.
///
/// `Selectable::DrawCircle` ends in a single call:
///
/// ```cpp
/// auto baseSize = CircleSize2Radius() * sizeFactor;
/// const Size s(baseSize * 8, baseSize * 6);
/// const Region r(Pos - p - s.Center(), s);
/// VideoDriver->DrawEllipse(r, *col);
/// ```
///
/// — an unfilled ellipse centred on the actor's position, stroked one device
/// pixel wide in a colour recomputed every frame. `GroundCircleResolver` decides
/// the colour and the size; this node is only the `DrawEllipse`.
///
/// It replaces a pair of painted PNGs whose colour was baked in and whose size
/// came from the contact shadow's footprint rather than from `circleSize`.
@MainActor
final class GroundCircleNode: SKShapeNode {
    /// On-screen width of the stroke, in points. `DrawEllipse` rasterises a
    /// one-pixel polyline at 1x; `lineWidth` is in world units here, so it is
    /// rescaled with the camera exactly as `HighlightOutlineLayer` does.
    static let edgeScreenPoints: CGFloat = 1

    /// Under the actor, over the shadow.
    ///
    /// `Actor::Draw` calls `DrawCircle` before any `DrawActorSprite`, so the
    /// sprite's feet occlude the middle of the ellipse. Ours sat at 0.5 and drew
    /// *over* the body instead — the comment said "below the body layers", the
    /// number did not.
    ///
    /// Zero is the value that means what the comment says. The soft contact
    /// shadow is also at local z 0 but is added to the actor first, and the body
    /// layers are added after, so SpriteKit's sibling order supplies the
    /// tie-break the engine gets from statement order: shadow, circle, body.
    static let localZPosition: CGFloat = 0

    private var appliedSize: CGSize = .zero

    override init() {
        super.init()
        name = "actor.groundCircle"
        fillColor = .clear
        // The engine's polyline is not antialiased. Ours is — SpriteKit gives no
        // way to turn it off on a stroked path, and a hard-aliased ellipse at our
        // zoom range would crawl. This is the one pixel-level departure.
        isAntialiased = true
        zPosition = Self.localZPosition
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("GroundCircleNode is created programmatically")
    }

    /// Draw what the resolver decided, or nothing at all.
    ///
    /// `nil` covers both of the engine's reasons not to draw — `ShouldDrawCircle`
    /// said no — and our one extra reason, which the detective supplies: the
    /// drawn body is not standing on the point the circle would mark.
    ///
    /// `cameraScale` is `playCameraScale` — world units per point — so the
    /// stroke keeps a constant on-screen width at every zoom step.
    func apply(_ circle: GroundCircle?, cameraScale: CGFloat) {
        guard let circle else {
            isHidden = true
            return
        }

        if circle.size != appliedSize {
            appliedSize = circle.size
            path = CGPath(
                ellipseIn: CGRect(
                    x: -circle.size.width / 2,
                    y: -circle.size.height / 2,
                    width: circle.size.width,
                    height: circle.size.height
                ),
                transform: nil
            )
        }

        strokeColor = SKColor(
            red: circle.color.red,
            green: circle.color.green,
            blue: circle.color.blue,
            alpha: circle.color.alpha
        )
        lineWidth = Self.edgeScreenPoints * cameraScale
        isHidden = false
    }
}

/// An actor that owns a ground circle.
///
/// GemRB reaches this state through `Selectable`, which every `Actor` is. We
/// have no such base class — the two actor nodes are unrelated `SKNode`s — so
/// the state and the two operations `GameControl` performs on it are named here
/// instead.
@MainActor
protocol GroundCircleHosting: SKNode {
    var groundCircleState: GroundCircleState { get set }
    /// Resolve and draw. `milliseconds` is wall clock, feeding `IEColorCycle`.
    func applyGroundCircle(cameraScale: CGFloat, milliseconds: UInt64)
}

extension GroundCircleHosting {
    /// `Selectable::IsOver` — is the pointer inside this actor's ground circle?
    /// The point must be in the same space as `position`.
    func isOverGroundCircle(_ point: CGPoint) -> Bool {
        GroundCircleResolver.isOverCircle(
            point,
            center: position,
            circleSize: groundCircleState.circleSize
        )
    }
}

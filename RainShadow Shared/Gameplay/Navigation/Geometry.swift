import CoreGraphics
import Foundation

/// The engine's distance and range arithmetic (GemRB `core/Geometry.cpp`,
/// `core/Core.cpp`).
///
/// These are separate from `Orientation.swift` because they answer a different
/// question: not "which way is that" but "is that within reach", which the
/// engine measures on an **ellipse**, not a circle. A foot is 16 world units
/// across and 12 up — the same 16:12 the search cell and the whole projection
/// lock are built on — so reach is wider east-west than north-south, exactly as
/// the ground reads.
enum IEGeometry {
    /// `Feet2Pixels` — how many world units one foot spans at this heading.
    ///
    /// Rounded into 5° intervals over a quarter turn the engine's own comment
    /// tabulates this as 16 16 16 16 15 15 15 14 14 14 13 13 13 12 12 12 12 12 12:
    /// sixteen units due east, twelve due north.
    ///
    /// The engine feeds this a fast rational `atan2` approximation accurate to
    /// 0.162°. We use the exact one: only `sin²` and `cos²` reach the formula,
    /// so neither the approximation's error nor the sign of `dy` — our world is
    /// y-up, the engine's is y-down — can change the answer.
    static func feetToUnits(_ feet: Int, angle: CGFloat) -> CGFloat {
        let sin2 = pow(sin(angle) / 12, 2)
        let cos2 = pow(cos(angle) / 16, 2)
        return sqrt(1 / (cos2 + sin2)) * CGFloat(feet)
    }

    /// `AngleFromPoints(p1, p2)`. Degenerate input answers `-pi/2`, as the
    /// engine does.
    static func angle(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        if dx == 0 && dy == 0 { return -.pi / 2 }
        return atan2(dy, dx)
    }

    /// `Selectable::CircleSize2Radius`. For size >= 2 the feet circle's radii
    /// are `(size - 1) * 16` by `(size - 1) * 12`; size 1 is a special case at
    /// 12 by 9, which is where the floor at 3 comes from.
    static func circleSizeToRadius(_ circleSize: Int) -> Int {
        let adjusted = (circleSize - 1) * 4
        return adjusted < 4 ? 3 : adjusted
    }

    /// `BasePoint::IsWithinEllipse(r, p, a, b)`. The defaults are the engine's:
    /// a foot is 16 units across and 12 up, so `r` counts search cells outward
    /// on both axes at once.
    ///
    /// ```cpp
    /// if (d.x < -r * a || d.x > r * a) return false;
    /// if (d.y < -r * b || d.y > r * b) return false;
    /// int ar = b * b * d.x * d.x + a * a * d.y * d.y;
    /// return ar <= a * a * b * b * r * r;
    /// ```
    ///
    /// The bounding-box rejection is not merely an optimisation: it is what
    /// keeps the products below from overflowing on a far-away point, which is
    /// why it is kept rather than folded into the ellipse test. Sign of `dy` is
    /// irrelevant — our world is y-up and the engine's y-down, and only `dy²`
    /// reaches the comparison.
    static func isWithinEllipse(
        _ point: CGPoint,
        of center: CGPoint,
        radius r: Int,
        a: Int = 16,
        b: Int = 12
    ) -> Bool {
        let dx = Int(point.x - center.x)
        let dy = Int(point.y - center.y)
        if dx < -r * a || dx > r * a { return false }
        if dy < -r * b || dy > r * b { return false }
        let ar = b * b * dx * dx + a * a * dy * dy
        return ar <= a * a * b * b * r * r
    }

    /// `DistanceFactor` — the engine scales the feet-circle radius by this
    /// before subtracting it, with the comment "ignore angle, go for the bigger
    /// size between [3, 4]".
    static let distanceFactor = 4

    /// `PersonalDistance(p, b)` — centre distance less the body's own feet
    /// circle, floored at zero. Truncated to a whole unit, as the engine's cast
    /// to `unsigned int` does.
    static func personalDistance(from point: CGPoint, to actor: CGPoint, circleSize: Int) -> Int {
        let raw = hypot(point.x - actor.x, point.y - actor.y)
            - CGFloat(circleSizeToRadius(circleSize) * distanceFactor)
        return raw < 0 ? 0 : Int(raw)
    }

    /// `WithinPersonalRange(actor, dest, distance)` — is `dest` within
    /// `distance` feet of the actor's feet circle, measured on the ellipse.
    static func withinPersonalRange(
        actor: CGPoint,
        circleSize: Int,
        destination: CGPoint,
        feet: Int
    ) -> Bool {
        let heading = angle(from: actor, to: destination)
        let distance = personalDistance(from: destination, to: actor, circleSize: circleSize)
        return CGFloat(distance) <= feetToUnits(feet, angle: heading)
    }
}

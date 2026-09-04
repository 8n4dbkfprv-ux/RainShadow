import CoreGraphics
import Foundation

/// The Infinity Engine's sixteen orientations, numbered as GemRB numbers them
/// (`core/Orientation.h`): `S = 0` and increasing clockwise on screen, so
/// `W = 4`, `N = 8`, `E = 12`.
///
/// The numbering is load-bearing, not cosmetic. `getNextFace`'s shorter-arc
/// comparison, `reduceToHalf`, `reflectOrientation`, `flipOrientation` and the
/// `sixteenToNine` art table are all arithmetic on the raw value, and they only
/// work against this order.
///
/// One deliberate adaptation: the engine's world is y-down, ours (SpriteKit) is
/// y-up. Every conversion between a vector and an orientation therefore flips
/// the sign of dy relative to the engine source. GemRB does the same flip
/// internally — `GetOrient` calls `AngleFromPoints(-deltaY, deltaX)` — so the
/// intermediate angle is the same quantity in both.
enum ActorFacing: Int, CaseIterable, Sendable {
    case south = 0
    case southSouthWest
    case southWest
    case westSouthWest
    case west
    case westNorthWest
    case northWest
    case northNorthWest
    case north
    case northNorthEast
    case northEast
    case eastNorthEast
    case east
    case eastSouthEast
    case southEast
    case southSouthEast

    /// `MAX_ORIENT` in the engine.
    static let count = 16
    static let sectorAngle = CGFloat.pi / 8

    // MARK: - Arithmetic (GemRB `core/Orientation.h`)

    /// `ClampToOrientation` — the engine masks rather than modulos, so negative
    /// values wrap the same way.
    static func clamped(_ raw: Int) -> ActorFacing {
        ActorFacing(rawValue: raw & (count - 1)) ?? .south
    }

    /// `NextOrientation` — clockwise on screen.
    func next(_ step: Int = 1) -> ActorFacing {
        Self.clamped(rawValue + step)
    }

    /// `PrevOrientation` — counter-clockwise on screen.
    func previous(_ step: Int = 1) -> ActorFacing {
        Self.clamped(rawValue - step)
    }

    /// `ReduceToHalf` — some animations only carry eight orientations.
    var reducedToHalf: ActorFacing {
        Self.clamped(rawValue & ~1)
    }

    /// `ReflectOrientation` — reflects through the centre.
    var reflected: ActorFacing {
        Self.clamped(rawValue ^ 8)
    }

    /// `FlipOrientation` — reflects over the vertical axis.
    var flipped: ActorFacing {
        Self.clamped(16 - rawValue)
    }

    /// `GetMathyOrientation`. Orientations start at 270° with S and run
    /// clockwise; trigonometry wants counter-clockwise from E. Multiply the
    /// result by `sectorAngle` to get an angle usable with `cos`/`sin`.
    var mathy: ActorFacing {
        ActorFacing.east.previous(rawValue)
    }

    /// The unit vector this orientation faces, in world (y-up) space.
    var vector: CGVector {
        let angle = CGFloat(mathy.rawValue) * Self.sectorAngle
        return CGVector(dx: cos(angle), dy: sin(angle))
    }

    /// `OrientedOffset` — the engine's integer step in this direction. Used by
    /// `AdjustPositionDirected` to walk outward in search-map cells, so the sign
    /// of the vertical component is in *cell* space, which is y-up like ours.
    func offset(_ distance: Int) -> (dx: Int, dy: Int) {
        let dy: Int
        switch self {
        case .westNorthWest, .northWest, .northNorthWest, .north,
             .northNorthEast, .northEast, .eastNorthEast:
            dy = 1
        case .west, .east:
            dy = 0
        default:
            dy = -1
        }

        let dx: Int
        switch self {
        case .southSouthWest, .southWest, .westSouthWest, .west,
             .westNorthWest, .northWest, .northNorthWest:
            dx = -1
        case .south, .north:
            dx = 0
        default:
            dx = 1
        }

        return (dx * distance, dy * distance)
    }

    /// `GetNextFace` — one step of the engine's gradual turn, taking the shorter
    /// arc. A standing creature rotates one 22.5° bin per logic tick; at 15 Hz a
    /// half-turn takes eight ticks, about 0.53 s. Walking creatures do not use
    /// this — `DoStep` assigns the path node's orientation outright.
    ///
    /// A clean 180° resolves toward increasing raw value, as the engine's
    /// `<= MAX_ORIENT / 2` comparison does.
    func stepped(toward target: ActorFacing) -> ActorFacing {
        guard self != target else { return self }
        return Self.clamped(target.rawValue - rawValue).rawValue <= Self.count / 2
            ? next()
            : previous()
    }

    /// `GetOrient` — the orientation that faces `to` from `from`.
    ///
    /// Transliterated including the fixed-point segment arithmetic, so ties fall
    /// the same way as the engine's. `dy` is *not* negated here the way the
    /// engine negates it, because our world is already y-up.
    static func orient(from: CGPoint, to: CGPoint) -> ActorFacing {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        if deltaX == 0 {
            // The engine's degenerate case (both deltas zero) answers S.
            return deltaY > 0 ? .north : .south
        }

        let angle = atan2(deltaY, deltaX)
        let halfSector = sectorAngle / 2
        let fullTurn = CGFloat.pi * 2
        let segment = (angle + halfSector + fullTurn)
            .truncatingRemainder(dividingBy: fullTurn)
        return ActorFacing.east.previous(Int(segment / sectorAngle))
    }

    /// Convenience for callers holding a delta rather than two points.
    static func orient(dx: CGFloat, dy: CGFloat) -> ActorFacing {
        orient(from: .zero, to: CGPoint(x: dx, y: dy))
    }

    // MARK: - Art

    /// `SixteenToNine` — the engine folds sixteen orientations onto nine
    /// authored strips, mirroring the eastern seven.
    static let sixteenToNine: [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1]

    /// Eastern orientations reuse the mirrored western strip.
    var isMirrored: Bool {
        switch self {
        case .northNorthEast, .northEast, .eastNorthEast, .east,
             .eastSouthEast, .southEast, .southSouthEast:
            true
        default:
            false
        }
    }

    /// Preferred source first, followed by fallbacks present in today's atlas.
    var textureSourceCandidates: [String] {
        switch self {
        case .south: ["s"]
        case .southSouthWest, .southSouthEast: ["ssw", "s", "sw"]
        case .southWest, .southEast: ["sw"]
        case .westSouthWest, .eastSouthEast: ["wsw", "sw", "w"]
        case .west, .east: ["w"]
        case .westNorthWest, .eastNorthEast: ["wnw", "w", "nw"]
        case .northWest, .northEast: ["nw"]
        case .northNorthWest, .northNorthEast: ["nnw", "nw", "n"]
        case .north: ["n"]
        }
    }
}

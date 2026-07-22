import CoreGraphics
import Foundation

/// Pure, SpriteKit-independent route execution for player and NPC actors.
///
/// Infinity Engine movement advances a creature toward successive path nodes at
/// a constant movement rate. Keeping the same responsibility in a value type
/// makes retargeting, pausing, arrival, and overshoot deterministic instead of
/// relying on a chain of independently timed `SKAction.move` operations.
struct RouteFollower {
    struct Step: Equatable {
        let position: CGPoint
        let direction: CGVector
        let didArrive: Bool
    }

    private(set) var waypoints: [CGPoint] = []
    let arrivalTolerance: CGFloat

    init(arrivalTolerance: CGFloat = 0.25) {
        precondition(arrivalTolerance >= 0)
        self.arrivalTolerance = arrivalTolerance
    }

    var isMoving: Bool { !waypoints.isEmpty }
    var destination: CGPoint? { waypoints.last }

    mutating func replaceRoute(with route: [CGPoint], from position: CGPoint) {
        waypoints = route
        discardReachedWaypoints(from: position)
    }

    /// Supports BG-style queued waypoints without coupling the follower to a
    /// particular input scheme. The current single-actor scenes use replacement
    /// orders; party input can opt into this when it is introduced.
    mutating func appendRoute(_ route: [CGPoint]) {
        for point in route where waypoints.last.map({ distance($0, point) > arrivalTolerance }) ?? true {
            waypoints.append(point)
        }
    }

    mutating func cancel() {
        waypoints.removeAll(keepingCapacity: true)
    }

    mutating func advance(
        from position: CGPoint,
        deltaTime: TimeInterval,
        speed: CGFloat
    ) -> Step {
        let wasMoving = isMoving
        guard wasMoving, deltaTime > 0, speed > 0 else {
            return Step(position: position, direction: .zero, didArrive: false)
        }

        var current = position
        var travelBudget = speed * CGFloat(deltaTime)
        var lastDirection = CGVector.zero

        while travelBudget > 0, let target = waypoints.first {
            let dx = target.x - current.x
            let dy = target.y - current.y
            let segmentDistance = hypot(dx, dy)

            if segmentDistance <= CGFloat.ulpOfOne {
                current = target
                waypoints.removeFirst()
                continue
            }

            lastDirection = CGVector(dx: dx / segmentDistance, dy: dy / segmentDistance)
            if travelBudget >= segmentDistance {
                current = target
                travelBudget = max(0, travelBudget - segmentDistance)
                waypoints.removeFirst()
            } else {
                current = CGPoint(
                    x: current.x + lastDirection.dx * travelBudget,
                    y: current.y + lastDirection.dy * travelBudget
                )
                travelBudget = 0
            }
        }

        return Step(
            position: current,
            direction: lastDirection,
            didArrive: wasMoving && waypoints.isEmpty
        )
    }

    private mutating func discardReachedWaypoints(from position: CGPoint) {
        while let first = waypoints.first, distance(position, first) <= arrivalTolerance {
            waypoints.removeFirst()
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

/// Sixteen logical directions with a small dead band at sector boundaries.
/// Current art can fall back to the nearest five stored western directions;
/// adding the four missing intermediate source strips will automatically expose
/// all sixteen distinct presentations without changing movement code.
enum ActorFacing: Int, CaseIterable {
    case east = 0
    case eastNorthEast
    case northEast
    case northNorthEast
    case north
    case northNorthWest
    case northWest
    case westNorthWest
    case west
    case westSouthWest
    case southWest
    case southSouthWest
    case south
    case southSouthEast
    case southEast
    case eastSouthEast

    static let sectorAngle = CGFloat.pi / 8
    static let defaultHysteresis = CGFloat.pi / 60 // 3 degrees

    var isMirrored: Bool {
        switch self {
        case .east, .eastNorthEast, .northEast, .northNorthEast,
             .southSouthEast, .southEast, .eastSouthEast:
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

    static func resolve(
        dx: CGFloat,
        dy: CGFloat,
        retaining current: ActorFacing,
        hysteresis: CGFloat = defaultHysteresis
    ) -> ActorFacing {
        guard dx != 0 || dy != 0 else { return current }

        let angle = normalizedAngle(atan2(dy, dx))
        let currentCenter = CGFloat(current.rawValue) * sectorAngle
        let distanceFromCurrent = angularDistance(angle, currentCenter)
        if distanceFromCurrent <= sectorAngle * 0.5 + max(0, hysteresis) {
            return current
        }

        let sector = Int((angle / sectorAngle).rounded()) % allCases.count
        return ActorFacing(rawValue: sector) ?? current
    }

    private static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        let remainder = angle.truncatingRemainder(dividingBy: fullTurn)
        return remainder >= 0 ? remainder : remainder + fullTurn
    }

    private static func angularDistance(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        let raw = abs(a - b).truncatingRemainder(dividingBy: fullTurn)
        return min(raw, fullTurn - raw)
    }
}

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

    /// Supports BG:EE-style queued waypoints (Shift+click / long-press) without
    /// coupling the follower to a particular input scheme. Scenes route from the
    /// last queued goal and append; plain click still uses `replaceRoute`.
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

/// Authored Lila exit strips: NW for western/northern travel (chair→internal door),
/// NE for eastern travel (door→corridor→exterior). Never mirror — handbag stays left.
enum ClientDepartureFacing: Equatable, Sendable {
    case northEast
    case northWest

    /// Map a path segment heading to the authored departure strip without mirroring.
    static func bin(dx: CGFloat, dy: CGFloat) -> ClientDepartureFacing {
        let facing = ActorFacing.resolve(dx: dx, dy: dy, retaining: .northEast, hysteresis: 0)
        switch facing {
        case .northWest, .northNorthWest, .westNorthWest, .west, .westSouthWest, .north:
            return .northWest
        default:
            return .northEast
        }
    }

    /// Per-segment strip bins along a departure polyline (skips zero-length edges).
    static func bins(along points: [CGPoint]) -> [ClientDepartureFacing] {
        guard points.count >= 2 else { return [] }
        var result: [ClientDepartureFacing] = []
        for index in 0..<(points.count - 1) {
            let dx = points[index + 1].x - points[index].x
            let dy = points[index + 1].y - points[index].y
            if dx == 0 && dy == 0 { continue }
            result.append(bin(dx: dx, dy: dy))
        }
        return result
    }

    /// Direction used for strip selection on dense paths: accumulate along the
    /// remaining polyline until at least `minimumDistance` of travel (or the end).
    static func lookAheadVector(
        along points: [CGPoint],
        fromIndex: Int,
        minimumDistance: CGFloat
    ) -> (dx: CGFloat, dy: CGFloat) {
        guard fromIndex >= 0, fromIndex < points.count - 1 else {
            return (dx: 0, dy: 0)
        }
        let origin = points[fromIndex]
        var traveled: CGFloat = 0
        var cursor = origin
        for index in (fromIndex + 1)..<points.count {
            let next = points[index]
            let step = hypot(next.x - cursor.x, next.y - cursor.y)
            if step <= 0.25 {
                cursor = next
                continue
            }
            traveled += step
            cursor = next
            if traveled >= minimumDistance {
                break
            }
        }
        return (dx: cursor.x - origin.x, dy: cursor.y - origin.y)
    }

    /// Rotate an 8-frame walk strip so playback continues at `phase` (handoff continuity).
    static func texturesStartingAtPhase<T>(_ textures: [T], phase: Int) -> [T] {
        guard !textures.isEmpty else { return textures }
        let count = textures.count
        let start = ((phase % count) + count) % count
        if start == 0 { return textures }
        return Array(textures[start...]) + Array(textures[..<start])
    }
}

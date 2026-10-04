import CoreGraphics
import Foundation

/// Authored Lila exit strips: NW for western/northern travel (chair→internal door),
/// NE for eastern travel (door→corridor→exterior). Never mirror — handbag stays left.
enum ClientDepartureFacing: Equatable, Sendable {
    case northEast
    case northWest

    /// Map a path segment heading to the authored departure strip without mirroring.
    static func bin(dx: CGFloat, dy: CGFloat) -> ClientDepartureFacing {
        switch ActorFacing.orient(dx: dx, dy: dy) {
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

/// GemRB 1c45c185 Animation::NextFrame, looping game-animation branch.
/// Animation advances independently of DoStep. The returned frame is sampled
/// before advancing, time is integral milliseconds, and pause gaps are excluded.
struct ActorAnimationClock: Equatable, Sendable {
    private var start: Int?
    private var lastTime = 0
    private var paused = false
    private var index = 0

    mutating func reset() { self = Self() }

    mutating func frame(at seconds: TimeInterval, count: Int, fps: Int = 15, frozen: Bool) -> Int {
        guard count > 0, fps > 0 else { return 0 }
        let result = index % count
        let now = Int(max(0, seconds) * 1000)
        var time = now
        if frozen {
            time = lastTime
            paused = true
        } else {
            if paused {
                paused = false
                if let origin = start { start = origin + now - lastTime }
            }
            lastTime = now
        }
        if start == nil { start = time }
        let duration = max(1, 1000 / fps)
        let elapsed = max(0, time - (start ?? time))
        if elapsed >= duration {
            index = (index + elapsed / duration) % count
            start = time
        }
        return result
    }
}

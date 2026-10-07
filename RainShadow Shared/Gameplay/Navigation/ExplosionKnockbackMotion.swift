import Foundation
import CoreGraphics

/// Closed-form impulse plus constant ground friction, in unprojected world units.
/// The navigation raster has already certified `to`; reaching it is an inelastic
/// collision (or the natural resting point). Never integrate past that endpoint.
enum ExplosionKnockbackMotion {
    static let initialSpeed = 320.0
    static let friction = initialSpeed * initialSpeed / (2 * CombatBarrel.pushDistance)
    static let stoppingTime = initialSpeed / friction

    static func stopTime(from: CGPoint, to: CGPoint) -> Double {
        let distance = min(CombatBarrel.pushDistance, CombatNavigation.distance(from, to))
        let remainingSpeed = sqrt(max(0, initialSpeed * initialSpeed - 2 * friction * distance))
        return 2 * distance / (initialSpeed + remainingSpeed)
    }
    static func position(from: CGPoint, to: CGPoint, elapsed: Double) -> CGPoint {
        let distance = CombatNavigation.distance(from, to)
        guard distance > 0, elapsed > 0 else { return from }
        let contact = stopTime(from: from, to: to)
        guard elapsed < contact else { return to }
        let travel = initialSpeed * elapsed - 0.5 * friction * elapsed * elapsed
        let fraction = CGFloat(min(1, max(0, travel / distance)))
        return CGPoint(x: from.x + (to.x - from.x) * fraction,
                       y: from.y + (to.y - from.y) * fraction).rounded
    }
    /// Reorient during the last planted recovery poses, preserving the actor's
    /// gameplay facing and sight cone rather than changing them with an effect.
    static func recoveryFacing(from: ActorFacing, to: ActorFacing, phase: Int, frames: Int) -> ActorFacing {
        let fraction = min(1, max(0, Double(phase - (frames - 6)) / 5))
        let delta = (to.rawValue - from.rawValue + 24) % 16 - 8
        let step = from.rawValue + Int((Double(delta) * fraction).rounded())
        return ActorFacing(rawValue: (step + 32) % 16)!
    }
    /// Strong/overlapping blasts topple a survivor only when there is room to fall.
    /// This is cosmetic recovery, not an extra prone condition or action charge.
    static func reaction(distanceFromBlast: Double, blasts: Int, travel: Double) -> CombatReactionKind {
        guard travel >= 12 else { return .hit }
        return travel >= 32 && (blasts > 1 || distanceFromBlast <= CombatBarrel.blastRadius * 0.65) ? .fall : .stumble
    }
}

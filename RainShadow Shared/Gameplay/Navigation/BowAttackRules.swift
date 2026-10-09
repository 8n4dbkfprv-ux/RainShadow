import Foundation
import CoreGraphics

/// RainShadow lookout rules. Equipment carry visuals and inventory ammunition
/// are independent: NPCs own a quiver; this does not spend the player's arrows.
enum CombatRangedWeapon: String, Codable { case bow }

enum CombatAmmunition: String, Codable {
    case normal, fire
    static let fireItemID = "fire-arrow"
}

enum BowAttackRules {
    static let range: Double = 640
    static let frames = 18
    static let framesPerSecond: Double = 15
    static let releasePhase = 10
    static let releaseTime = Double(releasePhase) / framesPerSecond
    static let recoveryTime = Double(frames) / framesPerSecond
    static func canShoot(attacker: Combatant, target: Combatant, clearLine: Bool) -> Bool {
        let distance = CombatNavigation.distance(attacker.position, target.position)
        return attacker.rangedWeapon == .bow && clearLine
            && distance > TacticalCombat.meleeReach && distance <= range
    }
    static func flightDuration(from: CGPoint, to: CGPoint) -> Double {
        min(0.65, max(0.22, CombatNavigation.distance(from, to) / 850))
    }
    static func arrowPosition(from: CGPoint, to: CGPoint, progress: Double) -> CGPoint {
        let t = min(1, max(0, progress))
        return CGPoint(x: from.x + (to.x - from.x) * t,
                       y: from.y + (to.y - from.y) * t + sin(t * .pi) * 7)
    }
}

import Foundation
import CoreGraphics

/// Presentation only: authored poses and markers never change combat outcomes.
enum WeaponTechniqueMotion {
    static func meleeFrames(_ move: CombatManeuver?) -> Int {
        move == .powerStrike ? 14 : move == .feintingCut ? 13 : MeleeAttackAnimationSet.frames
    }
    static func meleeFPS(_ move: CombatManeuver?) -> Double { move == .feintingCut ? 18 : 15 }
    static func meleeImpact(_ move: CombatManeuver?) -> Double {
        Double(move == .powerStrike || move == .feintingCut ? 8 : 6) / meleeFPS(move)
    }
    static func meleeDuration(_ move: CombatManeuver?) -> Double { Double(meleeFrames(move)) / meleeFPS(move) }
    static func trailStart(_ move: CombatManeuver?) -> Double { move == .powerStrike ? 6 : move == .feintingCut ? 6 : 4 }
    static func trailEnd(_ move: CombatManeuver?) -> Double { move == .powerStrike || move == .feintingCut ? 9 : 7 }
    static func aimHold(_ move: CombatManeuver?) -> Double { move == .aimedShot ? 0.4 : 0 }
    static func bowRelease(_ move: CombatManeuver?) -> Double { BowAttackRules.releaseTime + aimHold(move) }
    static func bowDuration(_ move: CombatManeuver?) -> Double { BowAttackRules.recoveryTime + aimHold(move) }
    static func bowPhase(elapsed: Double, move: CombatManeuver?) -> Int {
        // Hold the fully drawn phase 9, then release with the ordinary phase 10.
        let holdStart = 9.0 / BowAttackRules.framesPerSecond
        let sample = elapsed <= holdStart ? elapsed : max(holdStart, elapsed - aimHold(move))
        return min(BowAttackRules.frames - 1, max(0, Int(sample * BowAttackRules.framesPerSecond + 1e-9)))
    }
}

enum CombatReactionKind: String, CaseIterable {
    case hit, dodge
    var frames: Int { self == .hit ? 8 : 10 }
}

/// Authored reaction clock; the optional lean adds weight without navigation displacement.
struct CombatRecoil {
    let kind: CombatReactionKind
    let strength: Double
    let direction: Double
    var elapsed = 0.0
    static let dodgeLeadTime = 3.0 / 20
    var duration: Double { kind == .dodge ? 0.5 : strength > 1 ? 0.64 : 0.4 }
    var phase: Int { min(kind.frames - 1, max(0, Int(elapsed / duration * Double(kind.frames)))) }
    var finished: Bool { elapsed >= duration }
    var angle: Double {
        let t = min(1, max(0, elapsed / duration))
        // Fast impact, one small settling motion, exact return to neutral.
        return direction * (kind == .dodge ? 0 : strength) * 0.035 * sin(t * .pi) * (1 - 0.3 * t)
    }
    init(from attacker: CGPoint, to target: CGPoint, heavy: Bool, kind: CombatReactionKind = .hit) {
        self.kind = kind
        strength = heavy ? 2.2 : 1
        direction = target.x >= attacker.x ? -1 : 1
    }
}

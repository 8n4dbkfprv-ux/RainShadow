import Foundation
import CoreGraphics

/// Presentation only: authored poses and markers never change combat outcomes.
enum WeaponTechniqueMotion {
    static func meleeFrames(_ move: CombatManeuver?) -> Int {
        move == .tripAttack ? 16 : move == .powerStrike ? 14 : move == .feintingCut ? 13 : MeleeAttackAnimationSet.frames
    }
    /// Source rate is retained during the blade's fast contact arc. Preparation
    /// and settling have their own clocks; do not derive playback from one FPS.
    static func meleeFPS(_ move: CombatManeuver?) -> Double { move == .feintingCut || move == .tripAttack ? 18 : 15 }
    static func meleeWindup(_ move: CombatManeuver?) -> Double {
        move == .powerStrike ? 0.65 : move == .feintingCut || move == .tripAttack ? 0.45 : 0.4
    }
    static func meleeDuration(_ move: CombatManeuver?) -> Double {
        move == .powerStrike ? 1.4 : move == .feintingCut ? 1.0 : move == .tripAttack ? 1.15 : 1.1
    }
    /// Inverse marker mapping shared by contact, trail fade and the body clock.
    static func meleeTime(atFrame frame: Double, move: CombatManeuver?) -> Double {
        let start = trailStart(move), end = trailEnd(move), total = Double(meleeFrames(move))
        let phase = min(total, max(0, frame))
        let windup = meleeWindup(move), sweep = (end - start) / meleeFPS(move)
        if phase <= start { return phase / start * windup }
        if phase <= end { return windup + (phase - start) / meleeFPS(move) }
        return windup + sweep + (phase - end) / (total - end) * (meleeDuration(move) - windup - sweep)
    }
    static func meleeFrame(elapsed: Double, move: CombatManeuver?) -> Double {
        guard elapsed > 0 else { return 0 }
        let start = trailStart(move), end = trailEnd(move), total = Double(meleeFrames(move))
        let windup = meleeWindup(move), sweep = (end - start) / meleeFPS(move)
        if elapsed <= windup { return elapsed / windup * start }
        if elapsed <= windup + sweep { return start + (elapsed - windup) * meleeFPS(move) }
        if elapsed >= meleeDuration(move) { return total }
        return end + (elapsed - windup - sweep) / (meleeDuration(move) - windup - sweep) * (total - end)
    }
    static func meleePhase(elapsed: Double, move: CombatManeuver?) -> Int {
        min(meleeFrames(move) - 1, Int(meleeFrame(elapsed: elapsed, move: move) + 1e-9))
    }
    static func meleeImpact(_ move: CombatManeuver?) -> Double {
        meleeTime(atFrame: move == .powerStrike || move == .feintingCut || move == .tripAttack ? 8 : 6, move: move)
    }
    static func trailStart(_ move: CombatManeuver?) -> Double { move == .tripAttack ? 6 : move == .powerStrike ? 6 : move == .feintingCut ? 6 : 4 }
    static func trailEnd(_ move: CombatManeuver?) -> Double { move == .powerStrike || move == .feintingCut || move == .tripAttack ? 9 : 7 }
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
    case hit, dodge, stumble, fall
    case tripFall = "tripfall"
    var frames: Int {
        switch self { case .hit: 8; case .dodge: 10; case .stumble: 16; case .fall, .tripFall: 24 }
    }
    var isKnockback: Bool { self == .stumble || self == .fall }
}

/// Authored reaction clock; the optional lean adds weight without navigation displacement.
struct CombatRecoil {
    let kind: CombatReactionKind
    let strength: Double
    let direction: Double
    var elapsed = 0.0
    static let dodgeLeadTime = 3.0 / 20
    var duration: Double { (kind.isKnockback || kind == .tripFall) ? Double(kind.frames) / 20 : kind == .dodge ? 0.5 : strength > 1 ? 0.64 : 0.4 }
    var phase: Int { min(kind.frames - 1, max(0, Int(elapsed / duration * Double(kind.frames)))) }
    var finished: Bool { elapsed >= duration }
    var angle: Double {
        let t = min(1, max(0, elapsed / duration))
        // Fast impact, one small settling motion, exact return to neutral.
        return direction * (kind == .hit ? strength : 0) * 0.035 * sin(t * .pi) * (1 - 0.3 * t)
    }
    init(from attacker: CGPoint, to target: CGPoint, heavy: Bool, kind: CombatReactionKind = .hit) {
        self.kind = kind
        strength = heavy ? 2.2 : 1
        direction = target.x >= attacker.x ? -1 : 1
    }
}

/// Split the dedicated trip reaction at its braced ground pose. Recovery resumes on the
/// victim's turn; only the presentation clock waits, never initiative itself.
enum ProneMotion {
    static let holdPhase = 12
    static let holdTime = Double(holdPhase) / 20
}

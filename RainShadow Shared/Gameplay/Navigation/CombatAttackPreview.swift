import Foundation

/// Read-only forecast. Uses the same eligibility and damage functions as resolution;
/// never samples or advances the encounter's random stream.
struct CombatAttackPreview {
    let elevationModifier: Int
    let hitChance: Double
    let damage: ClosedRange<Int>
    let criticalDamage: ClosedRange<Int>
    let edge: Int
    let sneakDice: Int
    let unavailableReason: String?
    let cost: String
}

extension TacticalCombat {
    func attackUnavailableReason(target: Combatant, clearLine: Bool, ranged: Bool,
                                 ammunition: CombatAmmunition, maneuver: CombatManeuver?,
                                 hasSword: Bool, requireSneakAttack: Bool,
                                 allyLine: (Combatant, Combatant) -> Bool) -> String? {
        guard outcome == nil, target.conscious, target.player != current.player else { return "Target is invalid" }
        guard target.hidden != true else { return "Target is out of sight" }
        guard clearLine else { return "Target is blocked!" }
        if ammunition == .fire && (!ranged || maneuver != nil || requireSneakAttack) { return "Can't use" }
        if ammunition == .fire && !current.player && (current.fireArrows ?? 0) <= 0 { return "Can't use" }
        if ranged {
            guard !(current.player && isBear), current.rangedWeapon == .bow else { return "Can't use" }
            let distance = CombatNavigation.distance(current.position, target.position)
            guard distance > Self.meleeReach else { return "Can't use" }
            guard distance <= BowAttackRules.range else { return "Target is too far" }
        } else if CombatNavigation.distance(current.position, target.position) > Self.meleeReach
            || !canReachHeight(from: current.position, to: target.position) {
            return "Target is too far"
        }
        if let maneuver {
            guard current.player || current.enemyRole?.maneuvers.contains(maneuver) != false else { return "Can't use" }
            guard !(current.player && isBear) else { return "You cannot do this in your current form!" }
            guard maneuver.ranged == ranged, ranged || hasSword else { return "Can't use" }
            guard !(current.usedManeuvers ?? []).contains(maneuver) else { return "Can't use" }
            if maneuver == .tripAttack && (target.isProne || (target.player && isBear)) { return "Target is invalid" }
        }
        guard CombatBudget.transition(state: budget.state, cost: maneuver?.cost ?? 2) != nil else { return "Not enough resources: Action." }
        if requireSneakAttack {
            return sneakAttackReason(target: target, ranged: ranged, hasSword: hasSword, clearLine: clearLine, allyLine: allyLine)
        }
        return nil
    }

    static func weaponDamage(_ roll: Int, maneuver: CombatManeuver?) -> Int {
        if maneuver == .powerStrike { return roll + 3 }
        if maneuver == .feintingCut || maneuver == .pinningShot || maneuver == .tripAttack { return max(1, roll / 2) }
        return roll
    }
    static func attackHits(die: Int, bonus: Int, defence: Int) -> Bool {
        die == 20 || (die != 1 && die + bonus >= defence)
    }
    var weaponDamageRange: ClosedRange<Int> {
        current.player && isBear ? BearFormRules.damageMin...BearFormRules.damageMax : current.damageMin...current.damageMax
    }
    func attackPreview(target: Combatant, clearLine: Bool, ranged: Bool = false,
                       ammunition: CombatAmmunition = .normal, maneuver: CombatManeuver? = nil,
                       hasSword: Bool = false, requireSneakAttack: Bool = false,
                       allyLine: (Combatant, Combatant) -> Bool = { _, _ in true }) -> CombatAttackPreview {
        let edge = attackEdge(ranged: ranged, target: target, allyLine: allyLine)
        let elevation = elevationBonus(from: current.position, to: target.position, ranged: ranged)
        let bonus = attackBonus(for: current) + (maneuver?.accuracy ?? 0) + elevation
        let base = Double((1...20).filter { Self.attackHits(die: $0, bonus: bonus, defence: defence(for: target)) }.count) / 20
        let chance = edge > 0 ? 1 - pow(1 - base, 2) : edge < 0 ? base * base : base
        let dice = sneakAttackReason(target: target, ranged: ranged, hasSword: hasSword, clearLine: clearLine, allyLine: allyLine) == nil ? current.sneakDamageDice : 0
        func range(_ dice: Int) -> ClosedRange<Int> {
            let minimum = Self.weaponDamage(weaponDamageRange.lowerBound, maneuver: maneuver) + dice
            let maximum = Self.weaponDamage(weaponDamageRange.upperBound, maneuver: maneuver) + dice * 6
            return target.hasBladeWard ? (minimum / 2)...(maximum / 2) : minimum...maximum
        }
        return CombatAttackPreview(elevationModifier: elevation, hitChance: chance, damage: range(dice), criticalDamage: range(dice * 2), edge: edge, sneakDice: dice,
            unavailableReason: attackUnavailableReason(target: target, clearLine: clearLine, ranged: ranged, ammunition: ammunition,
                maneuver: maneuver, hasSword: hasSword, requireSneakAttack: requireSneakAttack, allyLine: allyLine),
            cost: "1 Action")
    }
}

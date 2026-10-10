import Foundation

/// Read-only forecast. Uses the same eligibility and damage functions as resolution;
/// never samples or advances the encounter's random stream.
struct CombatAttackPreview {
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
        guard outcome == nil, target.conscious, target.player != current.player else { return "Choose a conscious rival." }
        guard target.hidden != true else { return "The target is hidden." }
        guard clearLine else { return "Terrain or another character blocks the attack." }
        if ammunition == .fire && (!ranged || maneuver != nil || requireSneakAttack) { return "Fire Arrows require a normal Ranged Attack." }
        if ammunition == .fire && !current.player && (current.fireArrows ?? 0) <= 0 { return "No Fire Arrows remain." }
        if ranged {
            guard !(current.player && isBear), current.rangedWeapon == .bow else { return "Equip a bow in human form." }
            let distance = CombatNavigation.distance(current.position, target.position)
            guard distance > Self.meleeReach else { return "Too close for a bow. Move away or use melee." }
            guard distance <= BowAttackRules.range else { return "Outside bow range (80 ft)." }
        } else if CombatNavigation.distance(current.position, target.position) > Self.meleeReach {
            return "Outside melee reach. Move closer."
        }
        if let maneuver {
            guard current.player || current.enemyRole?.maneuvers.contains(maneuver) != false else { return "This technique is not in this enemy’s loadout." }
            guard !(current.player && isBear) else { return "Weapon techniques require human form." }
            guard maneuver.ranged == ranged, ranged || hasSword else { return "Equip the required weapon." }
            guard !(current.usedManeuvers ?? []).contains(maneuver) else { return "This technique is spent for this encounter." }
            if maneuver == .tripAttack && (target.isProne || (target.player && isBear)) { return "This target cannot be tripped." }
            if maneuver == .aimedShot && (budget.state != 4 || budget.movementRemaining != 0) { return "Aimed Shot requires a full turn, before moving." }
        }
        guard CombatBudget.transition(state: budget.state, cost: maneuver?.cost ?? 2) != nil else { return "No standard action remains." }
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
        let bonus = attackBonus(for: current) + (maneuver?.accuracy ?? 0)
        let base = Double((1...20).filter { Self.attackHits(die: $0, bonus: bonus, defence: defence(for: target)) }.count) / 20
        let chance = edge > 0 ? 1 - pow(1 - base, 2) : edge < 0 ? base * base : base
        let dice = sneakAttackReason(target: target, ranged: ranged, hasSword: hasSword, clearLine: clearLine, allyLine: allyLine) == nil ? current.sneakDamageDice : 0
        func range(_ dice: Int) -> ClosedRange<Int> {
            let minimum = Self.weaponDamage(weaponDamageRange.lowerBound, maneuver: maneuver) + dice
            let maximum = Self.weaponDamage(weaponDamageRange.upperBound, maneuver: maneuver) + dice * 6
            return target.hasBladeWard ? (minimum / 2)...(maximum / 2) : minimum...maximum
        }
        return CombatAttackPreview(hitChance: chance, damage: range(dice), criticalDamage: range(dice * 2), edge: edge, sneakDice: dice,
            unavailableReason: attackUnavailableReason(target: target, clearLine: clearLine, ranged: ranged, ammunition: ammunition,
                maneuver: maneuver, hasSword: hasSword, requireSneakAttack: requireSneakAttack, allyLine: allyLine),
            cost: maneuver == .aimedShot ? "Full turn · action + movement" : "1 standard action")
    }
}

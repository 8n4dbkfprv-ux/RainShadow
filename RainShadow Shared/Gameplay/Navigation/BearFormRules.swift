import Foundation

/// RainShadow's first magical form ability; not a claim of D&D Wild Shape fidelity.
enum BearFormRules {
    static let maximumEndurance = 8
    static let speed = 240.0
    static let attackBonus = 6
    static let defence = 14
    static let damageMin = 5
    static let damageMax = 8
    static let radius = 48.0
    static let circleSize = 5
    static let roarRadius = 240.0
    static let clawFPS = 20.0
    static let clawImpactTime = 12.0 / clawFPS
    static let clawDuration = Double(BearClawAnimationSet.frames) / clawFPS
    static let roarImpactTime = 9.0 / 20
    static let roarDuration = 24.0 / 20

    static func canStand(in map: NavigationMap, actor: Combatant) -> Bool {
        map.occupancy.withStampLifted(id: actor.id) {
            map.searchMap.blockedInRadiusTile(at: actor.position, size: circleSize).contains(.passable)
        }
    }
}

struct BearFormState: Codable, Equatable {
    var turnsRemaining = 3
    var temporaryHP = BearFormRules.maximumEndurance
    var activationTurn = true
    /// Optional so the original Bear Form checkpoints remain readable.
    var roarSpent: Bool? = nil
    var isValid: Bool {
        (0...3).contains(turnsRemaining) && (0...BearFormRules.maximumEndurance).contains(temporaryHP)
            && (turnsRemaining > 0 ? temporaryHP > 0 : temporaryHP == 0 && !activationTurn)
    }
}

/// Read-only UI projection. Resolve from presentedCombat so damage is never
/// revealed before the animation contact marker. Human equipment stays stored.
struct BearFormReadout: Equatable {
    let endurance: Int
    let humanHealth: Int
    let humanMaximumHealth: Int
    let defence: Int
    let attackBonus: Int
    let movementFeet: Int
    let turnsRemaining: Int

    init?(_ combat: TacticalCombat) {
        guard combat.isBear, let form = combat.bearForm,
              let player = combat.actors.first(where: \.player) else { return nil }
        endurance = form.temporaryHP
        humanHealth = player.hp
        humanMaximumHealth = player.maximumHP
        defence = combat.defence(for: player)
        attackBonus = combat.attackBonus(for: player)
        movementFeet = Int(combat.movementSpeed(for: player) / 8)
        turnsRemaining = form.turnsRemaining
    }
}

import Foundation

/// RainShadow's first magical form ability; not a claim of D&D Wild Shape fidelity.
enum BearFormRules {
    static let speed = 240.0
    static let attackBonus = 6
    static let defence = 14
    static let damageMin = 5
    static let damageMax = 8
    static let radius = 48.0
    static let circleSize = 5

    static func canStand(in map: NavigationMap, actor: Combatant) -> Bool {
        map.occupancy.withStampLifted(id: actor.id) {
            map.searchMap.blockedInRadiusTile(at: actor.position, size: circleSize).contains(.passable)
        }
    }
}

struct BearFormState: Codable, Equatable {
    var turnsRemaining = 3
    var temporaryHP = 8
    var activationTurn = true
    var isValid: Bool {
        (0...3).contains(turnsRemaining) && (0...8).contains(temporaryHP)
            && (turnsRemaining > 0 ? temporaryHP > 0 : temporaryHP == 0 && !activationTurn)
    }
}

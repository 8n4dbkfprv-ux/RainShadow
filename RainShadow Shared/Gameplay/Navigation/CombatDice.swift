import Foundation

/// Receipts, never random generators. Presentation cannot mutate combat or its RNG.
struct CombatDie: Codable, Equatable, Sendable {
    let sides: Int
    let value: Int
    var isValid: Bool { sides > 0 && sides <= 100 && (1...sides).contains(value) }
}

enum CombatRollKind: String, Codable, Sendable {
    case attack, damage, storyCritical, minor
    var visible: Bool { self != .minor }
}

struct CombatDiceRoll: Equatable, Sendable {
    let kind: CombatRollKind
    let dice: [CombatDie]
    let caption: String
    var critical = false
    var shouldPresent: Bool { kind.visible && !dice.isEmpty && dice.allSatisfy(\.isValid) }
}

enum CombatDiceSpeed: String, CaseIterable, Sendable {
    case normal, fast, skip
    var title: String { rawValue.capitalized }
    var multiplier: Double { self == .fast ? 3 : 1 }
    var next: Self { Self.allCases[(Self.allCases.firstIndex(of: self)! + 1) % Self.allCases.count] }
}

extension TacticalCombat.Strike {
    var dicePresentation: [CombatDiceRoll] {
        guard !attackRolls.isEmpty else { return [] }
        let selection = attackRolls.count > 1 ? " → \(roll)" : ""
        let attack = CombatDiceRoll(kind: .attack,
            dice: attackRolls.map { CombatDie(sides: 20, value: $0) },
            caption: "Attack: \(attackRolls.map(String.init).joined(separator: ", "))\(selection) + \(attackModifier) vs \(targetDefence) · \(landed ? (roll == 20 ? "Critical" : "Hit") : "Miss")", critical: landed && roll == 20)
        guard landed, !damageDice.isEmpty else { return [attack] }
        let adjustment = damage + wardAbsorbed - damageDice.reduce(0) { $0 + $1.value }
        let modifiers = adjustment == 0 ? "" : " · modifiers \(adjustment > 0 ? "+" : "")\(adjustment)"
        return [attack, CombatDiceRoll(kind: .damage, dice: damageDice,
            caption: "Damage: \(damageDice.map { "d\($0.sides):\($0.value)" }.joined(separator: " + "))\(modifiers) · \(damage) applied\(wardAbsorbed > 0 ? " · ward absorbed \(wardAbsorbed)" : "")")]
    }
}

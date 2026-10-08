import Foundation
import CoreGraphics

/// Authored combat physique, separate from attack accuracy. Optional on actors so
/// pre-shove saves remain readable. Kilograms are used only for shove eligibility.
struct ShoveProfile: Codable, Equatable {
    var strength: Int
    var athletics: Int
    var acrobatics: Int
    var weight: Double
    var isValid: Bool {
        (1...30).contains(strength) && (-5...30).contains(athletics)
            && (-5...30).contains(acrobatics) && weight.isFinite && (1...1000).contains(weight)
    }
    static let voss = Self(strength: 14, athletics: 4, acrobatics: 2, weight: 80)
    static let crew = Self(strength: 12, athletics: 3, acrobatics: 2, weight: 80)
    static let lookout = Self(strength: 10, athletics: 1, acrobatics: 4, weight: 75)
    static let bear = Self(strength: 20, athletics: 7, acrobatics: 0, weight: 350)
}

enum ShoveRules {
    // Adapted for RainShadow's level-ground maps: about 1–3 metres, clipped by
    // the existing search raster. No chasm or falling-damage terrain is authored.
    static func distance(attacker: ShoveProfile, target: ShoveProfile) -> Double {
        min(80, max(24, 80 * Double(attacker.strength) / 14 * 80 / target.weight))
    }
    static func chance(bonus: Int, dc: Int, advantage: Bool) -> Int {
        let p = Double((1...20).filter { $0 + bonus >= dc }.count) / 20
        return Int(((advantage ? 1 - (1 - p) * (1 - p) : p) * 100).rounded())
    }
}

struct ShovePreview: Equatable {
    let destination: CGPoint
    let chance: Int
    let dc: Int
    let bonus: Int
    let advantage: Bool
}

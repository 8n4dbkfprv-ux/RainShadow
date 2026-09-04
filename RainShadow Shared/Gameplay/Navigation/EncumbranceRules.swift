import Foundation

/// How much a character can carry before weight starts costing speed.
///
/// AD&D 2e gives this as a Strength-indexed Weight Allowance (*Player's Handbook*
/// Table 4). RainShadow has no Strength score yet — `PlayerTraits` is still
/// deferred in Technical Architecture §14.1 — so the shipped allowance is the
/// table's Strength 15 row, 55 lb, which is where a fit adult on his feet all
/// night sits. When traits ship, this becomes a lookup and nothing else moves.
struct CarryAllowance: Equatable, Sendable {
    let ounces: Int

    init(ounces: Int) {
        self.ounces = max(0, ounces)
    }

    init(pounds: Int) {
        self.init(ounces: pounds * 16)
    }

    /// Strength 15 weight allowance: 55 lb.
    static let detective = CarryAllowance(pounds: 55)

    var pounds: Double { Double(ounces) / 16 }
}

/// Weight → movement penalty, in the engine's own terms.
///
/// The bands are the ones `MovementProfile.Encumbrance` already documents from
/// the shipped *Adventurer's Guide* p. 43: over the weight Strength allows,
/// "movement speed is halved"; more than 10% over "prevents them from moving
/// altogether". They are 100% and 110% — not the 120% that circulates on wikis.
///
/// The warning band is deliberately not a fourth case. BG paints the weight
/// readout yellow as you approach the limit and that is *all* it does: no THAC0
/// change, no saves, no speed. Modelling it as an encumbrance state would invent
/// a penalty the engine does not have, so it lives here as a display threshold.
enum EncumbranceRules {
    /// Fraction of the allowance at which the readout turns amber. Cosmetic.
    static let warningFraction = 0.9

    /// Fraction above the allowance at which movement stops entirely.
    static let immobileFraction = 1.1

    static func band(
        carriedOunces: Int,
        allowance: CarryAllowance
    ) -> MovementProfile.Encumbrance {
        // A zero allowance would make every character immobile on an empty bag;
        // treat it as "no limit is being enforced" instead.
        guard allowance.ounces > 0 else { return .unencumbered }
        if carriedOunces <= allowance.ounces { return .unencumbered }
        if Double(carriedOunces) <= Double(allowance.ounces) * immobileFraction {
            return .overloaded
        }
        return .immobile
    }

    /// True once the readout should warn, which happens before any penalty does.
    static func isWarning(carriedOunces: Int, allowance: CarryAllowance) -> Bool {
        guard allowance.ounces > 0 else { return false }
        return Double(carriedOunces) >= Double(allowance.ounces) * warningFraction
    }

    /// The profile an actor should walk with, given what it is carrying.
    static func profile(
        base: MovementProfile = .humanoid,
        carriedOunces: Int,
        allowance: CarryAllowance
    ) -> MovementProfile {
        base.encumbered(band(carriedOunces: carriedOunces, allowance: allowance))
    }
}

/// The three things the inventory window's weight readout needs to draw itself.
struct EncumbranceReadout: Equatable, Sendable {
    let carriedOunces: Int
    let allowance: CarryAllowance
    let band: MovementProfile.Encumbrance
    /// Amber before any penalty lands; see `EncumbranceRules.warningFraction`.
    let isWarning: Bool

    init(carriedOunces: Int, allowance: CarryAllowance) {
        self.carriedOunces = max(0, carriedOunces)
        self.allowance = allowance
        self.band = EncumbranceRules.band(carriedOunces: carriedOunces, allowance: allowance)
        self.isWarning = EncumbranceRules.isWarning(
            carriedOunces: carriedOunces,
            allowance: allowance
        )
    }

    /// `12 lb / 55 lb`, the way the panel spells weight.
    var formatted: String {
        "\(Self.formatPounds(carriedOunces)) / \(Self.formatPounds(allowance.ounces)) lb"
    }

    private static func formatPounds(_ ounces: Int) -> String {
        let pounds = Double(ounces) / 16
        return pounds < 10
            ? String(format: "%.1f", pounds)
            : String(Int(pounds.rounded()))
    }
}

extension CharacterInventory {
    /// Everything the window and the actor need, in one pass over the bag.
    func encumbrance(
        catalog: ItemCatalog,
        allowance: CarryAllowance = .detective
    ) -> EncumbranceReadout {
        EncumbranceReadout(
            carriedOunces: carriedWeightOunces(catalog: catalog),
            allowance: allowance
        )
    }
}

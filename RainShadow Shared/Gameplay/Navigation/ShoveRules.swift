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
    // About 1–3 metres, clipped by the search raster. The wharf allows
    // terminal drops into its existing deep-water cells; ordinary routes do not.
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

extension TacticalCombat {
    var waterDropsEnabled: Bool { areaID == "RS0200" || areaID == "city_wharf_ladder" }
}

extension CombatNavigation {
    /// Bake a small, visible fire footprint once at ignition. It uses the existing
    /// floor raster and sight queries, and never spreads through a wall or into water.
    static func fireCells(in map: NavigationMap, barrel: CombatBarrel) -> [CGPoint] {
        let records = Array(map.occupancy.actors.values)
        records.forEach { map.unregisterActor(id: $0.id) }
        map.occupancy.restampAll()
        defer { records.forEach { map.occupancy.register($0) }; map.occupancy.restampAll() }
        let center = map.searchMap.cell(for: barrel.position)
        return (-4...4).flatMap { row in (-4...4).compactMap { column -> CGPoint? in
            let cell = SearchMapCell(column: center.column + column, row: center.row + row)
            let point = map.searchMap.center(of: cell)
            guard CombatNavigation.distance(point, barrel.position) <= 56,
                  map.searchMap.blockedInRadiusTile(at: cell, size: 2).contains(.passable),
                  clearLine(in: map, from: barrel.position, to: point) else { return nil }
            return point
        } }
    }
}


extension CombatNavigation {
    /// Conservative square around the falling footprint. This is a terminal
    /// hazard query, never a walking route or an additional world-geometry test.
    static func waterFringe(in map: NavigationMap, at point: CGPoint, size: Int) -> Bool {
        let center = map.searchMap.cell(for: point), radius = max(0, size - 2)
        var touchesWater = false
        for row in -radius...radius { for col in -radius...radius {
            let cell = SearchMapCell(column: center.column + col, row: center.row + row)
            let terrain = map.searchMap.terrain(at: cell)
            guard terrain.isWalkable || terrain == .waterImpassable,
                  map.searchMap.flags(at: cell).isDisjoint(with: [.doorImpassable, .actor, .sidewall]) else { return false }
            touchesWater = touchesWater || terrain == .waterImpassable
        } }
        return touchesWater
    }
}

/// Presentation of a certified terminal water drop. Horizontal impulse clears
/// the edge before gravity carries the body down to the lower harbour plane.
/// The saved combat position remains the certified water endpoint.
enum CombatWaterFallMotion {
    static let splashTime = 0.8
    static let fadeDuration = 0.35
    static let waterDepth = 96.0
    static func position(from: CGPoint, to: CGPoint, elapsed: Double) -> CGPoint {
        let t = min(1, max(0, elapsed / 0.5))
        return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
    }
    static func height(elapsed: Double) -> Double {
        let t = min(1, max(0, (elapsed - 0.18) / (splashTime - 0.18)))
        let submerged = min(1, max(0, (elapsed - splashTime) / fadeDuration))
        return -waterDepth * t * t - 60 * submerged
    }
    static func alpha(elapsed: Double) -> Double {
        1 - min(1, max(0, (elapsed - splashTime) / fadeDuration))
    }
    static func phase(elapsed: Double) -> Int {
        // Use only the airborne portion of the existing backwards fall. Never
        // play its floor landing, get-up, or the unrelated death-on-floor clip.
        min(5, max(0, Int(elapsed * 12)))
    }
}

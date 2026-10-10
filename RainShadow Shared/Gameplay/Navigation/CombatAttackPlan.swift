import Foundation
import CoreGraphics

struct CombatAttackOrder: Equatable {
    let targetID: String
    let ranged: Bool
    let ammunition: CombatAmmunition
    let maneuver: CombatManeuver?
    let hasSword: Bool
    let sneak: Bool
}

struct CombatAttackPlan {
    let path: Path?
    let preview: CombatAttackPreview
    let reason: String?
    let movement: Double
    var destination: CGPoint? { path?.destination }
}

/// RainShadow command planning, above the unchanged GemRB navigation port.
/// Candidate endpoints are suggestions only; the existing raster certifies every route.
enum CombatAttackPlanner {
    static func plan(combat: TacticalCombat, order: CombatAttackOrder, map: NavigationMap) -> CombatAttackPlan? {
        guard let target = combat.actors.first(where: { $0.id == order.targetID }) else { return nil }
        func line(_ a: Combatant, _ b: Combatant) -> Bool {
            CombatNavigation.clearLine(in: map, from: a.position, to: b.position, excluding: [a.id, b.id])
        }
        func preview(_ model: TacticalCombat) -> CombatAttackPreview {
            model.attackPreview(target: target, clearLine: line(model.current, target), ranged: order.ranged,
                ammunition: order.ammunition, maneuver: order.maneuver, hasSword: order.hasSword,
                requireSneakAttack: order.sneak, allyLine: line)
        }
        let standing = preview(combat)
        func blocked(_ reason: String?) -> CombatAttackPlan {
            CombatAttackPlan(path: nil, preview: standing, reason: reason, movement: 0)
        }
        guard standing.unavailableReason != nil else { return blocked(nil) }
        // Resource/gear/target failures cannot be fixed by walking. Do not spend movement.
        guard combat.outcome == nil, target.conscious, target.hidden != true, target.player != combat.current.player,
              combat.budget.canAttack, !combat.current.isProne,
              order.maneuver != .aimedShot,
              order.maneuver.map({ combat.canUse($0, hasSword: order.hasSword) }) ?? true,
              !order.sneak || (combat.current.sneakDamageDice > 0 && combat.current.sneakSpent != true && !(combat.current.player && combat.isBear)),
              !order.ranged || (combat.current.rangedWeapon == .bow && !(combat.current.player && combat.isBear)),
              order.maneuver != .tripAttack || (!target.isProne && !(target.player && combat.isBear)) else {
            return blocked(standing.unavailableReason)
        }
        let allowance = combat.budget.availableMovement(speed: combat.movementSpeed(for: combat.current))
        guard allowance > 0 else { return blocked("No movement remains to reach an attack position.") }
        let origin = combat.current.position
        let toward = atan2((origin.y - target.position.y) / 0.75, origin.x - target.position.x)
        let radii: [CGFloat] = order.ranged ? [628, 480, 320, 180, 132] : [96, 80]
        let candidates = radii.flatMap { radius in
            (0..<24).map { step in
                let angle = toward + CGFloat(step) * .pi / 12
                return CGPoint(x: target.position.x + cos(angle) * radius,
                               y: target.position.y + sin(angle) * radius * 0.75).rounded
            }
        }.filter { CombatNavigation.distance(origin, $0) <= allowance + 1 }
            .sorted { CombatNavigation.distance(origin, $0) < CombatNavigation.distance(origin, $1) }
        for point in candidates {
            var prospective = combat.current; prospective.position = point
            guard line(prospective, target),
                  let path = CombatNavigation.route(in: map, actor: combat.current, to: point, bear: combat.current.player && combat.isBear),
                  !path.isEmpty else { continue }
            var after = combat
            guard after.move(along: path) else { continue }
            if combat.current.hidden == true && path.remainingPoints.contains(where: { point in
                combat.actors.contains { observer in
                    observer.player != combat.current.player && observer.conscious
                        && TacticalCombat.insideSightCone(observer: observer, point: point)
                        && CombatNavigation.clearLine(in: map, from: observer.position, to: point, excluding: combat.actors.map(\.id))
                }
            }) { after.reveal(combat.current.id) }
            let forecast = preview(after)
            guard forecast.unavailableReason == nil else { continue }
            return CombatAttackPlan(path: path, preview: forecast, reason: nil,
                                    movement: CombatNavigation.length(path, from: origin))
        }
        return blocked("No reachable attack position with this turn’s movement. Move manually or choose another attack.")
    }
}

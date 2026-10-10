import Foundation
import CoreGraphics

/// RainShadow encounter policy, not a port of BG3 AI or of GemRB navigation.
enum EnemyCombatRole: String, Codable, CaseIterable {
    case bruiser, opportunist, archer
    var title: String { rawValue.capitalized }
    var maneuvers: [CombatManeuver] {
        switch self {
        case .bruiser: [.powerStrike]
        case .opportunist: [.tripAttack, .feintingCut]
        case .archer: [.aimedShot, .pinningShot]
        }
    }
}

struct EnemyDecision {
    enum Action {
        case attack(CombatAttackOrder), move(Path), dash(Path), barrel(String), shove(String), extinguish, endTurn
    }
    let action: Action
    let score: Double
    let reason: String
}

/// Scores legal choices without consuming dice, charges or occupancy. Paths and
/// attack forecasts come from the same authorities used by player commands.
enum EnemyTactics {
    static func role(for actor: Combatant) -> EnemyCombatRole {
        actor.enemyRole ?? (actor.rangedWeapon == .bow ? .archer : .bruiser)
    }

    static func choose(combat: TacticalCombat, map: NavigationMap, hasSword: Bool = true) -> EnemyDecision {
        let actor = combat.current, role = role(for: actor)
        guard combat.outcome == nil, !actor.player else {
            return EnemyDecision(action: .endTurn, score: 0, reason: "No enemy turn")
        }
        let focus = combat.goadingTarget(for: actor)
        let targets = combat.actors.filter { $0.conscious && $0.player != actor.player && $0.hidden != true
            && (focus == nil || $0.id == focus?.id) }.sorted { $0.id < $1.id }
        func line(_ a: Combatant, _ b: Combatant) -> Bool {
            CombatNavigation.clearLine(in: map, from: a.position, to: b.position, excluding: [a.id, b.id])
        }
        func blastLine(_ a: CGPoint, _ b: CGPoint) -> Bool {
            CombatNavigation.clearLine(in: map, from: a, to: b, excluding: Array(map.occupancy.actors.keys))
        }
        var best = EnemyDecision(action: .endTurn, score: 0, reason: "Hold position")
        func offer(_ action: EnemyDecision.Action, _ score: Double, _ reason: String) {
            // Stable enumeration breaks ties; small improvements do not cause shuffling.
            if score > best.score + 0.001 { best = EnemyDecision(action: action, score: score, reason: reason) }
        }
        if focus == nil, combat.canExtinguish {
            offer(.extinguish, Double(actor.burningTurns ?? 1) * 2.5 + (actor.hp <= 4 ? 6 : 0), "Put out the flames")
        }
        for target in targets {
            let distance = CombatNavigation.distance(actor.position, target.position)
            func scoreAttacks(_ model: TacticalCombat, path: Path?) {
                let travel = path.map { CombatNavigation.length($0, from: actor.position) } ?? 0
                let positionGain = positionValue(model.current.position, combat: combat, visible: blastLine)
                    - positionValue(actor.position, combat: combat, visible: blastLine)
                let travelRisk = path.map { pathRisk($0, combat: combat, visible: blastLine) } ?? 0
                for ranged in [false, true] where !ranged || actor.rangedWeapon == .bow {
                    let techniques: [CombatManeuver?] = [nil] + role.maneuvers.filter { $0.ranged == ranged }.map { Optional($0) }
                    for maneuver in techniques {
                        for ammo in [CombatAmmunition.normal, .fire] where ammo == .normal || (ranged && maneuver == nil && (actor.fireArrows ?? 0) > 0) {
                            let preview = model.attackPreview(target: target, clearLine: line(model.current, target), ranged: ranged,
                                ammunition: ammo, maneuver: maneuver, hasSword: hasSword, allyLine: line)
                            guard preview.unavailableReason == nil else { continue }
                            let score = attackScore(combat: model, target: target, preview: preview, maneuver: maneuver,
                                ammunition: ammo, allyLine: line) + positionGain - travel / 160 - travelRisk
                            let order = CombatAttackOrder(targetID: target.id, ranged: ranged, ammunition: ammo,
                                maneuver: maneuver, hasSword: hasSword, sneak: false)
                            offer(path.map { .move($0) } ?? .attack(order), score,
                                  path == nil ? (maneuver?.title ?? (ammo == .fire ? "Fire Arrow" : ranged ? "Ranged Attack" : "Melee Attack")) : "Find a better attack position")
                        }
                    }
                }
            }
            scoreAttacks(combat, path: nil)
            let allowance = combat.budget.availableMovement(speed: combat.movementSpeed(for: actor))
            // One certified approach per weapon; score every available technique at
            // that endpoint. Never rerun pathfinding separately for each technique.
            if combat.budget.canAttack, allowance > 0 {
                for ranged in [false, true] where !ranged || actor.rangedWeapon == .bow {
                    let order = CombatAttackOrder(targetID: target.id, ranged: ranged, ammunition: .normal,
                        maneuver: nil, hasSword: hasSword, sneak: false)
                    if let plan = CombatAttackPlanner.plan(combat: combat, order: order, map: map), plan.reason == nil,
                       let path = plan.path {
                        var moved = combat
                        if moved.move(along: path) { scoreAttacks(moved, path: path) }
                    }
                }
            }
            // Archers can create distance before shooting or use leftover movement
            // afterwards. Score gain must pay for the walk, preventing oscillation.
            if role == .archer, allowance > 0 {
                let away = atan2((actor.position.y - target.position.y) / 0.75, actor.position.x - target.position.x)
                for offset in [0.0, -0.6, 0.6, -1.2, 1.2] {
                    for travel in [min(120, allowance), min(240, allowance)] where travel > 8 {
                        let point = CGPoint(x: actor.position.x + cos(away + offset) * travel,
                            y: actor.position.y + sin(away + offset) * travel * 0.75).rounded
                        guard CombatNavigation.distance(point, target.position) <= BowAttackRules.range,
                              let path = CombatNavigation.route(in: map, actor: actor, to: point), !path.isEmpty else { continue }
                        var moved = combat
                        guard moved.move(along: path), line(moved.current, target) else { continue }
                        if combat.budget.canAttack { scoreAttacks(moved, path: path) }
                        else {
                            let gain = positionValue(moved.current.position, combat: combat, visible: blastLine)
                                - positionValue(actor.position, combat: combat, visible: blastLine)
                                - CombatNavigation.length(path, from: actor.position) / 160 - pathRisk(path, combat: combat, visible: blastLine)
                            offer(.move(path), gain - 0.5, "Keep a safe firing distance")
                        }
                    }
                }
            }
            // A bonus shove is valuable only when it actually frees a bow shot.
            if role == .archer, focus == nil, combat.canShove, combat.budget.canAttack, distance <= TacticalCombat.meleeReach {
                let end = CombatNavigation.knockbackDestination(in: map, actor: target, awayFrom: actor.position,
                    actors: combat.actors, destroyedBarrels: [], bear: target.player && combat.isBear,
                    maximumDistance: ShoveRules.distance(attacker: combat.physique(of: actor), target: combat.physique(of: target)))
                if CombatNavigation.distance(actor.position, end) > TacticalCombat.meleeReach + 8,
                   let shove = combat.shovePreview(target: target.id, clearLine: line(actor, target), destination: end), shove.chance >= 25 {
                    offer(.shove(target.id), 2 + Double(shove.chance) / 100 * 5, "Push the threat away before shooting")
                }
            }
        }
        if focus == nil, actor.rangedWeapon == .bow, combat.budget.canAttack, (actor.fireArrows ?? 0) > 0 {
            for barrel in combat.liveBarrels.sorted(by: { $0.id < $1.id }) {
                let distance = CombatNavigation.distance(actor.position, barrel.position)
                guard distance > TacticalCombat.meleeReach, distance <= BowAttackRules.range,
                      CombatNavigation.clearLine(in: map, from: actor.position, to: barrel.position, excluding: [actor.id, barrel.id]) else { continue }
                let chain = combat.explosionChain(startingAt: barrel.id, visible: blastLine)
                var damage = 0.0, safe = true
                for candidate in combat.actors where candidate.conscious {
                    let hits = chain.filter { CombatNavigation.distance($0.position, candidate.position) <= CombatBarrel.blastRadius
                        && blastLine($0.position, candidate.position) }.count
                    if candidate.player == actor.player && hits > 0 { safe = false }
                    // A concealed opponent is not a reason to target an otherwise empty barrel.
                    if candidate.player != actor.player && candidate.hidden != true { damage += min(Double(candidate.hp), Double(hits) * 4) }
                }
                if safe, damage > 0 { offer(.barrel(barrel.id), damage - 0.75, "Ignite a barrel clear of allies") }
            }
        }
        if best.score > 0 { return best }
        // With no useful action, close toward a visible opponent. Dash is a
        // deliberate fallback, never chosen instead of an available attack.
        for target in targets where combat.budget.canAttack {
            let full = approachPath(in: map, actor: actor, target: target)
            guard !full.isEmpty else { continue }
            let allowance = combat.budget.availableMovement(speed: combat.movementSpeed(for: actor))
            if let path = advance(in: map, actor: actor, full: full, limit: allowance), let end = path.destination,
               CombatNavigation.distance(end, target.position) + 8 < CombatNavigation.distance(actor.position, target.position) {
                offer(.move(path), 0.1, "Close the distance"); continue
            }
            var dashed = combat
            if dashed.dash(), let path = advance(in: map, actor: actor, full: full,
                limit: dashed.budget.availableMovement(speed: dashed.movementSpeed(for: actor))), let end = path.destination,
               CombatNavigation.distance(end, target.position) + 8 < CombatNavigation.distance(actor.position, target.position) {
                offer(.dash(path), 0.05, "Dash to engage")
            }
        }
        return best
    }

    /// One engine search for a distant approach. Sparse straight paths can have
    /// a single long segment, so prefixing whole nodes alone cannot spend a move.
    /// Suggest an integral point on that segment, then certify it with route().
    private static func approachPath(in map: NavigationMap, actor: Combatant, target: Combatant) -> Path {
        var finder = map.pathFinder
        finder.identity = actor.id
        return map.occupancy.withStampLifted(id: actor.id) {
            finder.findPath(from: actor.position, to: target.position, circleSize: map.circleSize,
                minDistance: 80, flags: [.sight, .actorsAreBlocking])
        }
    }
    private static func advance(in map: NavigationMap, actor: Combatant, full: Path, limit: Double) -> Path? {
        guard limit > 8, !full.isEmpty else { return nil }
        var previous = actor.position, remaining = limit
        for point in full.remainingPoints {
            let segment = CombatNavigation.distance(previous, point)
            if segment > remaining {
                // FindPath preserves the start's sub-cell offset. Reserve one
                // ground-space cell diagonal for the returned endpoint's offset.
                let margin = Double(hypot(map.searchMap.cellSize.width, map.searchMap.cellSize.height / 0.75)) + 1
                let ratio = max(0, remaining - margin) / segment
                let end = CGPoint(x: previous.x + (point.x - previous.x) * ratio,
                                  y: previous.y + (point.y - previous.y) * ratio).rounded
                guard let path = CombatNavigation.route(in: map, actor: actor, to: end),
                      CombatNavigation.length(path, from: actor.position) <= limit else { return nil }
                return path
            }
            remaining -= segment; previous = point
        }
        return full
    }

    static func attackScore(combat: TacticalCombat, target: Combatant, preview: CombatAttackPreview,
                            maneuver: CombatManeuver?, ammunition: CombatAmmunition,
                            allyLine: (Combatant, Combatant) -> Bool) -> Double {
        let chance = preview.hitChance, role = role(for: combat.current)
        let hp = target.player && combat.isBear ? (combat.bearForm?.temporaryHP ?? target.hp) : target.hp
        let damages = Array(preview.damage)
        let average = Double(damages.reduce(0) { $0 + min(hp, $1) }) / Double(damages.count)
        let finish = Double(damages.filter { $0 >= hp }.count) / Double(damages.count)
        var score = chance * (average + finish * 4)
        // Charges are encounter resources. Spend them for a material benefit.
        if maneuver != nil { score -= 0.3 }
        if ammunition == .fire {
            score -= 0.75
            if !target.isBurning, hp > preview.damage.upperBound { score += chance * 4 }
        }
        if maneuver == .feintingCut, target.conditions?.weakened != true, hp > preview.damage.upperBound {
            let pressure = Double(target.damageMin + target.damageMax) / 2
            score += chance * pressure * (role == .opportunist ? 0.55 : 0.3)
        }
        if maneuver == .pinningShot, target.conditions?.slowed != true, target.rangedWeapon == nil {
            let distance = CombatNavigation.distance(combat.current.position, target.position)
            let speed = combat.movementSpeed(for: target)
            if distance <= speed + TacticalCombat.meleeReach && distance > speed / 2 + TacticalCombat.meleeReach {
                score += chance * 4
            }
        }
        if maneuver == .tripAttack, !target.isProne, hp > preview.damage.upperBound {
            let targetIndex = combat.actors.firstIndex { $0.id == target.id }!
            let untilTarget = (targetIndex - combat.turn + combat.actors.count) % combat.actors.count
            for (index, ally) in combat.actors.enumerated() where ally.id != combat.current.id && ally.player == combat.current.player
                && ally.conscious && !ally.isProne && roleForMelee(ally) {
                let untilAlly = (index - combat.turn + combat.actors.count) % combat.actors.count
                if untilAlly > 0, untilAlly < untilTarget,
                   CombatNavigation.distance(ally.position, target.position) <= TacticalCombat.meleeReach, allyLine(ally, target) {
                    score += chance * (Double(ally.damageMin + ally.damageMax) / 8 + 2)
                }
            }
        }
        return score
    }
    private static func roleForMelee(_ actor: Combatant) -> Bool { role(for: actor) != .archer }

    private static func positionValue(_ point: CGPoint, combat: TacticalCombat,
                                      visible: (CGPoint, CGPoint) -> Bool) -> Double {
        var value = 0.0
        if role(for: combat.current) == .archer {
            let gap = combat.actors.filter { $0.player != combat.current.player && $0.conscious && $0.hidden != true }
                .map { CombatNavigation.distance(point, $0.position) }.min() ?? BowAttackRules.range
            // Safety plateaus: no endless retreat after reaching a useful firing lane.
            value += min(360, gap) / 60
            if gap <= TacticalCombat.meleeReach { value -= 3 }
        }
        for barrel in combat.liveBarrels where CombatNavigation.distance(point, barrel.position) <= CombatBarrel.blastRadius
            && visible(point, barrel.position) { value -= 2 }
        return value
    }
    private static func pathRisk(_ path: Path, combat: TacticalCombat, visible: (CGPoint, CGPoint) -> Bool) -> Double {
        // Oil/barrel danger is the only authored ground hazard in these encounters.
        combat.liveBarrels.reduce(0) { cost, barrel in
            cost + (path.remainingPoints.contains { CombatNavigation.distance($0, barrel.position) <= CombatBarrel.blastRadius
                && visible($0, barrel.position) } ? 0.5 : 0)
        }
    }
}

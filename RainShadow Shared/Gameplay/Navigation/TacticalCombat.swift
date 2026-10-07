import Foundation
import CoreGraphics

/// TemplePlus 03d7204510bc8401c67c59b3e4e23b6eefb087d0, action_sequence.cpp:
/// ActionSequenceSystem's transition table and GetHourglassTransition.
/// Copyright (c) 2015 Circle of Eight. MIT; see Documentation/Licenses/TemplePlus.txt.
/// The surrounding brawl rules are RainShadow adaptations, not a full D20 port.
struct CombatBudget: Codable, Equatable {
    private(set) var state = 4
    private(set) var movementRemaining: Double = 0
    static let transitions = [
        [0, -1, -1, -1, -1], [1, 0, -1, -1, -1], [2, 0, 0, -1, -1],
        [3, 0, 0, 0, -1], [4, 2, 1, -1, 0], [5, 2, 2, -1, 0], [6, 5, 2, -1, 3]
    ]
    static func transition(state: Int, cost: Int) -> Int? {
        guard transitions.indices.contains(state), (0..<5).contains(cost) else { return nil }
        let next = transitions[state][cost]
        return next < 0 ? nil : next
    }
    var canAttack: Bool { Self.transition(state: state, cost: 2) != nil }
    mutating func spend(_ cost: Int) -> Bool {
        guard let next = Self.transition(state: state, cost: cost) else { return false }
        state = next
        return true
    }
    func availableMovement(speed: Double) -> Double {
        var copy = self
        var result = movementRemaining
        while copy.spend(1) { result += speed }
        return result
    }
    /// Like TurnBasedStatusUpdate, reject on a copy so failure spends nothing.
    mutating func move(distance: Double, speed: Double) -> Bool {
        guard distance.isFinite, distance > 0, speed.isFinite, speed > 0 else { return false }
        var copy = self
        while copy.movementRemaining + 0.0001 < distance {
            guard copy.spend(1) else { return false }
            copy.movementRemaining += speed
        }
        copy.movementRemaining = max(0, copy.movementRemaining - distance)
        self = copy
        return true
    }
}

struct Combatant: Codable, Equatable {
    var id: String
    var name: String
    var player: Bool
    var position: CGPoint
    var hp: Int
    var maximumHP: Int
    var defence: Int
    var attackBonus: Int
    var damageMin: Int
    var damageMax: Int
    var initiativeBonus: Int
    var initiative = 0
    var speed: Double = 240
    var rangedWeapon: CombatRangedWeapon? = nil
    var defending = false
    var conscious: Bool { hp > 0 }
}

/// Actions resolve atomically before presentation. Checkpoints therefore resume
/// the accepted result, never replay an attack roll or grant its rewards twice.
struct TacticalCombat: Codable, Equatable {
    static let playerID = "detective.voss"
    static let meleeReach: Double = 105
    var version = 1
    var encounterID: String
    var areaID: String
    private(set) var actors: [Combatant]
    private(set) var turn = 0
    private(set) var round = 1
    private(set) var budget = CombatBudget()
    private(set) var randomState: UInt64
    private(set) var log: [String] = []
    /// Optional for compatibility with checkpoints made before Bear Form.
    /// Kept after reversion so reloading cannot grant another use.
    private(set) var bearForm: BearFormState?
    /// Optional so older checkpoints keep their original encounter layout.
    private(set) var barrels: [CombatBarrel]?
    var liveBarrels: [CombatBarrel] { (barrels ?? []).filter { !$0.exploded } }
    var isBear: Bool { (bearForm?.turnsRemaining ?? 0) > 0 }
    var canTransform: Bool { isPlayerTurn && bearForm == nil && budget.canAttack }
    func movementSpeed(for actor: Combatant) -> Double {
        actor.player && isBear ? BearFormRules.speed : actor.speed
    }
    enum Outcome: String, Codable { case won, lost }
    var outcome: Outcome? {
        if !actors.contains(where: { $0.player && $0.conscious }) { return .lost }
        if !actors.contains(where: { !$0.player && $0.conscious }) { return .won }
        return nil
    }
    var current: Combatant { actors[turn] }
    var isPlayerTurn: Bool { outcome == nil && current.player }

    init(encounterID: String, areaID: String, actors: [Combatant], seed: UInt64, barrels: [CombatBarrel] = []) {
        precondition(!actors.isEmpty && Set(actors.map(\.id)).count == actors.count)
        self.encounterID = encounterID; self.areaID = areaID; self.actors = actors
        self.barrels = barrels.isEmpty ? nil : barrels
        randomState = seed
        for i in self.actors.indices { self.actors[i].initiative = roll(20) + self.actors[i].initiativeBonus }
        // Explicit adaptation: stable IDs break remaining ties (no engine object registry).
        self.actors.sort {
            if $0.initiative != $1.initiative { return $0.initiative > $1.initiative }
            if $0.initiativeBonus != $1.initiativeBonus { return $0.initiativeBonus > $1.initiativeBonus }
            return $0.id < $1.id
        }
        if let first = self.actors.firstIndex(where: \.conscious) { turn = first }
        note("The fight begins. All strikes are nonlethal.")
    }

    /// Reject incompatible/corrupt checkpoints before indexing the active actor.
    var isValid: Bool {
        version == 1 && (bearForm?.isValid ?? true) && (barrels ?? []).count <= 8
        && Set((barrels ?? []).map(\.id)).count == (barrels ?? []).count
        && (barrels ?? []).allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite && !$0.id.isEmpty }
        && (2...8).contains(actors.count) && actors.indices.contains(turn)
        && actors.filter(\.player).count == 1 && actors.contains { $0.id == Self.playerID && $0.player }
        && Set((barrels ?? []).map(\.id)).isDisjoint(with: Set(actors.map(\.id)))
        && Set(actors.map(\.id)).count == actors.count && round > 0
        && CombatBudget.transitions.indices.contains(budget.state)
        && budget.movementRemaining.isFinite && budget.movementRemaining >= 0
        && actors.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite && $0.maximumHP > 0
            && $0.hp >= 0 && $0.hp <= $0.maximumHP && $0.speed.isFinite && $0.speed >= 0
            && $0.damageMin > 0 && $0.damageMax >= $0.damageMin && $0.damageMax <= 100
        } && (outcome != nil || current.conscious)
    }
    private mutating func roll(_ sides: Int) -> Int {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        return Int((randomState >> 32) % UInt64(sides)) + 1
    }
    private mutating func note(_ text: String) {
        log.append(text)
        if log.count > 30 { log.removeFirst(log.count - 30) }
    }
    @discardableResult mutating func endTurn() -> Bool {
        guard outcome == nil else { return false }
        if current.player, isBear {
            if bearForm!.activationTurn { bearForm!.activationTurn = false }
            else {
                bearForm!.turnsRemaining -= 1
                if !isBear { endBearForm() }
            }
        }
        repeat {
            turn = (turn + 1) % actors.count
            if turn == 0 { round += 1 }
        } while !current.conscious
        actors[turn].defending = false
        budget = CombatBudget()
        note("\(current.name)'s turn.")
        return true
    }
    @discardableResult mutating func defend() -> Bool {
        guard outcome == nil, budget.spend(2) else { return false }
        actors[turn].defending = true
        note("\(current.name) guards: +4 defence until their next turn.")
        return true
    }
    /// The caller supplies a route certified by CombatNavigation/SearchMap.
    @discardableResult mutating func move(along path: Path) -> Bool {
        guard outcome == nil, let end = path.destination, !path.isEmpty else { return false }
        let cost = CombatNavigation.length(path, from: current.position)
        guard budget.move(distance: cost, speed: movementSpeed(for: current)) else { return false }
        actors[turn].position = end
        note("\(current.name) moves.")
        return true
    }
    mutating func reconcilePosition(id: String, point: CGPoint) {
        guard let index = actors.firstIndex(where: { $0.id == id }) else { return }
        actors[index].position = point.rounded
    }
    mutating func yield() {
        guard isPlayerTurn else { return }
        actors[turn].hp = 0
        if isBear { endBearForm() }
        note("Voss yields. The crew lets him live.")
    }
    @discardableResult mutating func transformToBear(hasClearance: Bool) -> Bool {
        guard canTransform, hasClearance, budget.spend(2) else { return false }
        bearForm = BearFormState()
        note("Voss takes Bear Form: 8 temporary endurance, three full turns.")
        return true
    }
    @discardableResult mutating func revertBear() -> Bool {
        guard isPlayerTurn, isBear, budget.spend(2) else { return false }
        endBearForm()
        return true
    }
    private mutating func endBearForm() {
        bearForm?.turnsRemaining = 0
        bearForm?.temporaryHP = 0
        bearForm?.activationTurn = false
        note("Voss returns to human form. Bear Form is spent for this encounter.")
    }
    struct Strike: Equatable {
        let attacker: String
        let target: String
        let roll: Int
        let damage: Int
        let knockedOut: Bool
    }
    struct BarrelExplosion: Equatable {
        let barrel: CombatBarrel
        let hits: [Strike]
    }
    struct Displacement: Equatable {
        let id: String
        let from: CGPoint
        let to: CGPoint
    }
    /// A physical strike spills the contents without igniting them.
    mutating func breakBarrel(_ id: String, clearLine: Bool) -> Bool {
        guard outcome == nil, clearLine,
              let index = barrels?.firstIndex(where: { $0.id == id && !$0.isBroken }),
              CombatNavigation.distance(current.position, barrels![index].position) <= Self.meleeReach,
              budget.spend(2) else { return false }
        barrels![index].broken = true
        note("\(current.name) breaks the barrel. The spilled oil can still ignite.")
        return true
    }
    /// Resolve the whole chain's damage first, then push each survivor once.
    /// The adapter certifies straight-line clearance and reserves prior endpoints.
    mutating func applyExplosionKnockback(_ explosions: [BarrelExplosion],
        destination: (Combatant, CGPoint, [Combatant]) -> CGPoint) -> [Displacement] {
        var result: [Displacement] = []
        for index in actors.indices.sorted(by: { actors[$0].id < actors[$1].id }) where actors[index].conscious {
            let actor = actors[index]
            guard let source = explosions.first(where: { $0.hits.contains { $0.target == actor.id } }) else { continue }
            let point = destination(actor, source.barrel.position, actors)
            guard point.x.isFinite, point.y.isFinite,
                  CombatNavigation.distance(actor.position, point) <= CombatBarrel.pushDistance + 1,
                  point != actor.position else { continue }
            actors[index].position = point
            result.append(Displacement(id: actor.id, from: actor.position, to: point))
            note("\(actor.name) is pushed back by the blast.")
        }
        return result
    }
    /// Fire ignites a stationary barrel automatically. The caller certifies the
    /// shot and every blast/chain line against the shared terrain raster.
    mutating func igniteBarrel(_ id: String, clearShot: Bool,
                               visible: (CGPoint, CGPoint) -> Bool) -> [BarrelExplosion]? {
        guard outcome == nil, !isBear || !current.player,
              current.rangedWeapon == .bow,
              let barrel = liveBarrels.first(where: { $0.id == id }), clearShot,
              CombatNavigation.distance(current.position, barrel.position) <= BowAttackRules.range,
              CombatNavigation.distance(current.position, barrel.position) > Self.meleeReach,
              budget.spend(2) else { return nil }
        let attacker = current.id
        let chain = explosionChain(startingAt: id, visible: visible)
        var explosions: [BarrelExplosion] = []
        for barrel in chain {
            guard let index = barrels?.firstIndex(where: { $0.id == barrel.id }) else { continue }
            barrels![index].exploded = true
            note("\(barrel.name) explodes!")
            var hits: [Strike] = []
            for index in actors.indices where actors[index].conscious {
                guard CombatNavigation.distance(barrel.position, actors[index].position) <= CombatBarrel.blastRadius,
                      visible(barrel.position, actors[index].position) else { continue }
                let damage = 2 + roll(3)
                var injury = damage
                if actors[index].player, isBear {
                    let absorbed = min(injury, bearForm!.temporaryHP)
                    bearForm!.temporaryHP -= absorbed; injury -= absorbed
                    if bearForm!.temporaryHP == 0 { endBearForm() }
                }
                actors[index].hp = max(0, actors[index].hp - injury)
                hits.append(Strike(attacker: attacker, target: actors[index].id, roll: 0,
                                   damage: damage, knockedOut: !actors[index].conscious))
                note("Blast: \(damage) to \(actors[index].name).")
            }
            explosions.append(BarrelExplosion(barrel: barrel, hits: hits))
        }
        // A blast may knock out its shooter while both sides still have survivors.
        // Advance to a conscious actor so a saved checkpoint remains valid.
        if outcome == nil && !current.conscious { _ = endTurn() }
        return explosions
    }
    func explosionChain(startingAt id: String, visible: (CGPoint, CGPoint) -> Bool) -> [CombatBarrel] {
        guard let first = liveBarrels.first(where: { $0.id == id }) else { return [] }
        var result = [first]; var visited: Set<String> = [id]; var cursor = 0
        while cursor < result.count {
            let source = result[cursor]; cursor += 1
            for barrel in liveBarrels.sorted(by: { $0.id < $1.id }) where !visited.contains(barrel.id) {
                if CombatNavigation.distance(source.position, barrel.position) <= CombatBarrel.blastRadius,
                   visible(source.position, barrel.position) {
                    visited.insert(barrel.id); result.append(barrel)
                }
            }
        }
        return result
    }

    /// Ascending defence, natural 1/20 and flat damage bands are the initial
    /// RainShadow brawl rules. TemplePlus supplies action costs, not these stats.
    mutating func attack(target id: String, clearLine: Bool, ranged: Bool = false) -> Strike? {
        guard outcome == nil, let target = actors.firstIndex(where: { $0.id == id }),
              actors[target].conscious, actors[target].player != current.player,
              clearLine,
              !(ranged && current.player && isBear),
              ranged ? BowAttackRules.canShoot(attacker: current, target: actors[target], clearLine: clearLine)
                  : CombatNavigation.distance(current.position, actors[target].position) <= Self.meleeReach,
              budget.spend(2) else { return nil }
        let die = roll(20)
        let bearAttacker = current.player && isBear
        let attackBonus = bearAttacker ? BearFormRules.attackBonus : current.attackBonus
        let defence = (actors[target].player && isBear ? BearFormRules.defence : actors[target].defence)
            + (actors[target].defending ? 4 : 0)
        let hit = die == 20 || (die != 1 && die + attackBonus >= defence)
        let minimum = bearAttacker ? BearFormRules.damageMin : current.damageMin
        let maximum = bearAttacker ? BearFormRules.damageMax : current.damageMax
        let damage = hit ? minimum + roll(maximum - minimum + 1) - 1 : 0
        var injury = damage
        if actors[target].player, isBear {
            let absorbed = min(injury, bearForm!.temporaryHP)
            bearForm!.temporaryHP -= absorbed
            injury -= absorbed
            if bearForm!.temporaryHP == 0 { endBearForm() }
        }
        actors[target].hp = max(0, actors[target].hp - injury)
        let result = Strike(attacker: current.id, target: id, roll: die, damage: damage, knockedOut: !actors[target].conscious)
        note("\(current.name)\(ranged ? " fires" : ""): d20 \(die) + \(attackBonus) vs \(defence) — " +
             (hit ? "\(damage) to \(actors[target].name)." : "miss."))
        if result.knockedOut { note("\(actors[target].name) is out of the fight.") }
        return result
    }
}

/// Adapter over the existing navigation authority. No alternate collision geometry.
enum CombatNavigation {
    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(hypot(b.x - a.x, (b.y - a.y) / ActorLocomotionPacing.verticalProjectionScale))
    }
    static func length(_ path: Path, from origin: CGPoint) -> Double {
        var previous = origin
        return path.remainingPoints.reduce(0) { total, next in
            defer { previous = next }
            return total + distance(previous, next)
        }
    }
    static func route(in map: NavigationMap, actor: Combatant, to target: CGPoint, bear: Bool = false) -> Path? {
        // Combat requires this exact goal cell. Reject an occupied/undersized
        // goal before asking the engine to search for an adjusted destination
        // that this adapter would then discard, especially around a large bear.
        let size = bear ? BearFormRules.circleSize : map.circleSize
        var finder = map.pathFinder
        finder.identity = actor.id
        let path = map.occupancy.withStampLifted(id: actor.id) {
            guard map.searchMap.blockedInRadiusTile(at: target, size: size).contains(.passable) else { return Path() }
            return finder.findPath(from: actor.position, to: target, circleSize: size,
                                   flags: [.sight, .actorsAreBlocking])
        }
        guard let end = path.destination,
              map.searchMap.cell(for: end) == map.searchMap.cell(for: target) else { return nil }
        return path
    }
    static func clearLine(in map: NavigationMap, from a: CGPoint, to b: CGPoint, excluding ids: [String] = []) -> Bool {
        // withStampLifted is a single-requester operation: nesting it repaints
        // the other participant. Remove both records for this synchronous query,
        // then restore every stamp, including overlapping third-party footprints.
        let participants = ids.compactMap { map.occupancy.actors[$0] }
        participants.forEach { map.occupancy.unregister(id: $0.id) }
        map.occupancy.restampAll()
        defer {
            participants.forEach { map.occupancy.register($0) }
            map.occupancy.restampAll()
        }
        // The port's line walker visits no cells when both ends share one cell.
        // Combat still needs visibility for a character standing in spilled oil.
        if map.searchMap.cell(for: a) == map.searchMap.cell(for: b) {
            return map.searchMap.blockedInRadiusTile(at: a, size: 2).contains(.passable)
        }
        return map.searchMap.blockedInLine(from: a, to: b, size: -1).contains(.passable)
    }
    /// Forced movement stays on the shared raster and stops at the first obstruction.
    /// Temporary endpoint stamps keep chained pushes from overlapping survivors.
    static func knockbackDestination(in map: NavigationMap, actor: Combatant, awayFrom source: CGPoint,
        actors: [Combatant], destroyedBarrels: [String], bear: Bool = false) -> CGPoint {
        let ids = Set(actors.map(\.id) + destroyedBarrels)
        let originals = ids.compactMap { map.occupancy.actors[$0] }
        ids.forEach { map.occupancy.unregister(id: $0) }
        for other in actors where other.conscious && other.id != actor.id {
            if var record = originals.first(where: { $0.id == other.id }) {
                record.position = other.position; map.occupancy.register(record)
            } else {
                map.registerActor(id: other.id, kind: other.player ? .player : .npc, at: other.position)
            }
        }
        map.occupancy.restampAll()
        defer {
            ids.forEach { map.occupancy.unregister(id: $0) }
            originals.forEach { map.occupancy.register($0) }
            map.occupancy.restampAll()
        }
        let dx = actor.position.x - source.x, dy = (actor.position.y - source.y) / 0.75
        let distance = hypot(dx, dy)
        let direction = distance > 0 ? CGPoint(x: dx / distance, y: dy / distance) : CGPoint(x: 1, y: 0)
        let size = bear ? BearFormRules.circleSize : map.circleSize
        let startCell = map.searchMap.cell(for: actor.position)
        var end = actor.position
        for step in stride(from: 2.0, through: CombatBarrel.pushDistance, by: 2) {
            let point = CGPoint(x: actor.position.x + direction.x * step,
                                y: actor.position.y + direction.y * step * 0.75).rounded
            guard map.searchMap.blockedInRadiusTile(at: point, size: size).contains(.passable),
                  map.searchMap.cell(for: point) == startCell || map.searchMap.blockedInLine(
                    from: actor.position, to: point, size: size).contains(.passable) else { break }
            end = point
        }
        return end
    }
    static func prefix(_ path: Path, from origin: CGPoint, within limit: Double) -> Path {
        var result: [PathNode] = [], previous = origin, spent = 0.0
        for node in path.nodes.dropFirst(path.currentStep) {
            let step = distance(previous, node.point)
            guard spent + step <= limit + 0.0001 else { break }
            result.append(node); previous = node.point; spent += step
        }
        return Path(nodes: result)
    }
    /// Find a reachable firing lane using only the existing raster authority.
    /// The lookout holds a clear position; this is not a kiting/retreat policy.
    static func firingPosition(in map: NavigationMap, actor: Combatant, target: Combatant, limit: Double) -> Path? {
        let points = [CGFloat(180), 260, 360].flatMap { radius in
            (0..<16).map { i in
                let angle = CGFloat(i) * .pi / 8
                return CGPoint(x: target.position.x + cos(angle) * radius,
                    y: target.position.y + sin(angle) * radius * 0.75).rounded
            }
        }.sorted { distance(actor.position, $0) < distance(actor.position, $1) }
        for point in points {
            guard clearLine(in: map, from: point, to: target.position, excluding: [actor.id, target.id]),
                let path = route(in: map, actor: actor, to: point), !path.isEmpty, let end = path.destination,
                length(path, from: actor.position) <= limit,
                distance(end, target.position) > TacticalCombat.meleeReach,
                distance(end, target.position) <= BowAttackRules.range,
                clearLine(in: map, from: end, to: target.position, excluding: [actor.id, target.id]) else { continue }
            return path
        }
        return nil
    }
    static func gateBarrels(in map: NavigationMap, actors: [Combatant]) -> [CombatBarrel] {
        guard let player = actors.first(where: \.player) else { return [] }
        let candidates = [CGFloat(160), 210, 260].flatMap { radius in
            (0..<24).map { i in
                let angle = CGFloat(i) * .pi / 12
                return CGPoint(x: player.position.x + cos(angle) * radius,
                               y: player.position.y + sin(angle) * radius * 0.75).rounded
            }
        }.filter { point in
            map.searchMap.blockedInRadiusTile(at: point, size: 2).contains(.passable)
                && actors.allSatisfy { distance(point, $0.position) >= 65 }
                && clearLine(in: map, from: player.position, to: point, excluding: [player.id])
        }.sorted { a, b in
            let enemies = actors.filter { !$0.player }
            return enemies.map { distance(a, $0.position) }.min() ?? .infinity
                < enemies.map { distance(b, $0.position) }.min() ?? .infinity
        }
        guard let first = candidates.first else { return [] }
        var points = [first]
        if let second = candidates.first(where: { distance(first, $0) >= 70
            && distance(first, $0) <= 110 && clearLine(in: map, from: first, to: $0) }) { points.append(second) }
        return points.enumerated().map { CombatBarrel(id: "combat.oil.\($0.offset)", position: $0.element) }
    }
    static func approach(in map: NavigationMap, actor: Combatant, target: Combatant, limit: Double) -> Path? {
        let radius: CGFloat = (map.occupancy.actors[target.id]?.personalSpaceCells ?? 4) > 4 ? 100 : 84
        let points = (0..<16).map { i in
            let angle = CGFloat(i) * .pi / 8
            return CGPoint(x: target.position.x + cos(angle) * radius,
                           y: target.position.y + sin(angle) * radius * 0.75).rounded
        }.sorted { distance(actor.position, $0) < distance(actor.position, $1) }
        // Try nearby approaches first and stop at the first certified route.
        // This is RainShadow enemy policy, outside the unchanged engine port.
        for point in points {
            guard let path = route(in: map, actor: actor, to: point), let end = path.destination,
                  distance(end, target.position) <= TacticalCombat.meleeReach,
                  clearLine(in: map, from: end, to: target.position, excluding: [actor.id, target.id]) else { continue }
            let result = prefix(path, from: actor.position, within: limit)
            if !result.isEmpty { return result }
        }
        return nil
    }
}

/// Encounter props persist as destroyed entries so a reload cannot re-arm them.
struct CombatBarrel: Codable, Equatable {
    static let blastRadius: Double = 120
    static let pushDistance: Double = 80 // Ten feet, approximately three metres.
    let id: String
    var position: CGPoint
    var exploded = false
    var broken: Bool? // Optional for saves written before physical barrel strikes.
    var isBroken: Bool { broken == true || exploded }
    var name: String { isBroken ? "Oil spill" : "Oil barrel" }
}

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

    init(encounterID: String, areaID: String, actors: [Combatant], seed: UInt64) {
        precondition(!actors.isEmpty && Set(actors.map(\.id)).count == actors.count)
        self.encounterID = encounterID; self.areaID = areaID; self.actors = actors
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
        version == 1 && (bearForm?.isValid ?? true) && (2...8).contains(actors.count) && actors.indices.contains(turn)
        && actors.filter(\.player).count == 1 && actors.contains { $0.id == Self.playerID && $0.player }
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
    /// Ascending defence, natural 1/20 and flat damage bands are the initial
    /// RainShadow brawl rules. TemplePlus supplies action costs, not these stats.
    mutating func attack(target id: String, clearLine: Bool, ranged: Bool = false) -> Strike? {
        guard outcome == nil, let target = actors.firstIndex(where: { $0.id == id }),
              actors[target].conscious, actors[target].player != current.player,
              clearLine,
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
        return map.searchMap.blockedInLine(from: a, to: b, size: -1).contains(.passable)
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

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

/// RainShadow weapon techniques, not additional TemplePlus/D20 rules.
/// Every technique has one use per actor per encounter, including on a miss.
enum CombatManeuver: String, Codable, CaseIterable {
    case powerStrike, feintingCut, aimedShot, pinningShot, tripAttack
    var title: String {
        switch self {
        case .tripAttack: "Trip attack"
        case .powerStrike: "Power strike"
        case .feintingCut: "Feinting cut"
        case .aimedShot: "Aimed shot"
        case .pinningShot: "Pinning shot"
        }
    }
    var ranged: Bool { self == .aimedShot || self == .pinningShot }
    var cost: Int { self == .aimedShot ? 4 : 2 }
    var accuracy: Int { self == .powerStrike ? -3 : self == .aimedShot ? 4 : 0 }
    var detail: String {
        switch self {
        case .tripAttack: "Half damage; hit knocks a standing human Prone until their turn • standard action"
        case .powerStrike: "−3 accuracy, +3 damage • standard action"
        case .feintingCut: "Half damage; hit gives −3 accuracy through target's next turn • standard action"
        case .aimedShot: "+4 accuracy • full turn, before moving"
        case .pinningShot: "Half damage; hit halves movement through target's next turn • standard action"
        }
    }
}

struct CombatConditions: Codable, Equatable {
    var weakened = false
    var slowed = false
    var prone: Bool? = nil
    var attackAdvantage: Bool? = nil
    var attackDisadvantage: Bool? = nil
    var goadedBy: String? = nil
    var label: String { [prone == true ? "Prone" : nil, weakened ? "Weakened" : nil, slowed ? "Slowed" : nil, goadedBy != nil ? "Goaded" : nil].compactMap { $0 }.joined(separator: " · ") }
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
    /// Legacy checkpoint field. Defend has been replaced by Blade Ward.
    var defending = false
    var bladeWardTurns: Int? = nil
    var hasBladeWard: Bool { conscious && (bladeWardTurns ?? 0) > 0 }
    // Optional fields keep checkpoints from before weapon techniques readable.
    var usedManeuvers: [CombatManeuver]? = nil
    var conditions: CombatConditions? = nil
    /// Remaining end-of-turn burn ticks; absent in older saves. Refreshes, never stacks.
    var burningTurns: Int? = nil
    var isBurning: Bool { conscious && (burningTurns ?? 0) > 0 }
    // Optional additions preserve older checkpoints. Voss starts with the
    // level-one ability; NPCs need an explicitly authored positive dice count.
    var sneakDice: Int? = nil
    var sneakSpent: Bool? = nil
    var hidden: Bool? = nil
    var hideUsed: Bool? = nil
    var lastSeenPosition: CGPoint? = nil
    var combatFacing: Int? = nil
    var shoveProfile: ShoveProfile? = nil
    var shoveSpent: Bool? = nil
    var sneakDamageDice: Int { sneakDice ?? (player ? 1 : 0) }
    var conscious: Bool { hp > 0 }
    var isProne: Bool { conscious && conditions?.prone == true }
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
        (actor.player && isBear ? BearFormRules.speed : actor.speed) * (actor.conditions?.slowed == true ? 0.5 : 1)
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
        && (barrels ?? []).allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite && !$0.id.isEmpty
            && ($0.debris.map { $0.count == BarrelDebrisPhysics.fragmentCount && $0.allSatisfy(\.isValid) } ?? true) }
        && (2...8).contains(actors.count) && actors.indices.contains(turn)
        && actors.filter(\.player).count == 1 && actors.contains { $0.id == Self.playerID && $0.player }
        && Set((barrels ?? []).map(\.id)).isDisjoint(with: Set(actors.map(\.id)))
        && Set(actors.map(\.id)).count == actors.count && round > 0
        && CombatBudget.transitions.indices.contains(budget.state)
        && budget.movementRemaining.isFinite && budget.movementRemaining >= 0
        && actors.allSatisfy {
            $0.position.x.isFinite && $0.position.y.isFinite && $0.maximumHP > 0
            && $0.hp >= 0 && $0.hp <= $0.maximumHP && $0.speed.isFinite && $0.speed >= 0
            && Set($0.usedManeuvers ?? []).count == ($0.usedManeuvers ?? []).count
            && ($0.burningTurns.map { (1...2).contains($0) } ?? true)
            && ($0.bladeWardTurns.map { (1...2).contains($0) } ?? true)
            && ($0.shoveProfile?.isValid ?? true)
            && ($0.conditions?.goadedBy == nil || ($0.conditions?.goadedBy == Self.playerID && !$0.player && isBear))
            && (0...6).contains($0.sneakDamageDice)
            && ($0.combatFacing.map { (0..<16).contains($0) } ?? true)
            && ($0.lastSeenPosition.map { $0.x.isFinite && $0.y.isFinite } ?? true)
            && ($0.hidden != true || $0.lastSeenPosition != nil)
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
    @discardableResult mutating func endTurn(burningHit: (Strike) -> Void = { _ in }) -> Bool {
        guard outcome == nil else { return false }
        if current.isBurning {
            let damage = roll(4)
            var injury = damage
            if current.player, isBear {
                let absorbed = min(injury, bearForm!.temporaryHP)
                bearForm!.temporaryHP -= absorbed; injury -= absorbed
                if bearForm!.temporaryHP == 0 { endBearForm() }
            }
            actors[turn].hp = max(0, current.hp - injury)
            let remaining = (current.burningTurns ?? 1) - 1
            actors[turn].burningTurns = remaining > 0 && current.conscious ? remaining : nil
            note("Burning: \(damage) to \(current.name).")
            burningHit(.init(attacker: current.id, target: current.id, roll: 0, damage: damage, knockedOut: !current.conscious))
            if !current.conscious { note("\(current.name) is out of the fight.") }
            else if !current.isBurning { note("\(current.name)'s flames go out.") }
        }
        actors[turn].conditions = nil
        actors[turn].sneakSpent = nil
        if current.player, isBear {
            if bearForm!.activationTurn { bearForm!.activationTurn = false }
            else {
                bearForm!.turnsRemaining -= 1
                if !isBear { endBearForm() }
            }
        }
        guard outcome == nil else { return true }
        repeat {
            turn = (turn + 1) % actors.count
            if turn == 0 { round += 1 }
        } while !current.conscious
        actors[turn].defending = false
        if let turns = current.bladeWardTurns {
            actors[turn].bladeWardTurns = turns > 1 ? turns - 1 : nil
            if !current.hasBladeWard { note("\(current.name)'s Blade Ward fades.") }
        }
        actors[turn].hideUsed = nil
        actors[turn].shoveSpent = nil
        budget = CombatBudget()
        if current.isProne {
            // RainShadow adaptation: standing buys the first movement segment and
            // spends half of it; the standard action and remaining movement survive.
            let speed = movementSpeed(for: current)
            if speed > 0 { _ = budget.move(distance: speed / 2, speed: speed) }
            actors[turn].conditions?.prone = nil
            note("\(current.name) gets up, spending half their movement.")
        }
        note("\(current.name)'s turn.")
        return true
    }
    var canShove: Bool { outcome == nil && current.conscious && current.shoveSpent != true && !(current.player && isBear) }
    func physique(of actor: Combatant) -> ShoveProfile {
        actor.player && isBear ? .bear : actor.shoveProfile ?? (actor.player ? .voss : actor.rangedWeapon == .bow ? .lookout : .crew)
    }
    func shoveProblem(target id: String, clearLine: Bool, destination: CGPoint) -> String? {
        guard canShove else { return current.player && isBear ? "Shove requires human form." : "Shove bonus action is spent this turn." }
        guard let target = actors.first(where: { $0.id == id && $0.conscious }), id != current.id else { return "Choose another standing character." }
        guard CombatNavigation.distance(current.position, target.position) <= Self.meleeReach else { return "Move within melee reach to shove." }
        guard !target.isProne else { return "The target is already on the ground." }
        guard clearLine else { return "The target is blocked." }
        let source = physique(of: current), victim = physique(of: target)
        guard Double(source.strength) * 12 >= victim.weight else { return "Too heavy to shove." }
        let travel = CombatNavigation.distance(target.position, destination)
        let dx = destination.x - target.position.x, dy = (destination.y - target.position.y) / 0.75
        let ax = target.position.x - current.position.x, ay = (target.position.y - current.position.y) / 0.75
        guard destination.x.isFinite, destination.y.isFinite, travel >= 2,
              travel <= ShoveRules.distance(attacker: source, target: victim) + 1,
              dx * ax + dy * ay > 0, abs(dx * ay - dy * ax) <= hypot(ax, ay) else { return "No room to push: the landing path is blocked." }
        return nil
    }
    func shovePreview(target id: String, clearLine: Bool, destination: CGPoint) -> ShovePreview? {
        guard shoveProblem(target: id, clearLine: clearLine, destination: destination) == nil,
              let target = actors.first(where: { $0.id == id }) else { return nil }
        let source = physique(of: current), victim = physique(of: target)
        let dc = 10 + max(victim.athletics, victim.acrobatics)
        let advantage = current.hidden == true
        return ShovePreview(destination: destination,
            chance: target.player == current.player ? 100 : ShoveRules.chance(bonus: source.athletics, dc: dc, advantage: advantage),
            dc: dc, bonus: source.athletics, advantage: advantage)
    }
    struct Shove: Equatable {
        let attacker: String
        let target: String
        let roll: Int
        let secondRoll: Int?
        let succeeded: Bool
        let preview: ShovePreview
        let displacement: Displacement?
    }
    /// Resolve and save the destination before presentation. Invalid targeting is
    /// inert; a resisted shove consumes the bonus action but never the normal attack.
    mutating func shove(target id: String, clearLine: Bool, destination: CGPoint) -> Shove? {
        guard let preview = shovePreview(target: id, clearLine: clearLine, destination: destination),
              let index = actors.firstIndex(where: { $0.id == id }) else { return nil }
        let attacker = current, target = actors[index]
        let allied = target.player == attacker.player
        let first = allied ? 0 : roll(20)
        let second = preview.advantage && !allied ? roll(20) : nil
        let success = allied || max(first, second ?? first) + preview.bonus >= preview.dc
        actors[turn].shoveSpent = true
        face(attacker.id, toward: target.position)
        reveal(attacker.id); reveal(target.id)
        if success { actors[index].position = destination }
        note("\(attacker.name) shoves \(target.name): \(allied ? "willing target" : "\(max(first, second ?? first)) + \(preview.bonus) vs \(preview.dc)") — \(success ? "pushed" : "resisted") (bonus action).")
        return Shove(attacker: attacker.id, target: id, roll: first, secondRoll: second, succeeded: success, preview: preview,
            displacement: success ? .init(id: id, from: target.position, to: destination) : nil)
    }
    var canExtinguish: Bool { outcome == nil && current.isBurning && budget.canAttack }
    @discardableResult mutating func extinguish() -> Bool {
        guard canExtinguish, budget.spend(2) else { return false }
        actors[turn].burningTurns = nil
        note("\(current.name) extinguishes the flames (standard action).")
        return true
    }
    var canCastBladeWard: Bool {
        outcome == nil && current.conscious && !current.isProne
            && !(current.player && isBear) && budget.canAttack
    }
    @discardableResult mutating func castBladeWard() -> Bool {
        guard canCastBladeWard, budget.spend(2) else { return false }
        actors[turn].bladeWardTurns = 2
        actors[turn].defending = false
        reveal(current.id)
        note("\(current.name) casts Blade Ward: physical damage halved for two turns.")
        return true
    }
    /// The caller supplies a route certified by CombatNavigation/SearchMap.
    @discardableResult mutating func move(along path: Path) -> Bool {
        guard outcome == nil, let end = path.destination, !path.isEmpty else { return false }
        let cost = CombatNavigation.length(path, from: current.position)
        guard budget.move(distance: cost, speed: movementSpeed(for: current)) else { return false }
        let prior = path.remainingPoints.dropLast().last ?? current.position
        actors[turn].combatFacing = ActorFacing.orient(from: prior, to: end).rawValue
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
        reveal(current.id)
        bearForm = BearFormState()
        note("Voss takes Bear Form: \(BearFormRules.maximumEndurance) Bear Health, three full turns.")
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
        for i in actors.indices { actors[i].conditions?.goadedBy = nil }
        note("Voss returns to human form. Bear Form is spent for this encounter.")
    }
    var canGoadingRoar: Bool { isPlayerTurn && isBear && bearForm?.roarSpent != true && budget.canAttack }
    func roarTargets(clearLine: (Combatant, Combatant) -> Bool) -> [Combatant] {
        guard isPlayerTurn, isBear else { return [] }
        return actors.filter { !$0.player && $0.conscious && $0.hidden != true
            && CombatNavigation.distance(current.position, $0.position) <= BearFormRules.roarRadius
            && clearLine(current, $0) }
    }
    /// RainShadow adaptation: guaranteed goad, one use per transformation,
    /// through each victim's next turn. Reverting releases all affected enemies.
    mutating func goadingRoar(clearLine: (Combatant, Combatant) -> Bool) -> [String]? {
        guard canGoadingRoar else { return nil }
        let targets = roarTargets(clearLine: clearLine)
        guard !targets.isEmpty, budget.spend(2) else { return nil }
        bearForm?.roarSpent = true
        let source = current.id
        for target in targets {
            let i = actors.firstIndex { $0.id == target.id }!
            if actors[i].conditions == nil { actors[i].conditions = CombatConditions() }
            actors[i].conditions?.goadedBy = source
        }
        note("Goading Roar: \(targets.map(\.name).joined(separator: ", ")) must focus on the bear through their next turn.")
        return targets.map(\.id)
    }
    func goadingTarget(for actor: Combatant) -> Combatant? {
        guard isBear, let id = actor.conditions?.goadedBy else { return nil }
        return actors.first { $0.id == id && $0.conscious }
    }
    struct Strike: Equatable {
        let attacker: String
        let target: String
        let roll: Int
        let damage: Int
        let knockedOut: Bool
        var maneuver: CombatManeuver? = nil
        var sneakDamage = 0
        var requestedSneakAttack = false
        var attackRolls: [Int] = []
        var fireArrow = false
        var wardAbsorbed = 0
        /// A fully resisted one-point hit must not play a miss or dodge.
        var landed: Bool { damage > 0 || wardAbsorbed > 0 }
    }
    struct BarrelExplosion: Equatable {
        let barrel: CombatBarrel
        let hits: [Strike]
    }
    mutating func recordBarrelDebris(_ id: String, poses: [BarrelFragmentPose]) {
        guard poses.count == BarrelDebrisPhysics.fragmentCount, poses.allSatisfy(\.isValid),
              let index = barrels?.firstIndex(where: { $0.id == id && $0.isBroken }) else { return }
        barrels![index].debris = poses
    }
    struct Displacement: Equatable {
        let id: String
        let from: CGPoint
        let to: CGPoint
    }
    /// A physical strike spills the contents without igniting them.
    mutating func breakBarrel(_ id: String, clearLine: Bool) -> Bool {
        guard outcome == nil, clearLine, goadingTarget(for: current) == nil,
              let index = barrels?.firstIndex(where: { $0.id == id && !$0.isBroken }),
              CombatNavigation.distance(current.position, barrels![index].position) <= Self.meleeReach,
              budget.spend(2) else { return false }
        reveal(current.id)
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
        guard outcome == nil, !isBear || !current.player, goadingTarget(for: current) == nil,
              current.rangedWeapon == .bow,
              let barrel = liveBarrels.first(where: { $0.id == id }), clearShot,
              CombatNavigation.distance(current.position, barrel.position) <= BowAttackRules.range,
              CombatNavigation.distance(current.position, barrel.position) > Self.meleeReach,
              budget.spend(2) else { return nil }
        reveal(current.id)
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
                reveal(actors[index].id)
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

    /// A small combat stealth adapter, not a change to GemRB sight/navigation.
    /// Outside a 120-degree facing cone (or behind opaque terrain), Hide is
    /// deterministic. Light levels/perception checks are deliberately not modelled.
    static func insideSightCone(observer: Combatant, point: CGPoint) -> Bool {
        let dx = point.x - observer.position.x
        let dy = (point.y - observer.position.y) / ActorLocomotionPacing.verticalProjectionScale
        let length = hypot(dx, dy)
        guard length > 0.001 else { return true }
        guard length <= BowAttackRules.range else { return false }
        let angle = Double(observer.combatFacing ?? ActorFacing.south.rawValue) * .pi / 8
        return (-sin(angle) * dx - cos(angle) * dy) / length >= 0.5
    }
    mutating func face(_ id: String, toward point: CGPoint) {
        guard let i = actors.firstIndex(where: { $0.id == id }) else { return }
        actors[i].combatFacing = ActorFacing.orient(from: actors[i].position, to: point).rawValue
    }
    mutating func setInitialFacing(_ id: String, facing: ActorFacing) {
        guard let i = actors.firstIndex(where: { $0.id == id }), actors[i].combatFacing == nil else { return }
        actors[i].combatFacing = facing.rawValue
    }
    var canHide: Bool {
        outcome == nil && current.sneakDamageDice > 0 && current.hideUsed != true
            && current.hidden != true && !current.isBurning && !(current.player && isBear)
    }
    @discardableResult mutating func hide(observed: Bool) -> Bool {
        guard canHide, !observed else { return false }
        actors[turn].hidden = true; actors[turn].hideUsed = true
        actors[turn].lastSeenPosition = current.position
        note("\(current.name) hides: advantage on the next attack. Entering enemy sight reveals them.")
        return true
    }
    mutating func reveal(_ id: String) {
        guard let i = actors.firstIndex(where: { $0.id == id }), actors[i].hidden == true else { return }
        actors[i].hidden = nil; actors[i].lastSeenPosition = nil
        note("\(actors[i].name) is revealed.")
    }
    /// Opposing advantage/disadvantage sources cancel, regardless of their count.
    func attackEdge(ranged: Bool, target: Combatant? = nil, allyLine: (Combatant, Combatant) -> Bool) -> Int {
        let nearProne = target.map { $0.isProne && CombatNavigation.distance(current.position, $0.position) <= Self.meleeReach } ?? false
        let farProne = target.map { $0.isProne && CombatNavigation.distance(current.position, $0.position) > Self.meleeReach } ?? false
        let advantage = current.hidden == true || current.conditions?.attackAdvantage == true || nearProne
        let threatened = ranged && actors.contains { $0.conscious && !$0.isProne && $0.player != current.player
            && CombatNavigation.distance($0.position, current.position) <= Self.meleeReach && allyLine($0, current) }
        let disadvantage = current.conditions?.attackDisadvantage == true || threatened || farProne
        return advantage == disadvantage ? 0 : advantage ? 1 : -1
    }
    func sneakAttackReason(target: Combatant, ranged: Bool, hasSword: Bool, clearLine: Bool,
                          allyLine: (Combatant, Combatant) -> Bool = { _, _ in true }) -> String? {
        guard outcome == nil, target.conscious, target.player != current.player else { return "Choose a conscious rival." }
        guard target.hidden != true else { return "The target is hidden." }
        guard current.sneakDamageDice > 0 else { return "This character has no Sneak Attack ability." }
        guard !(current.player && isBear) else { return "Sneak Attack requires human form." }
        guard current.sneakSpent != true else { return "Sneak Attack is spent until your turn ends." }
        guard ranged ? current.rangedWeapon == .bow : hasSword else { return "Use a shortsword or bow." }
        guard clearLine else { return "The target is blocked by terrain." }
        let distance = CombatNavigation.distance(current.position, target.position)
        guard ranged ? (distance > Self.meleeReach && distance <= BowAttackRules.range) : distance <= Self.meleeReach else { return "Move into weapon range." }
        let edge = attackEdge(ranged: ranged, target: target, allyLine: allyLine)
        guard edge >= 0 else { return "Disadvantage prevents Sneak Attack." }
        let ally = actors.contains { $0.id != current.id && $0.player == current.player && $0.conscious && !$0.isProne
            && CombatNavigation.distance($0.position, target.position) <= Self.meleeReach && allyLine($0, target) }
        guard edge > 0 || ally else { return "Gain advantage by hiding, or have an ally beside the target." }
        guard budget.canAttack else { return "No standard action remains." }
        return nil
    }

    func canUse(_ maneuver: CombatManeuver, hasSword: Bool = false) -> Bool {
        outcome == nil && !(current.player && isBear)
            && !(current.usedManeuvers ?? []).contains(maneuver)
            && (maneuver.ranged ? current.rangedWeapon == .bow : hasSword)
            && CombatBudget.transition(state: budget.state, cost: maneuver.cost) != nil
            && (maneuver != .aimedShot || (budget.state == 4 && budget.movementRemaining == 0))
    }

    func attackBonus(for actor: Combatant) -> Int {
        (actor.player && isBear ? BearFormRules.attackBonus : actor.attackBonus)
            - (actor.conditions?.weakened == true ? 3 : 0)
    }
    func defence(for actor: Combatant) -> Int {
        actor.player && isBear ? BearFormRules.defence : actor.defence
    }
    /// Deterministic choices use visible conditions, never future rolls.
    /// The director checks range/terrain before requesting a technique.
    func preferredManeuver(target: Combatant, ranged: Bool, hasSword: Bool = false) -> CombatManeuver? {
        let chance = min(0.95, max(0.05, Double(21 + attackBonus(for: current) - defence(for: target)) / 20))
        if ranged {
            if chance < 0.7 && canUse(.aimedShot) { return .aimedShot }
            let distance = CombatNavigation.distance(current.position, target.position)
            if target.hp > current.damageMax, target.conditions?.slowed != true,
               distance > Self.meleeReach, distance <= movementSpeed(for: target) + Self.meleeReach,
               canUse(.pinningShot) { return .pinningShot }
        } else {
            if target.hp > current.damageMax, chance >= 0.8, canUse(.powerStrike, hasSword: hasSword) { return .powerStrike }
            if target.hp > current.damageMax, !target.isProne, !(target.player && isBear),
               target.damageMax >= 4,
               actors.contains(where: { $0.id != current.id && $0.player == current.player && $0.conscious && !$0.isProne
                   && CombatNavigation.distance($0.position, target.position) <= Self.meleeReach }),
               canUse(.tripAttack, hasSword: hasSword) { return .tripAttack }
            if target.hp > current.damageMax, target.conditions?.weakened != true,
               target.damageMax >= 3, canUse(.feintingCut, hasSword: hasSword) { return .feintingCut }
        }
        return nil
    }

    /// Ascending defence, natural 1/20 and flat damage bands are RainShadow
    /// adaptations. TemplePlus supplies the unchanged action-cost transitions.
    mutating func attack(target id: String, clearLine: Bool, ranged: Bool = false,
                         maneuver: CombatManeuver? = nil, hasSword: Bool = false,
                         requireSneakAttack: Bool = false,
                         allyLine: (Combatant, Combatant) -> Bool = { _, _ in true }) -> Strike? {
        let sneakEligible = actors.first(where: { $0.id == id }).map {
            sneakAttackReason(target: $0, ranged: ranged, hasSword: hasSword, clearLine: clearLine, allyLine: allyLine) == nil
        } ?? false
        guard outcome == nil, let target = actors.firstIndex(where: { $0.id == id }),
              actors[target].conscious, actors[target].hidden != true, actors[target].player != current.player,
              clearLine,
              maneuver != .tripAttack || (!actors[target].isProne && !(actors[target].player && isBear)),
              !requireSneakAttack || sneakAttackReason(target: actors[target], ranged: ranged,
                  hasSword: hasSword, clearLine: clearLine, allyLine: allyLine) == nil,
              maneuver.map({ $0.ranged == ranged && canUse($0, hasSword: hasSword) }) ?? true,
              !(ranged && current.player && isBear),
              ranged ? BowAttackRules.canShoot(attacker: current, target: actors[target], clearLine: clearLine)
                  : CombatNavigation.distance(current.position, actors[target].position) <= Self.meleeReach,
              budget.spend(maneuver?.cost ?? 2) else { return nil }
        if let maneuver {
            actors[turn].usedManeuvers = (actors[turn].usedManeuvers ?? []) + [maneuver]
        }
        let edge = attackEdge(ranged: ranged, target: actors[target], allyLine: allyLine)
        var attackRolls = [roll(20)]
        if edge != 0 { attackRolls.append(roll(20)) }
        let die = edge > 0 ? attackRolls.max()! : edge < 0 ? attackRolls.min()! : attackRolls[0]
        face(current.id, toward: actors[target].position)
        reveal(current.id)
        let bearAttacker = current.player && isBear
        let attackBonus = attackBonus(for: current) + (maneuver?.accuracy ?? 0)
        let defence = defence(for: actors[target])
        let hit = die == 20 || (die != 1 && die + attackBonus >= defence)
        let minimum = bearAttacker ? BearFormRules.damageMin : current.damageMin
        let maximum = bearAttacker ? BearFormRules.damageMax : current.damageMax
        var damage = hit ? minimum + roll(maximum - minimum + 1) - 1 : 0
        if hit {
            if maneuver == .powerStrike { damage += 3 }
            if maneuver == .feintingCut || maneuver == .pinningShot || maneuver == .tripAttack { damage = max(1, damage / 2) }
        }
        var sneakDamage = 0
        if hit && sneakEligible {
            for _ in 0..<(current.sneakDamageDice * (die == 20 ? 2 : 1)) { sneakDamage += roll(6) }
            damage += sneakDamage; actors[turn].sneakSpent = true
        }
        let wardAbsorbed = actors[target].hasBladeWard ? damage - damage / 2 : 0
        damage -= wardAbsorbed
        if hit { reveal(actors[target].id) }
        var injury = damage
        if actors[target].player, isBear {
            let absorbed = min(injury, bearForm!.temporaryHP)
            bearForm!.temporaryHP -= absorbed
            injury -= absorbed
            if bearForm!.temporaryHP == 0 { endBearForm() }
        }
        actors[target].hp = max(0, actors[target].hp - injury)
        if hit && actors[target].conscious {
            if maneuver == .tripAttack {
                if actors[target].conditions == nil { actors[target].conditions = CombatConditions() }
                actors[target].conditions?.prone = true
                actors[target].defending = false
                note("\(actors[target].name) is Prone until their turn; nearby attacks have advantage.")
            }
            if maneuver == .feintingCut {
                if actors[target].conditions == nil { actors[target].conditions = CombatConditions() }
                actors[target].conditions?.weakened = true
            }
            if maneuver == .pinningShot {
                if actors[target].conditions == nil { actors[target].conditions = CombatConditions() }
                actors[target].conditions?.slowed = true
            }
        }
        let fireArrow = ranged && maneuver == nil && !requireSneakAttack
        if hit && fireArrow && actors[target].conscious {
            actors[target].burningTurns = 2
            note("\(actors[target].name) is Burning: 1–4 damage at the end of each of their next two turns. Extinguish uses a standard action.")
        }
        if !actors[target].conscious { actors[target].burningTurns = nil }
        let result = Strike(attacker: current.id, target: id, roll: die, damage: damage,
                            knockedOut: !actors[target].conscious, maneuver: maneuver, sneakDamage: sneakDamage, requestedSneakAttack: requireSneakAttack, attackRolls: attackRolls, fireArrow: fireArrow, wardAbsorbed: wardAbsorbed)
        note("\(current.name)\(maneuver.map { " — " + $0.title } ?? (ranged ? " fires" : "")): d20 \(die) + \(attackBonus) vs \(defence) — " +
             (hit ? "\(damage) to \(actors[target].name)." : "miss."))
        if sneakDamage > 0 { note("Sneak Attack: +\(sneakDamage) damage\(die == 20 ? " (critical)" : "").") }
        if wardAbsorbed > 0 { note("Blade Ward prevented \(wardAbsorbed) physical damage.") }
        if edge != 0 { note("\(edge > 0 ? "Advantage" : "Disadvantage"): rolled \(attackRolls[0]) / \(attackRolls[1]), kept \(die).") }
        if hit, !result.knockedOut, maneuver == .feintingCut || maneuver == .pinningShot {
            note("\(actors[target].name): \(maneuver == .feintingCut ? "Weakened (−3 accuracy)" : "Slowed (half movement)") through their next turn.")
        }
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
        actors: [Combatant], destroyedBarrels: [String], bear: Bool = false, maximumDistance: Double = CombatBarrel.pushDistance) -> CGPoint {
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
        for step in stride(from: 2.0, through: min(CombatBarrel.pushDistance, max(0, maximumDistance)), by: 2) {
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
    var debris: [BarrelFragmentPose]? // Settled physics endpoint; absent in older checkpoints.
    var broken: Bool? // Optional for saves written before physical barrel strikes.
    var isBroken: Bool { broken == true || exploded }
    var name: String { isBroken ? "Oil spill" : "Oil barrel" }
}

import SpriteKit

/// A resolved action revealed at the authored hit marker, on the paused combat clock.
@MainActor
final class MeleeAttackPresentation {
    let before: TacticalCombat
    let result: TacticalCombat.Strike
    let target: Combatant
    let actor: CharacterAppearanceNode
    let facing: ActorFacing
    let barrelDestruction: BarrelDestruction?
    private(set) var elapsed: TimeInterval = 0
    var impactPresented = false
    var finished: Bool { elapsed >= MeleeAttackAnimationSet.recoveryTime }

    init(before: TacticalCombat, result: TacticalCombat.Strike, target: Combatant,
         actor: CharacterAppearanceNode, barrelDestruction: BarrelDestruction? = nil) {
        self.barrelDestruction = barrelDestruction
        self.before = before; self.result = result; self.target = target; self.actor = actor
        facing = .orient(from: before.current.position, to: target.position)
        try? actor.present(action: .attack, facing: facing, phase: 0)
    }
    func advance(delta: TimeInterval) {
        elapsed += delta
        let phase = min(MeleeAttackAnimationSet.frames - 1,
                        Int(elapsed * MeleeAttackAnimationSet.framesPerSecond))
        try? actor.present(action: .attack, facing: facing, phase: phase)
    }
    func stop() { try? actor.present(action: .idle, facing: facing, phase: 0) }
}

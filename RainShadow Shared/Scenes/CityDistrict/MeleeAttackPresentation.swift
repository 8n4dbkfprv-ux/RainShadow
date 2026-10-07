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
    let swingTrail: MeleeSwingTrail?
    private(set) var elapsed: TimeInterval = 0
    var impactPresented = false
    var dodgePresented = false
    var impactTime: TimeInterval { WeaponTechniqueMotion.meleeImpact(result.maneuver) }
    var finished: Bool { elapsed >= WeaponTechniqueMotion.meleeDuration(result.maneuver) }

    init(before: TacticalCombat, result: TacticalCombat.Strike, target: Combatant,
         actor: CharacterAppearanceNode, barrelDestruction: BarrelDestruction? = nil) {
        swingTrail = actor.definition.appearance.equipment.contains { $0.item == .lanternShortsword }
            ? MeleeSwingTrail() : nil
        self.barrelDestruction = barrelDestruction
        self.before = before; self.result = result; self.target = target; self.actor = actor
        facing = .orient(from: before.current.position, to: target.position)
        actor.setAttackTrail(swingTrail?.sprite)
        try? actor.presentTechnique(result.maneuver, action: .attack, facing: facing, phase: 0)
    }
    func advance(delta: TimeInterval) {
        elapsed += delta
        let phase = min(WeaponTechniqueMotion.meleeFrames(result.maneuver) - 1,
                        Int(elapsed * WeaponTechniqueMotion.meleeFPS(result.maneuver)))
        swingTrail?.sample(elapsed: elapsed, facing: facing, maneuver: result.maneuver)
        try? actor.presentTechnique(result.maneuver, action: .attack, facing: facing, phase: phase)
    }
    func stop() {
        actor.setAttackTrail(nil)
        try? actor.present(action: .idle, facing: facing, phase: 0)
    }
}

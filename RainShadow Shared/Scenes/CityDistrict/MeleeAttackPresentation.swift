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
    var isSneakAttack: Bool { StealthAnimationSet.usesAttack(result) }
    var impactTime: TimeInterval { isSneakAttack ? StealthAnimationSet.stabImpact : WeaponTechniqueMotion.meleeImpact(result.maneuver) }
    var finished: Bool { elapsed >= (isSneakAttack ? StealthAnimationSet.stabDuration : WeaponTechniqueMotion.meleeDuration(result.maneuver)) }

    init(before: TacticalCombat, result: TacticalCombat.Strike, target: Combatant,
         actor: CharacterAppearanceNode, barrelDestruction: BarrelDestruction? = nil) {
        swingTrail = !StealthAnimationSet.usesAttack(result) && actor.definition.appearance.equipment.contains { $0.item == .lanternShortsword }
            ? MeleeSwingTrail() : nil
        self.barrelDestruction = barrelDestruction
        self.before = before; self.result = result; self.target = target; self.actor = actor
        facing = .orient(from: before.current.position, to: target.position)
        actor.setAttackTrail(swingTrail?.sprite)
        present(phase: 0)
    }
    func advance(delta: TimeInterval) {
        elapsed += delta
        let phase = isSneakAttack ? StealthAnimationSet.phase(.sneakstab, elapsed: elapsed) : min(WeaponTechniqueMotion.meleeFrames(result.maneuver) - 1,
                        Int(elapsed * WeaponTechniqueMotion.meleeFPS(result.maneuver)))
        swingTrail?.sample(elapsed: elapsed, facing: facing, maneuver: result.maneuver)
        present(phase: phase)
    }
    private func present(phase: Int) {
        if isSneakAttack { try? actor.presentStealth(.sneakstab, facing: facing, phase: phase) }
        else { try? actor.presentTechnique(result.maneuver, action: .attack, facing: facing, phase: phase) }
    }
    func stop() {
        actor.setAttackTrail(nil)
        try? actor.present(action: .idle, facing: facing, phase: 0)
    }
}

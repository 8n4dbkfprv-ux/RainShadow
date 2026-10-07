import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct WeaponTechniqueMotionTests {
    @Test func distinctMeleeMarkersKeepWindupImpactAndRecoveryOrdered() {
        #expect(WeaponTechniqueMotion.meleeImpact(.powerStrike) > MeleeAttackAnimationSet.impactTime)
        #expect(WeaponTechniqueMotion.meleeDuration(.feintingCut) < MeleeAttackAnimationSet.recoveryTime)
        for move in [CombatManeuver.powerStrike, .feintingCut] {
            let fps = WeaponTechniqueMotion.meleeFPS(move)
            #expect(WeaponTechniqueMotion.trailStart(move) / fps < WeaponTechniqueMotion.meleeImpact(move))
            #expect(WeaponTechniqueMotion.meleeImpact(move) < WeaponTechniqueMotion.meleeDuration(move))
            #expect(WeaponTechniqueMotion.trailEnd(move) / fps + SwordSwingPath.fadeDuration < WeaponTechniqueMotion.meleeDuration(move))
        }
        #expect(WeaponTechniqueMotion.meleeDuration(nil) == MeleeAttackAnimationSet.recoveryTime)
        #expect(WeaponTechniqueMotion.meleeImpact(nil) == MeleeAttackAnimationSet.impactTime)
    }
    @Test func aimedShotHoldsTheNockedArrowThenReleasesInSync() {
        #expect(WeaponTechniqueMotion.bowPhase(elapsed: 0.8, move: .aimedShot) == 9)
        #expect(WeaponTechniqueMotion.bowPhase(elapsed: 0.98, move: .aimedShot) == 9)
        #expect(WeaponTechniqueMotion.bowPhase(elapsed: 0.8, move: nil) == 12)
        let release = WeaponTechniqueMotion.bowRelease(.aimedShot)
        #expect(release > BowAttackRules.releaseTime)
        #expect(WeaponTechniqueMotion.bowPhase(elapsed: release + 0.000001, move: .aimedShot) == 10)
        #expect(WeaponTechniqueMotion.bowDuration(.aimedShot) > release)
        #expect(WeaponTechniqueMotion.bowRelease(.pinningShot) == BowAttackRules.releaseTime)
    }
    @Test func recoilReturnsToNeutralAndHeavyImpactsAreStronger() {
        var normal = CombatRecoil(from: .zero, to: CGPoint(x: 80, y: 0), heavy: false)
        var heavy = CombatRecoil(from: .zero, to: CGPoint(x: 80, y: 0), heavy: true)
        #expect(normal.angle == 0 && heavy.angle == 0)
        normal.elapsed = 0.12; heavy.elapsed = 0.12
        #expect(abs(heavy.angle) > abs(normal.angle))
        #expect(heavy.duration > normal.duration)
        normal.elapsed = normal.duration; heavy.elapsed = heavy.duration
        #expect(normal.finished && heavy.finished)
        #expect(abs(normal.angle) < 0.000001 && abs(heavy.angle) < 0.000001)
    }
    @Test func techniqueBladePathsAreDistinctAndReturnToTheirSharedRest() {
        var powerSeparation = 0.0, feintSeparation = 0.0
        for facing in ActorFacing.allCases {
            let ordinary = SwordSwingPath.blade(phase: 3, facing: facing)
            let power = SwordSwingPath.blade(phase: 5, facing: facing, maneuver: .powerStrike)
            let feint = SwordSwingPath.blade(phase: 6, facing: facing, maneuver: .feintingCut)
            powerSeparation = max(powerSeparation, hypot(ordinary.tip.x - power.tip.x, ordinary.tip.y - power.tip.y))
            feintSeparation = max(feintSeparation, hypot(feint.tip.x - power.tip.x, feint.tip.y - power.tip.y))
            for move in [CombatManeuver.powerStrike, .feintingCut] {
                let start = SwordSwingPath.blade(phase: 0, facing: facing, maneuver: move)
                let end = SwordSwingPath.blade(phase: Double(WeaponTechniqueMotion.meleeFrames(move) - 1), facing: facing, maneuver: move)
                #expect(hypot(start.tip.x - end.tip.x, start.tip.y - end.tip.y) < 0.01)
            }
        }
        // Foreshortening can align two tips in an individual view. Across views,
        // the authored paths must be materially different in world space.
        #expect(powerSeparation > 5 && feintSeparation > 5)
    }
    @Test func allTechniqueDirectionsHaveCompletePinnedRegisteredLayers() throws {
        for character in WeaponTechniqueAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try WeaponTechniqueAnimationSet.validate(sprite, character: character)
            let moves: [CombatManeuver] = character == WeaponTechniqueAnimationSet.pinning ? [.pinningShot] : [.powerStrike, .feintingCut]
            for move in moves { for facing in ActorFacing.allCases {
                let count = move == .pinningShot ? 18 : WeaponTechniqueMotion.meleeFrames(move)
                let frames = try (0..<count).map { phase in
                    let key = try WeaponTechniqueAnimationSet.name(move, facing: facing, phase: phase)
                    return try #require(sprite.frame(atlas: character + ".atlas", name: key))
                }
                if character == WeaponTechniqueAnimationSet.body || character == WeaponTechniqueAnimationSet.pinning {
                    #expect(Set(frames.map { Data($0.indices) }).count >= 8)
                }
            }}
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try BowAttackAnimationSet.validate(IEIndexedSprite.load(character: BowAttackAnimationSet.character))
    }
}

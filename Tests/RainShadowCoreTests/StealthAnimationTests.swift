import Testing
import Foundation
@testable import RainShadowCore

struct StealthAnimationTests {
    @Test func reviewedPosesHaveAllFacingsAndMatchingEquipment() throws {
        #expect(StealthAnimationSet.hashes.count == 7)
        for character in StealthAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try StealthAnimationSet.validate(sprite, character: character)
            let clips: [StealthClip] = character == StealthAnimationSet.bow ? [.sneakshoot] : [.hide, .sneakidle, .sneakwalk, .sneakstab]
            for facing in ActorFacing.allCases {
                func frame(_ clip: StealthClip, _ phase: Int) throws -> IEIndexedSprite.Frame {
                    try #require(sprite.frame(atlas: character + ".atlas", name: StealthAnimationSet.name(clip, facing: facing, phase: phase)))
                }
                for clip in clips where character == StealthAnimationSet.body || character == StealthAnimationSet.bow {
                    let poses = try (0..<clip.frames).map { Data(try frame(clip, $0).indices) }
                    #expect(Set(poses).count >= 3)
                }
                if character != StealthAnimationSet.bow {
                    #expect(try frame(.hide, 7).indices == frame(.sneakidle, 0).indices)
                    #expect(try frame(.sneakstab, 0).indices == frame(.sneakidle, 0).indices)
                    #expect(try frame(.sneakstab, 17).indices == frame(.hide, 0).indices)
                }
            }
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try BowAttackAnimationSet.validate(IEIndexedSprite.load(character: BowAttackAnimationSet.character))
    }
    @Test func sneakStabClearlyLeavesTheGroundInEveryFacing() throws {
        let sprite = try IEIndexedSprite.load(character: StealthAnimationSet.body)
        for facing in ActorFacing.allCases {
            func bottom(_ phase: Int) throws -> Int {
                let frame = try #require(sprite.frame(atlas: StealthAnimationSet.body + ".atlas",
                    name: StealthAnimationSet.name(.sneakstab, facing: facing, phase: phase)))
                // Shadow index 1 remains on the floor; measure the solid body separately.
                let lastBodyPixel = try #require(frame.indices.lastIndex(where: { $0 > 1 }))
                return frame.trimOriginTopLeft.height + lastBodyPixel / frame.nativeSize.width
            }
            let grounded = try bottom(0), apex = try bottom(7), landed = try bottom(17)
            #expect(grounded - apex >= 12)
            #expect(landed - apex >= 10)
        }
    }
    @Test func holdAndImpactMarkersFollowTheirNewPoses() {
        #expect(StealthAnimationSet.phase(.hide, elapsed: 10) == 7)
        #expect(StealthAnimationSet.phase(.sneakwalk, elapsed: 1, looping: true) == 3)
        #expect(StealthAnimationSet.phase(.sneakstab, elapsed: StealthAnimationSet.stabImpact) == 9)
        #expect(StealthAnimationSet.phase(.sneakshoot, elapsed: StealthAnimationSet.bowRelease - 0.001) == 9)
        #expect(StealthAnimationSet.phase(.sneakshoot, elapsed: StealthAnimationSet.bowRelease) == 10)
        #expect(StealthAnimationSet.phase(.sneakshoot, elapsed: StealthAnimationSet.bowDuration) == 17)
    }
    @Test func explicitMissesAndAutomaticBonusesUseStealthButTechniquesKeepTheirOwnPose() {
        var strike = TacticalCombat.Strike(attacker: "a", target: "b", roll: 1, damage: 0, knockedOut: false)
        #expect(!StealthAnimationSet.usesAttack(strike))
        strike.requestedSneakAttack = true
        #expect(StealthAnimationSet.usesAttack(strike))
        strike.requestedSneakAttack = false; strike.sneakDamage = 4
        #expect(StealthAnimationSet.usesAttack(strike))
        strike.maneuver = .feintingCut
        #expect(!StealthAnimationSet.usesAttack(strike))
    }
}

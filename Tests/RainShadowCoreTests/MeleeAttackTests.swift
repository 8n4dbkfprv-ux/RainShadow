import Testing
import Foundation
@testable import RainShadowCore

struct MeleeAttackTests {
    @Test func everyFacingHasRegisteredBodyAndEquipmentLayers() throws {
        for character in MeleeAttackAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try MeleeAttackAnimationSet.validate(sprite, character: character)
            for facing in ActorFacing.allCases {
                #expect(try CharacterBodyCode.humanMale01.frameCount(for: .attack, facing: facing) == 12)
                let names = try (0..<12).map {
                    try CharacterBodyCode.humanMale01.frameName(action: .attack, facing: facing, phase: $0)
                }
                let frames = names.compactMap { sprite.frame(atlas: character + ".atlas", name: $0) }
                #expect(frames.count == 12)
                if character == MeleeAttackAnimationSet.body {
                    #expect(Set(frames.map { Data($0.indices) }).count >= 8)
                }
            }
        }
        #expect(MeleeAttackAnimationSet.hashes.count == 4)
        #expect(MeleeAttackAnimationSet.impactTime == 0.4)
        #expect(MeleeAttackAnimationSet.recoveryTime > MeleeAttackAnimationSet.impactTime)
    }

    @Test func meleeDoesNotReplaceApprovedLocomotionOrClaimFemaleFrames() throws {
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character))
        #expect(throws: CharacterAppearanceError.self) {
            try CharacterBodyCode.humanFemale01.frameCount(for: .attack, facing: .south)
        }
        #expect(MeleeAttackAnimationSet.equipment(.elvenCourtBow) == nil)
        #expect(MeleeAttackAnimationSet.equipment(.elvenCourtArrow) == nil)
        #expect(MeleeAttackAnimationSet.equipment(.lanternShortsword) != nil)
    }
    @Test func swordTrailUsesTheAuthoredSwingAndTheSameProjectionInEveryFacing() {
        let density = (1024 / 1.72 * 0.07465790639916813) * (140.625 / 128)
        let windup = SwordSwingPath.blade(phase: 3, facing: .south)
        #expect(abs(windup.tip.x - (-0.56518388 * density)) < 0.00001)
        for facing in ActorFacing.allCases {
            for step in 0...44 {
                let phase = Double(step) / 4
                let blade = SwordSwingPath.blade(phase: phase, facing: facing)
                #expect(blade.base.x.isFinite && blade.base.y.isFinite && blade.tip.x.isFinite && blade.tip.y.isFinite)
                #expect(abs(blade.tip.x) < 80 && abs(blade.tip.y) < 105)
            }
            let start = SwordSwingPath.blade(phase: 0, facing: facing)
            let end = SwordSwingPath.blade(phase: 11, facing: facing)
            #expect(start.base == end.base && start.tip == end.tip)
        }
        #expect(SwordSwingPath.endPhase / MeleeAttackAnimationSet.framesPerSecond
                + SwordSwingPath.fadeDuration < MeleeAttackAnimationSet.recoveryTime)
    }
}

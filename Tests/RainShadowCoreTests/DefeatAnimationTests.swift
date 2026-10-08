import Testing
import Foundation
@testable import RainShadowCore

struct DefeatAnimationTests {
    @Test func collapseHoldsTheFloorPoseWithoutLooping() {
        var motion = CombatDefeatMotion(facing: .southWest)
        #expect(motion.phase == 0 && !motion.finished)
        motion.elapsed = 0.4
        #expect(motion.phase == 6 && !motion.finished)
        motion.elapsed = DefeatAnimationSet.duration
        #expect(motion.phase == 17 && motion.finished)
        motion.elapsed = 1000
        #expect(motion.phase == 17 && motion.finished)
    }
    @Test func allDirectionalBodiesAndEquipmentHavePinnedCollapseFrames() throws {
        #expect(DefeatAnimationSet.hashes.count == 6)
        for character in DefeatAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try DefeatAnimationSet.validate(sprite, character: character)
            for facing in ActorFacing.allCases {
                let frames = try (0..<DefeatAnimationSet.frames).map { phase in
                    try #require(sprite.frame(atlas: character + ".atlas", name: DefeatAnimationSet.name(facing: facing, phase: phase)))
                }
                if character == DefeatAnimationSet.body {
                    #expect(Set(frames.map { Data($0.indices) }).count >= 12)
                    #expect(frames.first!.indices != frames.last!.indices)
                    // The final body lies lower than the standing pose, rather than vanishing.
                    #expect(!frames.last!.isEmpty)
                    #expect(frames.last!.trimOriginTopLeft.height > frames.first!.trimOriginTopLeft.height + 15)
                }
            }
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character))
    }
}

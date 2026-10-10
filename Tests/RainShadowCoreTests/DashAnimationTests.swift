import Foundation
import Testing
@testable import RainShadowCore

struct DashAnimationTests {
    @Test func registeredDashLayersAnimateAndRecoverInEveryFacing() throws {
        for character in DashAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try DashAnimationSet.validate(sprite, character: character)
            for facing in ActorFacing.allCases {
                let frames = try (0..<DashAnimationSet.frames).map {
                    sprite.frame(atlas: character + ".atlas", name: try DashAnimationSet.name(facing: facing, phase: $0))!
                }
                #expect(frames.first!.indices == frames.last!.indices)
                if character == DashAnimationSet.body { #expect(Set(frames.map { Data($0.indices) }).count >= 9) }
            }
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character))
        #expect(throws: CharacterAppearanceError.self) {
            try CharacterBodyCode.bearGuardian.frameCount(for: .dash, facing: .south)
        }
    }
    @Test func dashClockIsBoundedAndBurstLeavesTimeForRecovery() {
        #expect(DashAnimationSet.phase(elapsed: -1) == 0)
        #expect(DashAnimationSet.phase(elapsed: DashAnimationSet.duration) == DashAnimationSet.frames - 1)
        #expect(DashAnimationSet.phase(elapsed: DashAnimationSet.impactTime) == 5)
        #expect(DashAnimationSet.impactTime + 0.44 < DashAnimationSet.duration)
    }
}

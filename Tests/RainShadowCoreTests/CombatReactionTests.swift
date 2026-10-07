import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct CombatReactionTests {
    @Test func dodgePeaksAtImpactAndHeavyHitsRecoverMoreSlowly() {
        var dodge = CombatRecoil(from: .zero, to: .init(x: 50, y: 0), heavy: false, kind: .dodge)
        dodge.elapsed = CombatRecoil.dodgeLeadTime
        #expect(dodge.phase == 3 && dodge.angle == 0)
        var normal = CombatRecoil(from: .zero, to: .init(x: 50, y: 0), heavy: false)
        var heavy = CombatRecoil(from: .zero, to: .init(x: 50, y: 0), heavy: true)
        normal.elapsed = 0.4; heavy.elapsed = 0.4
        #expect(normal.finished && !heavy.finished)
        heavy.elapsed = heavy.duration
        #expect(heavy.finished && heavy.phase == 7 && abs(heavy.angle) < 0.000001)
        dodge.elapsed = 5
        #expect(dodge.finished && dodge.phase == 9)
    }
    @Test func everyReactionHasRegisteredEquipmentAndRestEndpoints() throws {
        for character in CombatReactionAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try CombatReactionAnimationSet.validate(sprite, character: character)
            for kind in CombatReactionKind.allCases { for facing in ActorFacing.allCases {
                let frames = try (0..<kind.frames).map { phase in
                    try #require(sprite.frame(atlas: character + ".atlas", name: CombatReactionAnimationSet.name(kind, facing: facing, phase: phase)))
                }
                #expect(frames.first!.indices == frames.last!.indices)
                if character == CombatReactionAnimationSet.body { #expect(Set(frames.map { Data($0.indices) }).count >= 6) }
            } }
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try BowAttackAnimationSet.validate(IEIndexedSprite.load(character: BowAttackAnimationSet.character))
    }
}

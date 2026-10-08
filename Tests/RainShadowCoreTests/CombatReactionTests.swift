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
    @Test func tripReactionIsDistinctFromCosmeticFallsAndHoldsBeforeRecovery() {
        #expect(!CombatReactionKind.tripFall.isKnockback)
        #expect(CombatReactionAnimationSet.kinds(for: CombatReactionAnimationSet.tripBody) == [.tripFall])
        #expect(CombatReactionAnimationSet.kinds(for: CombatReactionAnimationSet.knockbackBody) == [.stumble, .fall])
        var trip = CombatRecoil(from: .zero, to: .init(x: 80, y: 0), heavy: true, kind: .tripFall)
        trip.elapsed = ProneMotion.holdTime
        #expect(trip.phase == 12 && !trip.finished && trip.angle == 0)
        trip.elapsed = 0.9
        #expect(trip.phase == 18 && !trip.finished)
        trip.elapsed = 1.2
        #expect(trip.finished && trip.phase == 23)
    }
    @Test func everyReactionHasRegisteredEquipmentAndRestEndpoints() throws {
        #expect(CombatReactionAnimationSet.hashes.keys.filter { $0.hasPrefix(CombatReactionAnimationSet.knockbackBody) }.count == 6)
        #expect(CombatReactionAnimationSet.hashes.keys.filter { $0.hasPrefix(CombatReactionAnimationSet.tripBody) }.count == 5)
        #expect(CombatReactionAnimationSet.tripEquipment(.elvenCourtArrow) == nil)
        for character in CombatReactionAnimationSet.hashes.keys {
            let sprite = try IEIndexedSprite.load(character: character)
            try CombatReactionAnimationSet.validate(sprite, character: character)
            for kind in CombatReactionAnimationSet.kinds(for: character) { for facing in ActorFacing.allCases {
                let frames = try (0..<kind.frames).map { phase in
                    try #require(sprite.frame(atlas: character + ".atlas", name: CombatReactionAnimationSet.name(kind, facing: facing, phase: phase)))
                }
                #expect(frames.first!.indices == frames.last!.indices)
                if character == CombatReactionAnimationSet.body || character == CombatReactionAnimationSet.knockbackBody || character == CombatReactionAnimationSet.tripBody { #expect(Set(frames.map { Data($0.indices) }).count >= 6) }
            } }
        }
        let trip = try IEIndexedSprite.load(character: CombatReactionAnimationSet.tripBody)
        let knockback = try IEIndexedSprite.load(character: CombatReactionAnimationSet.knockbackBody)
        for facing in ActorFacing.allCases {
            let tripFrame = try #require(trip.frame(atlas: CombatReactionAnimationSet.tripBody + ".atlas",
                name: CombatReactionAnimationSet.name(.tripFall, facing: facing, phase: ProneMotion.holdPhase)))
            let oldFrame = try #require(knockback.frame(atlas: CombatReactionAnimationSet.knockbackBody + ".atlas",
                name: CombatReactionAnimationSet.name(.fall, facing: facing, phase: ProneMotion.holdPhase)))
            #expect(tripFrame.indices != oldFrame.indices)
        }
        try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character))
        try BowAttackAnimationSet.validate(IEIndexedSprite.load(character: BowAttackAnimationSet.character))
    }
}

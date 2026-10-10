import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct WeaponTechniqueMotionTests {
    @Test func pinningBracesBelowTheNormalDrawInEveryFacing() throws {
        let normal = try IEIndexedSprite.load(character: BowAttackAnimationSet.character)
        let pinning = try IEIndexedSprite.load(character: WeaponTechniqueAnimationSet.pinning)
        for facing in ActorFacing.allCases {
            func top(_ sprite: IEIndexedSprite, _ name: String) throws -> Int {
                let frame = try #require(sprite.frame(atlas: sprite.character + ".atlas", name: name))
                let first = try #require(frame.indices.firstIndex(where: { $0 > 1 }))
                return frame.trimOriginTopLeft.height + first / frame.nativeSize.width
            }
            let normalName = String(format: "shoot_%@_09.png", VossAnimationSet.direction(facing))
            let pinningName = try WeaponTechniqueAnimationSet.name(.pinningShot, facing: facing, phase: 9)
            // The brace must visibly lower the silhouette, including rear views.
            #expect(try top(pinning, pinningName) - top(normal, normalName) >= 8)
        }
    }
    @Test func retimedMeleeKeepsFastContactAndGivesEachAttackTimeToSettle() {
        for move in [nil, .powerStrike, .feintingCut, .tripAttack] as [CombatManeuver?] {
            let start = WeaponTechniqueMotion.trailStart(move), end = WeaponTechniqueMotion.trailEnd(move)
            let swingStart = WeaponTechniqueMotion.meleeTime(atFrame: start, move: move)
            let swingEnd = WeaponTechniqueMotion.meleeTime(atFrame: end, move: move)
            let sourceFPS = WeaponTechniqueMotion.meleeFPS(move)
            #expect(swingStart > start / sourceFPS)
            #expect(abs(swingEnd - swingStart - (end - start) / sourceFPS) < 0.000001)
            #expect(swingStart < WeaponTechniqueMotion.meleeImpact(move))
            #expect(WeaponTechniqueMotion.meleeImpact(move) < swingEnd)
            #expect(swingEnd + SwordSwingPath.fadeDuration < WeaponTechniqueMotion.meleeDuration(move))
            let oldRecovery = (Double(WeaponTechniqueMotion.meleeFrames(move)) - end) / sourceFPS
            #expect(WeaponTechniqueMotion.meleeDuration(move) - swingEnd > oldRecovery)
        }
        #expect(WeaponTechniqueMotion.meleeDuration(.powerStrike) > WeaponTechniqueMotion.meleeDuration(nil))
        #expect(WeaponTechniqueMotion.meleeWindup(.powerStrike) > WeaponTechniqueMotion.meleeWindup(nil))
        #expect(WeaponTechniqueMotion.meleeDuration(.feintingCut) < WeaponTechniqueMotion.meleeDuration(nil))
    }
    @Test func retimedMarkersAndPoseClockStayAlignedForEveryAuthoredFrame() {
        for move in [nil, .powerStrike, .feintingCut, .tripAttack] as [CombatManeuver?] {
            let count = WeaponTechniqueMotion.meleeFrames(move)
            var previous = -1.0
            for frame in 0...count {
                let time = WeaponTechniqueMotion.meleeTime(atFrame: Double(frame), move: move)
                #expect(time > previous)
                #expect(abs(WeaponTechniqueMotion.meleeFrame(elapsed: time, move: move) - Double(frame)) < 0.000001)
                #expect(WeaponTechniqueMotion.meleePhase(elapsed: time, move: move) == min(count - 1, frame))
                if frame > 0 { #expect(WeaponTechniqueMotion.meleePhase(elapsed: time - 0.00001, move: move) == frame - 1) }
                previous = time
            }
            let marker = WeaponTechniqueMotion.meleeImpact(move)
            #expect(WeaponTechniqueMotion.meleePhase(elapsed: marker, move: move) == (move == nil ? 6 : 8))
            #expect(WeaponTechniqueMotion.meleePhase(elapsed: -1, move: move) == 0)
            #expect(WeaponTechniqueMotion.meleePhase(elapsed: 100, move: move) == count - 1)
        }
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

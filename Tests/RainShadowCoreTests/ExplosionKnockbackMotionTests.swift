import Testing
import Foundation
import CoreGraphics
@testable import RainShadowCore

struct ExplosionKnockbackMotionTests {
    @Test func impulseDeceleratesAndStopsExactlyWithoutOvershoot() {
        let start = CGPoint.zero, end = CGPoint(x: 80, y: 0)
        #expect(ExplosionKnockbackMotion.stoppingTime == 0.5)
        #expect(ExplosionKnockbackMotion.position(from: start, to: end, elapsed: 0) == start)
        #expect(ExplosionKnockbackMotion.position(from: start, to: end, elapsed: 0.25) == CGPoint(x: 60, y: 0))
        var previous = 0.0, largestStep = 100.0
        for frame in 1...10 {
            let point = ExplosionKnockbackMotion.position(from: start, to: end, elapsed: Double(frame) * 0.05)
            let step = point.x - previous
            #expect(step >= 0 && step <= largestStep + 1)
            #expect(point.x <= 80)
            previous = point.x; largestStep = step
        }
        #expect(previous == 80)
        #expect(ExplosionKnockbackMotion.position(from: start, to: end, elapsed: 20) == end)
    }
    @Test func wallContactStopsEarlierWithoutSofteningTheInitialImpulse() {
        let wall = CGPoint(x: 18, y: 0), free = CGPoint(x: 80, y: 0)
        let contact = ExplosionKnockbackMotion.stopTime(from: .zero, to: wall)
        #expect(contact < 0.1)
        #expect(ExplosionKnockbackMotion.position(from: .zero, to: wall, elapsed: 0.025)
            == ExplosionKnockbackMotion.position(from: .zero, to: free, elapsed: 0.025))
        #expect(ExplosionKnockbackMotion.position(from: .zero, to: wall, elapsed: contact) == wall)
        #expect(ExplosionKnockbackMotion.position(from: wall, to: wall, elapsed: 2) == wall)
        #expect(ExplosionKnockbackMotion.stopTime(from: wall, to: wall) == 0)
    }
    @Test func projectionAndFrameRateDoNotChangeTheAcceptedEndpoint() {
        let from = CGPoint(x: 73, y: 25), to = CGPoint(x: 73, y: -35)
        #expect(ExplosionKnockbackMotion.stopTime(from: from, to: to) == 0.5)
        #expect(ExplosionKnockbackMotion.position(from: from, to: to, elapsed: 0.25) == CGPoint(x: 73, y: -20))
        for hz in [30.0, 60, 120] {
            let samples = (0...Int(hz)).map { ExplosionKnockbackMotion.position(from: from, to: to, elapsed: Double($0) / hz) }
            #expect(samples.last == to)
            #expect(samples.allSatisfy { $0.x == from.x && $0.y >= to.y && $0.y <= from.y })
        }
    }
    @Test func recoveryTurnsBackThroughTheShortestFacingArc() {
        for from in ActorFacing.allCases { for to in ActorFacing.allCases {
            #expect(ExplosionKnockbackMotion.recoveryFacing(from: from, to: to, phase: 9, frames: 16) == from)
            #expect(ExplosionKnockbackMotion.recoveryFacing(from: from, to: to, phase: 15, frames: 16) == to)
        } }
        #expect(ExplosionKnockbackMotion.recoveryFacing(from: ActorFacing(rawValue: 15)!, to: ActorFacing(rawValue: 1)!, phase: 12, frames: 16).rawValue == 0)
    }
    @Test func blastStrengthSelectsARecoveryWithTimeToSettle() {
        #expect(ExplosionKnockbackMotion.reaction(distanceFromBlast: 100, blasts: 1, travel: 80) == .stumble)
        #expect(ExplosionKnockbackMotion.reaction(distanceFromBlast: 70, blasts: 1, travel: 80) == .fall)
        #expect(ExplosionKnockbackMotion.reaction(distanceFromBlast: 100, blasts: 2, travel: 80) == .fall)
        #expect(ExplosionKnockbackMotion.reaction(distanceFromBlast: 30, blasts: 2, travel: 0) == .hit)
        for kind in [CombatReactionKind.stumble, .fall] {
            var motion = CombatRecoil(from: .zero, to: .init(x: 80, y: 0), heavy: true, kind: kind)
            motion.elapsed = ExplosionKnockbackMotion.stoppingTime
            #expect(!motion.finished && motion.angle == 0)
            motion.elapsed = motion.duration
            #expect(motion.finished && motion.phase == kind.frames - 1)
        }
    }
}

import CoreGraphics
import Testing
@testable import RainShadowCore

/// `Movable.ticksToReach` predicts how many logic ticks a leg will take. The
/// seat-egress animation is timed from it, so a wrong answer is not a rounding
/// nuisance — it sets how long Voss's body takes to travel from the chair back
/// to the point he actually occupies.
@Suite struct MovableTicksToReachTests {
    private static let scale = MovableTestSupport.humanoidWalkScale

    /// The regression. `NormalizeDeltas` rounds each step up to a whole unit, so
    /// a cursor that starts on a fraction can never satisfy the exact arrival
    /// test — it used to spin to the 4_096 iteration cap and report that as the
    /// tick count, which timed the egress at 273 seconds instead of ~2.
    @Test func aFractionalStartStillConvergesInsteadOfHittingTheIterationCap() {
        let map = MovableTestSupport.openMap()
        var movable = MovableTestSupport.movable(on: map, at: CGPoint(x: 300, y: 200))
        // `init` snaps, but `advanceWalkTick` assigns `movable.position` straight
        // from the SpriteKit node every tick, and that carries a remainder. This
        // is the value the office actually reported when the egress misfired.
        movable.position = CGPoint(x: 300.409912109375, y: 200.2862548828125)
        let ticks = movable.ticksToReach(CGPoint(x: 188, y: 140), walkScale: Self.scale)
        #expect(ticks > 0)
        #expect(ticks < 4_096)
    }

    /// An integral start was already fine; the snap must not change its answer.
    @Test func snappingDoesNotDisturbAStartThatWasAlreadyIntegral() {
        let map = MovableTestSupport.openMap()
        let whole = MovableTestSupport.movable(on: map, at: CGPoint(x: 300, y: 200))
        var fractional = MovableTestSupport.movable(on: map, at: CGPoint(x: 300, y: 200))
        fractional.position = CGPoint(x: 300.4, y: 200.29)
        let goal = CGPoint(x: 188, y: 140)
        #expect(
            whole.ticksToReach(goal, walkScale: Self.scale)
                == fractional.ticksToReach(goal, walkScale: Self.scale)
        )
    }

    /// The count is a duration, so it has to track distance rather than being
    /// any finite number: a leg twice as long takes more ticks, and a leg of no
    /// length takes none.
    @Test func theCountGrowsWithTheLengthOfTheLeg() {
        let map = MovableTestSupport.openMap()
        let movable = MovableTestSupport.movable(on: map, at: CGPoint(x: 100, y: 100))
        let near = movable.ticksToReach(CGPoint(x: 148, y: 100), walkScale: Self.scale)
        let far = movable.ticksToReach(CGPoint(x: 400, y: 100), walkScale: Self.scale)
        #expect(near > 0)
        #expect(far > near)
        #expect(movable.ticksToReach(CGPoint(x: 100, y: 100), walkScale: Self.scale) == 0)
    }

    /// `doStep` is the thing being predicted, so the prediction should agree
    /// with actually walking the leg.
    @Test func thePredictionMatchesWhatDoStepTakesToWalkTheSameLeg() {
        let map = MovableTestSupport.openMap()
        var movable = MovableTestSupport.movable(on: map, at: CGPoint(x: 100, y: 100))
        let goal = CGPoint(x: 292, y: 196)
        let predicted = movable.ticksToReach(goal, walkScale: Self.scale)

        movable.walkTo(goal, ticks: 0)
        var actual = 0
        var time = 1
        while movable.isMoving && actual < 4_096 {
            if movable.doStep(walkScale: Self.scale, time: time).moved { actual += 1 }
            time += 1
        }
        #expect(actual > 0)
        // The path may route around cells, so allow a little slack — the point
        // is that the two are the same order of magnitude, not that a straight
        // line and a searched path step identically.
        #expect(abs(predicted - actual) <= max(4, actual / 4))
    }

    /// `doStep` refuses to move without a walk scale, so a prediction of zero is
    /// the honest answer rather than an infinite loop.
    @Test func aStoppedActorNeedsNoTicks() {
        let map = MovableTestSupport.openMap()
        let movable = MovableTestSupport.movable(on: map, at: CGPoint(x: 100, y: 100))
        #expect(movable.ticksToReach(CGPoint(x: 400, y: 400), walkScale: 0) == 0)
    }
}

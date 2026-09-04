import CoreGraphics
import Testing
@testable import RainShadowCore

/// How a walk *ends*.
///
/// `doStep` reports arrival with an exact `position == step.point`, which is
/// only reachable because every position in the system is integral:
/// `NormalizeDeltas` ceils each axis, `findPath` snaps its source, and
/// `Path.init(points:from:)` rounds every node. The actor nodes are the one
/// place that invariant leaves the package — they hand `Movable` a SpriteKit
/// node position every tick — and when they handed it in raw, Voss's walks
/// never reported arrival and he held his last walk frame instead of returning
/// to idle.
@Suite struct MovableArrivalTests {
    private static let scale = MovableTestSupport.humanoidWalkScale

    /// The actor-node loop: the movable's position is re-read from the node
    /// before every step and written back after it, exactly as
    /// `DetectiveActorNode.advanceWalkTick` does.
    private static func walkFeedingPositionBack(
        from start: CGPoint,
        to goal: CGPoint,
        snapped: Bool,
        ticks: Int = 400
    ) -> (arrived: Bool, spent: Int) {
        let map = MovableTestSupport.openMap()
        var movable = MovableTestSupport.movable(on: map, at: start)
        var node = start
        movable.position = snapped ? node.rounded : node
        movable.walkTo(goal, ticks: 0)

        for tick in 1...ticks {
            movable.position = snapped ? node.rounded : node
            let outcome = movable.doStep(walkScale: scale, time: tick)
            node = movable.position
            if outcome.arrived { return (true, tick) }
            if outcome.abandoned { return (false, tick) }
        }
        return (false, ticks)
    }

    /// The regression, stated as the invariant it broke. The office's authored
    /// entrance is (2175.4100329414914, 1079.2861942938816); a fraction that
    /// whole-unit steps can never cancel keeps `position == step.point` out of
    /// reach for the whole route, so `currentStep` never advances and no tick
    /// ever reports `arrived`.
    @Test func aFractionalPositionFedBackEachTickNeverReportsArrival() {
        let result = Self.walkFeedingPositionBack(
            from: CGPoint(x: 100.4100329414914, y: 100.2861942938816),
            to: CGPoint(x: 292, y: 196),
            snapped: false
        )
        #expect(!result.arrived)
    }

    /// Snapping at the boundary — what `DetectiveActorNode.syncMovablePosition`
    /// and `ClientActorNode.syncMovablePosition` now do — restores it.
    @Test func snappingAtTheBoundaryLetsTheSameWalkArrive() {
        let result = Self.walkFeedingPositionBack(
            from: CGPoint(x: 100.4100329414914, y: 100.2861942938816),
            to: CGPoint(x: 292, y: 196),
            snapped: true
        )
        #expect(result.arrived)
        #expect(result.spent > 0)
    }

    /// The snap must not change a walk that was already integral.
    @Test func snappingDoesNotDisturbAWalkThatWasAlreadyIntegral() {
        let raw = Self.walkFeedingPositionBack(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 292, y: 196),
            snapped: false
        )
        let snapped = Self.walkFeedingPositionBack(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 292, y: 196),
            snapped: true
        )
        #expect(raw.arrived)
        #expect(snapped.arrived)
        #expect(raw.spent == snapped.spent)
    }

    /// Arrival is what clears the route. A walk that cannot report it leaves the
    /// movable in `.moving` with a live path forever, which is the state the
    /// actor node was reading as "still walking".
    @Test func aWalkThatCannotArriveIsStillMovingWhenTheBudgetRunsOut() {
        let map = MovableTestSupport.openMap()
        var movable = MovableTestSupport.movable(on: map, at: CGPoint(x: 100, y: 100))
        var node = CGPoint(x: 100.41, y: 100.29)
        movable.position = node
        movable.walkTo(CGPoint(x: 292, y: 196), ticks: 0)

        for tick in 1...400 {
            movable.position = node
            movable.doStep(walkScale: Self.scale, time: tick)
            node = movable.position
        }
        #expect(movable.isMoving)
        #expect(movable.hasPath)
    }
}

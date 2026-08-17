import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// First tests for the waypoint queue.
///
/// This logic shipped twice — once in each playable scene — and neither copy was
/// reachable from the SwiftPM target, so none of it was ever asserted. Every
/// behaviour below was previously guaranteed only by two hand-maintained copies
/// of the same 150 lines agreeing with each other.
struct MovementOrderQueueTests {

    /// A 320x240 room, open except for a wall down the middle with a gap.
    static func room(
        wall: Bool = false,
        agent: NavigationAgentProfile = .point
    ) -> NavigationMap {
        var obstacles: [CGRect] = []
        if wall {
            // Full-height wall at x 150...170 except a doorway at y 100...140.
            obstacles.append(CGRect(x: 150, y: 0, width: 20, height: 100))
            obstacles.append(CGRect(x: 150, y: 140, width: 20, height: 100))
        }
        return NavigationMap(
            worldBounds: CGRect(x: 0, y: 0, width: 320, height: 240),
            obstacles: obstacles,
            agentProfile: agent
        )
    }

    static func queue(_ map: NavigationMap) -> MovementOrderQueue {
        MovementOrderQueue(navigation: map, actorID: "test.actor")
    }

    // MARK: - Orders

    @Test func anOrderAcrossOpenFloorWalksAndBecomesTheOnlyGoal() {
        let queue = Self.queue(Self.room())
        let outcome = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 280, y: 200))
        guard case .walk(let path) = outcome else {
            Issue.record("expected a walk, got \(outcome)")
            return
        }
        #expect(!path.isEmpty)
        #expect(queue.goals.count == 1)
        #expect(queue.currentGoal == CGPoint(x: 280, y: 200))
    }

    /// `Movable::WalkTo`: clicking the cell you already stand in is a head turn.
    @Test func aClickInsideTheOccupiedCellTurnsInPlaceRatherThanWalking() {
        let map = Self.room()
        let queue = Self.queue(map)
        let position = CGPoint(x: 100, y: 100)
        // Same 16x12 search cell, a couple of units away.
        let nearby = CGPoint(x: 104, y: 103)
        #expect(map.searchMap.cell(for: position) == map.searchMap.cell(for: nearby))
        #expect(queue.order(actorAt: position, to: nearby) == .turnInPlace)
        #expect(queue.isEmpty)
    }

    /// The same click *with* an exact destination is an approach, not a turn —
    /// interactions are issued that way and must still walk the last few units.
    @Test func anExactOrderInsideTheOccupiedCellStillWalks() {
        let queue = Self.queue(Self.room())
        let outcome = queue.order(
            actorAt: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 104, y: 103),
            requiresExactDestination: true
        )
        if case .turnInPlace = outcome {
            Issue.record("an exact order degraded into a head turn")
        }
    }

    /// `IE_CURSOR_BLOCKED`: refused, not snapped. This is the property three
    /// shipped bugs in `AGENTS.md` came from losing.
    @Test func anOrderOntoSolidGroundIsRefusedRatherThanSnapped() {
        let queue = Self.queue(Self.room(wall: true))
        #expect(queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 160, y: 40)) == .refused)
        #expect(queue.isEmpty, "a refused order left goals behind")
    }

    @Test func aRefusedOrderDiscardsTheQueueItReplaced() {
        let queue = Self.queue(Self.room(wall: true))
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 100, y: 200))
        #expect(queue.goals.count == 1)
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 160, y: 40))
        #expect(queue.isEmpty)
    }

    // MARK: - Queued waypoints

    @Test func aQueuedWaypointAppendsBehindTheExistingGoal() {
        let queue = Self.queue(Self.room())
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 150, y: 60))
        let outcome = queue.order(
            actorAt: CGPoint(x: 20, y: 20),
            to: CGPoint(x: 280, y: 200),
            queueWaypoint: true
        )
        guard case .append = outcome else {
            Issue.record("expected an append, got \(outcome)")
            return
        }
        #expect(queue.goals.count == 2)
    }

    /// `AddWayPoint` returns without appending when the point is too close to
    /// plan for. Appending anyway leaves a goal no waypoints will consume and a
    /// reticle nothing retires.
    @Test func aQueuedWaypointOnTopOfTheLastGoalIsDroppedSilently() {
        let queue = Self.queue(Self.room())
        let goal = CGPoint(x: 150, y: 60)
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: goal)
        let outcome = queue.order(actorAt: CGPoint(x: 20, y: 20), to: goal, queueWaypoint: true)
        #expect(outcome == .ignored)
        #expect(queue.goals.count == 1, "an empty append still grew the queue")
    }

    /// Queueing is a convenience on top of a plain order; an exact order never
    /// queues, because an interaction replaces whatever was in flight.
    @Test func anExactOrderNeverQueues() {
        let queue = Self.queue(Self.room())
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 150, y: 60))
        let outcome = queue.order(
            actorAt: CGPoint(x: 20, y: 20),
            to: CGPoint(x: 280, y: 200),
            requiresExactDestination: true,
            queueWaypoint: true
        )
        guard case .walk = outcome else {
            Issue.record("an exact order queued instead of replacing, got \(outcome)")
            return
        }
        #expect(queue.goals.count == 1)
    }

    @Test func queueingWithNothingInFlightIsAPlainOrder() {
        let queue = Self.queue(Self.room())
        let outcome = queue.order(
            actorAt: CGPoint(x: 20, y: 20),
            to: CGPoint(x: 280, y: 200),
            queueWaypoint: true
        )
        guard case .walk = outcome else {
            Issue.record("expected a walk, got \(outcome)")
            return
        }
    }

    // MARK: - Pruning

    @Test func reachedGoalsArePrunedButTheLastOneSurvives() {
        let queue = Self.queue(Self.room())
        let first = CGPoint(x: 100, y: 60)
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: first)
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 280, y: 200), queueWaypoint: true)
        #expect(queue.goals.count == 2)

        let removed = queue.pruneReachedGoals(actorAt: first)
        #expect(removed.count == 1)
        #expect(queue.goals.count == 1)

        // Standing on the final goal must not prune it — locomotion's own
        // completion clears the queue, and dropping it here retires the
        // destination reticle a frame early.
        _ = queue.pruneReachedGoals(actorAt: CGPoint(x: 280, y: 200))
        #expect(queue.goals.count == 1)
    }

    @Test func aGoalJustOutsideArrivalSlopIsNotPruned() {
        let queue = Self.queue(Self.room())
        let first = CGPoint(x: 100, y: 60)
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: first)
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 280, y: 200), queueWaypoint: true)
        let justOutside = CGPoint(x: first.x + MovementOrderQueue.arrivalSlop + 1, y: first.y)
        #expect(queue.pruneReachedGoals(actorAt: justOutside).isEmpty)
        #expect(queue.goals.count == 2)
    }

    // MARK: - Corrective repath

    @Test func repathIsRateLimitedAndDoesNothingWhileStanding() {
        let queue = Self.queue(Self.room())
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 280, y: 200))

        #expect(
            queue.correctiveRepath(
                actorAt: CGPoint(x: 20, y: 20),
                remainingRoute: [CGPoint(x: 280, y: 200)],
                isMoving: false,
                at: 100
            ) == .keepWalking,
            "a standing actor was replanned"
        )
        // Moving, but the interval has not elapsed since the first call armed it.
        _ = queue.correctiveRepath(
            actorAt: CGPoint(x: 20, y: 20),
            remainingRoute: [CGPoint(x: 280, y: 200)],
            isMoving: true,
            at: 100
        )
        #expect(
            queue.correctiveRepath(
                actorAt: CGPoint(x: 21, y: 21),
                remainingRoute: [CGPoint(x: 280, y: 200)],
                isMoving: true,
                at: 100 + MovementOrderQueue.correctiveRepathInterval / 2
            ) == .keepWalking
        )
    }

    /// A route that is already near-optimal is left alone, so a replacement one
    /// unit shorter does not show as a mid-walk kink.
    @Test func aRouteThatIsAlreadyGoodIsNotReplaced() {
        let queue = Self.queue(Self.room())
        let start = CGPoint(x: 20, y: 20)
        let goal = CGPoint(x: 280, y: 200)
        guard case .walk(let path) = queue.order(actorAt: start, to: goal) else {
            Issue.record("expected a walk")
            return
        }
        let outcome = queue.correctiveRepath(
            actorAt: start,
            remainingRoute: path,
            isMoving: true,
            at: 1_000
        )
        #expect(outcome == .keepWalking)
    }

    /// The leg scan stops at the first point within arrival slop of the leg's
    /// destination, so a queued second leg is not measured as part of the first.
    @Test func theCurrentLegStopsAtItsOwnDestination() {
        let route = [
            CGPoint(x: 10, y: 0),
            CGPoint(x: 50, y: 0),
            CGPoint(x: 100, y: 0),   // the leg's destination
            CGPoint(x: 200, y: 0)    // belongs to the next leg
        ]
        let leg = MovementOrderQueue.leg(of: route, endingNear: CGPoint(x: 100, y: 0))
        #expect(leg.count == 3)
        #expect(leg.last == CGPoint(x: 100, y: 0))
    }

    /// Length is measured in the metric the actor walks, not raw screen
    /// distance. Ground is foreshortened 0.75 vertically, so a hundred screen
    /// pixels *up* the screen is 133 units of ground crossed while a hundred
    /// across is 100 — `projectedDistance` divides y by the scale to undo it.
    /// Comparing raw screen distance instead would make a route into the screen
    /// look a third cheaper than it is, and the repath would keep preferring it.
    @Test func routeLengthUsesTheProjectedMetricRatherThanScreenDistance() {
        let across = MovementOrderQueue.polylineLength([CGPoint(x: 100, y: 0)], from: .zero)
        let intoTheScreen = MovementOrderQueue.polylineLength([CGPoint(x: 0, y: 100)], from: .zero)
        #expect(across == 100)
        #expect(intoTheScreen > across, "depth travel was not un-foreshortened")
        #expect(
            abs(intoTheScreen / across - 1 / ActorLocomotionPacing.verticalProjectionScale) < 0.001
        )
    }

    @Test func finishClearsTheQueue() {
        let queue = Self.queue(Self.room())
        _ = queue.order(actorAt: CGPoint(x: 20, y: 20), to: CGPoint(x: 280, y: 200))
        #expect(!queue.isEmpty)
        queue.finish()
        #expect(queue.isEmpty)
        #expect(queue.currentGoal == nil)
    }
}

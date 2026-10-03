import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Click policy over `Movable`.
///
/// The queue no longer holds a list of goals — the engine keeps ordered
/// waypoints inside the `Path` itself (`AddWayPoint` marks the node it extends
/// from), so these assert against `Movable.pendingWaypoints` and the movement
/// state rather than against a parallel array.
struct MovementOrderQueueTests {

    /// A 320×240 room, open except for a wall down the middle with a gap.
    static func room(wall: Bool = false, circleSize: Int = 1) -> NavigationMap {
        var obstacles: [CGRect] = []
        if wall {
            // Full-height wall at x 150...170 except a doorway at y 100...140.
            obstacles.append(CGRect(x: 150, y: 0, width: 20, height: 100))
            obstacles.append(CGRect(x: 150, y: 140, width: 20, height: 100))
        }
        return NavigationMap(
            worldBounds: CGRect(x: 0, y: 0, width: 320, height: 240),
            obstacles: obstacles,
            agentProfile: NavigationAgentProfile(
                halfWidth: 0,
                halfHeight: 0,
                circleSize: circleSize
            )
        )
    }

    static func queue(_ map: NavigationMap) -> MovementOrderQueue {
        MovementOrderQueue(navigation: map, actorID: "test.actor")
    }

    static func walker(_ map: NavigationMap, at position: CGPoint) -> Movable {
        MovableTestSupport.movable(on: map, at: position, id: "test.actor")
    }

    // MARK: - Orders

    @Test func interactionDistanceMatchesGemRBOperatingRange() {
        #expect(MovementOrderQueue.defaultInteractionDistance == 40)
    }

    @Test func anOrderAcrossOpenFloorWalks() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(queue.order(&walker, to: CGPoint(x: 280, y: 200), ticks: 1) == .walk)
        #expect(walker.isMoving)
        #expect(!walker.remainingPoints.isEmpty)
        #expect(walker.destination == CGPoint(x: 280, y: 200))
    }

    /// `Movable::WalkTo`: clicking the cell you already stand in is a head turn.
    @Test func aClickInsideTheOccupiedCellTurnsInPlaceRatherThanWalking() {
        let map = Self.room()
        let queue = Self.queue(map)
        let position = CGPoint(x: 100, y: 100)
        // Same 16×12 search cell, a couple of units away.
        let nearby = CGPoint(x: 104, y: 103)
        #expect(map.searchMap.cell(for: position) == map.searchMap.cell(for: nearby))

        var walker = Self.walker(map, at: position)
        #expect(queue.order(&walker, to: nearby, ticks: 1) == .turnInPlace)
        #expect(!walker.isMoving)
        #expect(!walker.hasPath)
    }

    /// `IE_CURSOR_BLOCKED`: refused, not snapped.
    ///
    /// `FindPath` relocates a blocked goal on its own now, which is right for a
    /// scripted move but wrong for a click — a tap on a wall would silently walk
    /// somewhere the player did not point at. `GameControl::OnMouseUp` returns
    /// early on the blocked cursor, so the refusal stays at the click layer.
    /// This is the property three shipped bugs in `AGENTS.md` came from losing.
    @Test func anOrderOntoSolidGroundIsRefusedRatherThanSnapped() {
        let map = Self.room(wall: true)
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(queue.order(&walker, to: CGPoint(x: 160, y: 40), ticks: 1) == .refused)
        #expect(!walker.isMoving)
    }

    @Test func aRefusedOrderDiscardsTheRouteItReplaced() {
        let map = Self.room(wall: true)
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(queue.order(&walker, to: CGPoint(x: 60, y: 200), ticks: 1) == .walk)
        #expect(walker.isMoving)
        #expect(queue.order(&walker, to: CGPoint(x: 160, y: 40), ticks: 4) == .refused)
        #expect(!walker.isMoving)
        #expect(walker.pendingWaypoints.isEmpty)
    }

    // MARK: - Waypoints

    /// `AddWayPoint` extends the path from its **last node**, not from the
    /// actor, and marks that node so reticles survive the leg being walked.
    @Test func aQueuedWaypointAppendsBehindTheExistingRoute() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(queue.order(&walker, to: CGPoint(x: 200, y: 20), ticks: 1) == .walk)
        let firstLeg = walker.remainingPoints.count

        #expect(
            queue.order(
                &walker,
                to: CGPoint(x: 200, y: 200),
                queueWaypoint: true,
                ticks: 4
            ) == .append
        )
        #expect(walker.remainingPoints.count > firstLeg)
        #expect(walker.destination == CGPoint(x: 200, y: 200))
        // The junction between the legs is now a marked waypoint.
        #expect(walker.pendingWaypoints.count == 1)
    }

    /// "If the waypoint is too close to the current position, no path is
    /// generated." Appending anyway leaves a goal no node will ever retire.
    @Test func aQueuedWaypointOnTopOfTheLastGoalIsDroppedSilently() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(queue.order(&walker, to: CGPoint(x: 200, y: 20), ticks: 1) == .walk)
        let before = walker.remainingPoints.count
        // The last *node*, not the requested point: `AddWayPoint` searches from
        // there, and `FindPath`'s "too close to plan for" guard is
        // `nmptDest == nmptSource` against it.
        let goal = try! #require(walker.remainingPoints.last)

        #expect(
            queue.order(&walker, to: goal, queueWaypoint: true, ticks: 4) == .ignored
        )
        #expect(walker.remainingPoints.count == before)
        #expect(walker.isMoving)
    }

    /// Queueing is a convenience on top of a plain floor order; a proximity
    /// action never queues, because an interaction replaces whatever was in flight.
    @Test func aProximityOrderNeverQueues() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(queue.order(&walker, to: CGPoint(x: 200, y: 20), ticks: 1) == .walk)
        #expect(
            queue.order(
                &walker,
                to: CGPoint(x: 60, y: 200),
                minDistance: MovementOrderQueue.defaultInteractionDistance,
                queueWaypoint: true,
                ticks: 4
            ) == .walk
        )
        #expect(walker.destination == CGPoint(x: 60, y: 200))
        #expect(walker.pendingWaypoints.isEmpty)
    }

    @Test func aProximityOrderAlreadyInRangeDoesNotWalk() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(
            queue.order(
                &walker,
                to: CGPoint(x: 55, y: 20),
                minDistance: MovementOrderQueue.defaultInteractionDistance,
                ticks: 1
            ) == .alreadyInRange
        )
        #expect(!walker.isMoving)
    }

    /// An interaction may name the actor, door or object itself. Unlike a floor
    /// click, that target need not be passable; `MinDistance` stops on its near side.
    @Test func aProximityOrderMayApproachBlockedGeometry() {
        let map = Self.room(wall: true)
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 40))
        let target = CGPoint(x: 160, y: 40)

        #expect(
            queue.order(
                &walker,
                to: target,
                minDistance: 24,
                ticks: 1
            ) == .walk
        )
        #expect(!map.isOrderableFloor(target))
        #expect(walker.isMoving)
        #expect(walker.destination == target)

        var arrived = false
        for tick in 2..<4_096 {
            let step = walker.doStep(
                walkScale: MovableTestSupport.humanoidWalkScale,
                time: tick
            )
            if step.arrived {
                arrived = true
                break
            }
        }
        #expect(arrived)
        #expect(hypot(walker.position.x - target.x, walker.position.y - target.y) <= 24)
    }

    /// `if (!path) { WalkTo(Des); return; }` — an append with nothing to append
    /// to is a plain move.
    @Test func queueingWithNothingInFlightIsAPlainOrder() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        #expect(
            queue.order(
                &walker,
                to: CGPoint(x: 200, y: 200),
                queueWaypoint: true,
                ticks: 1
            ) == .walk
        )
        #expect(walker.pendingWaypoints.isEmpty)
    }

    /// A plain click wipes the route, as `actor->Stop()` clears the whole path.
    @Test func aPlainOrderReplacesAQueuedRoute() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        queue.order(&walker, to: CGPoint(x: 200, y: 20), ticks: 1)
        queue.order(&walker, to: CGPoint(x: 200, y: 200), queueWaypoint: true, ticks: 4)
        #expect(walker.pendingWaypoints.count == 1)

        #expect(queue.order(&walker, to: CGPoint(x: 40, y: 200), ticks: 7) == .walk)
        #expect(walker.pendingWaypoints.isEmpty)
        #expect(walker.destination == CGPoint(x: 40, y: 200))
    }

    // MARK: - Corrective repathing

    @Test func repathIsRateLimitedAndDoesNothingWhileStanding() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        // Standing still: nothing to replan.
        #expect(queue.correctiveRepath(&walker, at: 10, ticks: 1) == .keepWalking)

        queue.order(&walker, to: CGPoint(x: 280, y: 200), ticks: 1)
        // Due (the clock starts at zero), so the first call replans.
        #expect(queue.correctiveRepath(&walker, at: 10, ticks: 20) == .replanned)
        // Immediately after, it is not due again.
        #expect(queue.correctiveRepath(&walker, at: 10.1, ticks: 40) == .keepWalking)
    }

    /// `Actor::NewPath` rebuilds to `Destination`, which destroys intermediate
    /// waypoints. That is the engine's behaviour, waypoints and all — it is
    /// listed here so a future reader knows it was ported, not overlooked.
    @Test func repathRebuildsToDestinationAndDropsQueuedWaypoints() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        queue.order(&walker, to: CGPoint(x: 200, y: 20), ticks: 1)
        queue.order(&walker, to: CGPoint(x: 200, y: 200), queueWaypoint: true, ticks: 4)
        #expect(walker.pendingWaypoints.count == 1)

        #expect(queue.correctiveRepath(&walker, at: 10, ticks: 40) == .replanned)
        #expect(walker.pendingWaypoints.isEmpty)
        #expect(walker.destination == CGPoint(x: 200, y: 200))
    }

    /// The last cell of a walk is not replanned.
    ///
    /// `Movable::WalkTo` answers a destination inside the cell the actor already
    /// occupies with `ClearPath` and a head turn. That is right for a fresh
    /// order and wrong for a replan: it threw away the live route a walker was a
    /// few units from finishing and dropped it to `noMovement`, while still
    /// reporting `keepWalking` — so the caller kept a walk that could never
    /// report arrival, which is how Voss came to hold his last walk frame.
    @Test func repathLeavesTheRouteAloneOnceTheWalkerIsInTheDestinationCell() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))
        let destination = CGPoint(x: 280, y: 200)
        queue.order(&walker, to: destination, ticks: 1)

        // Walk until the destination's cell is the one the walker is standing in.
        let searchMap = map.searchMap
        var tick = 2
        while searchMap.cell(for: walker.position) != searchMap.cell(for: destination),
              tick < 4_096 {
            walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
            tick += 1
        }
        #expect(searchMap.cell(for: walker.position) == searchMap.cell(for: destination))
        #expect(walker.isMoving)

        #expect(queue.correctiveRepath(&walker, at: 10, ticks: tick) == .keepWalking)
        // The route survived: `DoStep` still has a leg to finish and can still
        // report arrival.
        #expect(walker.isMoving)
        #expect(walker.hasPath)
    }

    /// `MAX_PATH_TRIES`: a walk whose replans keep finding nothing is abandoned
    /// rather than retried forever.
    @Test func repathAbandonsOnceThePathTryBudgetIsSpent() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))
        queue.order(&walker, to: CGPoint(x: 280, y: 200), ticks: 1)

        // Spend the budget outright — the engine counts failed searches, which
        // cannot be provoked on open floor.
        for _ in 0...(Movable.maxPathTries) { walker.debugCountFailedPathTry() }
        #expect(walker.hasExhaustedPathTries)

        #expect(queue.correctiveRepath(&walker, at: 10, ticks: 40) == .abandon)
        #expect(!walker.isMoving)
        #expect(!walker.hasExhaustedPathTries)
    }

    @Test func cancelStopsAndClearsTheRoute() {
        let map = Self.room()
        let queue = Self.queue(map)
        var walker = Self.walker(map, at: CGPoint(x: 20, y: 20))

        queue.order(&walker, to: CGPoint(x: 280, y: 200), ticks: 1)
        #expect(walker.isMoving)
        queue.cancel(&walker)
        #expect(!walker.isMoving)
        #expect(!walker.hasPath)
        #expect(walker.pendingWaypoints.isEmpty)
    }
}

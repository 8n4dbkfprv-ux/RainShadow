import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The whole loop on shipped geometry: order in, `DoStep` per tick, arrival out.
///
/// Every other movement suite tests one layer against a fixture. This drives the
/// real office and district maps the way a scene does — `MovementOrderQueue`
/// issues, `Movable` walks, and nothing mocks the search — because the layers
/// agreeing individually is not the same as an actor getting across the room.
struct MovementIntegrationTests {

    /// Pump ticks until the walk ends, returning every position visited.
    private func walkOut(
        _ movable: inout Movable,
        startingAt tick: Int = 2,
        limit: Int = 4_000
    ) -> (positions: [CGPoint], arrived: Bool, ticks: Int) {
        var positions: [CGPoint] = []
        let walkScale = MovableTestSupport.humanoidWalkScale
        for offset in 0..<limit {
            let outcome = movable.doStep(walkScale: walkScale, time: tick + offset)
            if outcome.moved { positions.append(movable.position) }
            if outcome.arrived { return (positions, true, offset + 1) }
            if outcome.abandoned || outcome.backedOff { break }
            if !movable.isMoving { break }
        }
        return (positions, false, limit)
    }

    @Test func theDetectiveWalksToEveryOfficeApproachWithoutClippingAnObstacle() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        let queue = MovementOrderQueue(navigation: map, actorID: "detective")

        for (hotspotID, approach) in OfficeNavigationLayout.approachPoints {
            var walker = Movable(
                map: map,
                identity: "detective",
                position: OfficeNavigationLayout.actorStart,
                circleSize: map.circleSize,
                blocksSearchMap: false
            )

            let outcome = queue.order(
                &walker,
                to: approach,
                requiresExactDestination: true,
                ticks: 1
            )
            #expect(outcome == .walk, "\(hotspotID) order was \(outcome)")

            let walk = walkOut(&walker)
            #expect(walk.arrived, "\(hotspotID) never arrived")
            #expect(!walk.positions.isEmpty)
            #expect(
                map.searchMap.cell(for: walker.position) == map.searchMap.cell(for: approach),
                "\(hotspotID) stopped in the wrong cell"
            )
            for step in walk.positions {
                #expect(
                    !OfficeNavigationLayout.isBlocked(step),
                    "\(hotspotID) stepped inside an obstacle at \(step)"
                )
            }
        }
    }

    /// Every step is one `NormalizeDeltas` displacement — never a teleport, and
    /// never two nodes in one tick. The old follower spent a float budget and
    /// could consume several waypoints per frame; this cannot.
    @Test func everyStepIsOneEngineStride() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        var walker = Movable(
            map: map,
            identity: "detective",
            position: OfficeNavigationLayout.actorStart,
            circleSize: map.circleSize,
            blocksSearchMap: false
        )
        let approach = OfficeNavigationLayout.approachPoints.values.first!
        walker.walkTo(approach, ticks: 1)
        #expect(walker.isMoving)

        var previous = walker.position
        let walk = walkOut(&walker)
        #expect(walk.arrived)
        for step in walk.positions {
            let dx = abs(step.x - previous.x)
            let dy = abs(step.y - previous.y)
            #expect(dx <= ActorLocomotionPacing.horizontalStepPerTick, "jumped \(dx) in x")
            #expect(dy <= ActorLocomotionPacing.verticalStepPerTick, "jumped \(dy) in y")
            // Whole units: `NormalizeDeltas` ceils each axis.
            #expect(dx == dx.rounded(), "fractional x step \(dx)")
            #expect(dy == dy.rounded(), "fractional y step \(dy)")
            previous = step
        }
    }

    /// A queued second leg is walked after the first, and its junction reticle
    /// retires as it is passed — `AddWayPoint` marks the node, `DoStep` clears it.
    @Test func aQueuedLegIsWalkedAfterTheFirstAndRetiresItsPip() {
        let map = MovableTestSupport.openMap(columns: 60, rows: 60)
        let queue = MovementOrderQueue(navigation: map, actorID: "walker")
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))

        #expect(queue.order(&walker, to: CGPoint(x: 360, y: 30), ticks: 1) == .walk)
        #expect(
            queue.order(
                &walker,
                to: CGPoint(x: 360, y: 400),
                queueWaypoint: true,
                ticks: 4
            ) == .append
        )
        #expect(walker.pendingWaypoints.count == 1)

        let walk = walkOut(&walker, startingAt: 5)
        #expect(walk.arrived)
        // Cell-exact: the search terminates on the node inside the goal cell,
        // and an appended leg's nodes are laid off its own start, so the final
        // point sits on that lattice rather than on the requested coordinate.
        #expect(
            map.searchMap.cell(for: walker.position)
                == map.searchMap.cell(for: CGPoint(x: 360, y: 400))
        )
        #expect(walker.pendingWaypoints.isEmpty, "the junction pip outlived its goal")
    }

    /// The detective crosses a whole district — the case a node budget used to
    /// be able to fail outright.
    @Test func theDetectiveCrossesADistrictEndToEnd() {
        let map = CityDistrictLayout.makeGrid()
        let start = CityDistrictLayout.actorStart
        let reachable = map.reachableCellCenters(from: start)
        let far = reachable.max {
            hypot($0.x - start.x, $0.y - start.y) < hypot($1.x - start.x, $1.y - start.y)
        }
        guard let far else {
            Issue.record("district has no reachable floor")
            return
        }

        var walker = Movable(
            map: map,
            identity: "detective",
            position: start,
            circleSize: map.circleSize,
            blocksSearchMap: false
        )
        walker.walkTo(far, ticks: 1)
        #expect(walker.isMoving, "no route across the district")

        let walk = walkOut(&walker, limit: 20_000)
        #expect(walk.arrived, "stalled after \(walk.ticks) ticks at \(walker.position)")
        #expect(map.searchMap.cell(for: walker.position) == map.searchMap.cell(for: far))
    }
}

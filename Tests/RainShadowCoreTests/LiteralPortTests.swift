import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Behaviour that only exists because the navigation stack is a literal port of
/// GemRB rather than a paraphrase of it.
///
/// Each of these pins a place where RainShadow used to answer differently, and
/// names what changed, so a well-meaning "fix" that reintroduces the old answer
/// reads as a red test rather than as an improvement.
struct LiteralPortTests {
    private typealias Support = MovableTestSupport

    // MARK: - The raster is the only clearance authority

    /// A solid narrower than a cell still closes the cell.
    ///
    /// `SearchMap` used to mark a cell only when an obstacle covered its
    /// *centre*, and made up the difference with a world-space AABB test layered
    /// on top of every cell query. The port removed that second test, so the
    /// raster has to carry the whole answer — which means conservative coverage.
    @Test func aSolidThinnerThanACellStillClosesIt() {
        let hairline = CGRect(x: 100, y: 0, width: 2, height: 480)
        let map = Support.openMap(columns: 20, rows: 40, obstacles: [hairline])
        let cell = map.searchMap.cell(for: CGPoint(x: 101, y: 240))

        #expect(!map.searchMap.blockedTile(at: cell).contains(.passable))
        #expect(!map.isOrderableFloor(CGPoint(x: 101, y: 240)))
    }

    /// Edge contact is not overlap: a solid ending exactly on a cell boundary
    /// leaves the cell beyond it open. Without this every authored wall would
    /// eat a free column of floor beside it.
    @Test func aSolidEndingOnACellBoundaryDoesNotClaimTheNextCell() {
        let flush = CGRect(x: 0, y: 0, width: 96, height: 480)
        let map = Support.openMap(columns: 20, rows: 40, obstacles: [flush])
        let inside = map.searchMap.cell(for: CGPoint(x: 88, y: 240))
        let beyond = map.searchMap.cell(for: CGPoint(x: 104, y: 240))

        #expect(inside.column == 5 && beyond.column == 6)
        #expect(!map.searchMap.blockedTile(at: inside).contains(.passable))
        #expect(map.searchMap.blockedTile(at: beyond).contains(.passable))
    }

    // MARK: - Line queries

    /// `IsWalkableTo` walks the line in world units, so a diagonal cannot slip
    /// between two solids that meet at a corner.
    ///
    /// The tile-space walk — which `IsVisibleLOS` still uses, as the engine does
    /// — advances a whole cell per step and ceils each axis independently, so a
    /// 45° run goes corner to corner and never looks at the cells either side.
    /// Routing on it let the detective clip the corner of a desk.
    @Test func aDiagonalCannotSlipBetweenTwoCornerTouchingSolids() {
        let cell = SearchMap.defaultCellSize
        let lower = CGRect(x: 0, y: 0, width: cell.width * 4, height: cell.height * 4)
        let upper = CGRect(
            x: cell.width * 4,
            y: cell.height * 4,
            width: cell.width * 4,
            height: cell.height * 4
        )
        let map = Support.openMap(columns: 12, rows: 12, obstacles: [lower, upper])
        let below = CGPoint(x: cell.width * 5.5, y: cell.height * 1.5)
        let above = CGPoint(x: cell.width * 1.5, y: cell.height * 5.5)

        #expect(!map.pathFinder.isWalkableTo(
            below,
            above,
            circleSize: 1,
            actorsAreBlocking: false
        ))
    }

    /// Line of sight tests `SIDEWALL` and nothing else, over a line walked to
    /// the end rather than abandoned at the first impassable cell.
    ///
    /// RainShadow used to add `NO_SEE` to the test and stop early. Adding
    /// `NO_SEE` is not the engine's table, and stopping early makes "a wall is
    /// in the way" and "a desk is in the way" the same answer.
    @Test func lineOfSightAsksAboutSidewallsOnly() {
        let cell = SearchMap.defaultCellSize
        let desk = CGRect(
            x: cell.width * 4,
            y: cell.height * 2,
            width: cell.width,
            height: cell.height * 6
        )
        let map = Support.openMap(columns: 12, rows: 12, obstacles: [desk])
        let west = map.searchMap.cell(for: CGPoint(x: cell.width * 1.5, y: cell.height * 5.5))
        let east = map.searchMap.cell(for: CGPoint(x: cell.width * 8.5, y: cell.height * 5.5))

        // The desk is solid — you cannot walk through it — and yet it is seen over.
        #expect(!map.pathFinder.isWalkableTo(
            map.searchMap.center(of: west),
            map.searchMap.center(of: east),
            circleSize: 1,
            actorsAreBlocking: false
        ))
        #expect(map.pathFinder.isVisibleLOS(from: west, to: east, circleSize: 1))
    }

    // MARK: - Position adjustment

    /// `Map::AdjustPositionNavmap` asks for a passable *cell*, not for room to
    /// stand in — it is `BumpAway`'s helper, and a sidestep only has to be
    /// somewhere to stand for a moment. Asking for clearance would send a shoved
    /// actor much further than a step aside.
    @Test func bumpAwaySnapsToACellRatherThanToClearance() {
        let cell = SearchMap.defaultCellSize
        // A one-cell slot: standable, but with no room on either side.
        let west = CGRect(x: 0, y: 0, width: cell.width * 3, height: cell.height * 6)
        let east = CGRect(
            x: cell.width * 4,
            y: 0,
            width: cell.width * 6,
            height: cell.height * 6
        )
        let map = Support.openMap(columns: 12, rows: 12, obstacles: [west, east], circleSize: 3)
        let slot = CGPoint(x: cell.width * 3.5, y: cell.height * 3.5)
        let slotCell = map.searchMap.cell(for: slot)

        // Clearance says no; the plain cell test says yes.
        #expect(!map.searchMap.blockedInRadiusTile(at: slotCell, size: 3).contains(.passable))
        #expect(map.searchMap.blockedTile(at: slotCell).contains(.passable))
        #expect(map.searchMap.cell(for: map.pathFinder.adjustPositionNavmap(slot)) == slotCell)
    }

    // MARK: - Ruled lines

    /// A painted `SIDEWALL` column, the terrain a ruled line actually stops on.
    ///
    /// `CalculateLinePath` tests `DOOR_IMPASSABLE | SIDEWALL`, not passability:
    /// in an IE area a wall is search-map index 10, while a desk is index 0.
    /// A line is stopped by architecture, not by furniture.
    private func mapWithSidewallColumn(at column: Int, columns: Int, rows: Int) -> SearchMap {
        let cell = SearchMap.defaultCellSize
        var indices = [UInt8](
            repeating: SearchMapTerrain.stone.rawValue,
            count: columns * rows
        )
        for row in 0..<rows {
            indices[row * columns + column] = SearchMapTerrain.wall.rawValue
        }
        return SearchMap(
            worldBounds: CGRect(
                x: 0,
                y: 0,
                width: CGFloat(columns) * cell.width,
                height: CGFloat(rows) * cell.height
            ),
            terrainIndices: indices,
            columns: columns,
            rows: rows
        )
    }

    @Test func aLinePathStopsAtAWall() throws {
        let cell = SearchMap.defaultCellSize
        let searchMap = mapWithSidewallColumn(at: 6, columns: 12, rows: 12)
        let start = CGPoint(x: cell.width * 1.5, y: cell.height * 5.5)
        let past = CGPoint(x: cell.width * 10.5, y: cell.height * 5.5)

        let stopped = PathFinder.calculateLinePath(
            on: searchMap,
            start: start,
            dest: past,
            speed: 4,
            orientation: .east,
            termination: .normal
        )
        let through = PathFinder.calculateLinePath(
            on: searchMap,
            start: start,
            dest: past,
            speed: 4,
            orientation: .east,
            termination: .pass
        )

        let wallMinX = cell.width * 6
        let stoppedEnd = try #require(stopped.nodes.last?.point)
        let throughEnd = try #require(through.nodes.last?.point)
        #expect(stoppedEnd.x <= wallMinX + cell.width)
        #expect(through.size > stopped.size, "GL_PASS must carry on through the wall")
        #expect(throughEnd.x > wallMinX + cell.width)
    }

    /// `GL_REBOUND` reflects the heading through the centre. The engine leaves
    /// the destination unmirrored with a TODO, so the line keeps its original
    /// course and only the facing turns; that is reproduced, not corrected.
    @Test func aReboundingLineTurnsItsFacingAndKeepsGoing() throws {
        let cell = SearchMap.defaultCellSize
        let searchMap = mapWithSidewallColumn(at: 6, columns: 12, rows: 12)
        let path = PathFinder.calculateLinePath(
            on: searchMap,
            start: CGPoint(x: cell.width * 1.5, y: cell.height * 5.5),
            dest: CGPoint(x: cell.width * 10.5, y: cell.height * 5.5),
            speed: 4,
            orientation: .east,
            termination: .rebound
        )

        #expect(path.nodes.first?.orient == .east)
        #expect(
            path.nodes.contains { $0.orient != .east },
            "the heading never reflected"
        )
        // The engine reflects once per wall *cell* the line crosses, so a thick
        // wall flips the facing back and forth; what `GL_REBOUND` reliably does,
        // and `GL_NORMAL` does not, is carry the line past the wall at all.
        let end = try #require(path.nodes.last)
        #expect(end.point.x > cell.width * 7)
    }

    /// `MoveLine` builds its path by hand, so it has to advance the movement
    /// state by hand too — `doStep` ignores a path while the state is idle.
    @Test func moveLineWalksWithoutASearch() {
        let map = Support.openMap(columns: 40, rows: 40)
        var walker = Support.movable(on: map, at: CGPoint(x: 320, y: 240))
        walker.moveLine(steps: 4, orient: .east)

        #expect(walker.isMoving)
        #expect(walker.hasPath)
        #expect(walker.destination.x > 320)

        let outcomes = Support.run(&walker, ticks: 40)
        #expect(outcomes.contains { $0.moved })
        #expect(walker.position.x > 320)
    }

    // MARK: - Wandering and fleeing

    @Test func randomWalkReturnsHomeOnceTheBudgetIsSpent() {
        let map = Support.openMap(columns: 40, rows: 40)
        let home = CGPoint(x: 320, y: 240)
        var walker = Support.movable(on: map, at: home)
        walker.homeLocation = home

        var sawWander = false
        for tick in 1...(Movable.maxRandomWalk + 1) {
            walker.stop()
            let outcome = walker.randomWalk(
                canStop: false,
                run: false,
                walkScale: Support.humanoidWalkScale,
                ticks: tick * 4
            )
            if outcome == .wandering { sawWander = true }
            if tick > Movable.maxRandomWalk {
                #expect(outcome == .returningHome, "the wander budget did not run out")
            }
        }
        #expect(sawWander, "no wander step was ever taken")
    }

    @Test func randomWalkRefusesToStartWhileAlreadyWalking() {
        let map = Support.openMap(columns: 40, rows: 40)
        var walker = Support.movable(on: map, at: CGPoint(x: 320, y: 240))
        walker.walkTo(CGPoint(x: 560, y: 240), ticks: 1)
        #expect(walker.isMoving)

        let outcome = walker.randomWalk(
            canStop: false,
            run: false,
            walkScale: Support.humanoidWalkScale,
            ticks: 4
        )
        #expect(outcome == .busy)
    }

    @Test func runningAwayIncreasesTheDistanceFromTheThreat() {
        let map = Support.openMap(columns: 40, rows: 40)
        let start = CGPoint(x: 320, y: 240)
        let threat = CGPoint(x: 160, y: 240)
        var walker = Support.movable(on: map, at: start)

        walker.runAwayFrom(
            threat,
            pathLength: 6,
            noBackAway: true,
            walkScale: Support.humanoidWalkScale
        )
        #expect(walker.isMoving, "no flight route")
        #expect(
            hypot(walker.destination.x - threat.x, walker.destination.y - threat.y)
                > hypot(start.x - threat.x, start.y - threat.y),
            "fled toward the threat"
        )
    }

    // MARK: - Stepping

    /// `DoStep` reads `BlocksSearchMap` on the *blocker* as well as on the
    /// walker. A ghost is not something to shove or to wait behind.
    @Test func aBlockerThatDoesNotStampIsWalkedThrough() {
        let map = Support.openMap(columns: 40, rows: 40)
        let start = CGPoint(x: 320, y: 240)
        var walker = Support.movable(on: map, at: start, id: "walker", blocksSearchMap: true)
        map.registerActor(id: "walker", kind: .player, at: start)
        map.registerActor(
            id: "ghost",
            kind: .npc,
            at: CGPoint(x: 400, y: 240),
            isMoving: false,
            blocksSearchMap: false
        )

        walker.walkTo(CGPoint(x: 560, y: 240), ticks: 1)
        #expect(walker.isMoving)
        let outcomes = Support.run(&walker, ticks: 60, startingAt: 2)
        #expect(!outcomes.contains { $0.backedOff }, "backed off for a ghost")
        #expect(outcomes.allSatisfy { $0.bumpedActorID == nil }, "tried to bump a ghost")
    }
}

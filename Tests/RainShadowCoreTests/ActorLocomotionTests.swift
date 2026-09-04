import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// `Movable::DoStep` and the orders that feed it.
///
/// These replace `RouteFollowerTests`. Three of that suite's properties are
/// **invalid by construction** here and are not carried over: constant speed,
/// segmentation invariance, and timestep independence. `NormalizeDeltas` rounds
/// each axis up to a whole unit and `DoStep` emits exactly one step per tick, so
/// travel is quantised by design — a route split into more segments really does
/// take more ticks, because each node costs its own rounding. What replaces them
/// is an exact per-tick displacement table, which is a stronger assertion.
struct MovableTests {

    // MARK: - The step itself

    /// `PathFinder::NormalizeDeltas`, axis by axis.
    ///
    /// With BG:EE's constants the pre-rounding step is 6.79 east and 5.09 north.
    /// The engine ceils each axis, so the real stride is 7 and 6 — which is why
    /// the *effective* vertical ratio is 6/7, not the 0.75 the function
    /// multiplies by. Anything derived from the un-rounded numbers describes a
    /// gait no Infinity Engine creature has ever walked.
    @Test func normalizeDeltasRoundsEachAxisUpToAWholeUnit() {
        let factor = ActorLocomotionPacing.stepFactor

        var dx: CGFloat = 100
        var dy: CGFloat = 0
        PathFinder.normalizeDeltas(&dx, &dy, factor: factor)
        #expect(dx == 7)
        #expect(dy == 0)

        dx = 0
        dy = 100
        PathFinder.normalizeDeltas(&dx, &dy, factor: factor)
        #expect(dx == 0)
        #expect(dy == 6)

        #expect(ActorLocomotionPacing.horizontalStepPerTick == 7)
        #expect(ActorLocomotionPacing.verticalStepPerTick == 6)
    }

    /// Signs survive the absolute-value round trip.
    @Test func normalizeDeltasPreservesDirection() {
        for (sx, sy) in [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)] {
            var dx = CGFloat(sx) * 100
            var dy = CGFloat(sy) * 100
            PathFinder.normalizeDeltas(&dx, &dy, factor: ActorLocomotionPacing.stepFactor)
            #expect(dx.sign == (sx < 0 ? .minus : .plus))
            #expect(dy.sign == (sy < 0 ? .minus : .plus))
        }
    }

    /// `min(step * factor, original)` — a step can never overshoot its node.
    /// This is what makes arrival an exact `position == node.point` test rather
    /// than a tolerance, and it is load-bearing for the whole design.
    @Test func aStepNeverOvershootsItsNode() {
        var dx: CGFloat = 3
        var dy: CGFloat = 2
        PathFinder.normalizeDeltas(&dx, &dy, factor: ActorLocomotionPacing.stepFactor)
        #expect(dx == 3)
        #expect(dy == 2)
    }

    @Test func aWalkLandsExactlyOnItsDestination() {
        let map = MovableTestSupport.openMap()
        let goal = CGPoint(x: 264, y: 30)
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(goal, ticks: 1)
        #expect(walker.isMoving)

        var arrived = false
        for tick in 2...200 {
            let outcome = walker.doStep(
                walkScale: MovableTestSupport.humanoidWalkScale,
                time: tick
            )
            if outcome.arrived { arrived = true; break }
        }
        #expect(arrived)
        #expect(walker.position == goal)
        #expect(!walker.isMoving)
        #expect(!walker.hasPath)
    }

    /// One step per tick, and no more: a second `doStep` at the same tick value
    /// is a no-op. `DoStep` gates on `time <= timeStartStep`.
    @Test func onlyOneStepIsTakenPerTick() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 1)

        let first = walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: 2)
        let afterFirst = walker.position
        #expect(first.moved)

        let second = walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: 2)
        #expect(!second.moved)
        #expect(walker.position == afterFirst)
    }

    /// Due east at the humanoid rate is exactly seven units a tick.
    @Test func eastwardTravelAdvancesSevenUnitsPerTick() {
        let map = MovableTestSupport.openMap()
        let start = CGPoint(x: 24, y: 30)
        var walker = MovableTestSupport.movable(on: map, at: start)
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 1)

        for tick in 2...5 {
            walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
        }
        #expect(walker.position == CGPoint(x: start.x + 28, y: start.y))
    }

    // MARK: - Orders

    /// `Movable::WalkTo`'s same-cell early out is a head turn, not a step.
    @Test func anOrderInsideTheOccupiedCellTurnsRatherThanWalking() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 28, y: 33), ticks: 1)
        #expect(!walker.isMoving)
        #expect(!walker.hasPath)
    }

    /// An unreachable destination parks a `pathSearchFailed` verdict, which the
    /// *next* order for the same spot consumes. Without it the move actions
    /// refile the same hopeless request forever.
    @Test func anUnreachableDestinationTerminatesRatherThanRetryingForever() {
        // A sealed pocket: a ring of solid around the goal.
        let wall = CGRect(x: 160, y: 0, width: 32, height: 480)
        let map = MovableTestSupport.openMap(obstacles: [wall])
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 240))

        walker.walkTo(CGPoint(x: 176, y: 240), ticks: 1)
        #expect(!walker.isMoving)
        #expect(walker.movementState == .pathSearchFailed)

        // The same order again reports the failure and files nothing new.
        walker.walkTo(CGPoint(x: 176, y: 240), ticks: 10)
        #expect(walker.movementState == .noMovement)
    }

    /// The engine's 2-tick rate limit: `WalkTo` is called every tick while an
    /// actor follows another actor, so orders inside that window are dropped.
    @Test func ordersAreRateLimitedToOncePerTwoTicksWhileWalking() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 10)
        #expect(walker.destination == CGPoint(x: 264, y: 30))

        // One tick later: swallowed.
        walker.walkTo(CGPoint(x: 24, y: 300), ticks: 11)
        #expect(walker.destination == CGPoint(x: 264, y: 30))

        // Two ticks later: honoured.
        walker.walkTo(CGPoint(x: 24, y: 300), ticks: 12)
        #expect(walker.destination == CGPoint(x: 24, y: 300))
    }

    @Test func stopClearsTheRouteAndTheDestination() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 1)
        walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: 2)
        let livePosition = walker.position

        walker.stop()
        #expect(!walker.isMoving)
        #expect(!walker.hasPath)
        // "This is to make sure attackers come to us."
        #expect(walker.destination == livePosition)
        #expect(walker.position == livePosition)
    }

    /// A zero walk scale is the engine's immobile branch: stance drops to ready,
    /// the tick is consumed, and the route is untouched.
    @Test func zeroWalkScaleHoldsPositionAndKeepsTheRoute() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 1)
        let route = walker.remainingPoints

        let outcome = walker.doStep(walkScale: 0, time: 2)
        #expect(!outcome.moved)
        #expect(walker.position == CGPoint(x: 24, y: 30))
        #expect(walker.remainingPoints == route)
        #expect(walker.isMoving)
    }

    // MARK: - Waypoints

    /// `AddWayPoint` searches from the **last path node**, so legs chain end to
    /// end and the queue survives the actor being anywhere along the current one.
    @Test func anAppendedLegChainsFromTheLastNodeNotTheActor() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 1)
        let firstGoal = walker.destination

        // Walk a few ticks so the actor is mid-leg when the append lands.
        for tick in 2...5 {
            walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
        }
        #expect(walker.position.x > 24)

        walker.addWayPoint(CGPoint(x: 264, y: 300), ticks: 6)
        #expect(walker.destination == CGPoint(x: 264, y: 300))
        // The junction is marked, and it is the first goal, not the live position.
        #expect(walker.pendingWaypoints == [firstGoal])
    }

    /// `if (!path) { WalkTo(Des); return; }`.
    @Test func appendingWithNoPathIsAPlainWalk() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        #expect(!walker.hasPath)

        walker.addWayPoint(CGPoint(x: 264, y: 30), ticks: 1)
        #expect(walker.isMoving)
        #expect(walker.pendingWaypoints.isEmpty)
    }

    /// A waypoint mark is cleared as the node is reached, so reticles retire.
    @Test func walkingThroughAWaypointRetiresItsMark() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 108, y: 30), ticks: 1)
        walker.addWayPoint(CGPoint(x: 264, y: 30), ticks: 4)
        #expect(walker.pendingWaypoints.count == 1)

        for tick in 5...200 where !walker.pendingWaypoints.isEmpty {
            walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
        }
        #expect(walker.pendingWaypoints.isEmpty)
        #expect(walker.isMoving, "the second leg is still being walked")
    }

    /// Queued legs are walked in order, ending on the last goal.
    @Test func queuedLegsCompleteInOrder() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 264, y: 30), ticks: 1)
        walker.addWayPoint(CGPoint(x: 264, y: 294), ticks: 4)

        var visited: [CGPoint] = []
        for tick in 5...600 {
            let before = walker.position
            let outcome = walker.doStep(
                walkScale: MovableTestSupport.humanoidWalkScale,
                time: tick
            )
            if before != walker.position { visited.append(walker.position) }
            if outcome.arrived { break }
        }
        #expect(walker.position == CGPoint(x: 264, y: 294))
        // The route went east first, then north — not diagonally to the corner.
        let firstNorthward = visited.firstIndex { $0.y > 30 } ?? visited.count
        let lastEastward = visited.lastIndex { $0.x < 264 } ?? 0
        #expect(lastEastward < firstNorthward)
    }

    // MARK: - Facing

    /// `DoStep` assigns the node's stored orientation outright; a walking
    /// creature does not turn gradually.
    @Test func walkingSnapsFacingToTheNodeOrientation() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 240))
        #expect(walker.orientation == .south)

        walker.walkTo(CGPoint(x: 264, y: 240), ticks: 1)
        walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: 2)
        #expect(walker.orientation == .east)
    }

    /// `GetNextFace` turns at most one bin per tick, and not at all on a tick
    /// that already spent a step.
    @Test func aStandingActorTurnsOneBinPerTick() {
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 240))
        walker.newOrientation = .north

        #expect(walker.nextFace(at: 5) == walker.orientation.stepped(toward: .north))
        walker.advanceTurn(at: 5)
        #expect(walker.orientation != .south)
        #expect(walker.orientation != .north, "a half turn takes eight ticks, not one")

        var turns = 1
        while walker.orientation != .north && turns < 32 {
            walker.advanceTurn(at: 5 + turns)
            turns += 1
        }
        #expect(turns == 8, "S to N is eight 22.5-degree bins")
    }
}
/// `core/Orientation.h`.
///
/// The numbering changed with the port: the engine has `S = 0` running clockwise
/// on screen, so `W = 4`, `N = 8`, `E = 12`. Every helper below is arithmetic on
/// the raw value and only works against that order.
///
/// Hysteresis is gone with the old `resolve`. The engine has none: facing comes
/// from `GetOrient`, and a walking creature takes the orientation stored on the
/// path node rather than recomputing from velocity, so there is no boundary to
/// flicker across.
struct ActorFacingTests {
    @Test func theEngineNumberingIsSouthZeroClockwise() {
        #expect(ActorFacing.south.rawValue == 0)
        #expect(ActorFacing.west.rawValue == 4)
        #expect(ActorFacing.north.rawValue == 8)
        #expect(ActorFacing.east.rawValue == 12)
        #expect(ActorFacing.allCases.count == ActorFacing.count)
    }

    /// `GetOrient` on each of the sixteen sector centres.
    ///
    /// Note the y-up adaptation: the engine's world is y-down and it negates dy
    /// on the way in, ours is y-up and does not. `mathy` is the bridge back to
    /// trigonometry, so a facing's own vector must resolve to itself.
    @Test func orientResolvesEveryLogicalSectorCentre() {
        for facing in ActorFacing.allCases {
            let angle = CGFloat(facing.mathy.rawValue) * ActorFacing.sectorAngle
            #expect(ActorFacing.orient(dx: cos(angle), dy: sin(angle)) == facing)
        }
    }

    @Test func orientAgreesWithTheCardinalDirections() {
        #expect(ActorFacing.orient(dx: 1, dy: 0) == .east)
        #expect(ActorFacing.orient(dx: -1, dy: 0) == .west)
        #expect(ActorFacing.orient(dx: 0, dy: 1) == .north)
        #expect(ActorFacing.orient(dx: 0, dy: -1) == .south)
        #expect(ActorFacing.orient(dx: 1, dy: 1) == .northEast)
        #expect(ActorFacing.orient(dx: -1, dy: -1) == .southWest)
    }

    /// The engine's degenerate case (both deltas zero) answers S.
    @Test func orientWithNoMovementAnswersSouth() {
        #expect(ActorFacing.orient(dx: 0, dy: 0) == .south)
    }

    @Test func steppedTurnsOneBinAlongTheShorterArc() {
        // `GetNextFace`: one 22.5-degree bin per tick, shorter way round.
        #expect(ActorFacing.east.stepped(toward: .north) == .eastNorthEast)
        #expect(ActorFacing.east.stepped(toward: .south) == .eastSouthEast)
        #expect(ActorFacing.north.stepped(toward: .east) == .northNorthEast)
        // Already there: no movement, and no oscillation.
        #expect(ActorFacing.west.stepped(toward: .west) == .west)
    }

    @Test func steppedReachesAnyFacingWithinHalfATurn() {
        // Sixteen bins, so the worst case is eight steps — 0.53 s at 15 Hz.
        for start in ActorFacing.allCases {
            for target in ActorFacing.allCases {
                var facing = start
                var steps = 0
                while facing != target, steps <= ActorFacing.count {
                    facing = facing.stepped(toward: target)
                    steps += 1
                }
                #expect(facing == target)
                #expect(steps <= ActorFacing.count / 2)
            }
        }
    }

    @Test func steppedResolvesAHalfTurnConsistently() {
        // A clean 180 degrees is a tie; the engine's `<= MAX_ORIENT / 2`
        // comparison breaks it toward increasing raw value rather than dithering.
        for start in ActorFacing.allCases {
            #expect(start.stepped(toward: start.reflected) == start.next())
        }
    }

    /// The arithmetic helpers, each of which the engine relies on.
    @Test func orientationArithmeticMatchesTheEngineHelpers() {
        // ReflectOrientation: through the centre.
        #expect(ActorFacing.north.reflected == .south)
        #expect(ActorFacing.east.reflected == .west)
        // FlipOrientation: over the vertical axis.
        #expect(ActorFacing.northEast.flipped == .northWest)
        #expect(ActorFacing.east.flipped == .west)
        // ReduceToHalf: eight-orientation animations.
        #expect(ActorFacing.northNorthEast.reducedToHalf == .north)
        // ClampToOrientation wraps like a mask, negatives included.
        #expect(ActorFacing.south.previous() == .southSouthEast)
        #expect(ActorFacing.southSouthEast.next() == .south)
        // SixteenToNine folds the eastern half onto the authored western strips.
        #expect(ActorFacing.sixteenToNine.count == ActorFacing.count)
        #expect(ActorFacing.sixteenToNine[ActorFacing.east.rawValue]
                    == ActorFacing.sixteenToNine[ActorFacing.west.rawValue])
    }

    /// `OrientedOffset` — the integer cell step `AdjustPositionDirected` walks
    /// outward along. Cell rows are y-up here, as the world is.
    @Test func orientedOffsetStepsOneCellInEachDirection() {
        #expect(ActorFacing.east.offset(1) == (dx: 1, dy: 0))
        #expect(ActorFacing.west.offset(1) == (dx: -1, dy: 0))
        #expect(ActorFacing.north.offset(1) == (dx: 0, dy: 1))
        #expect(ActorFacing.south.offset(1) == (dx: 0, dy: -1))
        #expect(ActorFacing.northEast.offset(2) == (dx: 2, dy: 2))
        #expect(ActorFacing.southWest.offset(3) == (dx: -3, dy: -3))
    }

    @Test func tickClockDrainsWholeTicksAndKeepsTheRemainder() {
        var clock = LogicTickClock()
        // A 60 Hz frame is a quarter tick: three frames buy nothing, the fourth
        // buys exactly one. Dropping the remainder here would lose 25% of travel.
        let frame = 1.0 / 60.0
        #expect(clock.drain(deltaTime: frame) == 0)
        #expect(clock.drain(deltaTime: frame) == 0)
        #expect(clock.drain(deltaTime: frame) == 0)
        #expect(clock.drain(deltaTime: frame) == 1)

        // A long delta drains every whole tick it contains at once.
        var burst = LogicTickClock()
        #expect(burst.drain(deltaTime: LogicTickClock.tickDuration * 3.5) == 3)
        #expect(burst.drain(deltaTime: LogicTickClock.tickDuration * 0.5) == 1)

        // Non-positive deltas never advance, and reset drops the partial tick.
        var idle = LogicTickClock()
        #expect(idle.drain(deltaTime: 0) == 0)
        #expect(idle.drain(deltaTime: -1) == 0)
        _ = idle.drain(deltaTime: LogicTickClock.tickDuration * 0.9)
        idle.reset()
        #expect(idle.drain(deltaTime: LogicTickClock.tickDuration * 0.9) == 0)
    }

    @Test func tickClockKeepsMovementFrameRateIndependent() {
        // The same wall-clock second yields the same number of steps whether the
        // renderer runs at 30, 60, or 120 Hz.
        for frameRate in [30.0, 60.0, 120.0] {
            var clock = LogicTickClock()
            var ticks = 0
            for _ in 0..<Int(frameRate) {
                ticks += clock.drain(deltaTime: 1 / frameRate)
            }
            #expect(ticks == 15)
        }
    }

    @Test func easternFacingsReuseMirroredWesternSources() {
        #expect(ActorFacing.east.isMirrored)
        #expect(ActorFacing.east.textureSourceCandidates.first == "w")
        #expect(ActorFacing.northEast.textureSourceCandidates.first == "nw")
        #expect(ActorFacing.southEast.textureSourceCandidates.first == "sw")
        #expect(!ActorFacing.west.isMirrored)
        #expect(!ActorFacing.north.isMirrored)
        #expect(!ActorFacing.south.isMirrored)
    }

    @Test func gameArtRejectsMissingAtlasCandidatesInsteadOfRenderingRedX() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let gameArtURL = root.appendingPathComponent(
            "RainShadow Shared/Core/Assets/GameArt.swift"
        )
        let source = try String(contentsOf: gameArtURL, encoding: .utf8)

        // SpriteKit returns a non-zero red-X texture for unknown names. Candidate
        // fallback must be driven by the atlas manifest, never placeholder size.
        #expect(source.contains("atlas.textureNames.first"))
        #expect(source.contains("deletingPathExtension == name"))
        #expect(!source.contains("atlasTexture.size() != .zero"))
    }
}

import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct RouteFollowerTests {
    @Test func advancesAtConstantProjectedSpeed() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 100, y: 0)], from: .zero)

        let step = follower.advance(from: .zero, deltaTime: 0.25, speed: 120)

        #expect(step.position == CGPoint(x: 30, y: 0))
        #expect(step.direction == CGVector(dx: 1, dy: 0))
        #expect(!step.didArrive)
    }

    @Test func consumesOvershootAcrossMultipleWaypointsWithoutPassingDestination() {
        var follower = RouteFollower()
        follower.replaceRoute(
            with: [CGPoint(x: 30, y: 0), CGPoint(x: 30, y: 40)],
            from: .zero
        )

        let step = follower.advance(from: .zero, deltaTime: 1, speed: 100)

        #expect(step.position == CGPoint(x: 30, y: 40))
        #expect(step.didArrive)
        #expect(!follower.isMoving)
    }

    @Test func routeSegmentationDoesNotChangeTravelDistance() {
        var direct = RouteFollower()
        direct.replaceRoute(with: [CGPoint(x: 100, y: 0)], from: .zero)

        var segmented = RouteFollower()
        segmented.replaceRoute(
            with: [
                CGPoint(x: 25, y: 0),
                CGPoint(x: 50, y: 0),
                CGPoint(x: 75, y: 0),
                CGPoint(x: 100, y: 0)
            ],
            from: .zero
        )

        let directStep = direct.advance(from: .zero, deltaTime: 0.5, speed: 100)
        let segmentedStep = segmented.advance(from: .zero, deltaTime: 0.5, speed: 100)

        #expect(directStep.position == CGPoint(x: 50, y: 0))
        #expect(segmentedStep.position == directStep.position)
    }

    @Test func timeStepSizeDoesNotChangeProgressAroundACorner() {
        let route = [CGPoint(x: 30, y: 0), CGPoint(x: 30, y: 40)]
        var singleStep = RouteFollower()
        singleStep.replaceRoute(with: route, from: .zero)
        let expected = singleStep.advance(from: .zero, deltaTime: 0.5, speed: 100)

        var repeatedSteps = RouteFollower()
        repeatedSteps.replaceRoute(with: route, from: .zero)
        var position = CGPoint.zero
        for _ in 0..<5 {
            position = repeatedSteps.advance(
                from: position,
                deltaTime: 0.1,
                speed: 100
            ).position
        }

        // 50 units of budget: 30 spends the horizontal leg outright, and the
        // remaining 20 buys 0.75 × 20 = 15 units of foreshortened vertical travel.
        #expect(expected.position == CGPoint(x: 30, y: 15))
        #expect(position == expected.position)
    }

    @Test func arrivalToleranceNeverCreatesFreeTravelBudget() {
        var follower = RouteFollower(arrivalTolerance: 0.25)
        follower.replaceRoute(with: [CGPoint(x: 1, y: 0)], from: .zero)

        let partial = follower.advance(from: .zero, deltaTime: 1, speed: 0.8)
        #expect(abs(partial.position.x - 0.8) < 0.0001)
        #expect(!partial.didArrive)

        let arrived = follower.advance(from: partial.position, deltaTime: 0.3, speed: 0.8)
        #expect(arrived.position == CGPoint(x: 1, y: 0))
        #expect(arrived.didArrive)
    }

    @Test func replacementStartsAtLiveInterpolatedPosition() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 100, y: 0)], from: .zero)
        let first = follower.advance(from: .zero, deltaTime: 0.3, speed: 100)

        follower.replaceRoute(with: [CGPoint(x: 30, y: 100)], from: first.position)
        let redirected = follower.advance(from: first.position, deltaTime: 0.2, speed: 50)

        #expect(first.position == CGPoint(x: 30, y: 0))
        // Due north: the emitted step is the engine's squashed vector, so 10 units
        // of budget move 7.5 screen units and the heading is (0, 0.75), not a unit.
        #expect(redirected.position == CGPoint(x: 30, y: 7.5))
        #expect(redirected.direction == CGVector(dx: 0, dy: 0.75))
    }

    @Test func cancelStopsWithoutSyntheticArrival() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 100, y: 0)], from: .zero)
        follower.cancel()

        let step = follower.advance(from: .zero, deltaTime: 1, speed: 100)

        #expect(step.position == .zero)
        #expect(!step.didArrive)
        #expect(follower.destination == nil)
    }

    @Test func cancelMidRouteHoldsLivePositionWithoutArrival() {
        var follower = RouteFollower()
        follower.replaceRoute(
            with: [CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 80)],
            from: .zero
        )
        let mid = follower.advance(from: .zero, deltaTime: 0.25, speed: 100)
        #expect(mid.position == CGPoint(x: 25, y: 0))
        #expect(!mid.didArrive)

        follower.cancel()
        let afterCancel = follower.advance(from: mid.position, deltaTime: 1, speed: 100)

        #expect(afterCancel.position == mid.position)
        #expect(!afterCancel.didArrive)
        #expect(!follower.isMoving)
        #expect(follower.destination == nil)
    }

    @Test func replaceMidRouteDiscardsOldDestinationTail() {
        var follower = RouteFollower()
        follower.replaceRoute(
            with: [CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 50)],
            from: .zero
        )
        let mid = follower.advance(from: .zero, deltaTime: 0.3, speed: 100)
        #expect(mid.position == CGPoint(x: 30, y: 0))

        follower.replaceRoute(with: [CGPoint(x: 30, y: 60)], from: mid.position)

        #expect(follower.waypoints == [CGPoint(x: 30, y: 60)])
        #expect(follower.destination == CGPoint(x: 30, y: 60))
        #expect(follower.destination != CGPoint(x: 100, y: 50))
    }

    @Test func replaceAfterCancelStartsCleanRoute() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 80, y: 0)], from: .zero)
        _ = follower.advance(from: .zero, deltaTime: 0.2, speed: 100)
        follower.cancel()
        #expect(!follower.isMoving)

        follower.replaceRoute(with: [CGPoint(x: 20, y: 40)], from: CGPoint(x: 20, y: 0))
        let step = follower.advance(from: CGPoint(x: 20, y: 0), deltaTime: 0.5, speed: 40)

        #expect(step.position == CGPoint(x: 20, y: 15))
        #expect(!step.didArrive)
        #expect(follower.isMoving)
        #expect(follower.destination == CGPoint(x: 20, y: 40))
    }

    @Test func zeroSpeedDoesNotConsumeWaypoints() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 50, y: 0)], from: .zero)

        let step = follower.advance(from: .zero, deltaTime: 1, speed: 0)

        #expect(step.position == .zero)
        #expect(step.direction == .zero)
        #expect(!step.didArrive)
        #expect(follower.waypoints == [CGPoint(x: 50, y: 0)])
        #expect(follower.isMoving)
    }

    @Test func appendsDistinctWaypointsInOrder() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 20, y: 0)], from: .zero)
        follower.appendRoute([
            CGPoint(x: 20, y: 0),
            CGPoint(x: 20, y: 20)
        ])

        #expect(follower.waypoints == [CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 20)])
    }

    @Test func appendDeduplicatesNearArrivalTolerance() {
        var follower = RouteFollower(arrivalTolerance: 0.25)
        follower.replaceRoute(with: [CGPoint(x: 40, y: 0)], from: .zero)
        follower.appendRoute([
            CGPoint(x: 40.1, y: 0),
            CGPoint(x: 40, y: 30)
        ])

        #expect(follower.waypoints == [CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 30)])
    }

    @Test func appendExtendsActiveRouteWithoutDiscardingHead() {
        var follower = RouteFollower()
        follower.replaceRoute(
            with: [CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 20)],
            from: .zero
        )
        let mid = follower.advance(from: .zero, deltaTime: 0.2, speed: 100)
        #expect(mid.position == CGPoint(x: 20, y: 0))

        follower.appendRoute([CGPoint(x: 40, y: 60)])

        #expect(follower.waypoints == [
            CGPoint(x: 40, y: 0),
            CGPoint(x: 40, y: 20),
            CGPoint(x: 40, y: 60)
        ])
        #expect(follower.destination == CGPoint(x: 40, y: 60))
    }

    @Test func replaceClearsPreviouslyAppendedTail() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 50, y: 0)], from: .zero)
        follower.appendRoute([CGPoint(x: 50, y: 40), CGPoint(x: 10, y: 40)])
        #expect(follower.waypoints.count == 3)

        follower.replaceRoute(with: [CGPoint(x: 0, y: 80)], from: CGPoint(x: 20, y: 0))

        #expect(follower.waypoints == [CGPoint(x: 0, y: 80)])
        #expect(follower.destination == CGPoint(x: 0, y: 80))
    }

    @Test func queuedLegsCompleteInOrder() {
        var follower = RouteFollower()
        follower.replaceRoute(with: [CGPoint(x: 30, y: 0)], from: .zero)
        follower.appendRoute([CGPoint(x: 30, y: 30), CGPoint(x: 0, y: 30)])

        var position = CGPoint.zero
        var arrivals = 0
        // Drive until empty; each advance that empties counts as arrival.
        for _ in 0..<20 {
            let step = follower.advance(from: position, deltaTime: 0.25, speed: 120)
            position = step.position
            if step.didArrive {
                arrivals += 1
                break
            }
        }

        #expect(arrivals == 1)
        #expect(position == CGPoint(x: 0, y: 30))
        #expect(!follower.isMoving)
    }

    @Test func repathCurrentLegPreservesLaterAppendedGoals() {
        // Scene-level queue model: replace current-leg waypoints, then re-append
        // remaining goals (mirrors performCorrectiveRepathIfNeeded).
        var follower = RouteFollower()
        let currentGoal = CGPoint(x: 100, y: 0)
        let laterGoal = CGPoint(x: 100, y: 80)
        follower.replaceRoute(with: [currentGoal], from: .zero)
        follower.appendRoute([laterGoal])

        let mid = follower.advance(from: .zero, deltaTime: 0.25, speed: 100)
        #expect(mid.position == CGPoint(x: 25, y: 0))

        // Corrective repath of the current leg from the live position.
        follower.replaceRoute(with: [currentGoal], from: mid.position)
        follower.appendRoute([laterGoal])

        #expect(follower.waypoints == [currentGoal, laterGoal])
        #expect(follower.destination == laterGoal)

        let next = follower.advance(from: mid.position, deltaTime: 0.5, speed: 100)
        #expect(next.position == CGPoint(x: 75, y: 0))
        #expect(!next.didArrive)
        #expect(follower.destination == laterGoal)
    }

    @Test func remainingPathLengthSumsPolylineFromPosition() {
        var follower = RouteFollower()
        follower.replaceRoute(
            with: [CGPoint(x: 30, y: 0), CGPoint(x: 30, y: 40)],
            from: .zero
        )
        // Projected metric, not raw screen length: 30 horizontal + 40/0.75 vertical.
        // Callers compare this against a candidate route, so it has to be the same
        // currency the follower spends.
        #expect(abs(follower.remainingPathLength(from: .zero) - (30 + 40 / 0.75)) < 0.0001)
        #expect(
            abs(follower.remainingPathLength(from: CGPoint(x: 10, y: 0)) - (20 + 40 / 0.75))
                < 0.0001
        )
    }

    @Test func verticalTravelIsSlowerOnScreenThanHorizontal() {
        // The engine's perspective squash: for the same budget an actor covers
        // 0.75 as much screen distance walking north as walking east.
        var eastward = RouteFollower()
        eastward.replaceRoute(with: [CGPoint(x: 1_000, y: 0)], from: .zero)
        let east = eastward.advance(from: .zero, deltaTime: 1, speed: 100)

        var northward = RouteFollower()
        northward.replaceRoute(with: [CGPoint(x: 0, y: 1_000)], from: .zero)
        let north = northward.advance(from: .zero, deltaTime: 1, speed: 100)

        #expect(abs(east.position.x - 100) < 0.0001)
        #expect(abs(north.position.y - 75) < 0.0001)
        #expect(abs(north.position.y / east.position.x - 0.75) < 0.0001)
    }

    @Test func projectedTravelTakesEqualTimeInEveryDirection() {
        // One projected unit is one unit of wall-clock cost whichever way the
        // actor faces, which is what lets a single `walkSpeed` describe the gait.
        let horizontalGoal = CGPoint(x: 60, y: 0)
        let verticalGoal = CGPoint(x: 0, y: 45) // 45 / 0.75 == 60 projected

        var horizontal = RouteFollower()
        horizontal.replaceRoute(with: [horizontalGoal], from: .zero)
        let horizontalStep = horizontal.advance(from: .zero, deltaTime: 0.6, speed: 100)

        var vertical = RouteFollower()
        vertical.replaceRoute(with: [verticalGoal], from: .zero)
        let verticalStep = vertical.advance(from: .zero, deltaTime: 0.6, speed: 100)

        #expect(horizontalStep.didArrive)
        #expect(verticalStep.didArrive)
        #expect(horizontalStep.position == horizontalGoal)
        #expect(verticalStep.position == verticalGoal)
    }

    @Test func lookAheadVectorLeadsCornersBeforeArrival() {
        var follower = RouteFollower()
        follower.replaceRoute(
            with: [CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 40)],
            from: .zero
        )
        // Short look-ahead stays on the first segment (east).
        let near = follower.lookAheadVector(from: .zero, minimumDistance: 10)
        #expect(near.dx > 0)
        #expect(abs(near.dy) < 0.0001)

        // 24-unit look-ahead reaches past the corner and includes the north leg.
        let far = follower.lookAheadVector(from: .zero, minimumDistance: 24)
        #expect(far.dx > 0)
        #expect(far.dy > 0)
        #expect(far.dy > near.dy)
    }
}

struct ActorFacingTests {
    @Test func resolvesEveryLogicalSectorCenter() {
        for facing in ActorFacing.allCases {
            let angle = CGFloat(facing.rawValue) * ActorFacing.sectorAngle
            let resolved = ActorFacing.resolve(
                dx: cos(angle),
                dy: sin(angle),
                retaining: .east,
                hysteresis: 0
            )
            #expect(resolved == facing)
        }
    }

    @Test func hysteresisPreventsBoundaryFlicker() {
        let insideDeadBand = CGFloat(13) * .pi / 180
        let beyondDeadBand = CGFloat(16) * .pi / 180

        #expect(ActorFacing.resolve(
            dx: cos(insideDeadBand),
            dy: sin(insideDeadBand),
            retaining: .east
        ) == .east)
        #expect(ActorFacing.resolve(
            dx: cos(beyondDeadBand),
            dy: sin(beyondDeadBand),
            retaining: .east
        ) == .eastNorthEast)
    }

    @Test func hysteresisIsSymmetricAcrossEverySectorBoundary() {
        let hysteresis = ActorFacing.defaultHysteresis
        let inside = ActorFacing.sectorAngle * 0.5 + hysteresis - 0.001
        let outside = ActorFacing.sectorAngle * 0.5 + hysteresis + 0.001

        for facing in ActorFacing.allCases {
            let center = CGFloat(facing.rawValue) * ActorFacing.sectorAngle
            for sign: CGFloat in [-1, 1] {
                let retained = ActorFacing.resolve(
                    dx: cos(center + sign * inside),
                    dy: sin(center + sign * inside),
                    retaining: facing
                )
                #expect(retained == facing)

                let expectedRawValue = (
                    facing.rawValue + (sign > 0 ? 1 : -1) + ActorFacing.allCases.count
                ) % ActorFacing.allCases.count
                let changed = ActorFacing.resolve(
                    dx: cos(center + sign * outside),
                    dy: sin(center + sign * outside),
                    retaining: facing
                )
                #expect(changed.rawValue == expectedRawValue)
            }
        }
    }

    @Test func zeroVelocityRetainsIdleFacing() {
        #expect(ActorFacing.resolve(dx: 0, dy: 0, retaining: .northWest) == .northWest)
    }

    @Test func steppedTurnsOneBinAlongTheShorterArc() {
        // GemRB `GetNextFace`: one 22.5° bin per tick, shorter way round.
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
                while facing != target, steps <= ActorFacing.allCases.count {
                    facing = facing.stepped(toward: target)
                    steps += 1
                }
                #expect(facing == target)
                #expect(steps <= ActorFacing.allCases.count / 2)
            }
        }
    }

    @Test func steppedResolvesAHalfTurnConsistently() {
        // A clean 180° is a tie; the engine breaks it toward the next orientation
        // rather than dithering between the two arcs.
        for start in ActorFacing.allCases {
            let opposite = ActorFacing(
                rawValue: (start.rawValue + ActorFacing.allCases.count / 2)
                    % ActorFacing.allCases.count
            )!
            let expected = ActorFacing(
                rawValue: (start.rawValue + 1) % ActorFacing.allCases.count
            )!
            #expect(start.stepped(toward: opposite) == expected)
        }
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

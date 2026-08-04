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

        #expect(expected.position == CGPoint(x: 30, y: 20))
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
        #expect(redirected.position == CGPoint(x: 30, y: 10))
        #expect(redirected.direction == CGVector(dx: 0, dy: 1))
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

        #expect(step.position == CGPoint(x: 20, y: 20))
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

import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct ActorLocomotionPacingTests {
    @Test func walkSpeedUsesNormalizedHumanoidBaseline() {
        let speed = ActorLocomotionPacing.walkSpeed
        #expect(speed < ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        #expect(speed > 0)
        #expect(ActorLocomotionPacing.walkSpeedBand.contains(speed))
        #expect(ActorLocomotionPacing.infinityEngineHumanoidMoveScale == 9)
    }

    @Test func walkCycleFrameDurationIsSlowerThanLegacyDefaults() {
        let frame = ActorLocomotionPacing.walkCycleSecondsPerFrame
        #expect(frame > ActorLocomotionPacing.legacyDetectiveWalkFrameDuration)
        #expect(frame > ActorLocomotionPacing.legacyClientWalkFrameDuration)
        #expect(ActorLocomotionPacing.walkCycleSecondsPerFrameBand.contains(frame))
    }

    @Test func pathDurationUsesOneConstantMovementRate() {
        let distance: CGFloat = 400
        let shipped = ActorLocomotionPacing.pathDuration(distance: distance)
        let legacyDetective = TimeInterval(distance / ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        #expect(shipped > legacyDetective)
        #expect(abs(shipped - TimeInterval(distance / ActorLocomotionPacing.walkSpeed)) < 0.0001)
    }

    @Test func walkCycleTravelsApproximatelyOneBodyLength() {
        let cycleDuration = ActorLocomotionPacing.walkCycleSecondsPerFrame * 4
        let distancePerCycle = ActorLocomotionPacing.walkSpeed * CGFloat(cycleDuration)
        #expect((75 as CGFloat)...(110 as CGFloat) ~= distancePerCycle)
    }

    @Test func pathDurationUsesWalkSpeedEntryPoint() {
        // Drive the real helper actors call for SKAction.move durations.
        let samples: [CGFloat] = [50, 120, 270, 500]
        for distance in samples {
            let duration = ActorLocomotionPacing.pathDuration(distance: distance)
            #expect(duration >= ActorLocomotionPacing.minimumSegmentDuration)
            #expect(duration >= TimeInterval(distance / ActorLocomotionPacing.walkSpeed) - 0.0001)
            #expect(abs(duration - max(
                ActorLocomotionPacing.minimumSegmentDuration,
                TimeInterval(distance / ActorLocomotionPacing.walkSpeed)
            )) < 0.0001)
        }
    }

    @Test func shortSegmentsClampToMinimumDuration() {
        let tiny = ActorLocomotionPacing.pathDuration(distance: 0.5)
        #expect(tiny == ActorLocomotionPacing.minimumSegmentDuration)
    }

    @Test func standUpFrameDurationSupportsUnhurriedEgress() {
        #expect(ActorLocomotionPacing.standUpSecondsPerFrame > 0.1)
        #expect(ActorLocomotionPacing.standUpSecondsPerFrame < 0.2)
        let twelveFrameStandUp = ActorLocomotionPacing.standUpSecondsPerFrame * 12
        #expect(twelveFrameStandUp > 1.2)
        #expect(twelveFrameStandUp < 2.5)
    }

    @Test func actorsWireDeltaLocomotionAndShippedPacingConstants() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let detective = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Actors/DetectiveActorNode.swift"
            ),
            encoding: .utf8
        )
        let client = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Gameplay/Actors/ClientActorNode.swift"
            ),
            encoding: .utf8
        )

        #expect(detective.contains("RouteFollower"))
        #expect(detective.contains("routeFollower.advance"))
        #expect(detective.contains("func updateLocomotion"))
        #expect(detective.contains("ActorLocomotionPacing.maximumFrameDelta"))
        #expect(detective.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(detective.contains("ActorLocomotionPacing.standUpSecondsPerFrame"))
        #expect(!detective.contains("actions.append(.move(to:"))
        #expect(!detective.contains("withKey: \"actorPath\""))
        #expect(!detective.contains("withKey: \"walkCycle\""))
        #expect(!detective.contains("distance / 270"))
        #expect(!detective.contains("timePerFrame: 0.14"))

        #expect(client.contains("ActorLocomotionPacing.pathDuration"))
        #expect(client.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(!client.contains("distance / 82"))
        #expect(!client.contains("timePerFrame: 0.15"))
    }
}

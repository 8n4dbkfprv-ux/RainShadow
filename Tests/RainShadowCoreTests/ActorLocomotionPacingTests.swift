import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct ActorLocomotionPacingTests {
    @Test func walkSpeedIsSlowerThanLegacyDetectiveAndClientDefaults() {
        let speed = ActorLocomotionPacing.walkSpeed
        #expect(speed < ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        #expect(speed < ActorLocomotionPacing.legacyClientWalkSpeed)
        #expect(ActorLocomotionPacing.walkSpeedBand.contains(speed))
    }

    @Test func walkCycleFrameDurationIsSlowerThanLegacyDefaults() {
        let frame = ActorLocomotionPacing.walkCycleSecondsPerFrame
        #expect(frame > ActorLocomotionPacing.legacyDetectiveWalkFrameDuration)
        #expect(frame > ActorLocomotionPacing.legacyClientWalkFrameDuration)
        #expect(ActorLocomotionPacing.walkCycleSecondsPerFrameBand.contains(frame))
    }

    @Test func pathDurationIsLongerThanLegacyDetectiveFormula() {
        let distance: CGFloat = 400
        let shipped = ActorLocomotionPacing.pathDuration(distance: distance)
        let legacyDetective = TimeInterval(distance / ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        let legacyClient = TimeInterval(distance / ActorLocomotionPacing.legacyClientWalkSpeed)
        #expect(shipped > legacyDetective)
        #expect(shipped > legacyClient)
        #expect(abs(shipped - TimeInterval(distance / ActorLocomotionPacing.walkSpeed)) < 0.0001)
    }

    @Test func pathDurationUsesWalkSpeedEntryPoint() {
        // Drive the real helper actors call for SKAction.move durations.
        let samples: [CGFloat] = [50, 120, 270, 500]
        for distance in samples {
            let duration = ActorLocomotionPacing.pathDuration(distance: distance)
            #expect(duration >= ActorLocomotionPacing.minimumSegmentDuration)
            #expect(duration >= TimeInterval(distance / ActorLocomotionPacing.walkSpeed) - 0.0001)
            // Strictly slower travel than the old detective divisor for any non-trivial leg.
            #expect(duration > TimeInterval(distance / ActorLocomotionPacing.legacyDetectiveWalkSpeed))
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

    @Test func actorsWireShippedPacingConstants() throws {
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

        #expect(detective.contains("ActorLocomotionPacing.pathDuration"))
        #expect(detective.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(detective.contains("ActorLocomotionPacing.standUpSecondsPerFrame"))
        #expect(!detective.contains("distance / 270"))
        #expect(!detective.contains("timePerFrame: 0.14"))

        #expect(client.contains("ActorLocomotionPacing.pathDuration"))
        #expect(client.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(!client.contains("distance / 82"))
        #expect(!client.contains("timePerFrame: 0.15"))
    }
}

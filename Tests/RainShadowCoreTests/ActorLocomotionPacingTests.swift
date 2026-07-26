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

    @Test func walkCycleDurationIsSlowerThanLegacyDefaults() {
        // The V6 gait doubled frame density (8 frames) without changing stride
        // time, so the deliberate pace is asserted on the full cycle duration.
        let frame = ActorLocomotionPacing.walkCycleSecondsPerFrame
        let cycle = frame * TimeInterval(ActorLocomotionPacing.walkFramesPerCycle)
        let legacyDetectiveCycle = ActorLocomotionPacing.legacyDetectiveWalkFrameDuration * 4
        let legacyClientCycle = ActorLocomotionPacing.legacyClientWalkFrameDuration * 4
        #expect(cycle > legacyDetectiveCycle)
        #expect(cycle > legacyClientCycle)
        #expect(ActorLocomotionPacing.walkCycleSecondsPerFrameBand.contains(frame))
        #expect(ActorLocomotionPacing.walkCycleDurationBand.contains(cycle))
        #expect(ActorLocomotionPacing.walkFramesPerCycle == 8)
    }

    @Test func pathDurationUsesOneConstantMovementRate() {
        let distance: CGFloat = 400
        let shipped = ActorLocomotionPacing.pathDuration(distance: distance)
        let legacyDetective = TimeInterval(distance / ActorLocomotionPacing.legacyDetectiveWalkSpeed)
        #expect(shipped > legacyDetective)
        #expect(abs(shipped - TimeInterval(distance / ActorLocomotionPacing.walkSpeed)) < 0.0001)
    }

    @Test func walkCycleTravelsApproximatelyOneBodyLength() {
        let cycleDuration = ActorLocomotionPacing.walkCycleSecondsPerFrame
            * TimeInterval(ActorLocomotionPacing.walkFramesPerCycle)
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
        #expect(detective.contains("var isDeskRegistered"))
        #expect(detective.contains("var shouldHideEmptyDeskChair"))
        #expect(detective.contains("standUpEmptyChairHandoffFrame"))
        #expect(detective.contains("animateSeatTransition"))
        #expect(detective.contains("seatedUpperLocalZ"))
        #expect(!detective.contains("actions.append(.move(to:"))
        #expect(!detective.contains("withKey: \"actorPath\""))
        #expect(!detective.contains("withKey: \"walkCycle\""))
        #expect(!detective.contains("distance / 270"))
        #expect(!detective.contains("timePerFrame: 0.14"))

        let office = try String(
            contentsOf: root.appendingPathComponent(
                "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift"
            ),
            encoding: .utf8
        )
        #expect(office.contains("detective.isDeskRegistered"))
        #expect(office.contains("detective.shouldHideEmptyDeskChair"))
        #expect(office.contains("emptyDeskChairWorldPosition"))
        #expect(!office.contains("deskChairProp?.isHidden = detective.isSeated"))
        #expect(!office.contains("deskChairProp?.isHidden = detective.isDeskRegistered"))

        #expect(client.contains("ActorLocomotionPacing.pathDuration"))
        #expect(client.contains("ActorLocomotionPacing.walkCycleSecondsPerFrame"))
        #expect(client.contains("lila_departure_ne_"))
        #expect(client.contains("lila_departure_nw_"))
        #expect(client.contains("departureFacingBin"))
        #expect(client.contains("startDepartureWalkCycle"))
        // Door handoff: heading-matched strips with a short crossfade (no moonwalk hold).
        #expect(client.contains("stripHandoffDuration"))
        #expect(client.contains("bodyHandoff"))
        #expect(client.contains("crossfade:"))
        #expect(!client.contains("easternHandoffMaxAngle"))
        #expect(!client.contains("currentDepartureWalkFrame"))
        #expect(!client.contains("distance / 82"))
        #expect(!client.contains("timePerFrame: 0.15"))
        // Handbag/light contract: never mirror the client body for eastern bins.
        #expect(!client.contains("body.xScale = -"))
    }
}

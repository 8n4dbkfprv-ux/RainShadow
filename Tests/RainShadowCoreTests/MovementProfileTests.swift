import CoreGraphics
import Testing
@testable import RainShadowCore

/// Per-actor walk rate, expressed as BG:EE expresses it. See `MovementProfile`.
struct MovementProfileTests {
    // MARK: - Inertness

    @Test func humanoidProfileMatchesTheShippedPace() {
        // The whole point of A2 is a data spine, not a retune. If these ever
        // disagree, the profile has drifted away from the derivation that
        // ActorLocomotionPacing documents against the engine constants.
        #expect(MovementProfile.humanoid.moveScale == ActorLocomotionPacing.infinityEngineHumanoidMoveScale)
        #expect(abs(MovementProfile.humanoid.walkSpeed - ActorLocomotionPacing.walkSpeed) < 0.0001)
        #expect(ActorLocomotionPacing.walkSpeedBand.contains(MovementProfile.humanoid.walkSpeed))
    }

    @Test func walkScaleIsFifteenHundredOverTheRate() {
        // Actor::CalculateSpeedFromRate. Types spelled out: inside #expect an
        // integer-literal division defaults to Int, so `1500 / 9` would compare
        // against 166 rather than 166.67 and fail for the wrong reason.
        let expected: CGFloat = 1500 / CGFloat(9)
        #expect(MovementProfile.humanoid.walkScale == expected)
        #expect(MovementProfile(moveScale: 10).walkScale == CGFloat(150))
        #expect(MovementProfile(moveScale: 5).walkScale == CGFloat(300))
    }

    @Test func engineRateBandBracketsTheShippedValue() {
        // EXTSPEED.2da spans 5–10 across every creature in BG:EE.
        #expect(MovementProfile.engineMoveScaleRange.contains(MovementProfile.humanoid.moveScale))
    }

    // MARK: - Higher rate is faster

    @Test func higherMoveScaleWalksFaster() {
        let slow = MovementProfile(moveScale: 5)
        let fast = MovementProfile(moveScale: 10)
        #expect(slow.walkSpeed < MovementProfile.humanoid.walkSpeed)
        #expect(fast.walkSpeed > MovementProfile.humanoid.walkSpeed)
        // Rate maps linearly onto speed, so double the rate is double the pace.
        #expect(abs(fast.walkSpeed - 2 * slow.walkSpeed) < 0.0001)
    }

    // MARK: - Modifier stack

    @Test func hasteDoublesTheRate() {
        let hasted = MovementProfile.humanoid.hastened()
        #expect(abs(hasted.walkSpeed - 2 * MovementProfile.humanoid.walkSpeed) < 0.0001)
        #expect(!hasted.isImmobile)
    }

    @Test func overloadedHalvesAndImmobileStops() {
        // Adventurer's Guide p.43: over the Strength limit halves speed, more than
        // 10% over prevents movement entirely.
        let overloaded = MovementProfile.humanoid.encumbered(.overloaded)
        #expect(abs(overloaded.walkSpeed - MovementProfile.humanoid.walkSpeed / 2) < 0.0001)

        let immobile = MovementProfile.humanoid.encumbered(.immobile)
        #expect(immobile.isImmobile)
        #expect(immobile.walkSpeed == 0)
        #expect(immobile.walkScale == nil)
    }

    @Test func modifiersCompose() {
        let both = MovementProfile.humanoid.encumbered(.overloaded).hastened()
        // Haste on top of an overload nets back to the base pace.
        #expect(abs(both.walkSpeed - MovementProfile.humanoid.walkSpeed) < 0.0001)
    }

    @Test func immobileSurvivesAnyMultiplier() {
        let stuck = MovementProfile.humanoid.encumbered(.immobile).hastened(4)
        #expect(stuck.isImmobile)
        #expect(stuck.walkSpeed == 0)
    }

    // MARK: - Zero speed must hold, not corrupt

    @Test func zeroSpeedHoldsPositionAndKeepsTheRoute() {
        var follower = RouteFollower()
        let route = [CGPoint(x: 100, y: 0), CGPoint(x: 200, y: 0)]
        follower.replaceRoute(with: route, from: .zero)

        let immobile = MovementProfile.humanoid.encumbered(.immobile)
        let step = follower.advance(
            from: .zero,
            deltaTime: LogicTickClock.tickDuration,
            speed: immobile.walkSpeed
        )
        #expect(step.position == .zero)
        #expect(step.didArrive == false)
        // The route is still there — an immobile actor is stalled, not cancelled.
        #expect(follower.waypoints == route)

        // And it resumes intact once the load comes off.
        let resumed = follower.advance(
            from: .zero,
            deltaTime: LogicTickClock.tickDuration,
            speed: MovementProfile.humanoid.walkSpeed
        )
        #expect(resumed.position.x > 0)
    }

    // MARK: - Duration

    @Test func pathDurationNeverFallsBelowOneTick() {
        #expect(MovementProfile.humanoid.pathDuration(distance: 0) >= LogicTickClock.tickDuration)
        let long = MovementProfile.humanoid.pathDuration(distance: 1_000)
        #expect(long > LogicTickClock.tickDuration)
        // Slower rate, longer walk.
        #expect(MovementProfile(moveScale: 5).pathDuration(distance: 1_000) > long)
    }
}

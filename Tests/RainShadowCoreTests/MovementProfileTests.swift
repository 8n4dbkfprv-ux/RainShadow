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
        // Rate reaches the actor through `NormalizeDeltas`, which rounds each
        // axis up to a whole unit, so a halved rate cannot halve the stride
        // exactly — 6.79 -> 7 becomes 3.40 -> 4. What must hold is the ordering
        // and the halved `walkScale` the step is computed from.
        #expect(overloaded.walkScale == (MovementProfile.humanoid.walkScale ?? 0) * 2)
        #expect(overloaded.walkSpeed < MovementProfile.humanoid.walkSpeed)
        #expect(overloaded.walkSpeed > MovementProfile.humanoid.walkSpeed / 2)

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
        let map = MovableTestSupport.openMap()
        var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
        walker.walkTo(CGPoint(x: 200, y: 30), ticks: 1)
        #expect(walker.isMoving)
        let route = walker.remainingPoints

        // `DoStep`'s zero-speed branch: stamp the tick, take the ready stance,
        // and return without touching the path.
        let immobile = MovementProfile.humanoid.encumbered(.immobile)
        let stalled = walker.doStep(walkScale: immobile.walkScale ?? 0, time: 2)
        #expect(!stalled.moved)
        #expect(!stalled.arrived)
        // The route is still there — an immobile actor is stalled, not cancelled.
        #expect(walker.remainingPoints == route)
        #expect(walker.isMoving)

        // And it resumes intact once the load comes off.
        let resumed = walker.doStep(
            walkScale: MovementProfile.humanoid.walkScale ?? 0,
            time: 3
        )
        #expect(resumed.moved)
        #expect(walker.position.x > 24)
    }

    // MARK: - Rate

    /// Rate is felt through `NormalizeDeltas`, not through a scalar speed: a
    /// slower profile takes a shorter step each tick, so the same distance costs
    /// more ticks.
    @Test func aSlowerProfileTakesMoreTicksToCoverTheSameGround() {
        func ticksToCross(_ profile: MovementProfile) -> Int {
            let map = MovableTestSupport.openMap()
            var walker = MovableTestSupport.movable(on: map, at: CGPoint(x: 24, y: 30))
            walker.walkTo(CGPoint(x: 360, y: 30), ticks: 1)
            var ticks = 0
            for tick in 2...400 where walker.isMoving {
                walker.doStep(walkScale: profile.walkScale ?? 0, time: tick)
                ticks += 1
            }
            return ticks
        }

        let standard = ticksToCross(.humanoid)
        let slow = ticksToCross(MovementProfile(moveScale: 5))
        #expect(standard > 0)
        #expect(slow > standard, "moveScale 5 should be slower than the default 9")
    }
}

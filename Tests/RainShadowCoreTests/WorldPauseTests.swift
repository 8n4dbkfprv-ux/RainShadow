import CoreGraphics
import Testing
@testable import RainShadowCore

/// BG:EE tactical pause. See `WorldPauseController`.
struct WorldPauseTests {
    @Test func startsRunning() {
        let pause = WorldPauseController()
        #expect(!pause.isPaused)
        #expect(!pause.isPausedByPlayer)
    }

    @Test func spaceTogglesThePlayerFreeze() {
        var pause = WorldPauseController()
        #expect(pause.togglePlayerPause() == true)
        #expect(pause.isPaused)
        #expect(pause.isPausedByPlayer)
        #expect(pause.togglePlayerPause() == false)
        #expect(!pause.isPaused)
    }

    @Test func closingAnOverlayDoesNotStealThePlayersPause() {
        // The bug this type exists to make impossible: the freeze was a boolean
        // expression over overlay flags, so anything that recomputed it dropped a
        // pause the player had asked for.
        var pause = WorldPauseController()
        pause.togglePlayerPause()
        pause.setModal(dialogue: false, overlay: true)
        #expect(pause.isPaused)

        pause.setModal(dialogue: false, overlay: false)
        #expect(pause.isPaused, "closing the overlay released the player's pause")
        #expect(pause.isPausedByPlayer)
    }

    @Test func dialogueAndOverlaysFreezeWithoutClaimingPlayerOwnership() {
        var pause = WorldPauseController()
        pause.setModal(dialogue: true, overlay: false)
        #expect(pause.isPaused)
        // Only the player's own freeze recolours the world / lights the clock.
        #expect(!pause.isPausedByPlayer)

        pause.setModal(dialogue: false, overlay: false)
        #expect(!pause.isPaused)
    }

    @Test func clearingThePlayerPauseLeavesModalFreezesAlone() {
        var pause = WorldPauseController()
        pause.setModal(dialogue: true, overlay: false)
        pause.togglePlayerPause()
        pause.clearPlayerPause()
        #expect(pause.isPaused)
        #expect(!pause.isPausedByPlayer)
    }

    // MARK: - Orders survive the freeze

    @Test func routeIssuedWhileFrozenIsWalkedOnResume() {
        // The whole point of a tactical pause: issue orders into a stopped world.
        // Locomotion is gated on the freeze, so a route set while paused simply
        // waits — this pins that it waits *intact* rather than being consumed.
        var follower = RouteFollower()
        let goal = CGPoint(x: 120, y: 0)
        follower.replaceRoute(with: [goal], from: .zero)

        var clock = LogicTickClock()
        var position = CGPoint.zero
        var pause = WorldPauseController()
        pause.togglePlayerPause()

        // Ten frames of a paused world: the scene never drains the clock.
        for _ in 0..<10 where !pause.isPaused {
            for _ in 0..<clock.drain(deltaTime: 1.0 / 60) {
                position = follower.advance(
                    from: position,
                    deltaTime: LogicTickClock.tickDuration,
                    speed: MovementProfile.humanoid.walkSpeed
                ).position
            }
        }
        #expect(position == .zero)
        #expect(follower.isMoving)
        #expect(follower.destination == goal)

        // Unpause, and the queued order walks.
        pause.togglePlayerPause()
        clock.reset()
        for _ in 0..<10 where !pause.isPaused {
            for _ in 0..<clock.drain(deltaTime: 1.0 / 60) {
                position = follower.advance(
                    from: position,
                    deltaTime: LogicTickClock.tickDuration,
                    speed: MovementProfile.humanoid.walkSpeed
                ).position
            }
        }
        #expect(position.x > 0)
    }

    @Test func resettingTheClockOnResumeDropsTheStaleRemainder() {
        // LogicTickClock keeps a sub-tick remainder so a 60 Hz render loop does
        // not lose steps. Across a pause that remainder is stale: without the
        // reset the actor takes a step on the frame the player unfreezes.
        var clock = LogicTickClock()
        // Three 60 Hz frames = 0.05s, just under one 15 Hz tick (0.0667s).
        for _ in 0..<3 { #expect(clock.drain(deltaTime: 1.0 / 60) == 0) }
        var withoutReset = clock
        #expect(withoutReset.drain(deltaTime: 1.0 / 60) == 1)

        clock.reset()
        #expect(clock.drain(deltaTime: 1.0 / 60) == 0)
    }
}

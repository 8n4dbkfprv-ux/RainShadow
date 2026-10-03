import Testing
@testable import RainShadowCore

struct IEActorAnimationTests {
    @Test func frameBoundaryUsesGemRBIntegerMilliseconds() {
        var clip = IEActorAnimation()
        clip.advance(frameCount: 10, milliseconds: 1000, paused: false)
        #expect(clip.frameIndex == 0)
        clip.advance(frameCount: 10, milliseconds: 1065, paused: false)
        #expect(clip.frameIndex == 0)
        clip.advance(frameCount: 10, milliseconds: 1066, paused: false)
        #expect(clip.frameIndex == 1)
    }

    @Test func delayedDrawCatchesUpAndDiscardsTheRemainder() {
        var clip = IEActorAnimation()
        clip.advance(frameCount: 10, milliseconds: 1000, paused: false)
        clip.advance(frameCount: 10, milliseconds: 1200, paused: false)
        #expect(clip.frameIndex == 3)
        clip.advance(frameCount: 10, milliseconds: 1264, paused: false)
        #expect(clip.frameIndex == 3) // 2ms were discarded, not carried over.
        clip.advance(frameCount: 10, milliseconds: 1266, paused: false)
        #expect(clip.frameIndex == 4)
    }

    @Test func pausePreservesFrameAndPartialFrameTime() {
        var clip = IEActorAnimation()
        clip.advance(frameCount: 10, milliseconds: 1000, paused: false)
        clip.advance(frameCount: 10, milliseconds: 1100, paused: false)
        clip.advance(frameCount: 10, milliseconds: 1130, paused: false)
        clip.advance(frameCount: 10, milliseconds: 2000, paused: true)
        clip.advance(frameCount: 10, milliseconds: 9000, paused: true)
        #expect(clip.frameIndex == 1)
        clip.advance(frameCount: 10, milliseconds: 10000, paused: false)
        #expect(clip.frameIndex == 1)
        clip.advance(frameCount: 10, milliseconds: 10035, paused: false)
        #expect(clip.frameIndex == 1)
        clip.advance(frameCount: 10, milliseconds: 10036, paused: false)
        #expect(clip.frameIndex == 2)
    }

    @Test func aClipFirstSeenWhilePausedStartsAtZeroOnResume() {
        var clip = IEActorAnimation()
        clip.advance(frameCount: 10, milliseconds: 1000, paused: true)
        clip.advance(frameCount: 10, milliseconds: 9000, paused: false)
        #expect(clip.frameIndex == 0)
        clip.advance(frameCount: 10, milliseconds: 9066, paused: false)
        #expect(clip.frameIndex == 1)
    }

    @Test func clipLengthComesFromTheSelectedArtNotTheLegacyEightFrameConstant() {
        var voss = IEActorAnimation()
        var lila = IEActorAnimation()
        for time: UInt64 in [1000, 1594, 1660] {
            voss.advance(frameCount: VossAnimationSet.walkFrames, milliseconds: time, paused: false)
            lila.advance(frameCount: ActorLocomotionPacing.walkFramesPerCycle, milliseconds: time, paused: false)
            if time == 1594 {
                #expect(voss.frameIndex == 9)
                #expect(lila.frameIndex == 1)
            }
        }
        #expect(voss.frameIndex == 0)
        #expect(lila.frameIndex == 2)
    }

    @Test func eachStanceAndDirectionKeepsItsOwnCachedClock() {
        var playback = IEActorAnimationPlayback()
        #expect(playback.frame(for: "walk.s", count: 10, at: 1, paused: false) == 0)
        #expect(playback.frame(for: "walk.s", count: 10, at: 1.2, paused: false) == 3)
        #expect(playback.frame(for: "walk.n", count: 10, at: 1.2, paused: false) == 0)
        #expect(playback.frame(for: "ready.n", count: 65, at: 1.2, paused: false) == 0)
        #expect(playback.frame(for: "ready.n", count: 65, at: 1.4, paused: false) == 3)
        // Cached walk.s resumes its own timer, not ready.n's phase or frame zero.
        #expect(playback.frame(for: "walk.s", count: 10, at: 1.4, paused: false) == 6)
    }

    @Test func drawingAdvancesWithoutAnyMovementTicks() {
        var playback = IEActorAnimationPlayback()
        #expect(playback.frame(for: "ready.s", count: 65, at: 1, paused: false) == 0)
        #expect(playback.frame(for: "ready.s", count: 65, at: 1.33, paused: false) == 5)
        #expect(playback.frame(for: "idle.s", count: 65, at: 1.33, paused: false) == 0)
        #expect(playback.frame(for: "idle.s", count: 65, at: 1.66, paused: false) == 5)
    }

    @Test func clientStripSelectionConsumesTheStoredOrientation() {
        for facing in ActorFacing.allCases {
            let western: Set<ActorFacing> = [.northWest, .northNorthWest, .westNorthWest, .west, .westSouthWest, .north]
            #expect(ClientDepartureFacing.bin(facing: facing) == (western.contains(facing) ? .northWest : .northEast))
        }
    }
}

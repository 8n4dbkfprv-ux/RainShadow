import Foundation

/// GemRB Animation::NextFrame (1c45c185), for looping creature clips.
/// Animation advances at drawing time, independently of Movable::DoStep.
/// CharAnimations caches a separate Animation for each stance/orientation.
struct IEActorAnimation {
    static let framesPerSecond = 15
    private(set) var frameIndex = 0
    private var startTime: UInt64 = 0
    private var lastTime: UInt64 = 0
    private var wasPaused = false

    mutating func advance(frameCount: Int, milliseconds: UInt64, paused: Bool) {
        precondition(frameCount > 0)
        // `tick_t delta = 1000 / fps`, including integer millisecond truncation.
        let duration = UInt64(1000 / Self.framesPerSecond)
        let time: UInt64
        if paused {
            time = lastTime
            wasPaused = true
        } else {
            time = milliseconds
            if wasPaused {
                wasPaused = false
                startTime += time - lastTime
            }
            lastTime = time
        }
        if startTime == 0 { startTime = time }
        // GemRB catches up multiple frames, then discards the fractional remainder:
        // `frameIdx += inc; starttime = time;` (not starttime += inc * delta).
        if time >= startTime, time - startTime >= duration {
            let increment = (time - startTime) / duration
            frameIndex = (frameIndex + Int(increment % UInt64(frameCount))) % frameCount
            startTime = time
        }
    }
}

/// Indexed-art adapter for CharAnimations::Anims[stanceID][Orient]. Keys name
/// authored clips; cached clips retain their own frame and timer on re-entry.
struct IEActorAnimationPlayback {
    private var clips: [String: IEActorAnimation] = [:]

    func currentFrame(for key: String) -> Int { clips[key]?.frameIndex ?? 0 }

    mutating func frame(for key: String, count: Int, at time: TimeInterval, paused: Bool) -> Int {
        var clip = clips[key] ?? IEActorAnimation()
        clip.advance(frameCount: count, milliseconds: UInt64(max(0, time) * 1000), paused: paused)
        clips[key] = clip
        return clip.frameIndex
    }
}

import Foundation

/// Fixed-rate logic clock matching the Infinity Engine's game tick.
///
/// BG:EE runs gameplay logic on a fixed 15 Hz tick (GemRB `Interface.h`,
/// `defaultTicksPerSec = 15`). Both halves of locomotion advance exactly one
/// step per tick: `Movable::DoStep` emits one displacement, and the creature
/// animation advances one frame. That coupling is the structural reason the BG
/// gait never desynchronises from travel — there is no separate animation
/// timer to drift against.
///
/// Wall-clock delta accumulates here and is drained in whole ticks so the
/// render frame rate never leaks into movement or the walk cycle.
struct LogicTickClock {
    /// One Infinity Engine game tick.
    static let ticksPerSecond: TimeInterval = 15
    static let tickDuration: TimeInterval = 1 / ticksPerSecond

    private var accumulator: TimeInterval = 0

    /// Whole ticks elapsed for `deltaTime`, retaining the sub-tick remainder.
    ///
    /// The remainder is what keeps the clock exact: a 60 Hz render loop feeds
    /// 0.0167 s per call and drains one tick every fourth frame rather than
    /// rounding each frame to zero.
    mutating func drain(deltaTime: TimeInterval) -> Int {
        guard deltaTime > 0 else { return 0 }
        accumulator += deltaTime

        // Repeatedly subtracting `tickDuration` leaves the remainder a hair below
        // where exact arithmetic would put it. Without this tolerance an
        // accumulator sitting a few ULPs under a whole tick silently withholds a
        // step, and the actor drifts imperceptibly behind wall-clock time.
        let epsilon = Self.tickDuration * 1e-9
        guard accumulator + epsilon >= Self.tickDuration else { return 0 }

        let ticks = Int((accumulator + epsilon) / Self.tickDuration)
        accumulator = max(0, accumulator - TimeInterval(ticks) * Self.tickDuration)
        return ticks
    }

    /// Drops the partial tick. Used when locomotion resumes after a pause or a
    /// seat handoff so a stale remainder cannot spend an extra step.
    mutating func reset() {
        accumulator = 0
    }
}

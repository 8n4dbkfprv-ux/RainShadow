import CoreGraphics
import Foundation

/// Shared walk pace for office/world actors, derived from the Infinity Engine's
/// own movement arithmetic rather than tuned by eye.
///
/// GemRB (the maintained open-source reimplementation of the engine BG:EE runs
/// on) computes a walking step like this:
///
///     walkScale  = 1500 / IE_MOVEMENTRATE      Actor::CalculateSpeedFromRate
///     factor     = StepTime / walkScale        Movable::DoStep
///     step       = normalize(toNextNode) * STEP_RADIUS
///     step.y    *= 0.75                        Map::NormalizeDeltas
///     position  += step * factor               once per 15 Hz tick
///
/// With the shipped BG defaults — `IE_MOVEMENTRATE = 9` for an ordinary
/// humanoid, `StepTime = 566`, `STEP_RADIUS = 2.0` — that is 6.79 px/tick
/// horizontally and 5.09 px/tick vertically, or 101.9 and 76.4 px/s. BG1 draws
/// a standing adult in roughly 50 native rows, so the gait is ~2.04 body
/// heights per second horizontally. Everything below follows from those five
/// engine constants, so the pace stays correct at any sprite size.
enum ActorLocomotionPacing {
    // MARK: - Prior defaults (regression anchors for tests)

    /// Previous detective path speed (world units per second).
    static let legacyDetectiveWalkSpeed: CGFloat = 270
    /// Previous detective walk-cycle seconds per frame.
    static let legacyDetectiveWalkFrameDuration: TimeInterval = 0.14
    /// Previous client path speed (world units per second).
    static let legacyClientWalkSpeed: CGFloat = 82
    /// Previous client walk-cycle seconds per frame.
    static let legacyClientWalkFrameDuration: TimeInterval = 0.15

    // MARK: - Infinity Engine movement constants

    /// Game logic tick rate; GemRB `Interface.h`, `defaultTicksPerSec`.
    static let logicTicksPerSecond: CGFloat = CGFloat(LogicTickClock.ticksPerSecond)

    /// `StepTime` from the game INI, defaulting to BG2's value in GemRB
    /// `Interface.cpp`. Divided by the walk scale it yields the per-tick step
    /// multiplier.
    static let infinityEngineStepTime: CGFloat = 566

    /// `IE_MOVEMENTRATE` for an ordinary humanoid; GemRB `Actor.cpp` sets this
    /// as the base before `moverate.2da` overrides per creature.
    static let infinityEngineHumanoidMoveScale: CGFloat = 9

    /// `STEP_RADIUS` in GemRB `Map::NormalizeDeltas` — the length every step
    /// vector is normalized to before the perspective squash.
    static let stepRadius: CGFloat = 2

    /// Vertical foreshortening applied to every step vector by
    /// `Map::NormalizeDeltas`. Walking north covers 0.75 screen units for each
    /// one covered walking east, which is the same 12/16 ratio as the search
    /// map cell (`SearchMap.defaultCellSize`).
    static let verticalProjectionScale: CGFloat = 0.75

    /// Height in native pixels of a BG1 standing adult, the denominator that
    /// makes the engine's pixel rate scale-free. See
    /// `Documentation/PaperdollBGEESpriteRedoPlanV14.md`.
    static let infinityEngineBodyPixels: CGFloat = 50

    // MARK: - Derived pace

    /// `1500 / IE_MOVEMENTRATE`; larger means slower, as in the engine.
    static var infinityEngineWalkScale: CGFloat {
        1500 / infinityEngineHumanoidMoveScale
    }

    /// Per-tick step multiplier, `StepTime / walkScale`.
    static var stepFactor: CGFloat {
        infinityEngineStepTime / infinityEngineWalkScale
    }

    /// BG:EE gait in body-heights per second along the unforeshortened axis —
    /// the scale-free half of the contract.
    static var walkBodyHeightsPerSecond: CGFloat {
        stepRadius * stepFactor * logicTicksPerSecond / infinityEngineBodyPixels
    }

    /// Projected world-space speed, derived from the adult **as drawn on
    /// screen**. Deriving rather than hard-coding keeps the pace correct if the
    /// sprite is ever rebaked at a different body height.
    ///
    /// This is a speed in the *projected* metric: one projected unit costs the
    /// same wall-clock time in every direction. See `projectedDistance`.
    static var walkSpeed: CGFloat {
        walkBodyHeightsPerSecond * OfficeInteriorScale.standingAdultBodyHeight
    }

    /// Inclusive acceptance band for `walkSpeed` (used by tests).
    static let walkSpeedBand: ClosedRange<CGFloat> = 140...180

    // MARK: - Projected travel metric

    /// Screen-space distance in the metric the engine actually walks.
    ///
    /// Because `Map::NormalizeDeltas` shrinks the y component of every step to
    /// 0.75, covering a given screen distance vertically takes 1/0.75 as long
    /// as covering it horizontally. Measuring travel as `hypot(dx, dy / 0.75)`
    /// makes one unit cost the same time in every direction, so a single
    /// `walkSpeed` still describes the whole gait.
    static func projectedDistance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        hypot(end.x - start.x, (end.y - start.y) / verticalProjectionScale)
    }

    // MARK: - Animation

    /// V6 BGEE-density gait: 8 authored frames per cycle for every walking actor.
    static let walkFramesPerCycle = 8

    /// One authored frame per logic tick, as in the engine: creature animations
    /// advance a frame each time `DoStep` emits a displacement, which is why a
    /// BG walk cycle cannot drift against the distance travelled.
    static let walkCycleSecondsPerFrame: TimeInterval = LogicTickClock.tickDuration

    /// Inclusive acceptance band for walk-cycle frame duration.
    static let walkCycleSecondsPerFrameBand: ClosedRange<TimeInterval> = 0.06...0.075

    /// Inclusive acceptance band for the full walk-cycle duration (all frames).
    static let walkCycleDurationBand: ClosedRange<TimeInterval> = 0.48...0.60

    /// Stand-up sequence frame hold (12 frames); slightly slower than the old 0.1s
    /// so egress does not snap relative to the new walk.
    static let standUpSecondsPerFrame: TimeInterval = 0.13

    /// Minimum duration for any path segment (avoids zero-length pops). One
    /// logic tick is the shortest interval the engine can express.
    static let minimumSegmentDuration: TimeInterval = LogicTickClock.tickDuration

    /// Prevents a foreground/background or modal resume from spending an entire
    /// stale wall-clock delta in one visible frame.
    static let maximumFrameDelta: TimeInterval = 0.10

    /// Duration for a path segment of the given projected length.
    static func pathDuration(distance: CGFloat) -> TimeInterval {
        TimeInterval(max(CGFloat(minimumSegmentDuration), distance / walkSpeed))
    }
}

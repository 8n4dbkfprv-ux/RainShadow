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

    /// `personal_space` for a humanoid, read out of BG:EE's own animation data
    /// (`6100.ini` and every other character animation in `CHAAnim.bif`):
    ///
    ///     [general]
    ///     move_scale=9        ; = IE_MOVEMENTRATE
    ///     ellipse=16          ; the drawn ground circle — a different number
    ///     personal_space=3    ; the pathing footprint, in search-map cells
    ///
    /// `ellipse` and `personal_space` are separate fields for separate jobs; only
    /// this one is navigation.
    static let infinityEnginePersonalSpaceCells: CGFloat = 3

    // MARK: - Derived pace

    /// `1500 / IE_MOVEMENTRATE`; larger means slower, as in the engine.
    static var infinityEngineWalkScale: CGFloat {
        1500 / infinityEngineHumanoidMoveScale
    }

    /// Per-tick step multiplier, `StepTime / walkScale`.
    static var stepFactor: CGFloat {
        infinityEngineStepTime / infinityEngineWalkScale
    }

    /// What an ordinary humanoid actually covers in one tick walking due east.
    ///
    /// The arithmetic gives 6.79, but `NormalizeDeltas` rounds each axis **up**
    /// to a whole unit, so the engine's real horizontal stride is 7. Every pace
    /// figure below is taken after that rounding, because that is what the game
    /// does — deriving from the un-rounded 6.79 describes a gait no Infinity
    /// Engine creature has ever walked.
    static var horizontalStepPerTick: CGFloat {
        (stepRadius * stepFactor).rounded(.up)
    }

    /// The same, walking due north. 5.09 rounds up to 6, which is why the
    /// engine's *effective* vertical ratio is 6/7 - about 0.857 - rather than
    /// the 0.75 `NormalizeDeltas` multiplies by.
    static var verticalStepPerTick: CGFloat {
        (stepRadius * stepFactor * verticalProjectionScale).rounded(.up)
    }

    /// Horizontal gait in world units per second - 105 with BG:EE's defaults.
    ///
    /// This is no longer the quantity movement is computed from; `Movable.doStep`
    /// asks `PathFinder.normalizeDeltas` for a step and takes it. It survives
    /// because a few things genuinely need a scalar rate: camera scroll speeds
    /// (`Cutscene.ScrollSpeed`) and tests that want to state the pace.
    ///
    /// Note what quantisation costs. The old derivation was scale-free, phrased
    /// in body heights so a sprite rebake could not invalidate it. A whole-unit
    /// step cannot be. The actor now covers 7 world units per tick whatever size
    /// it is drawn - 7/16 of a search cell, exactly BG's stride in cell terms,
    /// and a slower-looking gait than BG only because our adult is drawn 1.4x
    /// taller against the same cell.
    static var walkSpeed: CGFloat {
        horizontalStepPerTick * logicTicksPerSecond
    }

    /// Inclusive acceptance band for `walkSpeed` (used by tests).
    static let walkSpeedBand: ClosedRange<CGFloat> = 100...110

    /// Humanoid personal space in *our* search-map cells.
    ///
    /// The engine's `3` cannot be copied across literally. BG measures 16x12 px
    /// cells against a ~50px adult; RainShadow measures 16x12 world-unit cells
    /// against a `standingAdultBodyHeight` of ~70, so its cells are relatively
    /// ~1.4x finer and a literal `3` would draw a footprint 1.4x too small
    /// against the body walking around inside it.
    ///
    /// Scaling the *radius* (`personalSpace - 1`) rather than the raw field is
    /// what keeps the derivation honest, and it lands on 4. Checked against the
    /// engine rather than assumed: BG's minimum centre-to-centre gap between two
    /// humans is test(1) + paint(2) = 3 cells = 48px = 0.96 body heights; at 4
    /// this yields test(2) + paint(3) = 5 cells = 80 units = 1.14 body heights,
    /// a little roomier than BG. The literal 3 would give 0.68 - materially
    /// tighter than the engine, in a direction that reads as actors clipping.
    static var personalSpaceCells: Int {
        let scaled = (infinityEnginePersonalSpaceCells - 1)
            * (OfficeInteriorScale.standingAdultBodyHeight / infinityEngineBodyPixels)
        return Int(scaled.rounded()) + 1
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
}

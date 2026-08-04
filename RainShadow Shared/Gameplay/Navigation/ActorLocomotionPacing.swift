import CoreGraphics
import Foundation

/// Shared walk pace for office/world actors, calibrated to Baldur's Gate:EE
/// on-screen humanoid walk energy.
///
/// BG:EE documents `move_scale = 9` for ordinary humanoids. That value is
/// animation-relative (9 px/tick × 15 AI ticks/s ≈ 135 px/s on ~55 px sprites),
/// which reads as roughly 2.2–2.7 body heights per second on screen. RainShadow
/// mirrors that feel on its 100-unit actor rather than treating `9` as world
/// units per second.
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

    // MARK: - BG-inspired normalized baseline

    /// Engine-relative ordinary humanoid movement baseline documented by BG:EE.
    static let infinityEngineHumanoidMoveScale: CGFloat = 9

    /// Projected world-space speed. At a 100-unit body this is 2.25 body heights
    /// per second — BG:EE parity, not the former deliberate 1.2 heights/s amble.
    static let walkSpeed: CGFloat = 225

    /// Inclusive acceptance band for `walkSpeed` (used by tests).
    static let walkSpeedBand: ClosedRange<CGFloat> = 195...260

    /// V6 BGEE-density gait: 8 authored frames per cycle for every walking actor.
    static let walkFramesPerCycle = 8

    /// Eight frames at 0.048s keep ~86.4 units of travel per cycle at 225 u/s,
    /// so stride length and foot-to-ground alignment match the prior 120 u/s /
    /// 0.09s gait while the on-screen pace matches BG:EE.
    static let walkCycleSecondsPerFrame: TimeInterval = 0.048

    /// Inclusive acceptance band for walk-cycle frame duration.
    static let walkCycleSecondsPerFrameBand: ClosedRange<TimeInterval> = 0.04...0.06

    /// Inclusive acceptance band for the full walk-cycle duration (all frames).
    static let walkCycleDurationBand: ClosedRange<TimeInterval> = 0.32...0.46

    /// Stand-up sequence frame hold (12 frames); slightly slower than the old 0.1s
    /// so egress does not snap relative to the new walk.
    static let standUpSecondsPerFrame: TimeInterval = 0.13

    /// Minimum duration for any path segment (avoids zero-length pops).
    static let minimumSegmentDuration: TimeInterval = 0.08

    /// Prevents a foreground/background or modal resume from spending an entire
    /// stale wall-clock delta in one visible frame.
    static let maximumFrameDelta: TimeInterval = 0.10

    /// Duration for a path segment of the given world-space length.
    static func pathDuration(distance: CGFloat) -> TimeInterval {
        TimeInterval(max(CGFloat(minimumSegmentDuration), distance / walkSpeed))
    }
}

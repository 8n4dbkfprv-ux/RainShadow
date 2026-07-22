import CoreGraphics
import Foundation

/// Shared walk pace for office/world actors, normalized around the Infinity
/// Engine's ordinary humanoid walk rather than treating its data value (`9`) as
/// world units per second.
///
/// BG:EE exposes movement as an animation-relative scale and applies modifiers
/// such as Haste on top. RainShadow therefore defines its ordinary walk as 1.0,
/// then calibrates that baseline to its 100-unit actor and four-frame gait.
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
    /// It is metadata, not a world-units-per-second conversion.
    static let infinityEngineHumanoidMoveScale: CGFloat = 9

    /// Projected world-space speed. At a 100-unit body this is 1.2 body heights
    /// per second: deliberate, but without the slow shuffle of the former 75 u/s.
    static let walkSpeed: CGFloat = 120

    /// Inclusive acceptance band for `walkSpeed` (used by tests).
    static let walkSpeedBand: ClosedRange<CGFloat> = 100...160

    /// Four frames produce a 0.72-second gait and travel 86.4 units per cycle,
    /// keeping the feet approximately aligned with one actor-length of travel.
    static let walkCycleSecondsPerFrame: TimeInterval = 0.18

    /// Inclusive acceptance band for walk-cycle frame duration.
    static let walkCycleSecondsPerFrameBand: ClosedRange<TimeInterval> = 0.15...0.22

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

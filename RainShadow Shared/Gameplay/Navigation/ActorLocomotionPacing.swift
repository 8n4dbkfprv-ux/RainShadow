import CoreGraphics
import Foundation

/// Shared walk pace for office/world actors, tuned to classic Baldur's Gate /
/// Infinity Engine party walk: deliberate point-and-click CRPG locomotion rather
/// than a modern jog.
///
/// Reference notes:
/// - Infinity Engine creature anims commonly draw near ~15 fps as a baseline,
///   but BG1 / BG:EE *party walk* reads slower and heavier than that full rate
///   on 4-frame walk cycles — hold each frame longer so the stride feels planted.
/// - Prior RainShadow defaults (detective `270` world-u/s @ `0.14` s/frame;
///   client `82` u/s @ `0.15` s/frame) read as a dash relative to a ~100px body.
///   These bands sit strictly slower than those defaults.
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

    // MARK: - Shipped BG-like bands

    /// World-space walk speed (units/second). About ~0.75 body-heights per second
    /// for the 100px detective, matching unhurried BG:EE party cross-room pace.
    static let walkSpeed: CGFloat = 75

    /// Inclusive acceptance band for `walkSpeed` (used by tests).
    static let walkSpeedBand: ClosedRange<CGFloat> = 55...110

    /// Seconds each walk-cycle frame is held. Four frames → ~0.8s full stride.
    static let walkCycleSecondsPerFrame: TimeInterval = 0.20

    /// Inclusive acceptance band for walk-cycle frame duration.
    static let walkCycleSecondsPerFrameBand: ClosedRange<TimeInterval> = 0.16...0.28

    /// Stand-up sequence frame hold (12 frames); slightly slower than the old 0.1s
    /// so egress does not snap relative to the new walk.
    static let standUpSecondsPerFrame: TimeInterval = 0.13

    /// Minimum duration for any path segment (avoids zero-length pops).
    static let minimumSegmentDuration: TimeInterval = 0.08

    /// Duration for a path segment of the given world-space length.
    static func pathDuration(distance: CGFloat) -> TimeInterval {
        TimeInterval(max(CGFloat(minimumSegmentDuration), distance / walkSpeed))
    }
}

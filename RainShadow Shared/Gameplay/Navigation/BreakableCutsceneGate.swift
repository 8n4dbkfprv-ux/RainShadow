import Foundation

/// Why a breakable cutscene ended. Skip and natural finish must apply the same
/// terminal game state; only presentation timing differs.
public enum CutsceneCompletionReason: String, Equatable, Sendable {
    case natural
    case skipped

    /// Presentation-only: a cutscene the user broke cuts straight to its terminal
    /// pose instead of playing the authored ease into it. Waiting the walk out and
    /// pressing Escape must still land on the *same* state — only how long the
    /// chrome takes to get there differs.
    public func chromeDuration(_ natural: TimeInterval) -> TimeInterval {
        self == .skipped ? 0 : natural
    }
}

/// BG:EE-style breakable cutscene gate: optional ESC/tap skip after a grace
/// window, with a single completion that cannot double-fire.
///
/// Pure value type, owned by `CutsceneRunner`. It answers *whether* a sequence
/// may be broken and *that* it ended exactly once; the cue list answers what
/// state it ends in.
///
/// It used to sit next to a `ClientEntranceTerminalState` describing, by hand,
/// the state both the skip and the natural finish had to produce. That type is
/// gone: a skip now replays the remaining cues in zero-duration terminal form,
/// so the two paths cannot drift apart in the first place.
public struct BreakableCutsceneGate: Equatable, Sendable {
    public var isActive: Bool
    public var isCompleted: Bool
    public var startedAt: TimeInterval
    /// Seconds after `startedAt` before skip is accepted (exterior uses 1.0).
    public var graceSeconds: TimeInterval
    /// BG:EE `SetCutSceneBreakable(1/0)`. Breakability is a per-sequence content
    /// flag in the Infinity Engine, not a universal rule — a non-breakable gate
    /// still single-fires its completion, it just refuses skip.
    public var isBreakable: Bool
    /// BG:EE `CutSceneBroken()` — "returns true if a breakable cutscene has been
    /// terminated by the user". Readable after completion so the terminal apply
    /// can cut instead of ease. It must never change *what* state is applied.
    public private(set) var wasBroken: Bool

    public static let defaultGraceSeconds: TimeInterval = 1.0

    public init(
        isActive: Bool = false,
        isCompleted: Bool = false,
        startedAt: TimeInterval = 0,
        graceSeconds: TimeInterval = BreakableCutsceneGate.defaultGraceSeconds,
        isBreakable: Bool = true,
        wasBroken: Bool = false
    ) {
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.startedAt = startedAt
        self.graceSeconds = graceSeconds
        self.isBreakable = isBreakable
        self.wasBroken = wasBroken
    }

    /// Arms a new sequence. Resets completion and the broken flag.
    public mutating func begin(
        at now: TimeInterval,
        graceSeconds: TimeInterval? = nil,
        breakable: Bool = true
    ) {
        isActive = true
        isCompleted = false
        wasBroken = false
        startedAt = now
        isBreakable = breakable
        if let graceSeconds {
            self.graceSeconds = graceSeconds
        }
    }

    /// True when the sequence is running, was armed breakable, and the grace
    /// window has elapsed.
    public func canSkip(at now: TimeInterval) -> Bool {
        isActive && isBreakable && !isCompleted && now >= startedAt + graceSeconds
    }

    /// Marks the sequence finished. Returns `true` only on the first completion
    /// (natural or skip) so callers share one terminal apply path.
    @discardableResult
    public mutating func markCompleted(reason: CutsceneCompletionReason = .natural) -> Bool {
        guard isActive, !isCompleted else { return false }
        isCompleted = true
        isActive = false
        wasBroken = reason == .skipped
        return true
    }

    /// Idle / unused gate.
    public mutating func reset() {
        isActive = false
        isCompleted = false
        wasBroken = false
        startedAt = 0
    }
}

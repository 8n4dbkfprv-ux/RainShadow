import Foundation

/// Why a breakable cutscene ended. Skip and natural finish must apply the same
/// terminal game state; only presentation timing differs.
public enum CutsceneCompletionReason: String, Equatable, Sendable {
    case natural
    case skipped
}

/// BG:EE-style breakable cutscene gate: optional ESC/tap skip after a grace
/// window, with a single completion that cannot double-fire.
///
/// Pure value type — scenes own the gate and apply terminal state themselves
/// (dialogue resume, actor snap, door, chrome). Mirrors exterior
/// `completeCinematic` convergence without importing Infinity Engine scripting.
public struct BreakableCutsceneGate: Equatable, Sendable {
    public var isActive: Bool
    public var isCompleted: Bool
    public var startedAt: TimeInterval
    /// Seconds after `startedAt` before skip is accepted (exterior uses 1.0).
    public var graceSeconds: TimeInterval

    public static let defaultGraceSeconds: TimeInterval = 1.0

    public init(
        isActive: Bool = false,
        isCompleted: Bool = false,
        startedAt: TimeInterval = 0,
        graceSeconds: TimeInterval = BreakableCutsceneGate.defaultGraceSeconds
    ) {
        self.isActive = isActive
        self.isCompleted = isCompleted
        self.startedAt = startedAt
        self.graceSeconds = graceSeconds
    }

    /// Arms a new breakable sequence. Resets completion.
    public mutating func begin(at now: TimeInterval, graceSeconds: TimeInterval? = nil) {
        isActive = true
        isCompleted = false
        startedAt = now
        if let graceSeconds {
            self.graceSeconds = graceSeconds
        }
    }

    /// True when the sequence is running and the grace window has elapsed.
    public func canSkip(at now: TimeInterval) -> Bool {
        isActive && !isCompleted && now >= startedAt + graceSeconds
    }

    /// Marks the sequence finished. Returns `true` only on the first completion
    /// (natural or skip) so callers share one terminal apply path.
    @discardableResult
    public mutating func markCompleted() -> Bool {
        guard isActive, !isCompleted else { return false }
        isCompleted = true
        isActive = false
        return true
    }

    /// Idle / unused gate.
    public mutating func reset() {
        isActive = false
        isCompleted = false
        startedAt = 0
    }
}

/// Pure terminal narrative/UI state for the Empty Coat entrance cutscene.
/// Skip and natural finish must produce the same values before the scene applies them.
public struct ClientEntranceTerminalState: Equatable, Sendable {
    /// Dialogue node to open after the walk (deferred Continue destination).
    public var resumeDialogueNodeID: String?
    /// Free-play rails stay hidden for the whole visit (BG CutSceneMode chrome).
    public var keepCutsceneChromeSuppressed: Bool
    /// Dialogue panel returns after the walk.
    public var restoreDialoguePanel: Bool

    public init(
        resumeDialogueNodeID: String?,
        keepCutsceneChromeSuppressed: Bool = true,
        restoreDialoguePanel: Bool = true
    ) {
        self.resumeDialogueNodeID = resumeDialogueNodeID
        self.keepCutsceneChromeSuppressed = keepCutsceneChromeSuppressed
        self.restoreDialoguePanel = restoreDialoguePanel
    }

    /// Builds the terminal state used by both natural path completion and skip.
    public static func forDeferredEntrance(resumeDialogueNodeID: String?) -> ClientEntranceTerminalState {
        ClientEntranceTerminalState(
            resumeDialogueNodeID: resumeDialogueNodeID,
            keepCutsceneChromeSuppressed: true,
            restoreDialoguePanel: true
        )
    }
}

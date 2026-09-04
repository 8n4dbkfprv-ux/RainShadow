import Foundation

/// Holds a dialogue step whose **presentation** was postponed for a cinematic.
///
/// The Infinity Engine runs a transition's actions when the transition is taken and
/// only then plays whatever cutscene the actions started — the conversation has
/// already moved. RainShadow's presenter used to do that for player replies but the
/// opposite for Continue: it asked the scene whether to defer *before* calling
/// `advanceContinue()`, so a deferred Continue left the session parked on the node the
/// player had just left. That only worked because the single shipped cue happens to sit
/// on a Continue-only monologue node, and it made `onLeaveCue` unauthorable anywhere else.
///
/// With this type both paths advance the session first and defer only the view, so
/// "where the conversation is" never depends on which control the player used.
struct DialogueDeferralState: Equatable, Sendable {
    /// The step whose view is being held back, if any.
    private(set) var pending: DialogueStepResult?

    var isDeferred: Bool { pending != nil }

    init(pending: DialogueStepResult? = nil) {
        self.pending = pending
    }

    /// Record the outcome of a transition. A non-deferred step clears any stale hold,
    /// so an interrupted cinematic cannot resurrect an older node later.
    mutating func note(_ result: DialogueStepResult, deferred: Bool) {
        pending = deferred ? result : nil
    }

    /// Take the held step, if there is one. Draining is single-shot: a second resume
    /// (skip racing the natural finish, say) returns `nil` rather than replaying.
    mutating func resume() -> DialogueStepResult? {
        defer { pending = nil }
        return pending
    }

    mutating func clear() {
        pending = nil
    }
}

import Foundation
import Testing
@testable import RainShadowCore

/// The presenter lives in `UI/`, which `Package.swift` compiles into no test target, so
/// the deferral *decision* is extracted here where it can actually be asserted.
struct DialogueDeferralStateTests {
    private let node = CaseDialogueNode(id: "a", speaker: "Voss", text: "…")

    @Test func holdsOnlyWhenDeferred() {
        var state = DialogueDeferralState()
        #expect(!state.isDeferred)

        state.note(.showing(node), deferred: false)
        #expect(!state.isDeferred)
        #expect(state.pending == nil)

        state.note(.showing(node), deferred: true)
        #expect(state.isDeferred)
        #expect(state.pending == .showing(node))
    }

    /// A cinematic that never resumed must not leave a node primed to appear after an
    /// unrelated later transition.
    @Test func anUndeferredStepClearsAStaleHold() {
        var state = DialogueDeferralState(pending: .showing(node))
        #expect(state.isDeferred)

        state.note(.showing(CaseDialogueNode(id: "b", speaker: "Lila", text: "…")), deferred: false)

        #expect(!state.isDeferred)
    }

    /// Draining is single-shot: a skip racing the natural cinematic finish resumes twice,
    /// and the second must be a no-op rather than re-showing the node.
    @Test func resumeDrainsExactlyOnce() {
        var state = DialogueDeferralState()
        state.note(.showing(node), deferred: true)

        #expect(state.resume() == .showing(node))
        #expect(state.resume() == nil)
        #expect(!state.isDeferred)
    }

    /// A deferred reply can be the one that ends the conversation, so the hold has to
    /// carry `.finished` too — not just `.showing`.
    @Test func holdsATerminalStep() {
        var state = DialogueDeferralState()
        let finished = DialogueStepResult.finished(caseState: CaseState(caseID: "case.x"))
        state.note(finished, deferred: true)
        #expect(state.resume() == finished)
    }

    @Test func clearDropsTheHold() {
        var state = DialogueDeferralState(pending: .showing(node))
        state.clear()
        #expect(!state.isDeferred)
    }
}

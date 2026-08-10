import Foundation
import Testing
@testable import RainShadowCore

struct DialogueStateModelsTests {
    @Test func caseStateFlagSetGetClear() {
        var state = CaseState(caseID: "case.test")
        #expect(!state.hasFlag("alpha"))

        state.setFlag("alpha")
        #expect(state.hasFlag("alpha"))
        #expect(state.hasFlag(WorldFlag("alpha")))

        state.setFlag("alpha")
        #expect(state.flags == ["alpha"])

        state.clearFlag("alpha")
        #expect(!state.hasFlag("alpha"))

        state.clearFlag("alpha")
        #expect(state.flags.isEmpty)
    }

    @Test func caseStateGrantEvidenceAndKnowledge() {
        var state = CaseState(caseID: "case.test")
        state.grantEvidence("ev.tram-receipt")
        state.grantKnowledge("know.client-name")

        #expect(state.hasEvidence("ev.tram-receipt"))
        #expect(!state.hasEvidence("ev.other"))
        #expect(state.hasKnowledge("know.client-name"))
        #expect(!state.hasKnowledge("know.other"))
        #expect(!state.hasFlag("ev.tram-receipt"))
        #expect(state.evidenceIDs == ["ev.tram-receipt"])
        #expect(state.knowledgeIDs == ["know.client-name"])
    }

    @Test func dialogueStateConversationFlagsAndHistory() {
        var dialogue = DialogueState(graphID: EmptyCoatDialogueKeys.graphID, currentNodeID: "start")
        #expect(!dialogue.hasConversationFlag("pressed"))

        dialogue.setConversationFlag("pressed")
        #expect(dialogue.hasConversationFlag("pressed"))

        dialogue.clearConversationFlag("pressed")
        #expect(!dialogue.hasConversationFlag("pressed"))

        dialogue.advance(to: "npc.1")
        #expect(dialogue.currentNodeID == "npc.1")
        #expect(dialogue.choiceHistory.isEmpty)

        dialogue.recordChoice(destinationID: "npc.2")
        #expect(dialogue.currentNodeID == "npc.2")
        #expect(dialogue.choiceHistory == ["npc.2"])

        dialogue.recordChoice(destinationID: "npc.end")
        #expect(dialogue.currentNodeID == "npc.end")
        #expect(dialogue.choiceHistory == ["npc.2", "npc.end"])
    }

    @Test func caseStateCodableRoundTrip() throws {
        var state = CaseState(
            caseID: "case.test",
            flags: ["a", "b"],
            knowledgeIDs: ["k1"],
            evidenceIDs: ["e1", "e2"]
        )
        state.setFlag("c")

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CaseState.self, from: data)
        #expect(decoded == state)
    }

    @Test func dialogueStateCodableRoundTrip() throws {
        var dialogue = DialogueState(
            graphID: "graph.demo",
            currentNodeID: "n1",
            conversationFlags: ["local"],
            choiceHistory: ["n0"]
        )
        dialogue.recordChoice(destinationID: "n2")

        let data = try JSONEncoder().encode(dialogue)
        let decoded = try JSONDecoder().decode(DialogueState.self, from: data)
        #expect(decoded == dialogue)
    }

    @Test func worldFlagCodableRoundTrip() throws {
        let flag = WorldFlag("empty-coat.client-retained")
        let data = try JSONEncoder().encode(flag)
        let decoded = try JSONDecoder().decode(WorldFlag.self, from: data)
        #expect(decoded == flag)
        #expect(decoded.rawValue == "empty-coat.client-retained")
    }

    @Test func runtimeContextReadsCaseAndConversationFlags() {
        var caseState = CaseState(caseID: "case.test")
        var dialogueState = DialogueState(graphID: "g", currentNodeID: "n")

        var context = DialogueRuntimeContext(caseState: caseState, dialogueState: dialogueState)
        #expect(!context.hasFlag("shared"))
        #expect(!context.hasFlag("case-only"))
        #expect(!context.hasFlag("talk-only"))

        caseState.setFlag("case-only")
        caseState.grantEvidence("ev.x")
        caseState.grantKnowledge("know.y")
        context.caseState = caseState
        #expect(context.hasFlag("case-only"))
        #expect(context.hasEvidence("ev.x"))
        #expect(context.hasKnowledge("know.y"))
        #expect(!context.hasFlag("talk-only"))

        dialogueState.setConversationFlag("talk-only")
        context.dialogueState = dialogueState
        #expect(context.hasFlag("talk-only"))
        #expect(context.hasFlag("case-only"))
        #expect(!context.hasFlag("missing"))
    }

    @Test func emptyCoatCaseIDMatchesJournal() {
        let state = CaseState(caseID: EmptyCoatJournalContent.caseID)
        #expect(state.caseID == "case.empty-coat")
        #expect(state.caseID == EmptyCoatJournalContent.caseID)
        #expect(EmptyCoatDialogueKeys.graphID.hasPrefix("case.empty-coat"))
    }
}

extension DialogueStateModelsTests {
    /// `CaseState` is what `GameSession.persist()` has to write out, but `App/` is in
    /// no SPM target so no test can watch that mapping directly. Pin the shape instead:
    /// adding a field here fails this test, which forces the "does this persist?"
    /// decision to be made rather than skipped. That is how knowledge, evidence, and
    /// journal fragments were lost in the first place.
    @Test func caseStatePersistedSurfaceIsComplete() {
        let labels = Mirror(reflecting: CaseState(caseID: "case.x")).children.compactMap(\.label)
        #expect(Set(labels) == [
            "caseID",
            "flags",
            "knowledgeIDs",
            "evidenceIDs",
            "queuedJournalFragments",
            "counters"
        ])
    }

    /// IE reads an unassigned `Global` as 0 rather than erroring.
    @Test func unsetCountersReadAsZero() {
        var state = CaseState(caseID: "case.x")
        #expect(state.counter("talk.npc.lila-march") == 0)
        state.counters["talk.npc.lila-march"] = 3
        #expect(state.counter("talk.npc.lila-march") == 3)
    }
}

// MARK: - Session merge (dialogue result folded back into the case)

extension DialogueStateModelsTests {
    /// The defect this replaced: `formUnion` meant a flag the conversation cleared
    /// came straight back, so `clearCaseFlag` never did anything at session level.
    @Test func seededMergeLetsDialogueClearAFlag() {
        let live = CaseState(caseID: "case.x", flags: ["a", "b"])
        var result = live
        result.clearFlag("a")
        result.setFlag("c")

        let merged = live.applying(result, wasSeeded: true)

        #expect(merged.flags == ["b", "c"])
    }

    /// An unseeded result never saw "b", so it must not be read as having removed it.
    @Test func unseededMergeOnlyAdds() {
        let live = CaseState(caseID: "case.x", flags: ["b"])
        let result = CaseState(caseID: "case.x", flags: ["c"])

        let merged = live.applying(result, wasSeeded: false)

        #expect(merged.flags == ["b", "c"])
    }

    @Test func seededMergeCarriesKnowledgeEvidenceAndCounters() {
        var live = CaseState(caseID: "case.x")
        live.counters["talk.npc.lila-march"] = 1
        var result = live
        result.grantKnowledge("kn.lied-about-the-tram")
        result.grantEvidence("ev.tram-receipt")
        result.counters["talk.npc.lila-march"] = 2

        let merged = live.applying(result, wasSeeded: true)

        #expect(merged.knowledgeIDs == ["kn.lied-about-the-tram"])
        #expect(merged.evidenceIDs == ["ev.tram-receipt"])
        #expect(merged.counter("talk.npc.lila-march") == 2)
    }

    /// Fragments merge by id on both paths — there is no action that retracts one, and
    /// `queueJournal` is already replace-by-id, so re-merging is idempotent.
    @Test func journalFragmentsMergeByIDAndKeepOrder() {
        var live = CaseState(caseID: "case.x")
        live.queueJournal(QueuedJournalFragment(id: "one", kind: .chronology, text: "first"))
        var result = live
        result.queueJournal(QueuedJournalFragment(id: "one", kind: .chronology, text: "revised"))
        result.queueJournal(QueuedJournalFragment(id: "two", kind: .lead, text: "second"))

        let merged = live.applying(result, wasSeeded: true)

        #expect(merged.queuedJournalFragments.map(\.id) == ["one", "two"])
        #expect(merged.queuedJournalFragments.first?.text == "revised")
        #expect(merged.applying(result, wasSeeded: true) == merged)
    }

    @Test func emptyCaseIDAdoptsTheDialogueCaseID() {
        let live = CaseState(caseID: "")
        let merged = live.applying(CaseState(caseID: "case.empty-coat"), wasSeeded: true)
        #expect(merged.caseID == "case.empty-coat")
    }
}


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

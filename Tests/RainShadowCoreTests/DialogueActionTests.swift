import Foundation
import Testing
@testable import RainShadowCore

struct DialogueActionTests {
    private func emptyContext(caseID: String = "case.test") -> DialogueRuntimeContext {
        DialogueRuntimeContext(
            caseState: CaseState(caseID: caseID),
            dialogueState: DialogueState(graphID: "graph.test")
        )
    }

    @Test func setConversationFlagUnlocksSameTalkCondition() {
        var context = emptyContext()
        let gated = CaseDialogueChoice(
            text: "Press",
            destinationID: "n2",
            conditions: [.hasFlag("alpha")]
        )
        #expect(!gated.isAvailable(in: context))

        DialogueActionRuntime.apply(
            [.setConversationFlag("alpha")],
            to: &context
        )
        #expect(context.hasFlag("alpha"))
        #expect(gated.isAvailable(in: context))
    }

    @Test func setAndClearCaseFlag() {
        var context = emptyContext()
        DialogueActionRuntime.apply([.setCaseFlag("case.open")], to: &context)
        #expect(context.caseState.hasFlag("case.open"))
        #expect(context.hasFlag("case.open"))

        DialogueActionRuntime.apply([.clearCaseFlag("case.open")], to: &context)
        #expect(!context.caseState.hasFlag("case.open"))
    }

    @Test func grantEvidenceAndKnowledge() {
        var context = emptyContext()
        DialogueActionRuntime.apply(
            [
                .grantEvidence("ev.tram-receipt"),
                .grantKnowledge("know.client")
            ],
            to: &context
        )
        #expect(context.hasEvidence("ev.tram-receipt"))
        #expect(context.hasKnowledge("know.client"))
        #expect(!context.hasFlag("ev.tram-receipt"))
    }

    @Test func actionsApplyInOrder() {
        var context = emptyContext()
        DialogueActionRuntime.apply(
            [
                .setCaseFlag("a"),
                .clearCaseFlag("a"),
                .setConversationFlag("b")
            ],
            to: &context
        )
        #expect(!context.caseState.hasFlag("a"))
        #expect(context.dialogueState.hasConversationFlag("b"))
    }

    @Test func queueJournalAppendsAndReplacesByID() {
        var context = emptyContext()
        let first = QueuedJournalFragment(id: "chrono.1", kind: "chronology", text: "First")
        let second = QueuedJournalFragment(id: "chrono.2", kind: "lead", text: "Second")
        let updated = QueuedJournalFragment(id: "chrono.1", kind: "chronology", text: "First revised")

        DialogueActionRuntime.apply([.queueJournal(first), .queueJournal(second)], to: &context)
        #expect(context.caseState.queuedJournalFragments.map(\.id) == ["chrono.1", "chrono.2"])

        DialogueActionRuntime.apply([.queueJournal(updated)], to: &context)
        #expect(context.caseState.queuedJournalFragments.count == 2)
        #expect(context.caseState.queuedJournalFragments.first { $0.id == "chrono.1" }?.text == "First revised")
    }

    @Test func caseStateCodableIncludesQueuedFragments() throws {
        var state = CaseState(caseID: "case.test")
        state.queueJournal(
            QueuedJournalFragment(id: "c1", kind: "chronology", text: "Note")
        )
        state.setFlag("f1")
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(CaseState.self, from: data)
        #expect(decoded == state)
    }

    @Test func emptyCoatCynicalOnSelectUnlocksPress() {
        let nodes = EmptyCoatCaseIntroduction.nodes
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        guard
            let entrance = byID["lila.entrance.case"],
            let cynical = entrance.choices.first(where: { $0.tone == .cynicalSarcasm }),
            let keyTriad = byID["lila.triad.key"]
        else {
            Issue.record("Missing Empty Coat nodes for action test")
            return
        }

        #expect(
            cynical.onSelect == [
                .setConversationFlag(EmptyCoatDialogueKeys.pressedHardOnStory)
            ]
        )

        var context = DialogueRuntimeContext(
            caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
            dialogueState: DialogueState(graphID: EmptyCoatDialogueKeys.graphID)
        )
        #expect(CaseDialogueGraph.visibleChoices(keyTriad.choices, in: context).count == 3)

        DialogueActionRuntime.apply(cynical.onSelect, to: &context)
        let visible = CaseDialogueGraph.visibleChoices(keyTriad.choices, in: context)
        #expect(visible.count == 4)
        #expect(visible.contains { $0.destinationID == "lila.reply.press.gated" })
    }

    @Test func emptyCoatAcceptanceQueuesClientRetainedJournal() {
        let nodes = EmptyCoatCaseIntroduction.nodes
        let acceptanceChoices = nodes.flatMap(\.choices).filter {
            $0.destinationID == "lila.plea" && !$0.onSelect.isEmpty
        }
        #expect(!acceptanceChoices.isEmpty)

        var context = DialogueRuntimeContext(
            caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
            dialogueState: DialogueState(graphID: EmptyCoatDialogueKeys.graphID)
        )
        DialogueActionRuntime.apply(acceptanceChoices[0].onSelect, to: &context)

        #expect(context.caseState.hasFlag(EmptyCoatDialogueKeys.clientRetained))
        #expect(
            context.caseState.queuedJournalFragments.contains {
                $0.id == EmptyCoatDialogueKeys.clientRetainedJournalID
                    && $0.kind == "chronology"
                    && $0.text.contains("Empty Coat")
            }
        )
    }

    @Test func emptyCoatGraphReportsActionChoices() {
        let report = CaseDialogueGraph.report(
            nodes: EmptyCoatCaseIntroduction.nodes,
            startID: EmptyCoatCaseIntroduction.startNodeID
        )
        #expect(report.actionChoiceCount >= 2)
        #expect(report.isSound)
    }

    @Test func emptyCoatPressChoiceQueuesJournalFragment() {
        let nodes = EmptyCoatCaseIntroduction.nodes
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        guard
            let keyTriad = byID["lila.triad.key"],
            let press = keyTriad.choices.first(where: { $0.destinationID == "lila.reply.press.gated" })
        else {
            Issue.record("Missing Press choice")
            return
        }
        #expect(
            press.onSelect.contains {
                if case .queueJournal(let fragment) = $0 {
                    return fragment.id == EmptyCoatDialogueKeys.pressedHardJournalID
                }
                return false
            }
        )

        var context = DialogueRuntimeContext(
            caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
            dialogueState: DialogueState(graphID: EmptyCoatDialogueKeys.graphID)
        )
        DialogueActionRuntime.apply(press.onSelect, to: &context)
        #expect(
            context.caseState.queuedJournalFragments.contains {
                $0.id == EmptyCoatDialogueKeys.pressedHardJournalID
            }
        )
    }
}

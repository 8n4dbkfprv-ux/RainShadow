import Foundation
import Testing
@testable import RainShadowCore

struct DialogueConditionTests {
    private func emptyContext(caseID: String = "case.test") -> DialogueRuntimeContext {
        DialogueRuntimeContext(
            caseState: CaseState(caseID: caseID),
            dialogueState: DialogueState(graphID: "graph.test")
        )
    }

    @Test func emptyConditionsAlwaysVisible() {
        let choice = CaseDialogueChoice(text: "Hello", destinationID: "n1")
        #expect(choice.isAvailable(in: emptyContext()))
        #expect(choice.conditions.isEmpty)
    }

    @Test func hasFlagFiltersCaseAndConversation() {
        var context = emptyContext()
        let choice = CaseDialogueChoice(
            text: "Press",
            destinationID: "n2",
            conditions: [.hasFlag("alpha")]
        )
        #expect(!choice.isAvailable(in: context))

        context.caseState.setFlag("alpha")
        #expect(choice.isAvailable(in: context))

        context.caseState.clearFlag("alpha")
        context.dialogueState.setConversationFlag("alpha")
        #expect(choice.isAvailable(in: context))
        #expect(context.hasFlag("alpha"))
    }

    @Test func hasEvidenceAndKnowledgeIndependentOfFlags() {
        var context = emptyContext()
        let evidenceChoice = CaseDialogueChoice(
            text: "Show receipt",
            destinationID: "n3",
            conditions: [.hasEvidence("ev.tram-receipt")]
        )
        let knowledgeChoice = CaseDialogueChoice(
            text: "Name drop",
            destinationID: "n4",
            conditions: [.hasKnowledge("know.client-name")]
        )

        #expect(!evidenceChoice.isAvailable(in: context))
        #expect(!knowledgeChoice.isAvailable(in: context))

        context.caseState.setFlag("ev.tram-receipt")
        #expect(!evidenceChoice.isAvailable(in: context))

        context.caseState.grantEvidence("ev.tram-receipt")
        #expect(evidenceChoice.isAvailable(in: context))
        #expect(!knowledgeChoice.isAvailable(in: context))

        context.caseState.grantKnowledge("know.client-name")
        #expect(knowledgeChoice.isAvailable(in: context))
    }

    @Test func andSemanticsRequireAllConditions() {
        var context = emptyContext()
        let choice = CaseDialogueChoice(
            text: "Both",
            destinationID: "n5",
            conditions: [.hasFlag("a"), .hasEvidence("ev.x")]
        )
        context.caseState.setFlag("a")
        #expect(!choice.isAvailable(in: context))
        context.caseState.grantEvidence("ev.x")
        #expect(choice.isAvailable(in: context))
    }

    @Test func disclosureLabelsHumanizeEvidenceAndAllowOverride() {
        let evidence = DialogueCondition.hasEvidence("ev.tram-receipt")
        #expect(evidence.disclosureLabel == "Evidence: Tram Receipt")

        let knowledge = DialogueCondition.hasKnowledge("know.sister-name")
        #expect(knowledge.disclosureLabel == "Knowledge: Sister Name")

        #expect(DialogueCondition.hasFlag("x").disclosureLabel == nil)

        let overridden = CaseDialogueChoice(
            text: "Push her",
            destinationID: "n6",
            conditions: [.hasFlag("x")],
            gateDisclosure: "Press"
        )
        #expect(overridden.resolvedGateDisclosure == nil)
        #expect(overridden.displayText(index: 2) == "3:  Push her")
        #expect(overridden.labeledBodyText == "Push her")

        let auto = CaseDialogueChoice(
            text: "Show it",
            destinationID: "n7",
            conditions: [.hasEvidence("ev.tram-receipt")]
        )
        #expect(auto.displayText(index: 0) == "1:  [Evidence: Tram Receipt]  Show it")

        // Intention is author method, not a row prefix. Evidence still discloses.
        let withIntention = CaseDialogueChoice(
            text: "Come in out of the wet.",
            destinationID: "n8",
            intention: .open
        )
        #expect(withIntention.labeledBodyText == "Come in out of the wet.")
        #expect(withIntention.displayText(index: 0) == "1:  Come in out of the wet.")

        let pressWithIntention = CaseDialogueChoice(
            text: "What are you not saying?",
            destinationID: "n9",
            intention: .press,
            conditions: [.hasFlag("x")],
            gateDisclosure: "Press"
        )
        #expect(pressWithIntention.rowPrefixLabels == [])
        #expect(pressWithIntention.labeledBodyText == "What are you not saying?")

        let intentionPlusEvidence = CaseDialogueChoice(
            text: "Show the receipt.",
            destinationID: "n10",
            intention: .press,
            conditions: [.hasEvidence("ev.tram-receipt")]
        )
        #expect(intentionPlusEvidence.rowPrefixLabels == ["Evidence: Tram Receipt"])
        #expect(
            intentionPlusEvidence.labeledBodyText
                == "[Evidence: Tram Receipt]  Show the receipt."
        )
    }

    @Test func visibleChoicesPreservesOrderAndFilters() {
        var context = emptyContext()
        let choices = [
            CaseDialogueChoice(text: "Always", destinationID: "a"),
            CaseDialogueChoice(
                text: "Gated",
                destinationID: "b",
                conditions: [.hasFlag("need")]
            ),
            CaseDialogueChoice(text: "Also always", destinationID: "c")
        ]

        let hidden = CaseDialogueGraph.visibleChoices(choices, in: context)
        #expect(hidden.map(\.destinationID) == ["a", "c"])
        #expect(hidden[0].displayText(index: 0).hasPrefix("1:"))
        #expect(hidden[1].displayText(index: 1).hasPrefix("2:"))

        context.dialogueState.setConversationFlag("need")
        let shown = CaseDialogueGraph.visibleChoices(choices, in: context)
        #expect(shown.map(\.destinationID) == ["a", "b", "c"])
    }

    @Test func softStuckWhenOnlyGatedChoicesAndNoContinue() {
        let node = CaseDialogueNode(
            id: "dead",
            speaker: "Lila March",
            text: "…",
            choices: [
                CaseDialogueChoice(
                    text: "Secret",
                    destinationID: "x",
                    conditions: [.hasFlag("never")]
                )
            ]
        )
        let visible = CaseDialogueGraph.visibleChoices(node.choices, in: emptyContext())
        #expect(CaseDialogueGraph.isSoftStuck(node: node, visibleChoices: visible))

        let withContinue = CaseDialogueNode(
            id: "ok",
            speaker: "Lila March",
            text: "…",
            choices: node.choices,
            nextNodeID: "next"
        )
        #expect(!CaseDialogueGraph.isSoftStuck(node: withContinue, visibleChoices: visible))
    }

    @Test func emptyCoatPressGateUnlocksAfterCynicalGrantFlag() throws {
        let nodes = EmptyCoatCaseIntroduction.nodes
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let keyTriad = try #require(byID["lila.triad.key"])
        let press = try #require(keyTriad.choices.first { $0.destinationID == "lila.reply.press.gated" })
        #expect(press.conditions == [.hasFlag(EmptyCoatDialogueKeys.pressedHardOnStory)])
        #expect(press.intention == .press)
        #expect(press.resolvedGateDisclosure == nil)

        var context = DialogueRuntimeContext(
            caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
            dialogueState: DialogueState(graphID: EmptyCoatDialogueKeys.graphID)
        )
        #expect(CaseDialogueGraph.visibleChoices(keyTriad.choices, in: context).count == 3)

        context.dialogueState.setConversationFlag(EmptyCoatDialogueKeys.pressedHardOnStory)
        let visible = CaseDialogueGraph.visibleChoices(keyTriad.choices, in: context)
        #expect(visible.count == 4)
        #expect(visible.contains { $0.destinationID == "lila.reply.press.gated" })

        let entrance = try #require(byID["lila.entrance.case"])
        let cynical = try #require(entrance.choices.first { $0.tone == .cynicalSarcasm })
        #expect(
            cynical.onSelect == [
                .setConversationFlag(EmptyCoatDialogueKeys.pressedHardOnStory)
            ]
        )
    }
}

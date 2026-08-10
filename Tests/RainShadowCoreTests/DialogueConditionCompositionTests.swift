import Foundation
import Testing
@testable import RainShadowCore

/// The Infinity Engine gives authors exactly two trigger combinators: a `!` prefix and
/// `OR(n)`. RainShadow's condition list was AND-only, so "unless" and "either" gates
/// were simply unwritable. These cover the two new shapes and their disclosure rules.
struct DialogueConditionCompositionTests {
    private func context(
        flags: Set<String> = [],
        evidence: Set<String> = [],
        knowledge: Set<String> = []
    ) -> DialogueRuntimeContext {
        DialogueRuntimeContext(
            caseState: CaseState(
                caseID: "case.x",
                flags: flags,
                knowledgeIDs: knowledge,
                evidenceIDs: evidence
            ),
            dialogueState: DialogueState(graphID: "g")
        )
    }

    @Test func notInvertsALeaf() {
        let condition = DialogueCondition.not(.hasFlag("f"))
        #expect(condition.isSatisfied(by: context()))
        #expect(!condition.isSatisfied(by: context(flags: ["f"])))
    }

    @Test func anyIsTrueWhenAnyChildPasses() {
        let condition = DialogueCondition.any([.hasEvidence("ev.receipt"), .hasKnowledge("kn.lie")])
        #expect(!condition.isSatisfied(by: context()))
        #expect(condition.isSatisfied(by: context(evidence: ["ev.receipt"])))
        #expect(condition.isSatisfied(by: context(knowledge: ["kn.lie"])))
    }

    /// "Any of nothing" holds for no reason; "all of nothing" matches `allSatisfy` and
    /// IE's untriggered state, which always fires.
    @Test func emptyCompositesFollowTheirOperator() {
        #expect(!DialogueCondition.any([]).isSatisfied(by: context()))
        #expect(DialogueCondition.all([]).isSatisfied(by: context()))
    }

    @Test func compositesNestBothWays() {
        // Show the line when we have the receipt, unless she already confessed.
        let condition = DialogueCondition.all([
            .any([.hasEvidence("ev.receipt"), .hasKnowledge("kn.lie")]),
            .not(.hasFlag("lila.confessed"))
        ])
        #expect(condition.isSatisfied(by: context(evidence: ["ev.receipt"])))
        #expect(!condition.isSatisfied(by: context(flags: ["lila.confessed"], evidence: ["ev.receipt"])))
        #expect(!condition.isSatisfied(by: context(flags: ["lila.confessed"])))
    }

    /// A negation must never disclose. `[Evidence: Tram Receipt]` on a `.not` would
    /// advertise the receipt to a player precisely because they do not have it.
    @Test func negationNeverDiscloses() {
        #expect(DialogueCondition.not(.hasEvidence("ev.tram-receipt")).disclosureLabel == nil)
        #expect(DialogueCondition.hasEvidence("ev.tram-receipt").disclosureLabel == "Evidence: Tram Receipt")
    }

    @Test func compositeDisclosureTakesTheFirstLabelledChild() {
        let condition = DialogueCondition.any([
            .hasFlag("silent"),
            .hasEvidence("ev.tram-receipt"),
            .hasKnowledge("kn.lie")
        ])
        #expect(condition.disclosureLabel == "Evidence: Tram Receipt")
    }

    @Test func depthCountsNestingAndLeavesAreOne() {
        #expect(DialogueCondition.hasFlag("f").depth == 1)
        #expect(DialogueCondition.not(.hasFlag("f")).depth == 2)
        #expect(DialogueCondition.any([.hasFlag("a"), .not(.hasFlag("b"))]).depth == 3)
    }

    @Test func referencedIDsReachThroughComposites() {
        let condition = DialogueCondition.all([
            .any([.hasEvidence("ev.receipt"), .hasKnowledge("kn.lie")]),
            .not(.hasFlag("lila.confessed"))
        ])
        #expect(condition.referencedIDs == ["ev.receipt", "kn.lie", "lila.confessed"])
    }

    @Test func compositesRoundTripThroughJSON() throws {
        let original = DialogueCondition.all([
            .any([.hasEvidence("ev.receipt"), .not(.hasKnowledge("kn.lie"))]),
            .hasFlag("f")
        ])
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(DialogueCondition.self, from: data) == original)
    }

    /// Shipped graphs are untouched by this change: a top-level `conditions` array is
    /// still ANDed, so leaf-only JSON decodes exactly as before.
    @Test func leafOnlyJSONStillDecodes() throws {
        let json = Data(#"{"type":"hasFlag","id":"empty-coat.dialogue.pressed-hard-on-story"}"#.utf8)
        let decoded = try JSONDecoder().decode(DialogueCondition.self, from: json)
        #expect(decoded == .hasFlag("empty-coat.dialogue.pressed-hard-on-story"))
    }

    @Test func loaderRejectsConditionsNestedPastTheAuthoringLimit() throws {
        var condition = DialogueCondition.hasFlag("f")
        for _ in 0..<DialogueCondition.maximumNestingDepth {
            condition = .not(condition)
        }
        let graph = DialogueGraph(
            id: "deep",
            startNodeID: "a",
            nodes: [
                CaseDialogueNode(
                    id: "a",
                    speaker: "S",
                    text: "T",
                    choices: [
                        CaseDialogueChoice(text: "Go", destinationID: "b", conditions: [condition])
                    ]
                ),
                CaseDialogueNode(id: "b", speaker: "S", text: "T", endsDialogue: true)
            ]
        )

        #expect(throws: DialogueGraphLoaderError.self) {
            try graph.validateAuthoring()
        }
    }
}

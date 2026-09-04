import Foundation
import Testing
@testable import RainShadowCore

/// RainShadow's flags are a `Set<String>` — boolean intent only. The Infinity Engine's
/// `Global` is an integer, and a good deal of BG's dialogue reactivity is arithmetic on
/// it (`GlobalGT`, `IncrementGlobal`, and the talk counts behind `NumTimesTalkedTo`).
/// Flags stay for boolean intent; counters cover the rest.
struct DialogueCounterTests {
    private func context(counters: [String: Int] = [:]) -> DialogueRuntimeContext {
        DialogueRuntimeContext(
            caseState: CaseState(caseID: "case.x", counters: counters),
            dialogueState: DialogueState(graphID: "g")
        )
    }

    @Test func comparisonsMatchTheirInfinityEngineTriggers() {
        let atLeastTwo = DialogueCondition.counterAtLeast("visits", 2)
        #expect(!atLeastTwo.isSatisfied(by: context()))
        #expect(!atLeastTwo.isSatisfied(by: context(counters: ["visits": 1])))
        #expect(atLeastTwo.isSatisfied(by: context(counters: ["visits": 2])))
        #expect(atLeastTwo.isSatisfied(by: context(counters: ["visits": 9])))

        let atMostOne = DialogueCondition.counterAtMost("visits", 1)
        #expect(atMostOne.isSatisfied(by: context()))
        #expect(!atMostOne.isSatisfied(by: context(counters: ["visits": 2])))

        let exactlyTwo = DialogueCondition.counterEquals("visits", 2)
        #expect(exactlyTwo.isSatisfied(by: context(counters: ["visits": 2])))
        #expect(!exactlyTwo.isSatisfied(by: context(counters: ["visits": 3])))
    }

    /// An unassigned `Global` is 0 in IE, not an error — so a first-visit gate can be
    /// written without seeding anything.
    @Test func unsetCountersCompareAsZero() {
        #expect(DialogueCondition.counterEquals("visits", 0).isSatisfied(by: context()))
        #expect(DialogueCondition.counterAtMost("visits", 0).isSatisfied(by: context()))
    }

    @Test func setAndAddActionsApply() {
        var ctx = context()
        DialogueActionRuntime.apply([.setCounter("visits", 3)], to: &ctx)
        #expect(ctx.counter("visits") == 3)

        DialogueActionRuntime.apply([.addToCounter("visits", 2)], to: &ctx)
        #expect(ctx.counter("visits") == 5)

        DialogueActionRuntime.apply([.addToCounter("visits", -5)], to: &ctx)
        #expect(ctx.counter("visits") == 0)
    }

    /// `IncrementGlobal` on an unset variable starts from zero rather than doing nothing.
    @Test func addingToAnUnsetCounterStartsFromZero() {
        var ctx = context()
        DialogueActionRuntime.apply([.addToCounter("visits", 1)], to: &ctx)
        #expect(ctx.counter("visits") == 1)
    }

    @Test func counterConditionsAndActionsRoundTripThroughJSON() throws {
        let conditions: [DialogueCondition] = [
            .counterAtLeast("visits", 2),
            .counterAtMost("visits", 5),
            .counterEquals("visits", 3),
            .not(.counterAtLeast("visits", 9))
        ]
        let conditionData = try JSONEncoder().encode(conditions)
        #expect(try JSONDecoder().decode([DialogueCondition].self, from: conditionData) == conditions)

        let actions: [DialogueAction] = [.setCounter("visits", 1), .addToCounter("visits", -2)]
        let actionData = try JSONEncoder().encode(actions)
        #expect(try JSONDecoder().decode([DialogueAction].self, from: actionData) == actions)
    }

    /// Counter ids take part in gate-reference validation the same way flags do, so a
    /// typo'd counter name shows up in `externallySuppliedConditionIDs`.
    @Test func counterIDsParticipateInIntegrityReporting() {
        let nodes = [
            CaseDialogueNode(
                id: "a",
                speaker: "S",
                text: "T",
                choices: [
                    CaseDialogueChoice(
                        text: "Again",
                        destinationID: "b",
                        conditions: [.counterAtLeast("visits", 1)],
                        onSelect: [.addToCounter("visits", 1)]
                    ),
                    CaseDialogueChoice(
                        text: "Typo",
                        destinationID: "b",
                        conditions: [.counterAtLeast("vists", 1)]
                    )
                ]
            ),
            CaseDialogueNode(id: "b", speaker: "S", text: "T", endsDialogue: true)
        ]

        let report = CaseDialogueGraph.report(nodes: nodes, startID: "a")

        #expect(report.conditionLeafIDs == ["visits", "vists"])
        #expect(report.actionWrittenStateIDs == ["visits"])
        #expect(report.externallySuppliedConditionIDs == ["vists"])
    }

    /// Counters are bookkeeping, not a player-facing gate reason.
    @Test func counterGatesStaySilentInTheChoiceRow() {
        #expect(DialogueCondition.counterAtLeast("visits", 2).disclosureLabel == nil)
    }

    @Test func countersSurviveTheSessionMerge() {
        var live = CaseState(caseID: "case.x", counters: ["visits": 1])
        var result = live
        result.addToCounter("visits", 1)
        live = live.applying(result, wasSeeded: true)
        #expect(live.counter("visits") == 2)
    }
}

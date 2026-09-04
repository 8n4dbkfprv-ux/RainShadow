import Foundation
import Testing
@testable import RainShadowCore

/// Area scripts, and the ordering rule that makes a script a list of priorities
/// rather than a set of rules.
struct AreaScriptTests {

    static let office = HarborpointAreas.office

    static func context(
        variables: AreaVariables = AreaVariables(),
        flags: Set<String> = []
    ) -> AreaScriptContext {
        var caseState = CaseState(caseID: "test")
        caseState.flags = flags
        return AreaScriptContext(
            area: office,
            variables: variables,
            dialogue: DialogueRuntimeContext(
                caseState: caseState,
                dialogueState: DialogueState(graphID: "test")
            )
        )
    }

    // MARK: - Ordering

    /// A Baldur's Gate `BCS` runs top down and stops at the first satisfied
    /// block. A runner that fired every match would run the idle behaviour
    /// alongside the emergency it was meant to pre-empt.
    @Test func onlyTheFirstSatisfiedBlockFires() {
        let script = AreaScript(id: "s", blocks: [
            AreaScriptBlock(id: "urgent", when: .variableIsSet("ALARM"),
                            do: [.setVariable("HANDLED", .integer(1))]),
            AreaScriptBlock(id: "idle", when: .always,
                            do: [.setVariable("IDLED", .integer(1))])
        ])

        var vars = AreaVariables()
        vars.setFlag(true, "ALARM", in: Self.office)
        let outcome = AreaScriptRunner.tick(script, in: Self.context(variables: vars))

        #expect(outcome.blockID == "urgent")
        #expect(outcome.variables.integer("HANDLED", in: Self.office) == 1)
        #expect(
            outcome.variables.integer("IDLED", in: Self.office) == 0,
            "the idle block ran alongside the urgent one"
        )
    }

    @Test func aLaterBlockFiresWhenTheEarlierOneDoesNot() {
        let script = AreaScript(id: "s", blocks: [
            AreaScriptBlock(id: "urgent", when: .variableIsSet("ALARM"), do: []),
            AreaScriptBlock(id: "idle", when: .always,
                            do: [.setVariable("IDLED", .integer(1))])
        ])
        let outcome = AreaScriptRunner.tick(script, in: Self.context())
        #expect(outcome.blockID == "idle")
        #expect(outcome.variables.integer("IDLED", in: Self.office) == 1)
    }

    @Test func aScriptWithNothingSatisfiedDoesNothing() {
        let script = AreaScript(id: "s", blocks: [
            AreaScriptBlock(id: "never", when: .variableIsSet("NOPE"),
                            do: [.setVariable("X", .integer(1))])
        ])
        let outcome = AreaScriptRunner.tick(script, in: Self.context())
        #expect(!outcome.didFire)
        #expect(outcome.actions.isEmpty)
        #expect(outcome.variables.isEmpty)
    }

    // MARK: - Conditions

    @Test func aBareVariableNameResolvesInTheScriptsOwnArea() {
        var vars = AreaVariables()
        vars.setFlag(true, "SEEN", in: HarborpointAreas.sableRow)
        // Same name, different area: the office's script must not see it.
        #expect(!AreaScriptCondition.variableIsSet("SEEN")
            .isSatisfied(by: Self.context(variables: vars)))

        vars.setFlag(true, "SEEN", in: Self.office)
        #expect(AreaScriptCondition.variableIsSet("SEEN")
            .isSatisfied(by: Self.context(variables: vars)))
    }

    @Test func theGlobalScopeIsReachableFromAnyArea() {
        var vars = AreaVariables()
        vars.setFlag(true, "ACT", in: AreaVariables.globalScope)
        #expect(AreaScriptCondition.globalIsSet("ACT")
            .isSatisfied(by: Self.context(variables: vars)))
        #expect(!AreaScriptCondition.variableIsSet("ACT")
            .isSatisfied(by: Self.context(variables: vars)))
    }

    /// The point of wrapping rather than reinventing: a script asks about case
    /// flags in the same language the shipped dialogue already uses.
    @Test func aScriptCanAskWhatDialogueAsks() {
        let condition = AreaScriptCondition.caseCondition(.hasFlag("empty-coat.accepted"))
        #expect(!condition.isSatisfied(by: Self.context()))
        #expect(condition.isSatisfied(by: Self.context(flags: ["empty-coat.accepted"])))
    }

    @Test func combinatorsNestAreaAndCaseQuestionsTogether() {
        var vars = AreaVariables()
        vars.setInteger(2, "VISITS", in: Self.office)
        let condition = AreaScriptCondition.all([
            .variableAtLeast("VISITS", 2),
            .not(.caseCondition(.hasFlag("done"))),
            .any([.variableEquals("VISITS", 9), .variableEquals("VISITS", 2)])
        ])
        #expect(condition.isSatisfied(by: Self.context(variables: vars)))
        #expect(!condition.isSatisfied(by: Self.context(variables: vars, flags: ["done"])))
    }

    // MARK: - Actions

    @Test func variableWritesAreAppliedAndCaseActionsAreHandedBack() {
        let script = AreaScript(id: "s", blocks: [
            AreaScriptBlock(id: "b", do: [
                .incrementVariable("VISITS", by: 1),
                .setGlobal("ACT", .integer(2)),
                .caseAction(.setCaseFlag("arrived")),
                .startCutscene("office.clientEntrance")
            ])
        ])
        let outcome = AreaScriptRunner.tick(script, in: Self.context())

        // The script owns its variables.
        #expect(outcome.variables.integer("VISITS", in: Self.office) == 1)
        #expect(outcome.variables.integer("ACT", in: AreaVariables.globalScope) == 2)
        // Everything else is handed back for the caller to apply, because case
        // state and the cutscene director live outside this target.
        #expect(outcome.actions.contains(.caseAction(.setCaseFlag("arrived"))))
        #expect(outcome.actions.contains(.startCutscene("office.clientEntrance")))
    }

    /// Ticking twice must not double-apply unless the script says so — the
    /// script is responsible for its own guard, exactly as a `BCS` is.
    @Test func aScriptGuardsItsOwnRepetition() {
        let script = AreaScript(id: "s", blocks: [
            AreaScriptBlock(id: "once", when: .not(.variableIsSet("DONE")), do: [
                .incrementVariable("RUNS", by: 1),
                .setVariable("DONE", .integer(1))
            ])
        ])
        var context = Self.context()
        var last = AreaScriptRunner.tick(script, in: context)
        context.variables = last.variables
        last = AreaScriptRunner.tick(script, in: context)

        #expect(!last.didFire, "the guarded block fired a second time")
        #expect(last.variables.integer("RUNS", in: Self.office) == 1)
    }
}

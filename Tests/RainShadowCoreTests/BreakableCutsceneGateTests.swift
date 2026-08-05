import Testing
@testable import RainShadowCore

struct BreakableCutsceneGateTests {
    @Test func graceWindowBlocksSkipThenAllowsIt() {
        var gate = BreakableCutsceneGate(graceSeconds: 1.0)
        gate.begin(at: 10.0)
        #expect(gate.isActive)
        #expect(!gate.isCompleted)
        #expect(!gate.canSkip(at: 10.0))
        #expect(!gate.canSkip(at: 10.99))
        #expect(gate.canSkip(at: 11.0))
        #expect(gate.canSkip(at: 12.5))
    }

    @Test func markCompletedIsSingleFireForNaturalAndSkip() {
        var gate = BreakableCutsceneGate(graceSeconds: 0.5)
        gate.begin(at: 0)
        let first = gate.markCompleted()
        #expect(first)
        #expect(gate.isCompleted)
        #expect(!gate.isActive)
        let second = gate.markCompleted()
        #expect(!second, "Second complete must no-op (skip + natural share one path)")
        #expect(!gate.canSkip(at: 100))
    }

    @Test func resetClearsCompletionForReuse() {
        var gate = BreakableCutsceneGate()
        gate.begin(at: 1)
        let first = gate.markCompleted()
        #expect(first)
        gate.reset()
        #expect(!gate.isActive)
        #expect(!gate.isCompleted)
        gate.begin(at: 5, graceSeconds: 0.25)
        #expect(gate.canSkip(at: 5.25))
        let second = gate.markCompleted()
        #expect(second)
    }

    @Test func entranceTerminalStateMatchesSkipAndNaturalContract() {
        let a = ClientEntranceTerminalState.forDeferredEntrance(resumeDialogueNodeID: "voss.monologue.5")
        let b = ClientEntranceTerminalState.forDeferredEntrance(resumeDialogueNodeID: "voss.monologue.5")
        #expect(a == b)
        #expect(a.keepCutsceneChromeSuppressed)
        #expect(a.restoreDialoguePanel)
        #expect(a.resumeDialogueNodeID == "voss.monologue.5")
    }

    @Test func defaultGraceMatchesExteriorOpening() {
        #expect(BreakableCutsceneGate.defaultGraceSeconds == 1.0)
    }
}
